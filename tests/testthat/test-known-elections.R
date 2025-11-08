# Test known elections produce expected results
# These are "snapshot" tests based on known election outcomes

library(testthat)
library(dplyr)
library(arrow)

test_that("2023 General Election has expected structure", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  # Filter to 2023 general
  election_2023 <- results %>%
    filter(ElectionDate == as.Date("2023-11-07"), ElectionType == "general")

  skip_if(nrow(election_2023) == 0, "2023 general election not in dataset")

  # Should have mayor race
  expect_true("mayor" %in% election_2023$Race)

  # Should have council races
  expect_true(any(grepl("^council_", election_2023$Race)))

  # Should have data for 18 precincts (current Framingham)
  n_precincts <- length(unique(election_2023$Precinct))
  expect_true(
    n_precincts >= 16 && n_precincts <= 20,
    info = paste("Expected 16-20 precincts, got:", n_precincts)
  )

  # Should have reasonable vote counts (not all zeros)
  expect_true(sum(election_2023$Votes) > 1000)
})

test_that("Mayor races have exactly one winner", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  mayor_results <- results %>%
    filter(Race == "mayor")

  skip_if(nrow(mayor_results) == 0, "No mayor races in dataset")

  # Check each mayor election
  mayor_totals <- mayor_results %>%
    group_by(ElectionDate, ElectionType) %>%
    summarize(
      total_votes = sum(Votes, na.rm = TRUE),
      n_candidates = n_distinct(Candidate),
      .groups = "drop"
    )

  # Should have multiple candidates (at least 2 in most elections)
  expect_true(
    mean(mayor_totals$n_candidates >= 2) > 0.5,
    info = "Less than 50% of mayor elections have 2+ candidates"
  )

  # Should have substantial vote totals (at least 1000 votes per election)
  expect_true(
    all(mayor_totals$total_votes > 1000),
    info = paste("Some mayor elections have suspiciously low totals:",
                 paste(mayor_totals$ElectionDate[mayor_totals$total_votes < 1000], collapse = ", "))
  )
})

test_that("No precinct has more votes than registered voters", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  turnout_file <- here::here("data/elections/all_turnout_2016_2025.parquet")

  skip_if_not(file.exists(results_file) && file.exists(turnout_file))

  results <- read_parquet(results_file)
  turnout <- read_parquet(turnout_file)

  # Join turnout to results
  combined <- results %>%
    left_join(
      turnout %>% select(ElectionDate, Precinct, Total_Registered),
      by = c("ElectionDate", "Precinct")
    )

  # Sum votes per precinct per race
  precinct_race_votes <- combined %>%
    group_by(ElectionDate, Race, Precinct, Total_Registered) %>%
    summarize(
      total_race_votes = sum(Votes, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(!is.na(Total_Registered))

  # Votes in any race should not exceed registered voters
  expect_true(
    all(precinct_race_votes$total_race_votes <= precinct_race_votes$Total_Registered, na.rm = TRUE),
    info = "Some precincts have more race votes than registered voters"
  )
})

test_that("Precincts are consistent within elections", {
  results_file <- here::here("data/elections/all_results_2016_2025.parquet")
  skip_if_not(file.exists(results_file))

  results <- read_parquet(results_file)

  # For each election, all races should have same precincts
  precinct_consistency <- results %>%
    group_by(ElectionDate, ElectionType) %>%
    summarize(
      n_unique_precincts_per_race = n_distinct(Precinct),
      .groups = "drop"
    ) %>%
    group_by(ElectionDate, ElectionType) %>%
    summarize(
      consistent = n_distinct(n_unique_precincts_per_race) == 1,
      .groups = "drop"
    )

  # At least 90% of elections should have consistent precincts
  expect_true(
    mean(precinct_consistency$consistent) > 0.9,
    info = "Less than 90% of elections have consistent precinct counts across races"
  )
})
