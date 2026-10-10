# utils.R ---------------------------------------------------------------------
# Small helpers used throughout the project.
#
# Every file in R/ only *defines* functions -- nothing runs when you source()
# it. Load them all with:
#
#   source(here::here("R/load.R"))
#
# Then call whatever you need, or run a script in scripts/.

#' Build a path relative to the project root
#'
#' A thin wrapper around here::here(), so code works no matter what your
#' working directory is (no more setwd()).
proj_path <- function(...) here::here(...)

#' Read the election registry
#'
#' data-raw/elections/elections.csv is the hub of the election pipeline: one
#' row per election, saying where its raw files live and how to read them.
#' Every column is read as text so nothing gets silently converted (for
#' example, a sheet called "1" must stay "1").
read_registry <- function(path = proj_path("data-raw", "elections", "elections.csv")) {
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()),
                  na = c("", "NA")) |>
    dplyr::mutate(election_date = as.Date(election_date))
}

#' Write a CSV the same way every time
#'
#' Fixed settings mean that re-running the build on unchanged data gives
#' byte-identical files, so `git diff` only shows real changes.
write_csv_stable <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(x, path, na = "")
  invisible(path)
}

#' Turn text from a spreadsheet cell into a number
#'
#' Clerk spreadsheets store numbers as text ("1,097", "7.00000000", "0.47"),
#' because they were converted from PDFs. Anything that isn't a number
#' becomes NA, with no warning.
as_number <- function(x) {
  x <- gsub(",", "", trimws(as.character(x)))
  suppressWarnings(as.numeric(x))
}

#' Tidy up a text label from a PDF-converted spreadsheet
#'
#' PDF converters leave non-breaking spaces, doubled spaces and stray
#' whitespace in names, so "District<NBSP>1" and "District 1" look
#' identical but don't match. This standardizes all of that.
clean_label <- function(x) {
  x <- enc2utf8(as.character(x))
  x <- gsub("\\x{00A0}", " ", x, perl = TRUE)  # non-breaking space -> normal space
  x <- gsub("\\s+", " ", x, perl = TRUE)       # collapse runs of whitespace
  trimws(x)
}
