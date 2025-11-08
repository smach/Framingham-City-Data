# BATCH PROCESS ALL ELECTION FILES
# Run this script to process all Excel files with LLM extraction
# Metadata (date, type, level) is read from election_files_inventory_complete.csv

# ============================================
# Setup
# ============================================

library(here)

# Source required scripts
source(here("R/load_packages.R"))  # Your package loading script
source(here("R/extract_race_metadata.R"))
source(here("R/process_election_with_llm.R"))
source(here("R/build_inventory.R"))

# ============================================
# Step 1: Check inventory
# ============================================

cat("\n")
cat("========================================\n")
cat("STEP 1: Checking inventory\n")
cat("========================================\n\n")

summarize_inventory()

# ============================================
# Step 2: Optional - Update inventory
# ============================================

# Uncomment this if you've added new files since last run
# update_inventory_with_files()

# ============================================
# Step 3: Batch process all elections
# ============================================

cat("\n")
cat("========================================\n")
cat("STEP 2: Processing all elections\n")
cat("========================================\n\n")

cat("This will:\n")
cat("  1. Read metadata from inventory CSV\n")
cat("  2. Process each Excel file with LLM\n")
cat("  3. Extract race metadata and candidate names\n")
cat("  4. Extract turnout data from each file\n")
cat("  5. Save BOTH results AND turnout to Parquet files\n\n")

cat("Estimated cost: ~$0.50 (using gpt-4o-mini)\n")
cat("Estimated time: ~10-15 minutes for all files\n\n")

# Ask for confirmation
response <- readline(prompt = "Continue? (y/n): ")

if (tolower(response) != "y") {
  cat("\nAborted. No changes made.\n")
  quit(save = "no")
}

# Process all elections
all_data <- process_all_elections_batch(
  inventory_path = "data-raw/elections/election_files_inventory_complete.csv",
  use_llm = TRUE,
  save_output = TRUE,
  output_dir = "data/elections/processed",
  process_all = TRUE  # Process everything, not just unprocessed
)

# ============================================
# Step 4: Save combined files
# ============================================

cat("\n")
cat("========================================\n")
cat("STEP 3: Saving combined files\n")
cat("========================================\n\n")

# Create output directory
dir.create("data/elections", showWarnings = FALSE, recursive = TRUE)

# Save combined results
arrow::write_parquet(
  all_data$results,
  "data/elections/all_results_2016_2025.parquet"
)
cat("✓ Saved: data/elections/all_results_2016_2025.parquet\n")

arrow::write_parquet(
  all_data$turnout,
  "data/elections/all_turnout_2016_2025.parquet"
)
cat("✓ Saved: data/elections/all_turnout_2016_2025.parquet\n")

# Also save as CSV for Excel users
readr::write_csv(
  all_data$results,
  "data/elections/all_results_2016_2025.csv"
)
cat("✓ Saved: data/elections/all_results_2016_2025.csv\n")

readr::write_csv(
  all_data$turnout,
  "data/elections/all_turnout_2016_2025.csv"
)
cat("✓ Saved: data/elections/all_turnout_2016_2025.csv\n")

# ============================================
# Step 5: Summary statistics
# ============================================

cat("\n")
cat("========================================\n")
cat("STEP 4: Summary\n")
cat("========================================\n\n")

cat("RESULTS data:\n")
cat("  Total rows: ", format(nrow(all_data$results), big.mark = ","), "\n")
cat("  Unique elections: ", n_distinct(all_data$results$ElectionDate), "\n")
cat("  Unique races: ", n_distinct(all_data$results$Race), "\n")
cat("  Unique candidates: ", n_distinct(all_data$results$Candidate), "\n\n")

cat("TURNOUT data:\n")
cat("  Total rows: ", format(nrow(all_data$turnout), big.mark = ","), "\n")
cat("  Unique elections: ", n_distinct(all_data$turnout$ElectionDate), "\n")
cat("  Avg turnout: ", round(mean(all_data$turnout$Pct_Turnout, na.rm = TRUE) * 100, 1), "%\n\n")

cat("Elections processed:\n")
all_data$results %>%
  distinct(ElectionDate, ElectionType, ElectionLevel) %>%
  arrange(desc(ElectionDate)) %>%
  mutate(
    Display = paste0("  ", ElectionDate, " - ",
                    ElectionLevel, " ", ElectionType)
  ) %>%
  pull(Display) %>%
  cat(sep = "\n")

cat("\n\nUnique races:\n")
all_data$results %>%
  count(Race, sort = TRUE) %>%
  head(20) %>%
  mutate(
    Display = paste0("  ", Race, ": ", format(n, big.mark = ","), " candidate-precinct rows")
  ) %>%
  pull(Display) %>%
  cat(sep = "\n")

cat("\n\nCandidates per election:\n")
all_data$results %>%
  group_by(ElectionDate, ElectionType) %>%
  summarize(
    n_candidates = n_distinct(Candidate),
    n_races = n_distinct(Race),
    .groups = "drop"
  ) %>%
  arrange(desc(ElectionDate)) %>%
  mutate(
    Display = paste0("  ", ElectionDate, " ", ElectionType, ": ",
                    n_candidates, " candidates in ", n_races, " races")
  ) %>%
  pull(Display) %>%
  cat(sep = "\n")

cat("\n")
cat("========================================\n")
cat("COMPLETE!\n")
cat("========================================\n\n")

cat("Next steps:\n")
cat("  1. Load into SQLite: source('R/load_to_database.R')\n")
cat("  2. Validate data: source('R/validate.R')\n")
cat("  3. Create visualizations: Your existing Shiny/map code!\n\n")

cat("Files ready for analysis:\n")
cat("  - data/elections/all_results_2016_2025.parquet\n")
cat("  - data/elections/all_turnout_2016_2025.parquet\n")
cat("  - data/elections/all_results_2016_2025.csv\n")
cat("  - data/elections/all_turnout_2016_2025.csv\n\n")
