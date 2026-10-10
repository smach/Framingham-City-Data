# elections_extract_llm.R -------------------------------------------------------
# Turn a City Clerk results PDF into data with Claude, via the ellmer package.
#
# This replaces the manual CometDocs / PDFTables step. How it works:
#   1. Send the PDF to Claude and ask for the results table back as a CSV, in
#      the same layout as the PDF (one row per candidate, one column per
#      precinct, plus the clerk's Total column).
#   2. Reshape that CSV into the standard "extracted" layout and save it as
#      data-raw/elections/<election_id>/extracted.csv.
#   3. Run the usual validation checks. The most important one: each row's
#      precinct numbers must add up to the clerk's Total column. A misread
#      digit almost always breaks that sum, so mistakes get caught.
#
# The CSV is saved and committed, so Claude is called ONCE per election.
# Rebuilding the data later never calls the API.
#
# Setup (one time):
#   install.packages("ellmer")
#   Put ANTHROPIC_API_KEY=your-key in ~/.Renviron (usethis::edit_r_environ()),
#   then restart R. In GitHub Actions the key comes from a repository secret.
#
# Why plain CSV instead of ellmer's structured-output helpers: some ellmer
# versions do structured output by *forcing* a tool call, and the newest
# Claude models reject forced tool calls. Plain text works with every ellmer
# version, and the validation checks catch formatting problems.

llm_extraction_prompt <- "
This PDF contains official or unofficial election results from the City Clerk
of Framingham, Massachusetts, broken down by precinct.

Return ALL of the results as ONE CSV table inside a ```csv code block, and
nothing else. Use exactly these columns, in this order:

section,party,race,candidate,<one column per precinct, named exactly as in the PDF header, e.g. 1,2,...,9A,9B,...>,Total

Rules:
- section is 'results' for candidate/question rows and 'turnout' for turnout
  or registered-voter rows.
- party: for party primaries, the party whose ballot the race is on (e.g.
  Democratic, Republican). Leave empty for non-partisan or general elections.
- race: the race or office heading exactly as printed, e.g.
  'Mayor (1 seat) for 4 years' or 'State Representative - 6th Middlesex'.
  Leave empty for turnout rows.
- candidate: the row label exactly as printed, including 'Blanks' and
  'Write-Ins' rows and ballot-question 'Yes'/'No' rows. For turnout use the
  printed label, e.g. 'Total Voter Turnout', 'Total Registered Voters',
  'Democratic Turnout'.
- Copy every number exactly. Numbers only: no commas, no percent signs.
- Leave a cell EMPTY when the PDF has no number for that precinct (for
  example, district races that only appear in some precincts). Don't write 0
  unless the PDF shows 0.
- Skip percentage rows, page titles, signatures and footnotes.
- If a race continues onto the next page, keep it under the same race name.
- Quote any value that contains a comma, e.g. \"George P. King, Jr.\".
"

#' Extract precinct results from a clerk PDF with Claude
#'
#' @param pdf_path Path to the results PDF.
#' @param out_path Where to save extracted.csv. NULL means don't save.
#' @param model Claude model ID. Claude Opus 5.5 is the most accurate; a
#'   cheaper model such as "claude-sonnet-5-5" may also work. Check the
#'   validation report either way.
#' @param effort How hard the model works ("low" to "max"). Copying a big
#'   table digit-for-digit rewards care, so the default is "high".
#' @return The extracted data frame (invisibly).
#'
#' @examples
#' \dontrun{
#' x <- extract_results_llm(
#'   "data-raw/elections/2022-11-08_state_general/NOVEMBER 8, 2022 STATE ELECTION UNOFFICIAL RESULTS.pdf",
#'   out_path = "data-raw/elections/2022-11-08_state_general/extracted.csv"
#' )
#' }
extract_results_llm <- function(pdf_path, out_path = NULL, model = "claude-opus-5-5",
                                effort = "high") {
  if (!requireNamespace("ellmer", quietly = TRUE)) {
    stop("Please install ellmer first: install.packages(\"ellmer\")")
  }
  if (Sys.getenv("ANTHROPIC_API_KEY") == "") {
    stop("ANTHROPIC_API_KEY isn't set. Add it to ~/.Renviron and restart R.")
  }

  chat <- ellmer::chat_anthropic(
    model = model,
    system_prompt = "You transcribe election results tables into CSV with perfect accuracy.",
    params = ellmer::params(max_tokens = 64000),
    # Sent as-is to the Claude API; this is how to set effort
    api_args = list(output_config = list(effort = effort))
  )
  message("Sending ", basename(pdf_path), " to ", model, " (this can take a few minutes)...")
  reply <- chat$chat(ellmer::content_pdf_file(pdf_path), llm_extraction_prompt, echo = "none")

  wide <- parse_llm_csv(reply)
  extracted <- wide_to_extracted(wide)
  if (!is.null(out_path)) {
    write_csv_stable(extracted, out_path)
    message("Saved ", nrow(extracted), " numbers to ", out_path)
  }
  invisible(extracted)
}

#' Pull the CSV out of the model's reply
#'
#' The reply should be one ```csv block. If there's no fence, the whole reply
#' is treated as CSV.
parse_llm_csv <- function(reply) {
  text <- paste(reply, collapse = "\n")
  m <- regmatches(text, regexpr("(?s)```(?:csv)?[ \\t]*\\n(.*?)```", text, perl = TRUE))  # (?s): "." also matches newlines
  if (length(m) == 1) text <- sub("^```(?:csv)?\\s*\\n", "", sub("```$", "", m), perl = TRUE)
  readr::read_csv(I(text), col_types = readr::cols(.default = readr::col_character()),
                  na = c(""), show_col_types = FALSE)
}

#' Reshape the clerk-style wide table into the standard extracted layout
#'
#' Every column after section/party/race/candidate is a precinct (or Total).
#' Empty cells mean "no number printed" and are dropped.
wide_to_extracted <- function(wide) {
  fixed <- c("section", "party", "race", "candidate")
  missing <- setdiff(fixed, names(wide))
  if (length(missing) > 0) stop("The model's CSV is missing columns: ", paste(missing, collapse = ", "))
  long <- tidyr::pivot_longer(wide, -dplyr::all_of(fixed), names_to = "precinct", values_to = "votes")
  long$precinct <- clean_label(long$precinct)
  long$precinct[tolower(long$precinct) %in% c("total", "totals")] <- "Total"
  long$votes <- as_number(long$votes)
  long <- long[!is.na(long$votes), ]
  long$section <- ifelse(grepl("turnout", tolower(long$section)), "turnout", "results")
  long$party[long$party == ""] <- NA
  as.data.frame(long[, c("section", "party", "race", "candidate", "precinct", "votes")])
}
