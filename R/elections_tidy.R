# elections_tidy.R --------------------------------------------------------------
# Turn the extracted layout (see elections_parse.R) into the analysis-friendly
# tables in data/elections/.
#
# This one set of functions replaces the old per-year scripts
# (election_general_2017_framingham.R, election_general_2023_framingham.R, ...).
# It works the same way for every election, so every election's output has
# the same columns and meanings.

# ---- Standard names --------------------------------------------------------

#' Standardize a race label into office, district and number of seats
#'
#' The clerk's labels vary from year to year ("At Large City Councilor",
#' "City Councilor At Large", "Rep. in General Court", "State Representative -
#' 6th Middlesex"). This maps them to one office name, so all City Council
#' at-large races can be filtered with a single value.
#'
#' @param race Character vector of race labels as printed.
#' @param level "municipal" or "state". It matters for "Councilor": in a
#'   state election that means the Governor's Council, not City Council.
#' @return A data frame with columns office, office_district and seats.
standardize_race <- function(race, level) {
  r <- clean_label(race)
  # "(2 seats)" / "(1 seat)" -> number of seats to elect
  seats <- suppressWarnings(as.integer(sub(".*\\((\\d+) seats?\\).*", "\\1", r)))
  seats[!grepl("\\(\\d+ seats?\\)", r)] <- NA
  # Strip "(1 seat) for 2 years" and similar from the end of the label
  base <- trimws(sub("\\s*\\(\\d+ seats?\\).*$", "", r))
  base <- trimws(sub("\\s+for \\d+ years?$", "", base))

  office <- base
  district <- NA_character_
  district <- rep(district, length(r))

  set <- function(pattern, value, district_group = NULL) {
    hit <- grepl(pattern, base, ignore.case = TRUE, perl = TRUE) & office == base
    if (any(hit)) {
      office[hit] <<- value
      if (!is.null(district_group)) {
        district[hit] <<- sub(paste0(".*?", pattern, ".*"), district_group, base[hit],
                              ignore.case = TRUE, perl = TRUE)
      }
    }
  }
  # Municipal offices
  set("^Mayor", "Mayor")
  set("(At.?Large City Council|City Council(or)? At.?Large)", "City Council At-Large")
  set("District (\\d+) City Council", "City Council District", "\\1")
  set("District (\\d+) School Committee", "School Committee District", "\\1")
  set("^Library Trustee", "Library Trustee")
  set("(Cemetery Trustee|Edgell Grove)", "Cemetery Trustee")
  set("Charter Question", "City Charter Question")
  set("^Pre\\w*?n\\w?t (\\d+)", "Town Meeting Member", "\\1")   # also catches typos "Precint", "Preinct"
  # State and federal offices
  set("^Presidential Preference", "Presidential Preference")
  set("^President", "President")
  set("^Town Committee", "Town Committee")
  set("^(Senator in Congress|U\\.?S\\.? Senator)", "U.S. Senator")
  set("^(Rep\\.? in Congress|Representative in Congress)", "U.S. Representative")
  set("^(Senator in General Court|State Senator)", "State Senator")
  set("^(Rep\\.? in General Court|State Rep(resentative)?\\.?)[ -]*\\(?(\\d+\\w* \\w+)?", "State Representative", "\\3")
  if (identical(level, "state")) set("^Council+or$", "Governor's Council")

  district[district == ""] <- NA
  data.frame(office = office, office_district = district, seats = seats, stringsAsFactors = FALSE)
}

#' Standard party names ("Democrat" -> "Democratic", ...)
standardize_party <- function(party) {
  p <- clean_label(party)
  p <- sub(" Party$", "", p)
  dplyr::case_when(
    is.na(p) ~ NA_character_,
    grepl("^Democrat", p, ignore.case = TRUE) ~ "Democratic",
    grepl("^Republican", p, ignore.case = TRUE) ~ "Republican",
    grepl("^Libertarian", p, ignore.case = TRUE) ~ "Libertarian",
    grepl("^Green", p, ignore.case = TRUE) ~ "Green-Rainbow",
    grepl("^(United Independent|UIP)", p, ignore.case = TRUE) ~ "United Independent",
    TRUE ~ p
  )
}

#' Classify a results row: a real candidate, blanks, write-ins, or a ballot
#' question response (Yes/No)
#'
#' The old files sometimes dropped blanks and write-ins and sometimes kept
#' them. Now they are always kept and labeled, so you can filter them out with
#' `candidate_type == "candidate"` when you don't want them.
#'
#' Some clerk files (e.g. the 2024 state primary) use longer labels:
#' "Times Blank Voted", "Total number of write-ins", and a per-race
#' "Total Ballots" line. That last one is a race total, not a candidate, so it
#' is typed "total" and dropped by tidy_results().
candidate_type <- function(candidate) {
  c <- tolower(clean_label(candidate))
  dplyr::case_when(
    c %in% c("blank", "blanks", "times blank voted") ~ "blank",
    grepl("^(total number of )?write[- ]?ins?$", c) ~ "write-in",
    grepl("^total (ballots|votes)( cast)?$", c) ~ "total",
    c %in% c("yes", "no") ~ "response",
    TRUE ~ "candidate"
  )
}

#' Standard spellings for blanks and write-ins ("Write Ins" -> "Write-ins")
standardize_candidate <- function(candidate) {
  c <- clean_label(candidate)
  type <- candidate_type(c)
  c[type == "blank"] <- "Blanks"
  c[type == "write-in"] <- "Write-ins"
  c
}

#' Sort precinct labels in natural order: 1, 2, ..., 9, 9A, 9B, 10, ...
precinct_order <- function(precinct) {
  p <- unique(precinct)
  p[order(as.integer(precinct_base(p)), p)]
}

# ---- Main tidy functions ---------------------------------------------------

#' Columns describing the election, added to every output row
election_columns <- function(meta) {
  data.frame(
    election_id   = meta$election_id,
    election_date = as.character(meta$election_date),
    level         = meta$level,
    type          = meta$type,
    status        = meta$status,
    stringsAsFactors = FALSE
  )
}

#' Tidy precinct-level results for one election
#'
#' @param extracted Extracted data frame for one election.
#' @param meta The election's registry row.
#' @param lookup Precinct-to-district table (read_precinct_districts()).
#' @param name_fixes Corrections for names the clerk cut short
#'   (read_candidate_name_fixes()).
#' @return One row per election x race x candidate x precinct, with these columns:
#'   election_id, election_date, level, type, status, party, race, office,
#'   office_district, seats, candidate, candidate_type, precinct,
#'   precinct_base, city_district, votes
tidy_results <- function(extracted, meta, lookup = read_precinct_districts(),
                         name_fixes = read_candidate_name_fixes()) {
  x <- extracted[extracted$section == "results" & extracted$precinct != "Total" &
                   candidate_type(extracted$candidate) != "total", ]
  if (nrow(x) == 0) return(NULL)
  offices <- standardize_race(x$race, meta$level)
  out <- data.frame(
    election_columns(meta)[rep(1, nrow(x)), ],
    party           = standardize_party(x$party),
    race            = clean_label(x$race),
    office          = offices$office,
    office_district = offices$office_district,
    seats           = offices$seats,
    candidate       = fix_candidate_names(standardize_candidate(x$candidate), meta$election_id, name_fixes),
    candidate_type  = candidate_type(x$candidate),
    precinct        = x$precinct,
    precinct_base   = precinct_base(x$precinct),
    city_district   = get_district(x$precinct, meta$election_date, lookup),
    votes           = as.integer(round(x$votes)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  out
}

#' Tidy precinct-level turnout for one election
#'
#' Clerk spreadsheets list turnout as rows such as "Total Voter Turnout",
#' "Total Registered Voters", and in primaries "Democrat Turnout". This turns
#' them into one row per precinct (and per party, for primaries):
#'   party         NA for all voters, or the party for a primary ballot
#'   registered    registered voters in the precinct (all parties)
#'   ballots_cast  ballots cast (all voters, or that party's ballots)
#'   turnout_pct   ballots_cast / registered * 100, rounded to 0.1.
#'                 ALWAYS a percent from 0 to 100 (old files mixed fractions
#'                 and percents).
tidy_turnout <- function(extracted, meta, lookup = read_precinct_districts()) {
  x <- extracted[extracted$section == "turnout" & extracted$precinct != "Total", ]
  if (nrow(x) == 0) return(NULL)
  label <- clean_label(x$candidate)
  x$measure <- ifelse(grepl("regist", label, ignore.case = TRUE), "registered", "ballots_cast")
  # Which party, if any, does a turnout row belong to? "Total Turnout" -> NA
  party_word <- stringr::str_extract(label, stringr::regex(
    "Democrat|Republican|Libertarian|Green[- ]?Rainbow|United Independent|UIP", ignore_case = TRUE))
  x$party <- standardize_party(party_word)
  x$party[x$measure == "registered"] <- NA

  # Some files list the same number twice (e.g. a turnout line at the end of
  # each party's section and again in a summary). Keep one copy.
  x <- dplyr::distinct(x, party, measure, precinct, votes)
  wide <- tidyr::pivot_wider(x, id_cols = c(party, precinct), names_from = measure,
                             values_from = votes, values_fn = function(v) v[1])
  if (!"ballots_cast" %in% names(wide)) wide$ballots_cast <- NA_real_
  if (!"registered" %in% names(wide)) wide$registered <- NA_real_

  # Registered voters are listed once per precinct; copy that to the party rows
  reg <- wide[is.na(wide$party), c("precinct", "registered")]
  wide <- dplyr::left_join(dplyr::select(wide, -registered), reg, by = "precinct")

  # Primaries sometimes only give party turnout. Then all-voter turnout is the
  # sum of the parties' ballots.
  if (!any(is.na(wide$party) & !is.na(wide$ballots_cast))) {
    totals <- wide |>
      dplyr::filter(!is.na(party)) |>
      dplyr::group_by(precinct) |>
      dplyr::summarize(ballots_cast = sum(ballots_cast, na.rm = TRUE), .groups = "drop")
    wide <- dplyr::bind_rows(
      dplyr::filter(wide, !is.na(party)),
      dplyr::left_join(totals, reg, by = "precinct") |> dplyr::mutate(party = NA_character_)
    )
  }
  wide <- wide[!(is.na(wide$ballots_cast) & !is.na(wide$party)), ]
  # A district-only election (e.g. the 2025 preliminary) can list every
  # precinct with 0 registered and 0 ballots. Those precincts weren't part of
  # the election, so drop them rather than report 0/0 turnout.
  wide <- wide[!(wide$registered %in% 0 & wide$ballots_cast %in% 0), ]

  data.frame(
    election_columns(meta)[rep(1, nrow(wide)), ],
    party         = wide$party,
    precinct      = wide$precinct,
    precinct_base = precinct_base(wide$precinct),
    city_district = get_district(wide$precinct, meta$election_date, lookup),
    registered    = as.integer(wide$registered),
    ballots_cast  = as.integer(wide$ballots_cast),
    turnout_pct   = round(100 * wide$ballots_cast / wide$registered, 1),
    stringsAsFactors = FALSE,
    row.names = NULL
  ) |>
    dplyr::arrange(!is.na(party), party, match(precinct, precinct_order(precinct)))
}

#' Add precinct results up to city council districts
#'
#' Only rows with a known city_district are included (elections before 2012
#' used different precincts).
summarize_results_by_district <- function(results) {
  results |>
    dplyr::filter(!is.na(city_district)) |>
    dplyr::group_by(election_id, election_date, level, type, status, party, race, office,
                    office_district, seats, candidate, candidate_type, city_district) |>
    dplyr::summarize(votes = sum(votes), .groups = "drop") |>
    dplyr::arrange(election_date, party, race, as.integer(city_district), dplyr::desc(votes))
}

#' Add precinct turnout up to city council districts
summarize_turnout_by_district <- function(turnout) {
  turnout |>
    dplyr::filter(!is.na(city_district)) |>
    dplyr::group_by(election_id, election_date, level, type, status, party, city_district) |>
    dplyr::summarize(registered = sum(registered), ballots_cast = sum(ballots_cast),
                     .groups = "drop") |>
    dplyr::mutate(turnout_pct = round(100 * ballots_cast / registered, 1)) |>
    dplyr::arrange(election_date, party, as.integer(city_district))
}

#' Citywide turnout, one row per election (and party, for primaries)
summarize_turnout_citywide <- function(turnout) {
  turnout |>
    dplyr::group_by(election_id, election_date, level, type, status, party) |>
    dplyr::summarize(registered = sum(registered), ballots_cast = sum(ballots_cast),
                     .groups = "drop") |>
    dplyr::mutate(turnout_pct = round(100 * ballots_cast / registered, 1)) |>
    dplyr::arrange(election_date, party)
}

#' Human-friendly wide table for one election, laid out like the clerk's
#'
#' One row per race and candidate, one column per precinct, plus a Total.
#' Turnout rows go at the bottom. Good for reading or opening in Excel; for
#' analysis use the tidy files.
make_wide_results <- function(results, turnout) {
  precincts <- precinct_order(c(results$precinct, turnout$precinct))
  res <- results |>
    dplyr::select(party, race, candidate, precinct, votes) |>
    tidyr::pivot_wider(names_from = precinct, values_from = votes)
  res$Total <- rowSums(res[, intersect(precincts, names(res)), drop = FALSE], na.rm = TRUE)
  if (!is.null(turnout) && nrow(turnout) > 0) {
    to <- turnout |>
      dplyr::mutate(race = "Turnout") |>
      tidyr::pivot_longer(c(ballots_cast, registered), names_to = "candidate", values_to = "votes") |>
      dplyr::filter(!(candidate == "registered" & !is.na(party))) |>
      dplyr::mutate(candidate = ifelse(candidate == "registered", "Registered voters", "Ballots cast")) |>
      dplyr::select(party, race, candidate, precinct, votes) |>
      tidyr::pivot_wider(names_from = precinct, values_from = votes)
    to$Total <- rowSums(to[, intersect(precincts, names(to)), drop = FALSE], na.rm = TRUE)
    res <- dplyr::bind_rows(res, to)
  }
  res[, c("party", "race", "candidate", intersect(precincts, names(res)), "Total")]
}
