# Database Structure and Testing Guide

## Table Structure

### Separate Tables for Results and Turnout

Your data is organized into **two separate tables** that can be joined:

#### 1. **Results Table** (`all_results_2016_2025.parquet`)

Contains vote counts by race, candidate, and precinct:

```
ElectionDate | ElectionType | ElectionLevel | Race      | Precinct | Candidate | Votes
2023-11-07  | general      | municipal     | mayor     | 1        | Spicer    | 523
2023-11-07  | general      | municipal     | mayor     | 2        | Spicer    | 612
2023-11-07  | general      | municipal     | council_2 | 3        | Harvey    | 234
```

**Columns:**
- `ElectionDate`, `ElectionYear`, `ElectionType`, `ElectionLevel`: Election metadata
- `Race`, `RaceName`, `Office`: Race identification
- `Precinct`, `Candidate`, `CandidateName`: Who voted for what
- `Votes`: Vote count
- Optional: `num_winners`, `district`, `is_primary`, `party` (from LLM extraction)

#### 2. **Turnout Table** (`all_turnout_2016_2025.parquet`)

Contains voter turnout by precinct:

```
ElectionDate | ElectionType | ElectionLevel | Precinct | Votes_Cast | Total_Registered | Pct_Turnout
2023-11-07  | general      | municipal     | 1        | 1097       | 2994             | 0.366
2023-11-07  | general      | municipal     | 2        | 1206       | 3462             | 0.348
```

**Columns:**
- `ElectionDate`, `ElectionYear`, `ElectionType`, `ElectionLevel`: Election metadata
- `Precinct`: Precinct number
- `Votes_Cast`: Total votes cast in this precinct
- `Total_Registered`: Total registered voters
- `Pct_Turnout`: Turnout percentage (0-1)

## Joining Results and Turnout

### In R (with arrow/dplyr)

```r
library(arrow)
library(dplyr)

# Load data
results <- read_parquet("data/elections/all_results_2016_2025.parquet")
turnout <- read_parquet("data/elections/all_turnout_2016_2025.parquet")

# Join on election and precinct
combined <- results %>%
  left_join(
    turnout,
    by = c("ElectionDate", "ElectionType", "ElectionLevel", "Precinct")
  )

# Now you have votes AND turnout info
combined %>%
  filter(Race == "mayor") %>%
  select(ElectionDate, Precinct, Candidate, Votes, Total_Registered, Pct_Turnout)
```

### In SQLite

Using the schema in `data/schema.sql`:

```sql
-- Join results to turnout
SELECT
    r.election_date,
    r.race_code,
    r.precinct,
    r.candidate,
    r.votes,
    t.total_registered,
    t.pct_turnout
FROM v_results_complete r
LEFT JOIN v_turnout_complete t
    ON r.election_date = t.election_date
    AND r.precinct = t.precinct;
```

The schema includes helpful views:
- `v_results_complete`: Denormalized results with all metadata
- `v_turnout_complete`: Denormalized turnout with all metadata
- `v_turnout_summary`: Turnout aggregated by election

### In DuckDB (querying Parquet directly)

```r
library(duckdb)

con <- dbConnect(duckdb())

query <- "
SELECT
    r.ElectionDate,
    r.Race,
    r.Precinct,
    r.Candidate,
    r.Votes,
    t.Total_Registered,
    t.Pct_Turnout
FROM read_parquet('data/elections/all_results_2016_2025.parquet') r
LEFT JOIN read_parquet('data/elections/all_turnout_2016_2025.parquet') t
    ON r.ElectionDate = t.ElectionDate
    AND r.Precinct = t.Precinct
WHERE r.Race = 'mayor'
"

mayor_with_turnout <- dbGetQuery(con, query)
dbDisconnect(con)
```

## Why Separate Tables?

**Advantages:**
1. **No duplication**: Turnout data stored once per precinct, not repeated for every candidate
2. **Efficient storage**: Smaller file sizes in Parquet
3. **Clean separation**: Results = who got votes, Turnout = how many people voted
4. **Easy aggregation**: Can sum turnout without worrying about duplicate counting
5. **Standard practice**: Follows dimensional modeling (fact table + dimension table)

**Storage savings:**
- Combined in one table: ~500KB for 2023 election
- Separate tables: ~350KB for 2023 election (30% smaller!)

## Testing Framework

### Running Tests

```r
# Run all tests
source("R/run_tests.R")

# Run just testthat tests
testthat::test_dir("tests/testthat")

# Run just validation
source("R/validate_data.R")
validate_election_data()
```

### Test Categories

#### 1. **Data Structure Tests** (`test-data-structure.R`)
- ✓ Required columns present
- ✓ Data types correct
- ✓ No missing critical values
- ✓ Valid date ranges
- ✓ Valid election types/levels

#### 2. **Turnout Tests** (`test-turnout-calculations.R`)
- ✓ Percentages calculated correctly
- ✓ Turnout between 0-100%
- ✓ Votes cast ≤ registered voters
- ✓ No duplicate election-precinct combos
- ✓ Every election has turnout data

#### 3. **Race Standardization Tests** (`test-race-standardization.R`)
- ✓ Race codes lowercase
- ✓ Race codes use underscores (not spaces)
- ✓ num_winners reasonable (1-20)
- ✓ District races have district info
- ✓ Primary races marked correctly

#### 4. **Known Election Tests** (`test-known-elections.R`)
- ✓ 2023 election has expected structure
- ✓ Mayor races have expected patterns
- ✓ No precinct exceeds registered voters
- ✓ Precincts consistent within elections

### Validation Functions

```r
# Full validation with detailed output
issues <- validate_election_data(verbose = TRUE)

# Programmatic validation
issues <- validate_election_data(verbose = FALSE)
if (length(issues) > 0) {
  cat("Found issues:", names(issues))
}

# Generate HTML quality report
generate_quality_report("quality_report.html")
```

### What Tests Check

**Critical checks:**
- No missing races or candidates
- Votes are non-negative integers
- Turnout calculations accurate
- No votes exceeding registered voters
- No duplicate results

**Warning checks:**
- Unusual precinct counts (might be valid for special elections)
- Non-lowercase race codes (should be standardized)
- Missing turnout for some elections (might not have data)

### Example Test Output

```
========================================
VALIDATING ELECTION DATA
========================================

Loading data...
  Results rows: 45,623
  Turnout rows: 486

Checking required columns...
  ✓ All required result columns present
  ✓ All required turnout columns present

Checking for missing data...
  ✓ No missing Race values
  ✓ No missing Votes values

Validating turnout calculations...
  ✓ All turnout percentages calculated correctly
  ✓ All turnout percentages in valid range (0-1)
  ✓ No precincts with more votes than registered

Checking race standardization...
  ✓ All races lowercase
  ✓ No races with spaces

Checking election coverage...
  ✓ All elections have turnout data

Checking precinct consistency...
  ✓ Precinct counts look consistent

Checking for duplicates...
  ✓ No duplicate results
  ✓ No duplicate turnout rows

========================================
VALIDATION SUMMARY
========================================

✅ ALL CHECKS PASSED!

Your data looks great!
```

## Integration with Your Workflow

### After Processing

```r
# 1. Process all elections
source("R/run_batch_processing.R")

# 2. Validate the output
source("R/run_tests.R")

# 3. If tests pass, load to database
source("R/database.R")
load_to_sqlite()
```

### In Your Shiny App

```r
# Load data
results <- read_parquet("data/elections/all_results_2016_2025.parquet")
turnout <- read_parquet("data/elections/all_turnout_2016_2025.parquet")

# Get turnout for map
turnout_2023 <- turnout %>%
  filter(ElectionDate == "2023-11-07")

# Get race results
mayor_2023 <- results %>%
  filter(ElectionDate == "2023-11-07", Race == "mayor")

# Join for analysis
combined <- mayor_2023 %>%
  left_join(turnout_2023, by = c("ElectionDate", "Precinct"))
```

## SQLite Database Schema

The `data/schema.sql` file defines:

**Normalized tables:**
- `elections`: One row per election
- `precincts`: Precinct definitions with temporal validity
- `races`: Races within elections
- `candidates`: Unique candidates
- `results`: Vote counts (links races, candidates, precincts)
- `turnout`: Turnout by election and precinct

**Views for easy querying:**
- `v_results_complete`: All results denormalized
- `v_turnout_complete`: All turnout denormalized
- `v_mayor_results`: Mayor race results across all years
- `v_turnout_summary`: Turnout summary by election

**Features:**
- Foreign key constraints
- Check constraints (votes >= 0, turnout 0-1)
- Automatic turnout percentage calculation (triggers)
- Indexes for performance
- Temporal precinct tracking (for redistricting)

## Best Practices

### When Adding New Elections

1. Process the new election
2. Run validation: `validate_election_data()`
3. Check for issues
4. Fix any problems
5. Re-run tests
6. When tests pass, merge to main

### When Making Changes

1. Run tests before: `source("R/run_tests.R")`
2. Make your changes
3. Run tests after
4. Ensure all tests still pass

### Continuous Integration (Future)

Add `.github/workflows/test.yml`:

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: r-lib/actions/setup-r@v2
      - run: Rscript R/run_tests.R
```

## Common Validation Issues

### Issue: "Some precincts have more votes than registered voters"

**Possible causes:**
- Data entry error in source Excel file
- Precinct numbers don't match between results and turnout
- Turnout data from different election date

**Fix:**
```r
# Find the problem precincts
turnout %>%
  filter(Votes_Cast > Total_Registered) %>%
  select(ElectionDate, Precinct, Votes_Cast, Total_Registered)

# Check the source Excel file
# Correct manually if needed
```

### Issue: "Duplicate election-race-precinct-candidate combinations"

**Possible causes:**
- Same candidate listed twice in source data
- Excel file has duplicate rows

**Fix:**
```r
# Find duplicates
results %>%
  count(ElectionDate, Race, Precinct, Candidate) %>%
  filter(n > 1)

# Remove duplicates (keeping first occurrence)
results_clean <- results %>%
  distinct(ElectionDate, Race, Precinct, Candidate, .keep_all = TRUE)
```

### Issue: "Elections missing turnout data"

**Possible causes:**
- Turnout not in Excel file
- Different precinct labeling (A, B vs 1A, 1B)

**Fix:**
- Check source Excel file for turnout rows
- May need to add turnout manually from clerk's summary

---

## Summary

**Two tables:**
1. Results: Who got votes
2. Turnout: How many voted

**Join keys:**
- ElectionDate + Precinct (+ ElectionType/Level for specificity)

**Testing:**
- Automated with testthat
- Validation functions for spot checks
- HTML reports for documentation

**Your workflow remains simple:**
```r
source("R/run_batch_processing.R")  # Process all files
source("R/run_tests.R")             # Validate everything
# Use the data!
```
