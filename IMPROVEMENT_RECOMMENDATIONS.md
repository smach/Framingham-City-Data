# Framingham City Data - Improvement Recommendations

**Date:** 2025-11-08
**Status:** Proposed improvements for repository structure and data management

---

## Executive Summary

This document provides comprehensive recommendations for improving the Framingham City Data repository, focusing on:
- GIS file management for multiple redistricting periods
- Election data consolidation strategy
- Database vs CSV approaches
- Data structure standardization
- Documentation improvements
- R-based analysis workflows
- Interactive data visualization options (Shiny vs datasette)

---

## 1. GIS File Management Strategy

### Current Situation
You have multiple shapefile versions:
- `FramPrecincts` (current, post-2021 redistricting)
- `FramPrecinctsPre2021Redistricting` (historical)
- `FRAMINGHAM_proposed_2020_precincts` (proposed boundaries)
- MA House districts (full state + Framingham subset)

### Recommended Approach: Year-Based Directory Structure

```
data/gis/
├── precincts/
│   ├── 2010-2020/           # Pre-redistricting boundaries
│   │   ├── FramPrecincts.*
│   │   └── metadata.yml     # Years valid, notes
│   ├── 2021-present/        # Current boundaries
│   │   ├── FramPrecincts.*
│   │   └── metadata.yml
│   └── proposed-2020/       # Historical proposals
│       └── ...
├── districts/
│   ├── local/
│   │   ├── 2017-2020/
│   │   └── 2021-present/
│   └── ma-house/
│       ├── 2011-2020/
│       └── 2021-present/
├── parcels/
│   └── 2018/
└── census/
    └── 2020/
```

### Implementation: R Package for GIS Management

**Create**: `R/gis_helpers.R`

```r
# GIS File Management Functions

#' Get the appropriate precinct shapefile for a given date
#' @param date Date or year of election
#' @return sf object with precinct boundaries
get_precincts_for_date <- function(date) {
  year <- lubridate::year(date)

  if (year <= 2020) {
    sf::st_read(here::here("data/gis/precincts/2010-2020/FramPrecincts.shp"))
  } else {
    sf::st_read(here::here("data/gis/precincts/2021-present/FramPrecincts.shp"))
  }
}

#' Get district boundaries for a given date
get_districts_for_date <- function(date, type = c("local", "ma_house")) {
  # Similar logic for districts
}

#' Spatial join election results to correct precinct boundaries
#' @param election_data Data frame with precinct results
#' @param election_date Date of election
join_election_to_precincts <- function(election_data, election_date) {
  precincts <- get_precincts_for_date(election_date)
  dplyr::left_join(precincts, election_data, by = c("PRECINCT" = "precinct"))
}
```

### Metadata Files

Create YAML metadata for each shapefile version:

**Example: `data/gis/precincts/2010-2020/metadata.yml`**
```yaml
valid_from: 2010-01-01
valid_to: 2020-12-31
description: Precinct boundaries before 2021 redistricting
elections_using_boundaries:
  - 2017 Preliminary
  - 2017 General
  - 2019 General
  - 2020 State Primary
source: Framingham GIS
projection: NAD83 / Massachusetts Mainland
notes: Used until 2021 redistricting following 2020 Census
```

---

## 2. Election Data Consolidation: SQLite Database Recommendation

### Why SQLite Over CSV

**Recommended: SQLite** (with CSV exports for sharing)

**Advantages:**
1. **Single file database** - Easy to version control and share
2. **SQL queries** - Flexible analysis without loading full datasets
3. **Data integrity** - Foreign keys, constraints, data types
4. **R integration** - Excellent support via DBI, RSQLite, dbplyr
5. **Excel compatibility** - Can export views/tables to CSV for Excel users
6. **Performance** - Fast queries on large datasets
7. **Relationships** - Proper normalization, no data duplication

### Recommended Database Schema

```sql
-- Core dimension tables
CREATE TABLE elections (
    election_id INTEGER PRIMARY KEY,
    election_date DATE NOT NULL,
    election_type TEXT NOT NULL, -- 'General', 'Preliminary', 'Special', 'Primary'
    election_level TEXT,         -- 'Municipal', 'State', 'Federal'
    description TEXT,
    is_official BOOLEAN DEFAULT 1,
    UNIQUE(election_date, election_type)
);

CREATE TABLE races (
    race_id INTEGER PRIMARY KEY,
    election_id INTEGER REFERENCES elections(election_id),
    office TEXT NOT NULL,         -- 'Mayor', 'City Council At-Large', etc.
    district TEXT,                -- NULL for at-large, or '1', '2', etc.
    seats_available INTEGER DEFAULT 1,
    UNIQUE(election_id, office, district)
);

CREATE TABLE candidates (
    candidate_id INTEGER PRIMARY KEY,
    candidate_name TEXT NOT NULL,
    normalized_name TEXT,         -- For matching across elections
    UNIQUE(candidate_name)
);

CREATE TABLE precincts (
    precinct_id INTEGER PRIMARY KEY,
    precinct_number INTEGER NOT NULL,
    district_number INTEGER,
    valid_from DATE,
    valid_to DATE,
    UNIQUE(precinct_number, valid_from)
);

-- Fact table
CREATE TABLE results (
    result_id INTEGER PRIMARY KEY,
    race_id INTEGER REFERENCES races(race_id),
    candidate_id INTEGER REFERENCES candidates(candidate_id),
    precinct_id INTEGER REFERENCES precincts(precinct_id),
    votes INTEGER NOT NULL,
    CHECK(votes >= 0)
);

CREATE TABLE turnout (
    turnout_id INTEGER PRIMARY KEY,
    election_id INTEGER REFERENCES elections(election_id),
    precinct_id INTEGER REFERENCES precincts(precinct_id),
    total_voter_turnout INTEGER,
    total_registered_voters INTEGER,
    turnout_pct REAL,
    UNIQUE(election_id, precinct_id)
);

-- Indexes for common queries
CREATE INDEX idx_results_race ON results(race_id);
CREATE INDEX idx_results_candidate ON results(candidate_id);
CREATE INDEX idx_results_precinct ON results(precinct_id);
CREATE INDEX idx_turnout_election ON turnout(election_id);
```

### Implementation: R Package for Database Access

**Create**: `R/database.R`

```r
library(DBI)
library(RSQLite)
library(dplyr)

# Database connection
get_db_connection <- function() {
  DBI::dbConnect(RSQLite::SQLite(), here::here("data/framingham_elections.db"))
}

# Initialize database with schema
initialize_database <- function(db_path = here::here("data/framingham_elections.db")) {
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)

  # Execute schema SQL (from external file or inline)
  schema <- readr::read_file(here::here("data/schema.sql"))
  DBI::dbExecute(con, schema)

  DBI::dbDisconnect(con)
  message("Database initialized at: ", db_path)
}

# High-level query functions
get_election_results <- function(year = NULL, office = NULL, precinct = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  query <- "
    SELECT
      e.election_date,
      e.election_type,
      r.office,
      r.district,
      c.candidate_name,
      p.precinct_number,
      res.votes
    FROM results res
    JOIN races r ON res.race_id = r.race_id
    JOIN elections e ON r.election_id = e.election_id
    JOIN candidates c ON res.candidate_id = c.candidate_id
    JOIN precincts p ON res.precinct_id = p.precinct_id
    WHERE 1=1
  "

  params <- list()
  if (!is.null(year)) {
    query <- paste(query, "AND strftime('%Y', e.election_date) = ?")
    params <- c(params, as.character(year))
  }
  if (!is.null(office)) {
    query <- paste(query, "AND r.office = ?")
    params <- c(params, office)
  }
  if (!is.null(precinct)) {
    query <- paste(query, "AND p.precinct_number = ?")
    params <- c(params, precinct)
  }

  DBI::dbGetQuery(con, query, params = params)
}

get_turnout_summary <- function(year = NULL) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  query <- "
    SELECT
      e.election_date,
      e.election_type,
      SUM(t.total_voter_turnout) as total_votes,
      SUM(t.total_registered_voters) as total_registered,
      ROUND(100.0 * SUM(t.total_voter_turnout) / SUM(t.total_registered_voters), 1) as turnout_pct
    FROM turnout t
    JOIN elections e ON t.election_id = e.election_id
  "

  if (!is.null(year)) {
    query <- paste(query, "WHERE strftime('%Y', e.election_date) = ?")
    query <- paste(query, "GROUP BY e.election_date, e.election_type")
    DBI::dbGetQuery(con, query, params = list(as.character(year)))
  } else {
    query <- paste(query, "GROUP BY e.election_date, e.election_type")
    DBI::dbGetQuery(con, query)
  }
}

# dbplyr integration for tidyverse users
elections_tbl <- function() {
  con <- get_db_connection()
  dplyr::tbl(con, "elections")
}

results_tbl <- function() {
  con <- get_db_connection()
  dplyr::tbl(con, "results")
}
```

### Migration Script

**Create**: `R/migrate_to_database.R`

```r
# Migrate all existing election CSVs to SQLite database
source(here::here("R/database.R"))
source(here::here("R/election_helpers.R"))

# Initialize database
initialize_database()

con <- get_db_connection()

# Populate elections table
elections_to_add <- tribble(
  ~election_date, ~election_type, ~election_level, ~description,
  "2017-09-14", "Preliminary", "Municipal", "2017 Preliminary Election",
  "2017-11-07", "General", "Municipal", "2017 General Municipal Election",
  "2019-11-05", "General", "Municipal", "2019 General Municipal Election",
  "2020-09-01", "Primary", "State", "2020 State Primary",
  "2021-09-14", "Preliminary", "Municipal", "2021 Preliminary Election",
  "2021-11-02", "General", "Municipal", "2021 General Municipal Election",
  "2022-09-06", "Primary", "State", "2022 State Primary",
  "2023-11-07", "General", "Municipal", "2023 General Municipal Election"
)

DBI::dbAppendTable(con, "elections", elections_to_add)

# Populate precincts
precincts_pre_2021 <- tibble(
  precinct_number = 1:18,
  district_number = rep(1:9, each = 2),
  valid_from = "2010-01-01",
  valid_to = "2020-12-31"
)

precincts_2021_plus <- tibble(
  precinct_number = 1:18,
  district_number = rep(1:9, each = 2),
  valid_from = "2021-01-01",
  valid_to = NA
)

DBI::dbAppendTable(con, "precincts", precincts_pre_2021)
DBI::dbAppendTable(con, "precincts", precincts_2021_plus)

# Function to import tidy CSV files
import_tidy_election <- function(csv_path, election_date, office) {
  data <- readr::read_csv(csv_path, show_col_types = FALSE)

  # Get election_id
  election_id <- DBI::dbGetQuery(con,
    "SELECT election_id FROM elections WHERE election_date = ?",
    params = list(election_date))$election_id

  # Create race if it doesn't exist
  race_id <- DBI::dbGetQuery(con,
    "INSERT INTO races (election_id, office, seats_available)
     VALUES (?, ?, 1)
     ON CONFLICT DO NOTHING
     RETURNING race_id",
    params = list(election_id, office))$race_id

  # If race already exists, get its ID
  if (length(race_id) == 0) {
    race_id <- DBI::dbGetQuery(con,
      "SELECT race_id FROM races WHERE election_id = ? AND office = ?",
      params = list(election_id, office))$race_id
  }

  # Process each row
  for (i in 1:nrow(data)) {
    # Add candidate if needed
    candidate_name <- data$Candidate[i]
    DBI::dbExecute(con,
      "INSERT OR IGNORE INTO candidates (candidate_name, normalized_name) VALUES (?, ?)",
      params = list(candidate_name, candidate_name))

    candidate_id <- DBI::dbGetQuery(con,
      "SELECT candidate_id FROM candidates WHERE candidate_name = ?",
      params = list(candidate_name))$candidate_id

    # Get precinct_id
    precinct_num <- data$Precinct[i]
    precinct_id <- DBI::dbGetQuery(con,
      "SELECT precinct_id FROM precincts
       WHERE precinct_number = ? AND valid_from <= ? AND (valid_to IS NULL OR valid_to >= ?)",
      params = list(precinct_num, election_date, election_date))$precinct_id

    # Insert result
    DBI::dbExecute(con,
      "INSERT INTO results (race_id, candidate_id, precinct_id, votes) VALUES (?, ?, ?, ?)",
      params = list(race_id, candidate_id, precinct_id, data$Votes[i]))
  }
}

# Import all tidy files
import_tidy_election("data/elections/tidy/2023_framingham_general.csv",
                      "2023-11-07", "At Large City Councilor")

# ... repeat for all tidy files

DBI::dbDisconnect(con)
```

### CSV Export for Excel Users

**Create**: `R/export_csv_views.R`

```r
# Export commonly used views to CSV for Excel users
source(here::here("R/database.R"))

con <- get_db_connection()

# Export 1: All election results in tidy format
all_results <- DBI::dbGetQuery(con, "
  SELECT
    e.election_date,
    e.election_type,
    r.office,
    r.district,
    c.candidate_name,
    p.precinct_number,
    p.district_number,
    res.votes
  FROM results res
  JOIN races r ON res.race_id = r.race_id
  JOIN elections e ON r.election_id = e.election_id
  JOIN candidates c ON res.candidate_id = c.candidate_id
  JOIN precincts p ON res.precinct_id = p.precinct_id
  ORDER BY e.election_date DESC, r.office, p.precinct_number, c.candidate_name
")

readr::write_csv(all_results, "data/exports/all_election_results.csv")

# Export 2: Turnout summary by election
turnout_summary <- get_turnout_summary()
readr::write_csv(turnout_summary, "data/exports/turnout_summary.csv")

# Export 3: Mayor race results across all years
mayor_results <- DBI::dbGetQuery(con, "
  SELECT
    e.election_date,
    e.election_type,
    c.candidate_name,
    SUM(res.votes) as total_votes
  FROM results res
  JOIN races r ON res.race_id = r.race_id
  JOIN elections e ON r.election_id = e.election_id
  JOIN candidates c ON res.candidate_id = c.candidate_id
  WHERE r.office = 'Mayor'
  GROUP BY e.election_date, e.election_type, c.candidate_name
  ORDER BY e.election_date DESC, total_votes DESC
")

readr::write_csv(mayor_results, "data/exports/mayor_results_all_years.csv")

DBI::dbDisconnect(con)
```

---

## 3. Standardized Column Structure

### Recommended Standard for Tidy Election Data

All tidy election CSVs should have these columns in this order:

```r
# Standard tidy election result format
tibble(
  election_date = as.Date("2023-11-07"),  # ISO 8601 format (YYYY-MM-DD)
  election_year = 2023L,                  # Integer year
  election_type = "General",              # General|Preliminary|Special|Primary
  election_level = "Municipal",           # Municipal|State|Federal
  office = "Mayor",                       # Full office name
  district = NA_character_,               # NULL for at-large, "1"-"9" for districts
  precinct = 1L,                          # Integer precinct number
  candidate_name = "Jane Smith",          # Full name as appears on ballot
  votes = 1234L,                          # Integer vote count
  is_blank = FALSE,                       # TRUE if blank votes
  is_writeIn = FALSE                      # TRUE if write-in votes
)
```

### Standardized Turnout Format

```r
# Standard turnout format
tibble(
  election_date = as.Date("2023-11-07"),
  election_year = 2023L,
  election_type = "General",
  election_level = "Municipal",
  precinct = 1L,
  district = 1L,
  total_registered_voters = 2994L,
  total_voter_turnout = 1097L,
  turnout_pct = 36.6                      # Calculated percentage
)
```

### Update `election_helpers.R` for Standardization

```r
#' Convert any election file to standard tidy format
#' @param data Data frame with raw election results
#' @param election_date Date of election (YYYY-MM-DD)
#' @param election_type Type of election
#' @param office Office being contested
#' @return Standardized tidy data frame
standardize_election_data <- function(data, election_date, election_type,
                                      election_level, office, district = NA) {
  election_date <- as.Date(election_date)

  data |>
    dplyr::mutate(
      election_date = election_date,
      election_year = lubridate::year(election_date),
      election_type = election_type,
      election_level = election_level,
      office = office,
      district = district,
      precinct = as.integer(precinct),
      votes = as.integer(votes),
      is_blank = stringr::str_detect(tolower(candidate_name), "blank"),
      is_writeIn = stringr::str_detect(tolower(candidate_name), "write")
    ) |>
    dplyr::select(
      election_date, election_year, election_type, election_level,
      office, district, precinct, candidate_name, votes, is_blank, is_writeIn
    )
}
```

---

## 4. Documentation Strategy

### A. Data Dictionary

**Create**: `data/DATA_DICTIONARY.md`

A comprehensive data dictionary documenting:
- All database tables and columns
- All CSV file formats
- GIS shapefile attributes
- Allowed values for categorical fields
- Data sources and update frequency

### B. Codebook for Researchers

**Create**: `data/CODEBOOK.md`

Research-oriented documentation:
- Variable definitions
- Measurement units
- Known data quality issues
- Suggested data cleaning steps
- Citation information

### C. Enhanced README.md

Update main README with:
- Quick start guide
- Data structure overview
- How to query the database
- How to export data
- Example analyses
- Contributing guidelines

### D. R Package Documentation (pkgdown)

Convert your R scripts into a proper R package with:

**Create**: `DESCRIPTION` file
```
Package: FraminghamElections
Title: Framingham Municipal Election Data Analysis
Version: 0.1.0
Authors@R: person("Your", "Name", email = "your@email.com", role = c("aut", "cre"))
Description: Tools for analyzing Framingham, MA municipal election data,
    including election results, turnout, and geographic analysis.
License: MIT + file LICENSE
Encoding: UTF-8
LazyData: true
Depends: R (>= 4.0.0)
Imports:
    DBI,
    RSQLite,
    dplyr,
    tidyr,
    sf,
    leaflet,
    readr,
    here,
    lubridate
Suggests:
    shiny,
    ggplot2,
    plotly,
    testthat,
    knitr,
    rmarkdown
RoxygenNote: 7.2.0
VignetteBuilder: knitr
```

**Benefits**:
- Automatic function documentation with roxygen2
- Beautiful website with pkgdown
- Vignettes for tutorials
- Unit tests with testthat
- Easy installation: `remotes::install_github("yourusername/Framingham-City-Data")`

### E. Vignettes

**Create**: `vignettes/` directory with tutorial articles:

- `getting-started.Rmd` - Basic data access
- `analyzing-turnout.Rmd` - Turnout analysis examples
- `mapping-results.Rmd` - Creating election maps
- `comparing-elections.Rmd` - Time series analysis
- `data-structure.Rmd` - Understanding the database schema

---

## 5. R-Based Analysis Workflows

### A. R Package Structure

Reorganize into proper R package:

```
Framingham-City-Data/
├── DESCRIPTION           # Package metadata
├── NAMESPACE            # Exported functions
├── LICENSE
├── README.md
├── R/                   # Function definitions
│   ├── database.R
│   ├── gis_helpers.R
│   ├── election_helpers.R
│   ├── analysis.R
│   └── visualization.R
├── data/                # Package data (small datasets)
│   └── district_precinct_mapping.rda
├── data-raw/            # Raw data and processing scripts
│   ├── elections/
│   └── scripts/
├── inst/                # Installed files
│   ├── extdata/         # Large datasets (SQLite, shapefiles)
│   │   ├── framingham_elections.db
│   │   └── gis/
│   └── shiny/           # Shiny apps
│       └── election_explorer/
├── vignettes/           # Documentation
├── tests/               # Unit tests
│   └── testthat/
├── man/                 # Auto-generated documentation
└── docs/                # pkgdown website
```

### B. Analysis Templates

**Create**: `inst/templates/` directory with R Markdown templates:

**Template 1: Election Summary Report**
```rmd
---
title: "{{ELECTION_NAME}} Summary Report"
output: html_document
params:
  election_date: "2023-11-07"
---

```{r setup, include=FALSE}
library(FraminghamElections)
library(dplyr)
library(ggplot2)

election_date <- params$election_date
```

## Election Overview

```{r}
results <- get_election_results(year = year(election_date))
turnout <- get_turnout_summary(year = year(election_date))
```

## Turnout Analysis
...
```

### C. Common Analysis Functions

**Add to `R/analysis.R`**:

```r
#' Calculate vote share by candidate in a race
calculate_vote_share <- function(race_id) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(con, "
    SELECT
      c.candidate_name,
      SUM(r.votes) as total_votes,
      ROUND(100.0 * SUM(r.votes) / (SELECT SUM(votes) FROM results WHERE race_id = ?), 2) as vote_share_pct
    FROM results r
    JOIN candidates c ON r.candidate_id = c.candidate_id
    WHERE r.race_id = ?
    GROUP BY c.candidate_name
    ORDER BY total_votes DESC
  ", params = list(race_id, race_id))
}

#' Compare candidate performance across precincts
precinct_performance <- function(candidate_name, year = NULL) {
  # Implementation
}

#' Calculate turnout trends over time
turnout_trends <- function(election_type = NULL) {
  # Implementation
}

#' Geographic analysis of voting patterns
analyze_geographic_patterns <- function(race_id) {
  # Join election results to GIS data
  # Calculate spatial statistics
}
```

---

## 6. Interactive Visualization: Shiny vs. Datasette

### Recommendation: Start with Shiny, Consider Datasette for Read-Only Access

### Option 1: Shiny App (Recommended for Analysis)

**Advantages for your use case**:
- Full R integration (you're an R user)
- Interactive plots with plotly/ggplot2
- Interactive maps with leaflet
- Custom analysis workflows
- Can include complex statistical models
- Beautiful UI with bslib/thematic

**Create**: `inst/shiny/election_explorer/app.R`

```r
library(shiny)
library(bslib)
library(FraminghamElections)
library(dplyr)
library(ggplot2)
library(plotly)
library(leaflet)
library(sf)

ui <- page_navbar(
  title = "Framingham Election Explorer",
  theme = bs_theme(bootswatch = "flatly"),

  nav_panel("Overview",
    layout_columns(
      card(
        card_header("Select Election"),
        selectInput("election_year", "Year", choices = 2017:2023),
        selectInput("election_type", "Type",
                    choices = c("General", "Preliminary", "Primary", "Special"))
      ),
      card(
        card_header("Turnout Summary"),
        plotlyOutput("turnout_plot")
      )
    ),
    card(
      card_header("Results by Race"),
      selectInput("office", "Office", choices = c("Mayor", "City Council At-Large")),
      plotlyOutput("results_plot")
    )
  ),

  nav_panel("Maps",
    layout_sidebar(
      sidebar = sidebar(
        selectInput("map_year", "Election Year", choices = 2017:2023),
        selectInput("map_race", "Race", choices = NULL),
        selectInput("map_metric", "Show",
                    choices = c("Turnout" = "turnout", "Vote Share" = "vote_share"))
      ),
      leafletOutput("election_map", height = 600)
    )
  ),

  nav_panel("Trends",
    layout_columns(
      card(
        card_header("Turnout Over Time"),
        plotlyOutput("turnout_trend")
      ),
      card(
        card_header("Candidate Comparison"),
        selectInput("candidate_select", "Select Candidates",
                    choices = NULL, multiple = TRUE),
        plotlyOutput("candidate_trend")
      )
    )
  ),

  nav_panel("Data Export",
    card(
      card_header("Download Data"),
      selectInput("export_table", "Select Data",
                  choices = c("All Results", "Turnout", "By Office")),
      downloadButton("download_csv", "Download CSV"),
      downloadButton("download_excel", "Download Excel")
    ),
    card(
      card_header("Custom Query"),
      textAreaInput("custom_query", "SQL Query",
                    value = "SELECT * FROM elections LIMIT 10",
                    rows = 5),
      actionButton("run_query", "Run Query"),
      tableOutput("query_results")
    )
  )
)

server <- function(input, output, session) {

  # Reactive data
  election_results <- reactive({
    get_election_results(year = input$election_year)
  })

  # Turnout plot
  output$turnout_plot <- renderPlotly({
    data <- get_turnout_summary(year = input$election_year)

    p <- ggplot(data, aes(x = election_type, y = turnout_pct)) +
      geom_col(fill = "#3498db") +
      geom_text(aes(label = paste0(turnout_pct, "%")), vjust = -0.5) +
      theme_minimal() +
      labs(title = "Turnout by Election Type", x = "", y = "Turnout %")

    ggplotly(p)
  })

  # Results plot
  output$results_plot <- renderPlotly({
    # Implementation
  })

  # Interactive map
  output$election_map <- renderLeaflet({
    precincts <- get_precincts_for_date(paste0(input$map_year, "-11-01"))
    results <- election_results()

    # Join data
    map_data <- precincts |>
      left_join(results, by = c("PRECINCT" = "precinct_number"))

    # Color palette
    pal <- colorNumeric("YlOrRd", domain = map_data$turnout_pct)

    leaflet(map_data) |>
      addProviderTiles(providers$CartoDB.Positron) |>
      addPolygons(
        fillColor = ~pal(turnout_pct),
        weight = 2,
        opacity = 1,
        color = "white",
        fillOpacity = 0.7,
        label = ~paste0("Precinct ", PRECINCT, ": ", turnout_pct, "%")
      ) |>
      addLegend(pal = pal, values = ~turnout_pct, title = "Turnout %")
  })

  # Download handlers
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("framingham_elections_", Sys.Date(), ".csv")
    },
    content = function(file) {
      data <- election_results()
      readr::write_csv(data, file)
    }
  )
}

shinyApp(ui, server)
```

**Deployment options**:
- shinyapps.io (free tier: 5 apps, 25 active hours/month)
- Your own server with Shiny Server
- GitHub Pages + WebR (experimental, static data only)

### Option 2: Datasette (Recommended for Public Data Sharing)

**Advantages**:
- Zero-code web interface to SQLite
- Automatic API generation
- Faceted browsing
- SQL query interface
- Custom pages with templates
- Can run on free tier of Vercel/Fly.io

**Setup**:

```bash
# Install datasette
pip install datasette

# Install useful plugins
datasette install datasette-leaflet-geojson
datasette install datasette-cluster-map
datasette install datasette-vega
datasette install datasette-export-notebook

# Run locally
datasette data/framingham_elections.db
```

**Create**: `metadata.yml` for datasette

```yaml
title: Framingham Election Data
description: Municipal election results for Framingham, MA (2017-2023)
databases:
  framingham_elections:
    tables:
      elections:
        description: All elections held in Framingham
        label_column: description
      results:
        description: Election results by candidate and precinct
        facets:
          - election_date
          - office
      turnout:
        description: Voter turnout by precinct and election
        facets:
          - election_date
plugins:
  datasette-leaflet-geojson:
    latitude_column: lat
    longitude_column: lon
```

### Hybrid Approach (Best of Both Worlds)

1. **SQLite database** as single source of truth
2. **Datasette** for public data browsing and API
3. **Shiny app** for advanced analysis and visualization
4. **CSV exports** from database for Excel users

---

## 7. Implementation Priorities

### Phase 1: Foundation (1-2 weeks)
1. ✅ Reorganize GIS files with year-based structure
2. ✅ Create `gis_helpers.R` with date-based lookup functions
3. ✅ Design and implement SQLite database schema
4. ✅ Create `database.R` with connection and query functions
5. ✅ Migrate existing tidy data to SQLite

### Phase 2: Standardization (1 week)
1. ✅ Update `election_helpers.R` with standardization functions
2. ✅ Re-process all election files to standard format
3. ✅ Create CSV export functions for Excel users
4. ✅ Add data validation and tests

### Phase 3: Documentation (1 week)
1. ✅ Write DATA_DICTIONARY.md
2. ✅ Write CODEBOOK.md
3. ✅ Update README.md with quick start
4. ✅ Add roxygen2 documentation to all functions

### Phase 4: R Package (1-2 weeks)
1. ✅ Convert to proper R package structure
2. ✅ Create DESCRIPTION and NAMESPACE
3. ✅ Build pkgdown website
4. ✅ Write vignettes

### Phase 5: Visualization (2-3 weeks)
1. ✅ Build basic Shiny app
2. ✅ Add interactive maps
3. ✅ Add trend analysis
4. ✅ Deploy to shinyapps.io
5. ⚪ Optional: Set up datasette for public API

---

## 8. Specific Next Steps

### Immediate Actions (This Week)

1. **Reorganize GIS files**
   ```r
   # Create new directory structure
   dir.create("data/gis/precincts/2010-2020", recursive = TRUE)
   dir.create("data/gis/precincts/2021-present", recursive = TRUE)

   # Move files (manually or with file.rename())
   # Create metadata.yml files
   ```

2. **Initialize SQLite database**
   ```r
   # Run database initialization
   source("R/database.R")
   initialize_database()
   ```

3. **Create migration plan**
   - List all CSV files that need migration
   - Map each to database structure
   - Write import scripts

### Medium Term (Next Month)

1. Complete data migration
2. Write comprehensive tests
3. Create first vignette
4. Build basic Shiny app prototype

### Long Term (3-6 Months)

1. Full R package release
2. Comprehensive Shiny app
3. Public data portal (datasette or Shiny)
4. Research paper using the data

---

## 9. Additional Recommendations

### A. Version Control Best Practices

- Keep SQLite database in Git (it's small enough)
- Use Git LFS for large shapefiles
- Tag releases when adding new election data
- Use GitHub Releases for distributing data packages

### B. Data Update Workflow

**Create**: `R/update_data.R`

```r
#' Add new election to database
#' @param raw_file Path to raw XLSX file from clerk
#' @param election_date Date of election
#' @param election_type Type of election
add_new_election <- function(raw_file, election_date, election_type) {
  # 1. Process raw file
  # 2. Validate data
  # 3. Add to database
  # 4. Generate CSV exports
  # 5. Update documentation
  # 6. Run tests
}
```

### C. Data Quality Checks

**Create**: `R/validate.R`

```r
# Validation functions
validate_precinct_totals <- function(election_id) {
  # Check that precinct totals match city totals
}

validate_turnout_consistency <- function(election_id) {
  # Check turnout calculations
}

check_missing_data <- function() {
  # Identify gaps in data collection
}
```

### D. Automated Testing

**Create**: `tests/testthat/test-database.R`

```r
test_that("Database connection works", {
  con <- get_db_connection()
  expect_s4_class(con, "SQLiteConnection")
  DBI::dbDisconnect(con)
})

test_that("All elections have turnout data", {
  elections <- elections_tbl() |> collect()
  turnout <- turnout_tbl() |> collect()

  for (eid in elections$election_id) {
    expect_true(eid %in% turnout$election_id)
  }
})
```

### E. Collaboration Features

**Create**: `.github/ISSUE_TEMPLATE/new-election-data.md`

Template for adding new election data:
```markdown
## New Election Data

**Election Date:** YYYY-MM-DD
**Election Type:** General/Preliminary/Primary/Special
**Data Source:** [Link to city clerk results]

**Checklist:**
- [ ] Raw data file added to `data-raw/elections/`
- [ ] Processing script created/updated
- [ ] Data added to SQLite database
- [ ] CSV exports generated
- [ ] Tests pass
- [ ] Documentation updated
- [ ] Shiny app updated (if needed)
```

---

## 10. Estimated Resource Requirements

### Storage
- SQLite database: ~5-10 MB (with all elections 2008-2030)
- GIS files: ~50 MB (all shapefiles)
- Total repository: ~60-80 MB (very manageable)

### Performance
- SQLite queries: <100ms for typical queries
- Shiny app: Can handle 10-50 concurrent users
- Data exports: Seconds for any reasonable query

### Maintenance
- New election data: 2-4 hours per election (decreasing with automation)
- Package updates: Quarterly
- Documentation: Continuous

---

## Summary of Key Recommendations

1. **GIS Management**: Year-based directories + R helper functions for date-based lookups
2. **Data Consolidation**: SQLite database as source of truth, CSV exports for Excel users
3. **Column Structure**: Standardized tidy format with election metadata
4. **Documentation**: Convert to R package with pkgdown, vignettes, and data dictionary
5. **R Integration**: Full R package with documented functions, tests, and templates
6. **Visualization**: Shiny app for interactive analysis, datasette for public API (optional)
7. **Priority**: Start with database migration and GIS reorganization, then package structure

This approach gives you:
- **Flexibility**: SQLite for analysis, CSV for sharing
- **Reproducibility**: All processing in versioned R scripts
- **Accessibility**: Shiny app for non-coders, R package for analysts
- **Sustainability**: Clear structure for adding future elections
- **Collaboration**: Well-documented, tested, shareable code

The entire system is R-based as you requested, leveraging the tidyverse ecosystem you're already using.
