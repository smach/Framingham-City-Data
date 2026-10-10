# Tests for the building blocks: lookups, parsing, naming and validation.

test_that("district lookup depends on the election date", {
  expect_equal(get_district(c("4", "7"), "2017-11-07"), c("3", "3"))
  expect_equal(get_district(c("4", "22", "9A", "21C"), "2023-11-07"), c("8", "1", "6", "3"))
  # Before the 2012 precinct map there is no lookup
  expect_true(all(is.na(get_district("1", "2008-11-04"))))
})

test_that("race labels are standardized", {
  r <- standardize_race(c("At Large City Councilor (2 seats) for 2 years",
                          "City Councilor At Large (2 seats) for 4 years",
                          "District 3 School Committee (1 seat) for 2 years",
                          "State Rep. (7th Middlesex)",
                          "Councillor"), level = "state")
  expect_equal(r$office, c("City Council At-Large", "City Council At-Large",
                           "School Committee District", "State Representative",
                           "Governor's Council"))
  expect_equal(r$office_district, c(NA, NA, "3", "7th Middlesex", NA))
  expect_equal(r$seats, c(2L, 2L, 1L, NA, NA))
})

test_that("blanks and write-ins are labeled consistently", {
  expect_equal(standardize_candidate(c("Blanks", "Blank", "Write Ins", "Write-Ins", "Jane Doe")),
               c("Blanks", "Blanks", "Write-ins", "Write-ins", "Jane Doe"))
})

# A tiny fake clerk sheet for testing the parser and validation
fake_sheet <- function() {
  rows <- list(
    c("City Election Official Results", rep(NA, 4)),
    c(NA, "1", "2", "3", "Total"),
    c("Mayor (1 seat) for 4 years", NA, NA, NA, NA),
    c("Blanks", "1", "0", "2", "3"),
    c("Jane Doe", "50", "60", "70", "180"),
    c("John Roe", "40", "30", "20", "90"),
    c("Total Voter Turnout", "91", "90", "92", "273"),
    c("Total Registered Voters", "300", "300", "300", "900")
  )
  as.data.frame(do.call(rbind, rows), stringsAsFactors = FALSE)
}
fake_meta <- data.frame(election_id = "2099-11-01_municipal_general",
                        election_date = as.Date("2023-11-07"), level = "municipal",
                        type = "general", status = "official", stringsAsFactors = FALSE)

run_checks <- function(raw) {
  ex <- parse_clerk_table(raw)
  res <- tidy_results(ex, fake_meta)
  to <- tidy_turnout(ex, fake_meta)
  validate_election(ex, res, to, fake_meta)
}

test_that("parser finds races, candidates and turnout", {
  ex <- parse_clerk_table(fake_sheet())
  expect_equal(unique(ex$race[ex$section == "results"]), "Mayor (1 seat) for 4 years")
  expect_equal(sum(ex$votes[ex$candidate == "Jane Doe" & ex$precinct != "Total"]), 180)
  expect_true(all(c("Total Voter Turnout", "Total Registered Voters") %in% ex$candidate))
})

test_that("clean fake data passes every check", {
  checks <- run_checks(fake_sheet())
  expect_true(all(checks$status == "pass"), info = paste(checks$detail, collapse = " "))
})

test_that("validation catches a misread number", {
  raw <- fake_sheet()
  raw[5, 3] <- "66"   # Jane Doe precinct 2 misread: precincts no longer sum to 180
  checks <- run_checks(raw)
  expect_equal(checks$status[checks$check == "precincts_sum_to_reported_total"], "fail")
})

test_that("validation catches more ballots than registered voters", {
  raw <- fake_sheet()
  raw[7, 2:5] <- c("391", "90", "92", "573")
  checks <- run_checks(raw)
  expect_equal(checks$status[checks$check == "ballots_not_above_registered"], "fail")
})

test_that("validation catches a one-seat race with more votes than ballots", {
  raw <- fake_sheet()
  raw[5, 2:5] <- c("80", "60", "70", "210")   # 1 + 80 + 40 = 121 votes, 91 ballots
  checks <- run_checks(raw)
  expect_equal(checks$status[checks$check == "one_seat_races_not_above_ballots"], "fail")
})
