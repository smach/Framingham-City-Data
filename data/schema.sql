-- SQLite Database Schema for Framingham Election Data
-- Version: 1.0
-- Normalized structure with proper foreign keys

-- ============================================
-- DIMENSION TABLES
-- ============================================

-- Elections catalog
CREATE TABLE IF NOT EXISTS elections (
    election_id INTEGER PRIMARY KEY AUTOINCREMENT,
    election_date DATE NOT NULL,
    election_year INTEGER NOT NULL,
    election_type TEXT NOT NULL CHECK(election_type IN ('general', 'preliminary', 'primary', 'special', 'charter')),
    election_level TEXT NOT NULL CHECK(election_level IN ('municipal', 'state', 'federal')),
    description TEXT,
    is_official BOOLEAN DEFAULT 1,
    UNIQUE(election_date, election_type, election_level)
);

-- Precincts (with temporal validity for redistricting)
CREATE TABLE IF NOT EXISTS precincts (
    precinct_id INTEGER PRIMARY KEY AUTOINCREMENT,
    precinct_number TEXT NOT NULL,  -- Can be "1", "2", "1A", "1B" etc.
    district_number INTEGER,
    valid_from DATE,
    valid_to DATE,
    notes TEXT,
    UNIQUE(precinct_number, valid_from)
);

-- Races within elections
CREATE TABLE IF NOT EXISTS races (
    race_id INTEGER PRIMARY KEY AUTOINCREMENT,
    election_id INTEGER NOT NULL REFERENCES elections(election_id) ON DELETE CASCADE,
    race_code TEXT NOT NULL,  -- 'mayor', 'council_2', 'sc_at_large', etc.
    race_name TEXT NOT NULL,  -- Display name
    office TEXT,  -- Original office name from file
    district TEXT,  -- District number, 'at_large', or NULL
    num_winners INTEGER DEFAULT 1 CHECK(num_winners >= 1),
    office_level TEXT CHECK(office_level IN ('municipal', 'state', 'federal')),
    is_primary BOOLEAN DEFAULT 0,
    party TEXT,  -- 'democratic', 'republican', etc. for primaries
    UNIQUE(election_id, race_code)
);

-- Candidates
CREATE TABLE IF NOT EXISTS candidates (
    candidate_id INTEGER PRIMARY KEY AUTOINCREMENT,
    candidate_short_name TEXT NOT NULL,  -- Last name or short reference
    candidate_full_name TEXT,  -- Full name as appears on ballot
    normalized_name TEXT,  -- For matching across elections
    is_special BOOLEAN DEFAULT 0,  -- TRUE for "Blanks", "Write-in", "YES", "NO"
    UNIQUE(candidate_short_name, candidate_full_name)
);

-- ============================================
-- FACT TABLES
-- ============================================

-- Election results (many-to-many: races x candidates x precincts)
CREATE TABLE IF NOT EXISTS results (
    result_id INTEGER PRIMARY KEY AUTOINCREMENT,
    race_id INTEGER NOT NULL REFERENCES races(race_id) ON DELETE CASCADE,
    candidate_id INTEGER NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    precinct_id INTEGER NOT NULL REFERENCES precincts(precinct_id),
    votes INTEGER NOT NULL CHECK(votes >= 0),
    UNIQUE(race_id, candidate_id, precinct_id)
);

-- Turnout data (separate table, can be joined via election_id + precinct_id)
CREATE TABLE IF NOT EXISTS turnout (
    turnout_id INTEGER PRIMARY KEY AUTOINCREMENT,
    election_id INTEGER NOT NULL REFERENCES elections(election_id) ON DELETE CASCADE,
    precinct_id INTEGER NOT NULL REFERENCES precincts(precinct_id),
    votes_cast INTEGER NOT NULL CHECK(votes_cast >= 0),
    total_registered INTEGER NOT NULL CHECK(total_registered >= 0),
    pct_turnout REAL,  -- Calculated percentage
    UNIQUE(election_id, precinct_id)
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX IF NOT EXISTS idx_results_race ON results(race_id);
CREATE INDEX IF NOT EXISTS idx_results_candidate ON results(candidate_id);
CREATE INDEX IF NOT EXISTS idx_results_precinct ON results(precinct_id);
CREATE INDEX IF NOT EXISTS idx_races_election ON races(election_id);
CREATE INDEX IF NOT EXISTS idx_turnout_election ON turnout(election_id);
CREATE INDEX IF NOT EXISTS idx_turnout_precinct ON turnout(precinct_id);
CREATE INDEX IF NOT EXISTS idx_elections_date ON elections(election_date);
CREATE INDEX IF NOT EXISTS idx_precincts_valid_dates ON precincts(valid_from, valid_to);

-- ============================================
-- VIEWS FOR COMMON QUERIES
-- ============================================

-- Complete results with all metadata (denormalized for easy querying)
CREATE VIEW IF NOT EXISTS v_results_complete AS
SELECT
    e.election_date,
    e.election_year,
    e.election_type,
    e.election_level,
    r.race_code,
    r.race_name,
    r.office,
    r.district,
    r.num_winners,
    r.is_primary,
    r.party,
    c.candidate_short_name AS candidate,
    c.candidate_full_name,
    p.precinct_number AS precinct,
    p.district_number AS precinct_district,
    res.votes
FROM results res
JOIN races r ON res.race_id = r.race_id
JOIN elections e ON r.election_id = e.election_id
JOIN candidates c ON res.candidate_id = c.candidate_id
JOIN precincts p ON res.precinct_id = p.precinct_id
WHERE e.election_date >= p.valid_from
  AND (p.valid_to IS NULL OR e.election_date <= p.valid_to);

-- Complete turnout with all metadata
CREATE VIEW IF NOT EXISTS v_turnout_complete AS
SELECT
    e.election_date,
    e.election_year,
    e.election_type,
    e.election_level,
    p.precinct_number AS precinct,
    p.district_number AS district,
    t.votes_cast,
    t.total_registered,
    t.pct_turnout
FROM turnout t
JOIN elections e ON t.election_id = e.election_id
JOIN precincts p ON t.precinct_id = p.precinct_id
WHERE e.election_date >= p.valid_from
  AND (p.valid_to IS NULL OR e.election_date <= p.valid_to);

-- Mayor results across all elections (example aggregate view)
CREATE VIEW IF NOT EXISTS v_mayor_results AS
SELECT
    election_date,
    election_type,
    candidate_full_name,
    SUM(votes) AS total_votes
FROM v_results_complete
WHERE race_code = 'mayor'
GROUP BY election_date, election_type, candidate_full_name
ORDER BY election_date DESC, total_votes DESC;

-- Turnout summary by election
CREATE VIEW IF NOT EXISTS v_turnout_summary AS
SELECT
    election_date,
    election_type,
    election_level,
    SUM(votes_cast) AS total_votes,
    SUM(total_registered) AS total_registered,
    ROUND(100.0 * SUM(votes_cast) / SUM(total_registered), 1) AS turnout_pct,
    COUNT(DISTINCT precinct) AS num_precincts
FROM v_turnout_complete
GROUP BY election_date, election_type, election_level
ORDER BY election_date DESC;

-- ============================================
-- TRIGGERS FOR DATA INTEGRITY
-- ============================================

-- Auto-calculate turnout percentage
CREATE TRIGGER IF NOT EXISTS trg_calculate_turnout_pct
AFTER INSERT ON turnout
FOR EACH ROW
WHEN NEW.pct_turnout IS NULL
BEGIN
    UPDATE turnout
    SET pct_turnout = ROUND(CAST(NEW.votes_cast AS REAL) / NEW.total_registered, 3)
    WHERE turnout_id = NEW.turnout_id;
END;

-- Update turnout percentage on update
CREATE TRIGGER IF NOT EXISTS trg_update_turnout_pct
AFTER UPDATE OF votes_cast, total_registered ON turnout
FOR EACH ROW
BEGIN
    UPDATE turnout
    SET pct_turnout = ROUND(CAST(NEW.votes_cast AS REAL) / NEW.total_registered, 3)
    WHERE turnout_id = NEW.turnout_id;
END;
