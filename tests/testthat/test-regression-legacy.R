# Regression tests: the new pipeline must reproduce the numbers in the old,
# hand-checked output files (now in data/legacy/elections/).
#
# Labels changed on purpose (race names, "General Municipal", turnout as a
# percent), so these tests compare only the NUMBERS: votes per candidate per
# precinct, and ballots/registered voters per precinct.

legacy_dir <- here::here("data", "legacy", "elections")

read_legacy <- function(file) {
  x <- readr::read_csv(file.path(legacy_dir, file), show_col_types = FALSE,
                       col_types = readr::cols(.default = readr::col_character()))
  names(x) <- tolower(gsub("[^A-Za-z]+", "_", trimws(sub("^﻿", "", names(x)))))
  x
}

# Compare names ignoring case and punctuation: an old file has
# "Joseph P Kennedy III" where the clerk printed "Joseph P. Kennedy III"
name_key <- function(x) gsub("[^a-z0-9]", "", tolower(x))

# --- Results -----------------------------------------------------------------
# Old tidy file -> the election it belongs to (dates corrected where the old
# label was wrong, e.g. the "2021 special" was held January 11 2022)
legacy_results <- tibble::tribble(
  ~file,                                              ~election_id,
  "tidy/2017_general_tidy_framingham.csv",            "2017-11-07_municipal_general",
  "tidy/2017_preliminary_tidy_framingham.csv",        "2017-09-26_municipal_preliminary",
  "tidy/2020_us_senate_democratic_primary.csv",       "2020-09-01_state_primary",
  "2021_preliminary_mayor_tidy_framingham.csv",       "2021-09-14_municipal_preliminary",
  "2021_general_mayor_tidy_framingham.csv",           "2021-11-02_municipal_general",
  "2021_general_council_tidy_framingham.csv",         "2021-11-02_municipal_general",
  "tidy/2022_6th_middlesex_democratic_primary.csv",   "2022-09-06_state_primary",
  "tidy/2023_framingham_general.csv",                 "2023-11-07_municipal_general"
)

for (i in seq_len(nrow(legacy_results))) {
  file <- legacy_results$file[i]
  id <- legacy_results$election_id[i]
  test_that(paste("results match legacy file", file), {
    old <- read_legacy(file)
    # The old 2023 file has stray rows where the repeated page header
    # ("Candidate 1 2 3 ...") was read as a candidate -- skip those
    old <- old[!is.na(old$votes) & !old$precinct %in% c("Total", "Totals") & old$candidate != "Candidate" &
                 !grepl("turnout|registered|percent", old$candidate, ignore.case = TRUE) &
                 candidate_type(old$candidate) == "candidate", ]
    # The old files have names as the clerk printed them; apply the same
    # corrections the build does (data-raw/lookups/candidate_name_fixes.csv)
    old$candidate <- fix_candidate_names(old$candidate, id)
    new <- built_results[built_results$election_id == id, ]
    # In primaries the same name can only appear in one party; sum across
    # races in case a candidate is listed in two
    new_votes <- tapply(as.numeric(new$votes), paste(name_key(new$candidate), new$precinct), sum)
    key <- paste(name_key(old$candidate), old$precinct)
    expect_true(all(key %in% names(new_votes)),
                info = paste("Missing:", paste(utils::head(setdiff(key, names(new_votes))), collapse = ", ")))
    expect_equal(as.numeric(new_votes[key]), as.numeric(old$votes))
  })
}

test_that("2017 charter vote matches legacy file", {
  old <- read_legacy("tidy/2017_charter_results_tidy_framingham.csv")
  new <- built_results[built_results$election_id == "2017-04-04_municipal_town", ]
  old <- old[old$metric %in% c("Yes", "No", "Blanks"), ]   # turnout lines are tested below
  new_votes <- tapply(as.numeric(new$votes), paste(new$candidate, new$precinct), sum)
  expect_equal(as.numeric(new_votes[paste(old$metric, old$precinct)]), as.numeric(old$value))
})

# --- Turnout ------------------------------------------------------------------
legacy_turnout <- tibble::tribble(
  ~file,                                      ~election_id,
  "2016_general_turnout_framingham.csv",      "2016-03-29_municipal_town",   # old label said "general"
  "2017_charter_turnout_framingham.csv",      "2017-04-04_municipal_town",
  "2017_preliminary_turnout_framingham.csv",  "2017-09-26_municipal_preliminary",
  "2017_general_turnout_framingham.csv",      "2017-11-07_municipal_general",
  "2019_general_turnout_framingham.csv",      "2019-11-05_municipal_general",
  "2020_state_primary_turnout.csv",           "2020-09-01_state_primary",
  "2021_preliminary_turnout_framingham.csv",  "2021-09-14_municipal_preliminary",
  "2021_general_turnout_framingham.csv",      "2021-11-02_municipal_general",
  "2022_state_primary_turnout.csv",           "2022-09-06_state_primary",   # old file said Year 2020
  "2023_general_turnout.csv",                 "2023-11-07_municipal_general"
  # Not compared: 2021_special_turnout_framingham.csv is broken in the old
  # data (empty numbers), which is one of the bugs this rebuild fixes.
)

for (i in seq_len(nrow(legacy_turnout))) {
  file <- legacy_turnout$file[i]
  id <- legacy_turnout$election_id[i]
  test_that(paste("turnout matches legacy file", file), {
    old <- read_legacy(file)
    old <- old[old$precinct != "Total", ]
    reg_col <- intersect(c("total_registered_voters", "total_registered"), names(old))[1]
    new <- built_turnout[built_turnout$election_id == id & is.na(built_turnout$party), ]
    m <- match(old$precinct, new$precinct)
    expect_false(anyNA(m))
    expect_equal(as.numeric(new$ballots_cast[m]), as.numeric(old$total_voter_turnout))
    expect_equal(as.numeric(new$registered[m]), as.numeric(old[[reg_col]]))
  })
}
