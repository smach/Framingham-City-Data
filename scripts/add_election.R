# add_election.R ----------------------------------------------------------------
# Add one election from a spreadsheet you converted in Adobe Acrobat.
#
# First, in Adobe Acrobat: open the clerk's results PDF and export it to an
# Excel workbook. (See the README for why, and what to do with scanned PDFs.)
#
# Then, from a terminal in the project folder:
#   Rscript scripts/add_election.R 2025-11-04_municipal_general path/to/results.xlsx unofficial path/to/results.pdf
#
# Or in RStudio:
#   source(here::here("R/load.R"))
#   add_election("2025-11-04_municipal_general", "~/Downloads/results.xlsx",
#                status = "unofficial", pdf = "~/Downloads/results.pdf")
#
# What happens:
#   1. The spreadsheet (and PDF) are copied to data-raw/elections/<election_id>/
#   2. The registry (data-raw/elections/elections.csv) is updated
#   3. All of data/elections/ is rebuilt
#   4. That election's validation checks are printed. If any say "fail", the
#      detail names the race and precinct that don't add up: compare with the
#      PDF, fix the spreadsheet, and run scripts/build_all.R again.

source(here::here("R/load.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript scripts/add_election.R <election_id> <spreadsheet> [unofficial|official] [pdf]")
}
checks <- add_election(args[1], args[2],
                       status = if (length(args) >= 3) args[3] else "unofficial",
                       pdf = if (length(args) >= 4) args[4] else NA)
print(checks[, c("check", "status", "detail")])
if (any(checks$status == "fail")) message("\nSome checks failed. See the details above.")
