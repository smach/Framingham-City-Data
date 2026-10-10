# check_new_elections.R ---------------------------------------------------------
# Used by the weekly GitHub Action (.github/workflows/check-elections.yml).
#
# Looks at the City Clerk's election results page for PDFs that aren't in the
# registry yet and, if it finds any, writes issue_body.md listing them. The
# Action turns that into a GitHub issue reminding you to convert them in Adobe
# Acrobat and add them with add_election().
#
# It changes nothing in the repository.

source(here::here("R/load.R"))

new_links <- find_new_results()

if (nrow(new_links) == 0) {
  message("No new results found.")
} else {
  message(nrow(new_links), " new results link(s) found.")
  entries <- vapply(seq_len(nrow(new_links)), function(i) {
    link <- new_links[i, ]
    # Suggest an election_id, so the add_election() line is ready to paste
    id <- if (is.na(link$election_date)) "YYYY-MM-DD_level_type" else {
      kind <- guess_election_kind(link$link_text)
      paste(format(link$election_date), kind$level, kind$type, sep = "_")
    }
    status <- if (grepl("unofficial", link$link_text, ignore.case = TRUE)) "unofficial" else "official"
    sprintf(paste0("- [%s](%s)\n\n  ```r\n  add_election(\"%s\", \"path/to/spreadsheet.xlsx\", ",
                   "status = \"%s\",\n               pdf = \"path/to/results.pdf\", source_url = \"%s\")\n  ```"),
            link$link_text, link$url, id, status, link$url)
  }, character(1))
  writeLines(c(
    "The City Clerk's results page has results that aren't in the registry yet.",
    "",
    "For each one: download the PDF, export it to an Excel workbook in Adobe",
    "Acrobat (see the README for scanned PDFs), then in R run",
    "`source(here::here(\"R/load.R\"))` and the line below it. Check the suggested",
    "election id first. Close this issue when you're done.",
    "",
    entries
  ), "issue_body.md")
}
