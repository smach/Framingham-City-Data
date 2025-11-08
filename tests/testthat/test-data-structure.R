# Test data structure and column presence

library(testthat)
library(dplyr)
library(arrow)

test_that("Processed results have required columns", {
  # If results file exists, test it
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")

  skip_if_not(file.exists(results_file), "Results file not yet created")

  results <- read_parquet(results_file)

  # Required columns
  required_cols <- c(
    "ElectionDate", "ElectionYear", "ElectionType", "ElectionLevel",
    "Race", "RaceName", "Office",
    "Precinct", "Candidate", "CandidateName", "Votes"
  )

  expect_true(
    all(required_cols %in% names(results)),
    info = paste("Missing columns:", paste(setdiff(required_cols, names(results)), collapse = ", "))
  )
})

test_that("Turnout data has required columns", {
  turnout_file <- here::here("data/elections/all_turnout_2016_2025.parquet")

  skip_if_not(file.exists(turnout_file), "Turnout file not yet created")

  turnout <- read_parquet(turnout_file)

  required_cols <- c(
    "ElectionDate", "ElectionYear", "ElectionType", "ElectionLevel",
    "Precinct", "Votes_Cast", "Total_Registered", "Pct_Turnout"
  )

  expect_true(all(required_cols %in% names(turnout)))
})

test_that("Election dates are valid", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  # All dates should be valid
  expect_true(all(!is.na(results$ElectionDate)))

  # Dates should be in reasonable range
  expect_true(all(results$ElectionYear >= 2016 & results$ElectionYear <= 2030))

  # ElectionYear should match year from ElectionDate
  expect_equal(
    results$ElectionYear,
    lubridate::year(results$ElectionDate)
  )
})

test_that("Vote counts are non-negative integers", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  expect_true(all(results$Votes >= 0, na.rm = TRUE))
  expect_true(all(results$Votes == floor(results$Votes), na.rm = TRUE))
})

test_that("Election types are valid values", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  valid_types <- c("general", "preliminary", "primary", "special", "charter")
  expect_true(all(results$ElectionType %in% valid_types))

  valid_levels <- c("municipal", "state", "federal")
  expect_true(all(results$ElectionLevel %in% valid_levels))
})

test_that("No missing race or candidate data", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  # Should have race for every row
  expect_equal(sum(is.na(results$Race)), 0)

  # Should have candidate for every row
  expect_equal(sum(is.na(results$Candidate)), 0)

  # Should have votes for every row
  expect_equal(sum(is.na(results$Votes)), 0)
})
