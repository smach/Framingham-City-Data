# add_election.R ----------------------------------------------------------------
# Add one election from a City Clerk results PDF.
#
# From a terminal in the project folder:
#   Rscript scripts/add_election.R 2025-11-04_municipal_general path/or/url/to/results.pdf unofficial
#
# Or in RStudio:
#   source(here::here("R/load.R"))
#   add_election("2025-11-04_municipal_general", "~/Downloads/results.pdf", status = "unofficial")
#
# What happens:
#   1. The PDF is saved in data-raw/elections/<election_id>/
#   2. Claude reads it and writes extracted.csv next to it (needs ANTHROPIC_API_KEY)
#   3. The registry (data-raw/elections/elections.csv) is updated
#   4. All of data/elections/ is rebuilt
#   5. That election's validation checks are printed. If any say "fail", look
#      at the detail, compare with the PDF, and fix extracted.csv by hand
#      (it's a plain CSV), then run scripts/build_all.R again.

source(here::here("R/load.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript scripts/add_election.R <election_id> <pdf path or URL> [unofficial|official]")
}
checks <- add_election(args[1], args[2], status = if (length(args) >= 3) args[3] else "unofficial")
print(checks[, c("check", "status", "detail")])
if (any(checks$status == "fail")) message("\nSome checks failed. See the details above.")
