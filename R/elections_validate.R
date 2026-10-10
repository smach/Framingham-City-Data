# elections_validate.R ----------------------------------------------------------
# Automatic checks for one election's data.
#
# These are the safety net that makes automation (including LLM extraction)
# trustworthy: if a number was misread, the precincts won't add up to the
# clerk's total, or a race will have more votes than ballots cast.
#
# validate_election() returns one row per check:
#   election_id, check, status ("pass", "warn" or "fail"), detail
# build_all() saves every election's checks to
# data/elections/validation_report.csv, and the GitHub Action puts failures
# in the pull request description.

#' Run all checks for one election
#'
#' @param extracted The election's extracted data (which keeps the clerk's
#'   "Total" column).
#' @param results,turnout Output of tidy_results() and tidy_turnout().
#' @param meta The election's registry row.
#' @param lookup Precinct-to-district table.
validate_election <- function(extracted, results, turnout, meta, lookup = read_precinct_districts()) {
  checks <- list()
  add <- function(check, ok, detail_if_bad, warn_only = FALSE) {
    status <- if (ok) "pass" else if (warn_only) "warn" else "fail"
    checks[[length(checks) + 1]] <<- data.frame(
      election_id = meta$election_id, check = check, status = status,
      detail = if (ok) "" else paste(utils::head(detail_if_bad, 10), collapse = "; "),
      stringsAsFactors = FALSE
    )
  }

  # 1. There is something there at all
  add("has_results", !is.null(results) && nrow(results) > 0, "No results rows were found")
  add("has_turnout", !is.null(turnout) && nrow(turnout) > 0, "No turnout rows were found",
      warn_only = TRUE)
  if (is.null(results) || nrow(results) == 0) return(dplyr::bind_rows(checks))

  # 2. Every results row belongs to a race
  no_race <- unique(results$candidate[is.na(results$race)])
  add("every_row_has_race", length(no_race) == 0,
      paste("No race header above:", no_race))

  # 3. Precinct numbers add up to the clerk's reported Total. This is the main
  #    check against typos and extraction mistakes.
  key <- function(d) paste(d$section, d$party, d$race, d$candidate, sep = " | ")
  # Some files print the same line twice (e.g. registered voters at the end of
  # each party's section), so identical lines are counted once.
  ex <- dplyr::distinct(extracted, section, party, race, candidate, precinct, votes)
  ex$key <- key(ex)
  reported <- ex[ex$precinct == "Total", c("key", "votes")]
  summed <- stats::aggregate(votes ~ key, data = ex[ex$precinct != "Total", ], FUN = sum)
  both <- merge(summed, reported, by = "key", suffixes = c("_sum", "_reported"))
  bad <- both[abs(both$votes_sum - both$votes_reported) > 0.5, ]
  add("precincts_sum_to_reported_total", nrow(bad) == 0,
      sprintf("%s: precincts add to %s, clerk total %s", bad$key, bad$votes_sum, bad$votes_reported))
  add("reported_totals_present", nrow(reported) > 0,
      "No 'Total' column found, so precinct sums could not be checked", warn_only = TRUE)

  # 4. Precinct labels match the precinct map in use on the election date
  valid <- unique(lookup$precinct[lookup$valid_from <= meta$election_date &
                                    (is.na(lookup$valid_to) | meta$election_date < lookup$valid_to)])
  if (length(valid) > 0) {
    unknown <- setdiff(unique(precinct_base(c(results$precinct, turnout$precinct))), valid)
    add("precincts_match_map", length(unknown) == 0,
        paste("Precincts not on the map for this date:", unknown))
  }

  if (!is.null(turnout) && nrow(turnout) > 0) {
    # 5. Can't have more ballots than registered voters
    over <- turnout[!is.na(turnout$registered) & turnout$ballots_cast > turnout$registered, ]
    add("ballots_not_above_registered", nrow(over) == 0,
        sprintf("Precinct %s%s: %s ballots, %s registered", over$precinct,
                ifelse(is.na(over$party), "", paste0(" (", over$party, ")")),
                over$ballots_cast, over$registered))

    # 6. In a one-seat race, candidate votes + blanks + write-ins should not be
    #    more than the ballots cast (each voter gets one vote). Primaries are
    #    checked against the party's own ballots.
    one_seat <- results[!is.na(results$seats) & results$seats == 1, ]
    if (nrow(one_seat) > 0) {
      race_totals <- one_seat |>
        dplyr::group_by(party, race, precinct) |>
        dplyr::summarize(race_votes = sum(votes), .groups = "drop")
      ballots <- turnout[, c("party", "precinct", "ballots_cast")]
      joined <- dplyr::left_join(race_totals, ballots, by = c("party", "precinct"))
      too_many <- joined[!is.na(joined$ballots_cast) & joined$race_votes > joined$ballots_cast, ]
      add("one_seat_races_not_above_ballots", nrow(too_many) == 0,
          sprintf("%s, precinct %s: %s votes but %s ballots", too_many$race, too_many$precinct,
                  too_many$race_votes, too_many$ballots_cast))
    }
  }

  # 7. The same candidate shouldn't appear twice in a race/precinct
  dupes <- results |>
    dplyr::count(party, race, candidate, precinct) |>
    dplyr::filter(n > 1)
  add("no_duplicate_rows", nrow(dupes) == 0,
      sprintf("%s / %s appears %s times in precinct %s", dupes$race, dupes$candidate, dupes$n, dupes$precinct))

  dplyr::bind_rows(checks)
}
