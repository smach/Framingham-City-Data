# Test turnout calculations and data integrity

library(testthat)
library(dplyr)
library(arrow)

test_that("Turnout percentages are calculated correctly", {
  turnout_file <- here::here("data/elections/all_turnout_2016_2025.parquet")
  skip_if_not(file.exists(turnout_file))

  turnout <- read_parquet(turnout_file)

  # Recalculate percentages
  calculated <- turnout %>%
    mutate(
      calc_pct = Votes_Cast / Total_Registered
    )

  # Should match within rounding error (0.001)
  expect_true(
    all(abs(calculated$Pct_Turnout - calculated$calc_pct) < 0.001, na.rm = TRUE)
  )
})

test_that("Turnout percentages are between 0 and 1", {
  turnout_file <- here::here("data/elections/all_turnout_2016_2025.parquet")
  skip_if_not(file.exists(turnout_file))

  turnout <- read_parquet(turnout_file)

  expect_true(all(turnout$Pct_Turnout >= 0, na.rm = TRUE))
  expect_true(all(turnout$Pct_Turnout <= 1, na.rm = TRUE))
})

test_that("Votes cast never exceeds registered voters", {
  turnout_file <- here::here("data/elections/all_turnout_2016_2025.parquet")
  skip_if_not(file.exists(turnout_file))

  turnout <- read_parquet(turnout_file)

  # Should never have more votes than registered
  expect_true(all(turnout$Votes_Cast <= turnout$Total_Registered, na.rm = TRUE))
})

test_that("Each election-precinct combination appears only once", {
  turnout_file <- here::here("data/elections/all_turnout_2016_2025.parquet")
  skip_if_not(file.exists(turnout_file))

  turnout <- read_parquet(turnout_file)

  duplicates <- turnout %>%
    count(ElectionDate, Precinct) %>%
    filter(n > 1)

  expect_equal(nrow(duplicates), 0,
    info = paste("Duplicate election-precinct combos:",
                 paste(duplicates$ElectionDate, duplicates$Precinct, collapse = ", "))
  )
})

test_that("Turnout data exists for all elections in results", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  turnout_file <- here::here("data/elections/all_turnout_2016_2025.parquet")

  skip_if_not(file.exists(results_file) && file.exists(turnout_file))

  results <- read_parquet(results_file)
  turnout <- read_parquet(turnout_file)

  # Get unique elections from results
  result_elections <- results %>%
    distinct(ElectionDate, ElectionType, ElectionLevel)

  # Get unique elections from turnout
  turnout_elections <- turnout %>%
    distinct(ElectionDate, ElectionType, ElectionLevel)

  # Every election in results should have turnout data
  missing_turnout <- result_elections %>%
    anti_join(turnout_elections, by = c("ElectionDate", "ElectionType", "ElectionLevel"))

  expect_equal(nrow(missing_turnout), 0,
    info = paste("Elections missing turnout:", paste(missing_turnout$ElectionDate, collapse = ", "))
  )
})
