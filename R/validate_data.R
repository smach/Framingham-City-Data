# Data Validation Functions
# Can be used in testthat tests or run standalone

library(dplyr)
library(arrow)
library(here)

#' Validate processed election results
#'
#' @param results_path Path to results parquet file
#' @param turnout_path Path to turnout parquet file
#' @param verbose Print detailed messages
#'
#' @return List of validation results
validate_election_data <- function(results_path = "data/elections/all_results_2016_2025.parquet",
                                    turnout_path = "data/elections/all_turnout_2016_2025.parquet",
                                    verbose = TRUE) {

  if (verbose) {
    cat("========================================\n")
    cat("VALIDATING ELECTION DATA\n")
    cat("========================================\n\n")
  }

  issues <- list()

  # ============================================
  # Load data
  # ============================================
  if (verbose) cat("Loading data...\n")

  results <- read_parquet(here(results_path))
  turnout <- read_parquet(here(turnout_path))

  if (verbose) {
    cat("  Results rows:", format(nrow(results), big.mark = ","), "\n")
    cat("  Turnout rows:", format(nrow(turnout), big.mark = ","), "\n\n")
  }

  # ============================================
  # Check 1: Required columns present
  # ============================================
  if (verbose) cat("Checking required columns...\n")

  required_result_cols <- c("ElectionDate", "ElectionYear", "ElectionType",
                            "ElectionLevel", "Race", "Precinct", "Candidate", "Votes")
  missing_result_cols <- setdiff(required_result_cols, names(results))

  if (length(missing_result_cols) > 0) {
    issues$missing_result_columns <- missing_result_cols
    if (verbose) cat("  ❌ Missing columns in results:", paste(missing_result_cols, collapse = ", "), "\n")
  } else {
    if (verbose) cat("  ✓ All required result columns present\n")
  }

  required_turnout_cols <- c("ElectionDate", "Precinct", "Votes_Cast", "Total_Registered")
  missing_turnout_cols <- setdiff(required_turnout_cols, names(turnout))

  if (length(missing_turnout_cols) > 0) {
    issues$missing_turnout_columns <- missing_turnout_cols
    if (verbose) cat("  ❌ Missing columns in turnout:", paste(missing_turnout_cols, collapse = ", "), "\n")
  } else {
    if (verbose) cat("  ✓ All required turnout columns present\n")
  }

  # ============================================
  # Check 2: No missing critical data
  # ============================================
  if (verbose) cat("\nChecking for missing data...\n")

  missing_race <- sum(is.na(results$Race))
  if (missing_race > 0) {
    issues$missing_race <- missing_race
    if (verbose) cat("  ❌", missing_race, "rows missing Race\n")
  } else {
    if (verbose) cat("  ✓ No missing Race values\n")
  }

  missing_votes <- sum(is.na(results$Votes))
  if (missing_votes > 0) {
    issues$missing_votes <- missing_votes
    if (verbose) cat("  ❌", missing_votes, "rows missing Votes\n")
  } else {
    if (verbose) cat("  ✓ No missing Votes values\n")
  }

  # ============================================
  # Check 3: Turnout calculations
  # ============================================
  if (verbose) cat("\nValidating turnout calculations...\n")

  turnout_check <- turnout %>%
    mutate(
      calc_pct = Votes_Cast / Total_Registered,
      diff = abs(Pct_Turnout - calc_pct)
    )

  bad_turnout <- turnout_check %>%
    filter(diff > 0.001)

  if (nrow(bad_turnout) > 0) {
    issues$bad_turnout_calculations <- nrow(bad_turnout)
    if (verbose) cat("  ❌", nrow(bad_turnout), "rows have incorrect turnout calculations\n")
  } else {
    if (verbose) cat("  ✓ All turnout percentages calculated correctly\n")
  }

  # Check turnout range
  out_of_range <- turnout %>%
    filter(Pct_Turnout < 0 | Pct_Turnout > 1)

  if (nrow(out_of_range) > 0) {
    issues$turnout_out_of_range <- nrow(out_of_range)
    if (verbose) cat("  ❌", nrow(out_of_range), "rows have turnout outside 0-1 range\n")
  } else {
    if (verbose) cat("  ✓ All turnout percentages in valid range (0-1)\n")
  }

  # Check votes_cast <= registered
  over_registered <- turnout %>%
    filter(Votes_Cast > Total_Registered)

  if (nrow(over_registered) > 0) {
    issues$votes_exceed_registered <- nrow(over_registered)
    if (verbose) {
      cat("  ❌", nrow(over_registered), "precincts have more votes than registered voters\n")
      if (nrow(over_registered) <= 5) {
        print(over_registered %>% select(ElectionDate, Precinct, Votes_Cast, Total_Registered))
      }
    }
  } else {
    if (verbose) cat("  ✓ No precincts with more votes than registered\n")
  }

  # ============================================
  # Check 4: Race standardization
  # ============================================
  if (verbose) cat("\nChecking race standardization...\n")

  races <- unique(results$Race)

  # Check lowercase
  non_lowercase <- races[races != tolower(races)]
  if (length(non_lowercase) > 0) {
    issues$non_lowercase_races <- non_lowercase
    if (verbose) cat("  ⚠️", length(non_lowercase), "races not lowercase\n")
  } else {
    if (verbose) cat("  ✓ All races lowercase\n")
  }

  # Check no spaces
  with_spaces <- races[grepl(" ", races)]
  if (length(with_spaces) > 0) {
    issues$races_with_spaces <- with_spaces
    if (verbose) cat("  ⚠️", length(with_spaces), "races contain spaces\n")
  } else {
    if (verbose) cat("  ✓ No races with spaces\n")
  }

  # ============================================
  # Check 5: Election coverage
  # ============================================
  if (verbose) cat("\nChecking election coverage...\n")

  result_elections <- results %>%
    distinct(ElectionDate, ElectionType, ElectionLevel) %>%
    arrange(desc(ElectionDate))

  turnout_elections <- turnout %>%
    distinct(ElectionDate, ElectionType, ElectionLevel) %>%
    arrange(desc(ElectionDate))

  # Elections with results but no turnout
  missing_turnout_elections <- result_elections %>%
    anti_join(turnout_elections, by = c("ElectionDate", "ElectionType", "ElectionLevel"))

  if (nrow(missing_turnout_elections) > 0) {
    issues$elections_missing_turnout <- missing_turnout_elections
    if (verbose) {
      cat("  ⚠️", nrow(missing_turnout_elections), "elections missing turnout data:\n")
      print(missing_turnout_elections)
    }
  } else {
    if (verbose) cat("  ✓ All elections have turnout data\n")
  }

  # ============================================
  # Check 6: Precinct consistency
  # ============================================
  if (verbose) cat("\nChecking precinct consistency...\n")

  precinct_counts <- results %>%
    group_by(ElectionDate, ElectionType) %>%
    summarize(
      n_precincts = n_distinct(Precinct),
      .groups = "drop"
    )

  # Most elections should have 18 precincts (post-2021) or similar
  typical_count <- median(precinct_counts$n_precincts)

  unusual_precinct_counts <- precinct_counts %>%
    filter(abs(n_precincts - typical_count) > 5)

  if (nrow(unusual_precinct_counts) > 0) {
    issues$unusual_precinct_counts <- unusual_precinct_counts
    if (verbose) {
      cat("  ⚠️", nrow(unusual_precinct_counts), "elections have unusual precinct counts:\n")
      print(unusual_precinct_counts)
    }
  } else {
    if (verbose) cat("  ✓ Precinct counts look consistent\n")
  }

  # ============================================
  # Check 7: Duplicate detection
  # ============================================
  if (verbose) cat("\nChecking for duplicates...\n")

  # Check for duplicate election-race-precinct-candidate combos
  duplicates <- results %>%
    count(ElectionDate, Race, Precinct, Candidate) %>%
    filter(n > 1)

  if (nrow(duplicates) > 0) {
    issues$duplicate_results <- nrow(duplicates)
    if (verbose) {
      cat("  ❌", nrow(duplicates), "duplicate election-race-precinct-candidate combinations\n")
      if (nrow(duplicates) <= 10) {
        print(duplicates)
      }
    }
  } else {
    if (verbose) cat("  ✓ No duplicate results\n")
  }

  # Check for duplicate turnout
  turnout_duplicates <- turnout %>%
    count(ElectionDate, Precinct) %>%
    filter(n > 1)

  if (nrow(turnout_duplicates) > 0) {
    issues$duplicate_turnout <- nrow(turnout_duplicates)
    if (verbose) {
      cat("  ❌", nrow(turnout_duplicates), "duplicate election-precinct turnout rows\n")
      if (nrow(turnout_duplicates) <= 10) {
        print(turnout_duplicates)
      }
    }
  } else {
    if (verbose) cat("  ✓ No duplicate turnout rows\n")
  }

  # ============================================
  # Summary
  # ============================================
  if (verbose) {
    cat("\n========================================\n")
    cat("VALIDATION SUMMARY\n")
    cat("========================================\n\n")

    if (length(issues) == 0) {
      cat("✅ ALL CHECKS PASSED!\n\n")
      cat("Your data looks great!\n")
    } else {
      cat("⚠️  FOUND", length(issues), "ISSUES\n\n")
      cat("Issues found:\n")
      for (issue_name in names(issues)) {
        cat("  -", issue_name, "\n")
      }
      cat("\nSee details above for each issue.\n")
    }
    cat("\n")
  }

  invisible(issues)
}

#' Generate data quality report
#'
#' @param output_file Path to save HTML report
generate_quality_report <- function(output_file = "data_quality_report.html") {
  # Run validation
  issues <- validate_election_data(verbose = FALSE)

  results <- read_parquet(here("data/elections/all_results_2016_2025.parquet"))
  turnout <- read_parquet(here("data/elections/all_turnout_2016_2025.parquet"))

  # Create HTML report
  html <- paste0("
  <html>
  <head><title>Election Data Quality Report</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    h2 { color: #666; border-bottom: 2px solid #ddd; }
    .pass { color: green; }
    .fail { color: red; }
    .warn { color: orange; }
    table { border-collapse: collapse; width: 100%; margin: 10px 0; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f0f0f0; }
  </style>
  </head>
  <body>
  <h1>Framingham Election Data Quality Report</h1>
  <p>Generated: ", Sys.time(), "</p>

  <h2>Data Summary</h2>
  <table>
  <tr><th>Metric</th><th>Value</th></tr>
  <tr><td>Total result rows</td><td>", format(nrow(results), big.mark = ","), "</td></tr>
  <tr><td>Total turnout rows</td><td>", format(nrow(turnout), big.mark = ","), "</td></tr>
  <tr><td>Unique elections</td><td>", n_distinct(results$ElectionDate), "</td></tr>
  <tr><td>Unique races</td><td>", n_distinct(results$Race), "</td></tr>
  <tr><td>Unique candidates</td><td>", n_distinct(results$Candidate), "</td></tr>
  <tr><td>Date range</td><td>", min(results$ElectionDate), " to ", max(results$ElectionDate), "</td></tr>
  </table>

  <h2>Validation Results</h2>
  ")

  if (length(issues) == 0) {
    html <- paste0(html, "<p class='pass'>✅ All validation checks passed!</p>")
  } else {
    html <- paste0(html, "<p class='fail'>⚠️ Found ", length(issues), " issues:</p>")
    html <- paste0(html, "<ul>")
    for (issue_name in names(issues)) {
      html <- paste0(html, "<li>", issue_name, "</li>")
    }
    html <- paste0(html, "</ul>")
  }

  html <- paste0(html, "</body></html>")

  writeLines(html, output_file)
  message("Quality report saved to: ", output_file)

  if (interactive()) {
    browseURL(output_file)
  }

  invisible(issues)
}

# ============================================
# Example usage
# ============================================

if (FALSE) {
  # Run validation
  issues <- validate_election_data()

  # Generate HTML report
  generate_quality_report("election_data_quality_report.html")
}
