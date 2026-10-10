# build_all.R -------------------------------------------------------------------
# Rebuild every file in data/elections/ from the raw files in data-raw/.
#
# Run from the project folder:   Rscript scripts/build_all.R
# or in RStudio:                 source("scripts/build_all.R")
#
# Re-running on unchanged inputs gives identical files, so `git diff`
# afterwards shows exactly what a change to the data or code did.

source(here::here("R/load.R"))

checks <- build_all()

# Make the script "fail" (non-zero exit) when a check fails, so GitHub Actions
# flags it. Warnings don't stop the build.
if (any(checks$status == "fail") && !interactive()) {
  quit(status = 1)
}
