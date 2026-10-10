# check_new_elections.R ---------------------------------------------------------
# Used by the scheduled GitHub Action (.github/workflows/check-elections.yml).
#
# 1. Looks at the City Clerk's election results page for PDFs that aren't in
#    the registry yet.
# 2. For each one, downloads it and extracts the results with Claude.
# 3. Writes pr_body.md describing what was added and the validation results.
#    The Action turns that into a pull request for a human to review.
#
# It never changes the main branch directly; you merge the pull request.

source(here::here("R/load.R"))

new_links <- find_new_results()
body <- character(0)

if (nrow(new_links) == 0) {
  message("No new results found.")
} else {
  for (i in seq_len(nrow(new_links))) {
    link <- new_links[i, ]
    if (is.na(link$election_date)) {
      body <- c(body, sprintf("- Skipped **%s** (%s): couldn't tell the election date from the link text.",
                              link$link_text, link$url))
      next
    }
    kind <- guess_election_kind(link$link_text)
    id <- paste(format(link$election_date), kind$level, kind$type, sep = "_")
    status <- if (grepl("unofficial", link$link_text, ignore.case = TRUE)) "unofficial" else "official"
    message("Adding ", id, " from ", link$url)
    checks <- tryCatch(
      add_election(id, link$url, status = status, name = link$link_text),
      error = function(e) {
        body <<- c(body, sprintf("- **%s**: extraction failed: %s", id, conditionMessage(e)))
        NULL
      }
    )
    if (is.null(checks)) next
    failed <- checks[checks$status != "pass", ]
    body <- c(body, sprintf("### %s\nSource: %s\n", id, link$url))
    body <- c(body, if (nrow(failed) == 0) "All validation checks passed.\n" else
      c("**Checks that need a look:**\n", sprintf("- %s (%s): %s", failed$check, failed$status, failed$detail), ""))
  }
}

if (length(body) > 0) {
  writeLines(c(
    "New election results found on the City Clerk's page and extracted automatically with Claude.",
    "",
    "Please spot-check a few numbers against the PDF before merging, especially any checks listed below.",
    "",
    body
  ), "pr_body.md")
}
