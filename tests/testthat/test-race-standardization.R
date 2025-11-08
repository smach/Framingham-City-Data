# Test race code standardization

library(testthat)
library(dplyr)
library(arrow)

test_that("Race codes follow naming convention", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  # Get unique races
  races <- unique(results$Race)

  # Should all be lowercase
  expect_true(all(races == tolower(races)))

  # Should use underscores, not spaces
  expect_false(any(grepl(" ", races)))

  # Common patterns should match expected format
  mayor_races <- races[grepl("mayor", races)]
  expect_true(all(mayor_races == "mayor"))

  council_races <- races[grepl("^council_\\d+$", races)]
  expect_true(length(council_races) > 0, info = "Should have district council races")

  at_large_races <- races[grepl("at_large", races)]
  expect_true(all(grepl("_at_large$", at_large_races)))
})

test_that("num_winners is reasonable", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  # If num_winners column exists
  if ("num_winners" %in% names(results)) {
    # Should be at least 1
    expect_true(all(results$num_winners >= 1, na.rm = TRUE))

    # Should be reasonable (not > 20)
    expect_true(all(results$num_winners <= 20, na.rm = TRUE))

    # Mayor should always be 1
    mayor_results <- results %>% filter(Race == "mayor")
    if (nrow(mayor_results) > 0) {
      expect_true(all(mayor_results$num_winners == 1, na.rm = TRUE))
    }
  }
})

test_that("District races have district information", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  # District council races (e.g., council_2)
  district_races <- results %>%
    filter(grepl("^council_\\d+$|^sc_\\d+$", Race))

  if (nrow(district_races) > 0 && "district" %in% names(district_races)) {
    # Should have district info
    expect_true(
      sum(is.na(district_races$district)) / nrow(district_races) < 0.1,
      info = "More than 10% of district races missing district info"
    )
  }
})

test_that("Primary races are marked correctly", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  if ("is_primary" %in% names(results)) {
    # Primary elections should have is_primary = TRUE
    primary_elections <- results %>%
      filter(ElectionType == "primary")

    if (nrow(primary_elections) > 0) {
      expect_true(
        mean(primary_elections$is_primary, na.rm = TRUE) > 0.8,
        info = "Less than 80% of primary election races marked as primary"
      )
    }

    # General elections should mostly have is_primary = FALSE
    general_elections <- results %>%
      filter(ElectionType == "general")

    if (nrow(general_elections) > 0) {
      expect_true(
        mean(!general_elections$is_primary, na.rm = TRUE) > 0.8,
        info = "Less than 80% of general election races marked as non-primary"
      )
    }
  }
})
