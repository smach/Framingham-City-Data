# lookups.R -------------------------------------------------------------------
# Which city district each precinct belongs to, ON A GIVEN DATE.
#
# Framingham was redrawn after the 2020 Census: 18 precincts became 27
# (the old map was last used in the January 11 2022 special election; the new
# one first in the September 6 2022 state primary). A precinct number means
# different places before and after, so every lookup needs the election date.
#
# The table lives in data-raw/lookups/precinct_districts.csv:
#   precinct, city_district, valid_from, valid_to, map_name
# A row applies when valid_from <= election_date < valid_to
# (an empty valid_to means "still in use").

#' Read the precinct-to-district table
read_precinct_districts <- function(path = proj_path("data-raw", "lookups", "precinct_districts.csv")) {
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character())) |>
    dplyr::mutate(
      valid_from = as.Date(valid_from),
      valid_to   = as.Date(valid_to)
    )
}

#' Strip a sub-precinct letter: "9A" -> "9", "21C" -> "21", "4" -> "4"
#'
#' Since 2022 some precincts are split into sub-precincts because a state
#' House district line runs through them. For city purposes they are still
#' part of the parent precinct.
precinct_base <- function(precinct) {
  sub("^(\\d+)[A-Za-z]$", "\\1", precinct)
}

#' Look up city council districts for precincts on an election date
#'
#' @param precinct Character vector of precincts, e.g. c("1", "9A", "22").
#'   Sub-precincts are matched to their parent precinct.
#' @param election_date One date (a Date or "YYYY-MM-DD").
#' @param lookup The table from read_precinct_districts(). Pass it in when
#'   calling this many times, so the CSV is only read once.
#' @return A character vector of districts, the same length as `precinct`.
#'   It is NA when no map covers that date (for example, before 2012).
#'
#' @examples
#' get_district(c("4", "7"), "2017-11-07")   # "3" "3"
#' get_district(c("4", "22"), "2023-11-07")  # "8" "1"
get_district <- function(precinct, election_date, lookup = read_precinct_districts()) {
  election_date <- as.Date(election_date)
  stopifnot(length(election_date) == 1)
  in_effect <- lookup[lookup$valid_from <= election_date &
                        (is.na(lookup$valid_to) | election_date < lookup$valid_to), ]
  # A named vector works as a fast "dictionary": names are precincts, values are districts
  dict <- stats::setNames(in_effect$city_district, in_effect$precinct)
  unname(dict[precinct_base(precinct)])
}
