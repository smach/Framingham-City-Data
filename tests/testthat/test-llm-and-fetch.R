# Tests for the code around the LLM extraction and the clerk-page checker.
# These don't call Claude or the internet: they feed in a fake model reply
# built from a real clerk spreadsheet.

# Turn an extracted data frame back into the wide CSV text Claude is asked for
fake_llm_reply <- function(extracted) {
  wide <- tidyr::pivot_wider(extracted, names_from = precinct, values_from = votes)
  csv <- readr::format_csv(wide, na = "")
  paste0("Here are the results:\n\n```csv\n", csv, "```\n")
}

test_that("a CSV reply from the model becomes the same extracted data", {
  meta <- read_registry()
  meta <- meta[meta$election_id == "2023-11-07_municipal_general", ]
  original <- read_election_raw(meta)
  roundtrip <- wide_to_extracted(parse_llm_csv(fake_llm_reply(original)))
  key <- function(d) d[order(d$section, d$race, d$candidate, d$precinct), c("section", "race", "candidate", "precinct", "votes")]
  expect_equal(key(roundtrip), key(original), ignore_attr = TRUE)
})

test_that("a model reply with a wrong digit is caught by validation", {
  meta <- read_registry()
  meta <- meta[meta$election_id == "2017-11-07_municipal_general", ]
  original <- read_election_raw(meta)
  reply <- fake_llm_reply(original)
  # Simulate a misread: Yvonne M. Spicer's precinct-1 vote 755 read as 735
  reply <- sub("Yvonne M. Spicer,755,", "Yvonne M. Spicer,735,", reply, fixed = TRUE)
  ex <- wide_to_extracted(parse_llm_csv(reply))
  checks <- validate_election(ex, tidy_results(ex, meta), tidy_turnout(ex, meta), meta)
  expect_equal(checks$status[checks$check == "precincts_sum_to_reported_total"], "fail")
})

test_that("dates and election kinds are guessed from link text", {
  expect_equal(guess_date(c("November 4, 2025 City Election - Unofficial", "Results 9/6/2022", "Other")),
               as.Date(c("2025-11-04", "2022-09-06", NA)))
  k <- guess_election_kind(c("September 3 2024 State Primary", "November 4 2025 City Election",
                             "September 16 2025 City Preliminary"))
  expect_equal(paste(k$level, k$type), c("state primary", "municipal general", "municipal preliminary"))
})

test_that("register_election adds and updates registry rows", {
  tmp <- tempfile(fileext = ".csv")
  file.copy(here::here("data-raw", "elections", "elections.csv"), tmp)
  register_election("2030-11-05_municipal_general", status = "unofficial", parser = "not_collected", path = tmp)
  reg <- read_registry(tmp)
  expect_true("2030-11-05_municipal_general" %in% reg$election_id)
  expect_equal(reg$level[reg$election_id == "2030-11-05_municipal_general"], "municipal")
  register_election("2030-11-05_municipal_general", status = "official", path = tmp)
  expect_equal(read_registry(tmp)$status[read_registry(tmp)$election_id == "2030-11-05_municipal_general"], "official")
})
