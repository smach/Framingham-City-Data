# LLM-Powered Election Data Extraction Guide

This guide explains how to use ellmer (LLM) to automatically extract race metadata from Framingham election files.

## Why Use LLMs for This?

**Problem**: 39 elections with inconsistent race formatting:
- "District 2 City Councilor (Vote for not more than 1)"
- "City Council At-Large (Vote for 3)"
- "Mayor"
- "Question 1: Charter Amendment..."
- "President of the United States (Democratic Primary)"

**Solution**: LLM extracts structured data automatically!

## What Gets Extracted

For each race, the LLM extracts:

1. **`race_standardized`**: Consistent code (`mayor`, `council_2`, `sc_at_large`, `president_d`)
2. **`race_display_name`**: Clean name ("District 2 City Council")
3. **`num_winners`**: Number of seats (extracted from "Vote for X")
4. **`district`**: District number, "at_large", or NULL
5. **`office_level`**: municipal, state, or federal
6. **`is_primary`**: TRUE/FALSE for primary elections
7. **`party`**: democratic, republican, etc. (for primaries)

For candidates, it extracts:
- **`candidate_last_name`**: Last name for short references

## Setup

### Install Required Packages

```r
install.packages("ellmer")
install.packages("arrow")  # For parquet
install.packages("dplyr")
install.packages("tidyr")
install.packages("stringr")
install.packages("readr")
install.packages("rio")
install.packages("here")
```

### Set OpenAI API Key

```r
# In your .Renviron file:
OPENAI_API_KEY=your-api-key-here

# Or in R session:
Sys.setenv(OPENAI_API_KEY = "your-api-key-here")
```

## Quick Start: Process One Election

```r
# Load the processing function
source("R/process_election_with_llm.R")

# Process 2023 general election
result <- process_election_file(
  excel_path = "data-raw/elections/election_general_2023_framingham_raw_unofficial.xlsx",
  election_date = "2023-11-07",
  election_type = "general",
  election_level = "municipal",
  use_llm = TRUE
)

# View results
View(result$results)  # Tidy race results with metadata
View(result$turnout)  # Turnout by precinct

# Check what was extracted
unique(result$results$Race)  # All race codes
table(result$results$num_winners)  # How many winners per race
```

## Process All Elections

```r
# Process all 39 elections from inventory
all_data <- process_all_elections_batch(
  inventory_path = "data-raw/elections/election_files_inventory_complete.csv",
  use_llm = TRUE,
  save_output = TRUE,
  output_dir = "data/elections/processed"
)

# Combined data across all elections
View(all_data$results)   # All results 2016-2025
View(all_data$turnout)   # All turnout 2016-2025

# Save combined files
arrow::write_parquet(all_data$results, "data/elections/all_results_2016_2025.parquet")
arrow::write_parquet(all_data$turnout, "data/elections/all_turnout_2016_2025.parquet")
```

## How It Works

### Step-by-Step Process

1. **Import Excel** (from Adobe PDF conversion)
2. **Identify race headers** vs candidate rows
3. **Extract race metadata with LLM**:
   ```r
   Office: "District 2 City Councilor (Vote for not more than 1)"

   LLM extracts:
   - race_standardized: "council_2"
   - num_winners: 1
   - district: "2"
   - office_level: "municipal"
   ```

4. **Extract candidate names with LLM**:
   ```r
   CandidateName: "John A. Stefanini"

   LLM extracts:
   - candidate_last_name: "Stefanini"
   ```

5. **Pivot to tidy format** (one row per candidate per precinct)
6. **Extract turnout data** from same Excel file

### Example Output

**Tidy Results Format**:
```
ElectionDate | Race       | Precinct | Candidate  | Votes | num_winners
2023-11-07  | mayor      | 1        | Spicer     | 523   | 1
2023-11-07  | mayor      | 2        | Spicer     | 612   | 1
2023-11-07  | council_2  | 3        | Stefanini  | 234   | 1
2023-11-07  | council_2  | 4        | Stefanini  | 189   | 1
```

**Turnout Format**:
```
ElectionDate | Precinct | Votes_Cast | Total_Registered | Pct_Turnout
2023-11-07  | 1        | 1097       | 2994             | 0.366
2023-11-07  | 2        | 1206       | 3462             | 0.348
```

## Cost Estimates

Using `gpt-4o-mini` (cheapest model):
- **Race metadata**: ~50 unique races across all 39 elections = ~$0.10
- **Candidate names**: ~2000 candidates total = ~$0.30
- **Total for all 39 elections**: ~$0.50

Using `gpt-4o`:
- About 5x more expensive, but potentially more accurate
- Total: ~$2.50

**Recommendation**: Start with `gpt-4o-mini`, upgrade to `gpt-4o` if you see errors.

## Quality Control

### Validate Extractions

```r
# Load processed data
results <- arrow::read_parquet("data/elections/all_results_2016_2025.parquet")

# Check race standardization
results %>%
  count(Race, RaceName, num_winners) %>%
  arrange(Race)

# Look for issues
results %>%
  filter(is.na(Race)) %>%
  View()  # Any races that failed to extract?

# Check num_winners looks reasonable
results %>%
  count(Race, num_winners)
```

### Common Issues

**Issue**: LLM creates slightly different codes for same race
```
council_at_large
council_atlarge
councilatlarge
```

**Fix**: Manual standardization after extraction:
```r
results <- results %>%
  mutate(
    Race = case_when(
      str_detect(Race, "council.*at.*large") ~ "council_at_large",
      str_detect(Race, "^council_\\d+$") ~ Race,  # Keep district councils
      TRUE ~ Race
    )
  )
```

**Issue**: Ballot questions get weird names

**Fix**: Standardize ballot question numbering:
```r
results <- results %>%
  mutate(
    Race = if_else(
      str_detect(Race, "question|ballot"),
      paste0("ballot_question_", str_extract(RaceName, "\\d+")),
      Race
    )
  )
```

## Integration with Database

After processing all elections, load into SQLite:

```r
source("R/database.R")
source("R/storage.R")

# Initialize databases
initialize_storage()

# Load results
results <- arrow::read_parquet("data/elections/all_results_2016_2025.parquet")
turnout <- arrow::read_parquet("data/elections/all_turnout_2016_2025.parquet")

# Save to SQLite + Parquet
save_dual(results, "results", partition_cols = "ElectionYear")
save_dual(turnout, "turnout", partition_cols = "ElectionYear")

# Query example
con <- get_db_connection()
mayor_races <- dbGetQuery(con, "
  SELECT ElectionDate, Candidate, SUM(Votes) as TotalVotes
  FROM results
  WHERE Race = 'mayor'
  GROUP BY ElectionDate, Candidate
  ORDER BY ElectionDate DESC, TotalVotes DESC
")
dbDisconnect(con)
```

## Advantages Over Manual Coding

### Manual Approach (your current one-off script):
- ❌ Requires hardcoded race list for each election
- ❌ Regex patterns miss edge cases
- ❌ Difficult to extract "num_winners" consistently
- ❌ Breaks when clerk changes format
- ⏱️ ~30-60 minutes per election to write custom code

### LLM Approach:
- ✅ Automatically handles any race name format
- ✅ Extracts num_winners from natural language
- ✅ Adapts to format changes
- ✅ Works for historical elections without modification
- ⏱️ ~2 minutes per election (mostly just processing time)

## Best Practices

1. **Reuse chat object**: Pass same `chat` to batch function for efficiency
2. **Validate first election carefully**: Check extractions, then trust the rest
3. **Keep raw files**: Always keep Excel files as backup
4. **Version control**: Commit processed parquet files to git
5. **Document quirks**: Note any manual fixes in `notes` column

## Troubleshooting

### "Rate limit exceeded"
Increase `Sys.sleep()` between batches or reduce `max_active` parameter.

### "API key not found"
Set `OPENAI_API_KEY` environment variable.

### Extraction looks wrong
Try `gpt-4o` instead of `gpt-4o-mini`:
```r
chat <- chat_openai(model = "gpt-4o")
```

### Some races not extracted
Check the Office names in Excel - might need manual fix:
```r
results %>%
  filter(is.na(Race)) %>%
  count(Office) %>%
  View()
```

## Next Steps

After extraction:
1. Load into SQLite database (see `IMPROVEMENT_RECOMMENDATIONS.md`)
2. Create Shiny app for exploration
3. Run analysis (turnout trends, competitive races, etc.)
4. Set up automated pipeline for future elections

---

## Your Existing Script Comparison

**Your 2025 script** (excellent work!):
- ✅ Uses ellmer for candidate names
- ✅ Handles Excel structure well
- ✅ Creates turnout visualizations
- ⚠️ Hardcoded race patterns
- ⚠️ Manual candidate/race list

**This generalized approach**:
- ✅ All your good stuff
- ✅ Plus: LLM race extraction
- ✅ Plus: Works for all 39 elections
- ✅ Plus: Extracts num_winners automatically
- ✅ Plus: Batch processing

You can still use your visualization code! Just load the processed parquet files.
