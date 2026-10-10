# Tests for the validation safety net and the clerk-page checker.
# None of these touch the internet.

test_that("a misread digit is caught by validation", {
  meta <- read_registry()
  meta <- meta[meta$election_id == "2017-11-07_municipal_general", ]
  ex <- read_election_raw(meta)
  # Simulate a PDF-conversion misread: Yvonne M. Spicer's precinct-1 vote 755 read as 735
  hit <- ex$candidate == "Yvonne M. Spicer" & ex$precinct == "1" & ex$votes == 755
  expect_equal(sum(hit), 1)
  ex$votes[hit] <- 735
  checks <- validate_election(ex, tidy_results(ex, meta), tidy_turnout(ex, meta), meta)
  expect_equal(checks$status[checks$check == "precincts_sum_to_reported_total"], "fail")
})

test_that("long clerk labels are typed as blanks, write-ins or race totals", {
  expect_equal(candidate_type(c("Times Blank Voted", "Total number of write-ins", "Total Ballots",
                                "Blanks", "Write-Ins", "Yes", "Karen E. Spilka")),
               c("blank", "write-in", "total", "blank", "write-in", "response", "candidate"))
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
