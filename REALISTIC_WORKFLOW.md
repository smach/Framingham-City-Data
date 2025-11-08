# Realistic Workflow for Election Data Processing

Based on your experience with Framingham clerk PDFs, here's a practical workflow that assumes manual PDF conversion will be needed.

## Phase 1: Data Collection

### Step 1: Download Missing PDFs
- Visit https://www.framinghamma.gov/3095/Election-Results
- Download the 17 missing elections (see `MISSING_ELECTIONS.md`)
- Save to new branch: `data-collection/add-missing-elections-2024`
- Use original filenames from clerk website

### Step 2: Organize Files
```bash
# Create branch for data collection
git checkout -b data-collection/add-missing-elections-2024

# Download files to data-raw/elections/
# Keep original filenames for now

# Update inventory
# Edit: data-raw/elections/election_files_inventory_complete.csv
# Add the original filename for each new download

# Commit
git add data-raw/elections/*.pdf
git add data-raw/elections/election_files_inventory_complete.csv
git commit -m "Add missing election PDFs from 2024, 2023, 2020, 2019, 2018, 2016"
git push -u origin data-collection/add-missing-elections-2024
```

---

## Phase 2: PDF to Excel Conversion

### Option A: Test R Extraction (Optional)
Run the test script to see if automated extraction is feasible:

```r
source("R/test_pdf_extraction.R")
```

**If extraction looks good (80%+ accurate)**:
- Use R for batch conversion
- Plan for manual cleanup in Excel afterwards

**If extraction is messy**:
- Proceed to Option B

### Option B: Manual Adobe Conversion (Recommended)

For each PDF that needs conversion:

1. **Upload to Adobe Acrobat** (or use desktop Adobe)
2. **Export as Excel** (xlsx format)
3. **Quick visual check** - make sure tables look reasonable
4. **Save with standardized name** in `data-raw/elections/`
   - Example: `2024-11-05_state_general_official_framingham.xlsx`
5. **Update inventory CSV** - mark as converted

### Batch Processing Tips
- Do 5-10 files at a time
- Keep PDF and Excel versions (disk is cheap)
- Don't worry about perfect Excel formatting - we'll clean in R
- Just make sure precinct numbers and vote counts are readable

---

## Phase 3: Excel to Tidy Data (R Processing)

This is where R shines! Even messy Excel files can be cleaned programmatically.

### Step 1: Inspect Raw Excel Structure

For each election, look at the Excel structure:
```r
library(readxl)

# What sheets exist?
excel_sheets("data-raw/elections/2024-11-05_state_general_official_framingham.xlsx")

# Read first sheet
raw <- read_excel("data-raw/elections/2024-11-05_state_general_official_framingham.xlsx",
                  sheet = 1)

# Look at structure
View(raw)
str(raw)
```

### Step 2: Create Custom Processing Function

Each election might need slightly different cleaning logic:

```r
# R/process_2024_state_general.R

process_2024_state_general <- function() {
  library(dplyr)
  library(tidyr)
  library(readxl)
  library(janitor)
  library(here)

  raw <- read_excel(here("data-raw/elections/2024-11-05_state_general_official_framingham.xlsx"))

  # Custom cleaning for this election
  clean <- raw %>%
    # Remove empty rows
    filter(!is.na(Precinct) | !is.na(`Precinct`)) %>%  # Handle different column names
    # Clean column names
    janitor::clean_names() %>%
    # Remove "Total" rows
    filter(precinct != "Total") %>%
    # Convert to tidy format
    pivot_longer(
      cols = -precinct,
      names_to = "candidate_name",
      values_to = "votes"
    ) %>%
    # Add metadata
    mutate(
      election_date = as.Date("2024-11-05"),
      election_year = 2024,
      election_level = "state",
      election_type = "general",
      precinct = as.integer(precinct),
      votes = as.integer(votes),
      is_blank = str_detect(tolower(candidate_name), "blank"),
      is_writeIn = str_detect(tolower(candidate_name), "write")
    ) %>%
    # Reorder columns
    select(election_date, election_year, election_level, election_type,
           precinct, candidate_name, votes, is_blank, is_writeIn)

  return(clean)
}

# Process and save
tidy_data <- process_2024_state_general()
write_csv(tidy_data, "data/elections/tidy/2024-11-05_state_general_framingham.csv")
```

### Step 3: Process All Elections

Create a master processing script:

```r
# R/process_all_elections.R

source(here::here("R/election_helpers.R"))

# List all processing functions
process_2017_general <- function() { ... }
process_2017_preliminary <- function() { ... }
process_2019_general <- function() { ... }
# ... etc for each election

# Run all
all_tidy_data <- list(
  process_2017_general(),
  process_2017_preliminary(),
  process_2019_general(),
  # ... etc
) %>%
  bind_rows()

# Quality check
summary(all_tidy_data)
```

---

## Phase 4: Load into SQLite + Parquet

Once you have tidy CSV files, loading into database is straightforward:

```r
source(here::here("R/database.R"))
source(here::here("R/storage.R"))

# Initialize databases
initialize_storage()

# Load all tidy CSVs
tidy_files <- list.files("data/elections/tidy", pattern = "*.csv", full.names = TRUE)

for (file in tidy_files) {
  data <- read_csv(file)

  # Save to both SQLite and Parquet
  save_dual(data, table_name = "results", partition_cols = "election_year")
}

# Verify
con <- get_db_connection()
dbGetQuery(con, "SELECT COUNT(*) FROM results")
dbDisconnect(con)
```

---

## Phase 5: Validation & Quality Checks

After loading everything:

```r
source(here::here("R/validate.R"))

# Check for missing precincts
check_missing_precincts()

# Validate totals
validate_precinct_totals()

# Check for duplicates
check_duplicates()

# Generate summary report
generate_data_quality_report()
```

---

## Realistic Timeline

### Week 1: Data Collection
- Download 17 missing PDFs
- Convert to Excel (Adobe or R)
- Update inventory CSV
- **Estimate**: 3-4 hours

### Week 2: R Processing
- Create processing functions for each election
- Convert Excel → Tidy CSV
- Fix any data issues discovered
- **Estimate**: 6-8 hours (more if elections have weird formatting)

### Week 3: Database Setup
- Implement SQLite schema
- Load all data
- Set up Parquet storage
- Run validation checks
- **Estimate**: 4-6 hours

### Week 4: Documentation & Testing
- Document any data quirks
- Create analysis examples
- Write tests
- **Estimate**: 2-4 hours

**Total**: 15-22 hours over 4 weeks

---

## Key Principles

1. **Keep raw files forever** - PDFs and Excel versions are your source of truth
2. **Iterate on R scripts** - First pass won't be perfect, that's okay
3. **Manual is fine** - If Adobe conversion saves you 10 hours of debugging R code, do it
4. **Document quirks** - Note weird formatting in `notes` column of inventory
5. **Validate early** - Check precinct totals after each election to catch errors fast

---

## Common Issues & Solutions

### Issue: Excel file has multiple sheets
**Solution**:
```r
sheets <- excel_sheets(file)
all_data <- map_df(sheets, ~read_excel(file, sheet = .x))
```

### Issue: Column names change between elections
**Solution**:
```r
# Use janitor::clean_names() to standardize
# Then use rename() to fix any remaining issues
data %>%
  clean_names() %>%
  rename(
    votes = total_votes,
    candidate = candidate_name
  )
```

### Issue: Precinct numbers have leading zeros or text
**Solution**:
```r
data %>%
  mutate(
    precinct = str_extract(precinct, "\\d+"),  # Extract just numbers
    precinct = as.integer(precinct)
  )
```

### Issue: Blank/Write-in rows mixed with candidates
**Solution**:
```r
data %>%
  mutate(
    is_blank = str_detect(tolower(candidate_name), "blank"),
    is_writeIn = str_detect(tolower(candidate_name), "write")
  ) %>%
  # Keep all rows, just flag them
  # OR filter them out if not needed
  filter(!is_blank & !is_writeIn)
```

---

## What Success Looks Like

At the end of this process, you'll have:

✅ All 39 elections from 2016-2025 in consistent format
✅ SQLite database for complex queries
✅ Parquet files for fast analytics
✅ CSV exports for Excel users
✅ Validated data (totals match, no missing precincts)
✅ Reproducible R scripts for future elections
✅ Clear documentation of process

And most importantly: **A system that makes adding new elections easy!**

When the 2026 preliminary election happens, you'll just:
1. Download PDF from clerk
2. Convert to Excel (Adobe)
3. Run: `process_2026_preliminary()` (copy/paste from previous election script)
4. Load into database
5. Done in < 30 minutes!
