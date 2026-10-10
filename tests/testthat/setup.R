# Runs once before the tests: load the project functions and build every
# election into a temporary folder, so the tests check fresh output (not
# whatever happens to be committed in data/elections/).
source(here::here("R/load.R"))

test_out_dir <- file.path(tempdir(), "built-elections")
build_all(out_dir = test_out_dir, quiet = TRUE)

read_built <- function(name) {
  readr::read_csv(file.path(test_out_dir, name), show_col_types = FALSE,
                  col_types = readr::cols(.default = readr::col_character()))
}
built_results <- read_built("results_precinct.csv")
built_turnout <- read_built("turnout_precinct.csv")
