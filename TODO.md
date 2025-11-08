# Framingham City Data - Action Items

Based on the comprehensive review in `IMPROVEMENT_RECOMMENDATIONS.md`, here are prioritized action items.

## Phase 1: Foundation (Weeks 1-2) ⚡ HIGH PRIORITY

### GIS File Reorganization
- [ ] Create year-based directory structure for GIS files
  ```
  data/gis/
  ├── precincts/
  │   ├── 2010-2020/
  │   ├── 2021-present/
  │   └── proposed-2020/
  ├── districts/local/
  └── districts/ma-house/
  ```
- [ ] Move existing shapefiles to appropriate year directories
- [ ] Create `metadata.yml` file for each shapefile version
- [ ] Create `R/gis_helpers.R` with `get_precincts_for_date()` function

### SQLite Database Implementation
- [ ] Create database schema SQL file (`data/schema.sql`)
- [ ] Create `R/database.R` with connection and query functions
- [ ] Initialize empty SQLite database
- [ ] Test database connection and basic queries
- [ ] Create `R/migrate_to_database.R` script
- [ ] Migrate existing tidy election data to database
- [ ] Validate migrated data

## Phase 2: Standardization (Week 3)

### Data Standardization
- [ ] Update `R/election_helpers.R` with standardization functions
  - [ ] Add `standardize_election_data()` function
  - [ ] Update existing helper functions to use standard format
- [ ] Re-process all election CSV files to standard format with columns:
  - election_date, election_year, election_type, election_level
  - office, district, precinct, candidate_name, votes
  - is_blank, is_writeIn
- [ ] Create `R/export_csv_views.R` for Excel-friendly exports
- [ ] Generate standard CSV exports:
  - [ ] `data/exports/all_election_results.csv`
  - [ ] `data/exports/turnout_summary.csv`
  - [ ] `data/exports/mayor_results_all_years.csv`

### Data Quality
- [ ] Create `R/validate.R` with data quality checks
  - [ ] `validate_precinct_totals()`
  - [ ] `validate_turnout_consistency()`
  - [ ] `check_missing_data()`
- [ ] Run validation on all migrated data
- [ ] Document any data quality issues found

## Phase 3: Documentation (Week 4)

### Core Documentation
- [ ] Create `data/DATA_DICTIONARY.md`
  - [ ] Document database tables and columns
  - [ ] Document CSV file formats
  - [ ] Document GIS shapefile attributes
  - [ ] List allowed values for categorical fields
- [ ] Create `data/CODEBOOK.md` for researchers
  - [ ] Variable definitions
  - [ ] Data sources
  - [ ] Known issues
  - [ ] Citation information
- [ ] Update `README.md` with:
  - [ ] Quick start guide
  - [ ] How to query the database
  - [ ] How to export data
  - [ ] Example analyses

### Function Documentation
- [ ] Add roxygen2 documentation to all R functions
- [ ] Document parameters and return values
- [ ] Add examples to function documentation

## Phase 4: R Package Conversion (Weeks 5-6)

### Package Structure
- [ ] Create `DESCRIPTION` file with package metadata
- [ ] Create proper R package directory structure
- [ ] Move functions to `R/` with proper roxygen comments
- [ ] Generate `NAMESPACE` with roxygen2
- [ ] Create `LICENSE` file (recommend MIT or GPL-3)
- [ ] Move SQLite database to `inst/extdata/`
- [ ] Move large GIS files to `inst/extdata/gis/`

### Package Documentation
- [ ] Set up pkgdown for website generation
- [ ] Create `_pkgdown.yml` configuration
- [ ] Write vignettes:
  - [ ] `vignettes/getting-started.Rmd`
  - [ ] `vignettes/analyzing-turnout.Rmd`
  - [ ] `vignettes/mapping-results.Rmd`
  - [ ] `vignettes/data-structure.Rmd`
- [ ] Build and preview pkgdown website
- [ ] Test package installation

### Testing
- [ ] Create `tests/testthat/` directory
- [ ] Write tests for database functions
- [ ] Write tests for GIS helper functions
- [ ] Write tests for election helper functions
- [ ] Write data validation tests
- [ ] Set up GitHub Actions for automated testing (optional)

## Phase 5: Interactive Visualization (Weeks 7-9)

### Shiny App Development
- [ ] Create `inst/shiny/election_explorer/` directory
- [ ] Build basic Shiny app structure with bslib
- [ ] Create "Overview" tab with:
  - [ ] Election selector
  - [ ] Turnout summary plots
  - [ ] Results by race plots
- [ ] Create "Maps" tab with:
  - [ ] Interactive leaflet maps
  - [ ] Precinct-level choropleth
  - [ ] Toggle between turnout and vote share
- [ ] Create "Trends" tab with:
  - [ ] Turnout over time
  - [ ] Candidate comparison across elections
- [ ] Create "Data Export" tab with:
  - [ ] CSV download functionality
  - [ ] Excel export option
  - [ ] Custom SQL query interface
- [ ] Test app locally
- [ ] Deploy to shinyapps.io

### Datasette Setup (Optional)
- [ ] Install datasette and plugins
- [ ] Create `metadata.yml` for datasette
- [ ] Test local datasette deployment
- [ ] Deploy to Vercel/Fly.io (optional)

## Quick Wins (Can Do Immediately) ⭐

These can be done in any order and provide immediate value:

- [ ] Create `R/analysis.R` with common analysis functions:
  - [ ] `calculate_vote_share()`
  - [ ] `precinct_performance()`
  - [ ] `turnout_trends()`
- [ ] Create `.github/ISSUE_TEMPLATE/new-election-data.md` template
- [ ] Add `.gitattributes` for Git LFS (for large shapefiles)
- [ ] Create `R/update_data.R` with `add_new_election()` function
- [ ] Update `file_index.csv` with new structure

## Long-term Enhancements (3-6 months)

- [ ] Statistical analysis vignettes (regression, spatial analysis)
- [ ] Demographic data integration (census data)
- [ ] Historical election data digitization (pre-2008)
- [ ] API development for external use
- [ ] Research publication using the data
- [ ] Integration with other municipal data (budget, demographics)

## Questions to Resolve

1. **Package Name**: Should we rename to `framinghamelections` package?
2. **License**: MIT (permissive) or GPL-3 (copyleft)?
3. **Public Access**: Make repository public now or after cleanup?
4. **Shiny Hosting**: shinyapps.io free tier or self-host?
5. **Data Releases**: How often to tag new versions (per election or quarterly)?

## Resources Needed

- Time estimate: ~40-60 hours total for Phases 1-5
- R packages to install: roxygen2, devtools, usethis, pkgdown, testthat, shiny, bslib, datasette (Python)
- Hosting: shinyapps.io account (free tier sufficient initially)

## Success Metrics

- [ ] All election data (2008-2023) in SQLite database
- [ ] All GIS files properly organized and documented
- [ ] R package installable from GitHub
- [ ] Package documentation website live
- [ ] Basic Shiny app deployed and accessible
- [ ] At least 3 analysis vignettes completed
- [ ] All core functions have tests (>80% coverage)

---

**Last Updated:** 2025-11-08
**Next Review:** After Phase 1 completion
