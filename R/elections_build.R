# elections_build.R -------------------------------------------------------------
# Rebuild everything in data/elections/ from the raw files in data-raw/.
#
# The data is small enough that rebuilding all elections takes seconds, so we
# always rebuild everything instead of tracking what changed. That way the
# output files can never drift away from the code that makes them (which is
# what happened with the hand-edited "General Municipal" CSVs).
#
# Never edit files in data/elections/ by hand. Fix the raw data, the registry
# (data-raw/elections/elections.csv) or the code, then rebuild with:
#
#   Rscript scripts/build_all.R

#' Process one election: read, tidy, validate
#'
#' @param meta One registry row.
#' @param lookup Precinct-to-district table.
#' @return A list with results, turnout and checks.
build_election <- function(meta, lookup = read_precinct_districts()) {
  extracted <- read_election_raw(meta)
  results <- tidy_results(extracted, meta, lookup)
  turnout <- tidy_turnout(extracted, meta, lookup)
  checks <- validate_election(extracted, results, turnout, meta, lookup)
  list(results = results, turnout = turnout, checks = checks)
}

#' Rebuild all election outputs
#'
#' @param registry The registry (read_registry()).
#' @param out_dir Where to write. Tests point this at a temporary folder.
#' @param quiet Set TRUE to turn off progress messages.
#' @return The validation report, invisibly.
build_all <- function(registry = read_registry(), out_dir = proj_path("data", "elections"),
                      quiet = FALSE) {
  lookup <- read_precinct_districts()
  ready <- registry[registry$parser %in% c("clerk_xlsx", "extracted_csv"), ]
  ready <- ready[order(ready$election_date), ]

  built <- lapply(seq_len(nrow(ready)), function(i) {
    meta <- ready[i, ]
    if (!quiet) message("Building ", meta$election_id)
    build_election(meta, lookup)
  })
  results <- dplyr::bind_rows(lapply(built, `[[`, "results"))
  turnout <- dplyr::bind_rows(lapply(built, `[[`, "turnout"))
  checks  <- dplyr::bind_rows(lapply(built, `[[`, "checks"))

  # Main analysis files: every election in one place
  write_csv_stable(results, file.path(out_dir, "results_precinct.csv"))
  write_csv_stable(summarize_results_by_district(results), file.path(out_dir, "results_district.csv"))
  write_csv_stable(turnout, file.path(out_dir, "turnout_precinct.csv"))
  write_csv_stable(summarize_turnout_by_district(turnout), file.path(out_dir, "turnout_district.csv"))
  write_csv_stable(summarize_turnout_citywide(turnout), file.path(out_dir, "turnout_citywide.csv"))

  # Election list, including the ones not collected yet, as a to-do list
  election_list <- registry |>
    dplyr::mutate(
      election_date = as.character(election_date),
      has_data = parser %in% c("clerk_xlsx", "extracted_csv")
    ) |>
    dplyr::select(election_id, election_date, level, type, name, status, has_data, source_url, notes) |>
    dplyr::arrange(election_date)
  write_csv_stable(election_list, file.path(out_dir, "elections.csv"))

  # Human-friendly wide file for each election, laid out like the clerk's
  by_election_dir <- file.path(out_dir, "by_election")
  unlink(by_election_dir, recursive = TRUE)
  for (i in seq_along(built)) {
    id <- ready$election_id[i]
    # No precinct results (the "has_results" check fails): nothing to lay out
    if (is.null(built[[i]]$results) || nrow(built[[i]]$results) == 0) next
    wide <- make_wide_results(built[[i]]$results, built[[i]]$turnout)
    write_csv_stable(wide, file.path(by_election_dir, paste0(id, "_results_wide.csv")))
  }

  write_csv_stable(checks, file.path(out_dir, "validation_report.csv"))
  if (!quiet) {
    n_fail <- sum(checks$status == "fail")
    message(sprintf("Done: %d elections, %s result rows, %d failed checks.",
                    nrow(ready), format(nrow(results), big.mark = ","), n_fail))
    if (n_fail > 0) print(checks[checks$status == "fail", c("election_id", "check", "detail")])
  }
  invisible(checks)
}
