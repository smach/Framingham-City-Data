# Run all tests for Framingham Election Data

library(testthat)
library(here)

cat("\n")
cat("========================================\n")
cat("RUNNING TEST SUITE\n")
cat("========================================\n\n")

# Run tests
test_results <- test_dir(
  here("tests/testthat"),
  reporter = "progress"
)

cat("\n")
cat("========================================\n")
cat("TEST SUMMARY\n")
cat("========================================\n\n")

# Show summary
if (all(test_results$passed)) {
  cat("✅ ALL TESTS PASSED!\n\n")
} else {
  cat("❌ SOME TESTS FAILED\n\n")
  cat("Failed tests:\n")
  failed <- test_results[!test_results$passed, ]
  print(failed)
}

cat("\n")

# Also run validation
cat("========================================\n")
cat("RUNNING DATA VALIDATION\n")
cat("========================================\n\n")

source(here("R/validate_data.R"))
issues <- validate_election_data(verbose = TRUE)

cat("\n")

if (all(test_results$passed) && length(issues) == 0) {
  cat("🎉 EVERYTHING LOOKS GREAT!\n\n")
  cat("Your data is clean and ready for analysis.\n\n")
} else {
  cat("⚠️  REVIEW NEEDED\n\n")
  if (!all(test_results$passed)) {
    cat("Some tests failed - check the output above.\n")
  }
  if (length(issues) > 0) {
    cat("Some validation issues found - check the output above.\n")
  }
  cat("\n")
}
