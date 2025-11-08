# Quick Start: Process All Election Files

This guide shows you how to process all your election files in one go, with metadata automatically read from the inventory CSV.

## ✅ What You Need

1. Excel files (converted from PDFs using Adobe)
2. OpenAI API key for LLM extraction
3. `election_files_inventory_complete.csv` with metadata

## 🚀 One-Command Processing

```r
# Process everything!
source("R/run_batch_processing.R")
```

That's it! The script will:
- ✅ Read metadata (date, type, level) from inventory CSV
- ✅ Process all Excel files with LLM
- ✅ Extract race metadata and candidate names
- ✅ Save to Parquet + CSV

**No manual date/type entry needed!** Everything is pulled from the inventory.

## 📋 How It Works

### The Inventory CSV Structure

```csv
election_date,election_level,election_type,have_file,filename_original
2023-11-07,municipal,general,YES,election_general_2023_framingham_raw_unofficial.xlsx
2022-11-08,state,general,YES,NOVEMBER 8, 2022 STATE ELECTION UNOFFICIAL RESULTS.pdf
2021-11-02,municipal,general,YES,election_general_2021_framingham_official_raw.xlsx
```

The batch processor reads these columns:
- **`election_date`**: Used for ElectionDate
- **`election_level`**: municipal/state/federal
- **`election_type`**: general/preliminary/primary/special
- **`filename_original`**: Which file to process

**No parsing filenames!** Everything is in the CSV.

## 📝 Step-by-Step Workflow

### Before Processing

1. **Download missing PDFs** from city clerk website (see `MISSING_ELECTIONS.md`)

2. **Convert PDFs to Excel** using Adobe Acrobat

3. **Update inventory CSV** with new files:
   ```r
   source("R/build_inventory.R")

   # Option A: Auto-scan directory and build inventory
   inventory <- scan_and_build_inventory("data-raw/elections")

   # Option B: Update existing inventory
   update_inventory_with_files()

   # Option C: Manually edit the CSV
   # Just add rows with: election_date, election_level, election_type, filename_original
   ```

4. **Check inventory**:
   ```r
   source("R/build_inventory.R")
   summarize_inventory()
   ```

### During Processing

5. **Run batch processor**:
   ```r
   source("R/run_batch_processing.R")
   ```

   This prompts for confirmation, then processes everything.

### After Processing

6. **Check output**:
   ```r
   # Read combined results
   library(arrow)
   results <- read_parquet("data/elections/all_results_2016_2025.parquet")
   turnout <- read_parquet("data/elections/all_turnout_2016_2025.parquet")

   # Quick check
   View(results)
   unique(results$Race)  # All races extracted
   ```

7. **Validate**:
   ```r
   # Check for missing races
   results %>%
     filter(is.na(Race)) %>%
     count(Office)

   # Check num_winners looks reasonable
   results %>%
     count(Race, num_winners)
   ```

## 🎛️ Customization Options

### Process Only New Files

```r
# Only process files where has_been_processed = FALSE
all_data <- process_all_elections_batch(
  process_all = FALSE  # Only new files
)
```

### Use Manual Regex Instead of LLM

```r
# Skip LLM, use regex patterns
all_data <- process_all_elections_batch(
  use_llm = FALSE
)
```

### Process Single Election

```r
source("R/process_election_with_llm.R")

result <- process_election_file(
  excel_path = "data-raw/elections/election_general_2023_framingham_raw_unofficial.xlsx",
  election_date = "2023-11-07",      # From inventory CSV
  election_type = "general",          # From inventory CSV
  election_level = "municipal",       # From inventory CSV
  use_llm = TRUE
)

View(result$results)
```

## 📊 Output Files

After processing, you'll have:

### Individual Election Files
```
data/elections/processed/
├── 2023-11-07_municipal_general_results.parquet
├── 2023-11-07_municipal_general_turnout.parquet
├── 2022-11-08_state_general_results.parquet
├── 2022-11-08_state_general_turnout.parquet
└── ... (one pair per election)
```

### Combined Files
```
data/elections/
├── all_results_2016_2025.parquet    # All elections combined
├── all_turnout_2016_2025.parquet    # All turnout combined
├── all_results_2016_2025.csv        # CSV for Excel users
└── all_turnout_2016_2025.csv        # CSV for Excel users
```

## 🔧 Common Tasks

### Add New Election

1. Download PDF from clerk website
2. Convert to Excel with Adobe
3. Add row to inventory CSV:
   ```csv
   2025-11-04,municipal,general,YES,2025_general_unofficial.xlsx
   ```
4. Run: `source("R/run_batch_processing.R")`

### Re-process One Election

```r
# Just delete the output file and re-run
file.remove("data/elections/processed/2023-11-07_municipal_general_results.parquet")
source("R/run_batch_processing.R")
```

### Update Inventory from Files

```r
source("R/build_inventory.R")

# Scan directory and match against inventory
update_inventory_with_files()
```

## 💰 Cost & Time

- **Cost**: ~$0.50 for all 39 elections (using gpt-4o-mini)
- **Time**: ~10-15 minutes total processing time
- **Per election**: ~$0.01 and ~20 seconds

## ❓ Troubleshooting

### "File not found" error
- Check that `filename_original` in CSV matches actual filename
- Check that file is in `data-raw/elections/` directory

### "Missing metadata" warning
- Make sure inventory has: `election_date`, `election_level`, `election_type`
- Run `summarize_inventory()` to find missing metadata

### LLM extraction looks wrong
- Try `gpt-4o` instead of `gpt-4o-mini` (5x more expensive but more accurate)
- Or set `use_llm = FALSE` to use regex patterns

### Rate limit errors
- Reduce `max_active` in `extract_race_metadata()`
- Add longer `Sys.sleep()` between batches

## 🎯 Your Existing Code

Good news: Your existing visualization code will work with the output!

```r
# Your existing script
results_tidy <- arrow::read_parquet("data/elections/all_results_2016_2025.parquet")

# Filter to specific election
results_2025 <- results_tidy %>%
  filter(ElectionDate == "2025-11-04")

# Your visualization code works as-is!
# Just use ElectionDate, Race, Candidate, Votes, Precinct columns
```

## 📚 Additional Resources

- **Full documentation**: `LLM_EXTRACTION_GUIDE.md`
- **Workflow details**: `REALISTIC_WORKFLOW.md`
- **Improvements plan**: `IMPROVEMENT_RECOMMENDATIONS.md`
- **Missing files**: `MISSING_ELECTIONS.md`

---

## TL;DR

```r
# 1. Set your API key
Sys.setenv(OPENAI_API_KEY = "your-key-here")

# 2. Make sure inventory CSV has metadata for all files
source("R/build_inventory.R")
summarize_inventory()

# 3. Run the batch processor
source("R/run_batch_processing.R")

# 4. Use the output
results <- arrow::read_parquet("data/elections/all_results_2016_2025.parquet")
```

**The inventory CSV has all the metadata - no manual entry needed!**
