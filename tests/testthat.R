# Run all tests from the project folder with:
#   Rscript tests/testthat.R
# or in RStudio: testthat::test_dir("tests/testthat")
testthat::test_dir(here::here("tests", "testthat"), stop_on_failure = TRUE)
