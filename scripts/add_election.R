# add_election.R ----------------------------------------------------------------
# Add one election from a spreadsheet you converted in Adobe Acrobat.
#
# First, in Adobe Acrobat: open the clerk's results PDF and export it to an
# Excel workbook. (See the README for why, and what to do with scanned PDFs.)
#
# Then, from a terminal in the project folder:
#   Rscript scripts/add_election.R <election_id> <spreadsheet> <unofficial|official> [pdf] [source_url] [name]
# e.g.
#   Rscript scripts/add_election.R 2026-11-03_state_general data-raw/elections/2026-11-03_state_general/Official_Results_110326.xlsx official data-raw/elections/2026-11-03_state_general/Official_Results_110326.pdf https://www.framinghamma.gov/DocumentCenter/View/55543/Official-Results--110326
#
# The name ("November 3 2026 State Election") is made from the election id if
# you leave it out. Use "" to skip an argument, e.g. a name with no PDF.
#
# Or in RStudio:
#   source(here::here("R/load.R"))
#   add_election("2026-11-03_state_general", "path/to/results.xlsx",
#                status = "official", pdf = "path/to/results.pdf",
#                source_url = "https://www.framinghamma.gov/DocumentCenter/View/...")
#
# What happens:
#   1. The spreadsheet (and PDF) are copied to data-raw/elections/<election_id>/
#      (if they're already there, they stay put)
#   2. The registry (data-raw/elections/elections.csv) is updated
#   3. All of data/elections/ is rebuilt
#   4. That election's validation checks are printed. If any say "fail", the
#      detail names the race and precinct that don't add up: compare with the
#      PDF, fix the spreadsheet, and run scripts/build_all.R again.

source(here::here("R/load.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript scripts/add_election.R <election_id> <spreadsheet> [unofficial|official] [pdf] [source_url] [name]")
}
# Optional argument n, or NA when it's missing or ""
arg <- function(n) if (length(args) >= n && nzchar(args[n])) args[n] else NA

checks <- add_election(args[1], args[2],
                       status = if (is.na(arg(3))) "unofficial" else arg(3),
                       pdf = arg(4), source_url = arg(5), name = arg(6))
options(width = 200)
print(as.data.frame(checks[, c("check", "status", "detail")]), right = FALSE)
if (any(checks$status == "fail")) message("\nSome checks failed. See the details above.")
