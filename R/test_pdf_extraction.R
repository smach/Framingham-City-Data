# PDF to Excel Conversion Testing Script

# This script tests PDF extraction on Framingham election PDFs
# EXPECTATION: This will likely NOT be perfect - manual cleanup will be needed
# GOAL: See if we can get 80% of the way there, then manual cleanup in Excel

library(pdftools)
# library(tabulizer)  # Uncomment if you have Java installed

# Test file
test_pdf <- here::here("data-raw/elections/NOVEMBER 8, 2022 STATE ELECTION UNOFFICIAL RESULTS.pdf")

cat("=== Testing PDF Extraction ===\n")
cat("File:", basename(test_pdf), "\n\n")

# ============================================
# Method 1: pdftools (simple text extraction)
# ============================================
cat("--- Method 1: pdftools::pdf_text() ---\n")
text <- pdftools::pdf_text(test_pdf)
cat("Number of pages:", length(text), "\n")
cat("\nFirst 500 characters of page 1:\n")
cat(substr(text[1], 1, 500), "\n\n")

# ============================================
# Method 2: pdftools::pdf_data (structured)
# ============================================
cat("--- Method 2: pdftools::pdf_data() ---\n")
data <- pdftools::pdf_data(test_pdf)
cat("Number of pages:", length(data), "\n")
cat("\nStructure of page 1 data:\n")
print(str(data[[1]]))
cat("\nFirst 10 rows of page 1:\n")
print(head(data[[1]], 10))

# ============================================
# Method 3: tabulizer (if available)
# ============================================
if (requireNamespace("tabulizer", quietly = TRUE)) {
  cat("\n--- Method 3: tabulizer::extract_tables() ---\n")

  tryCatch({
    tables <- tabulizer::extract_tables(test_pdf)
    cat("Number of tables extracted:", length(tables), "\n")

    if (length(tables) > 0) {
      cat("\nFirst table dimensions:", dim(tables[[1]]), "\n")
      cat("\nFirst few rows of first table:\n")
      print(head(tables[[1]], 10))

      # Try to convert to data frame
      df <- as.data.frame(tables[[1]], stringsAsFactors = FALSE)
      cat("\nData frame structure:\n")
      print(str(df))
    }
  }, error = function(e) {
    cat("Error with tabulizer:", e$message, "\n")
  })
} else {
  cat("\n--- Method 3: tabulizer NOT AVAILABLE ---\n")
  cat("Install with: install.packages('tabulizer')\n")
  cat("Note: Requires Java\n")
}

# ============================================
# Recommendation
# ============================================
cat("\n=== RECOMMENDATION ===\n")
cat("Based on the output above:\n")
cat("1. If tabulizer worked well → use it for batch extraction\n")
cat("2. If extraction is messy → use Adobe for PDF to Excel conversion\n")
cat("3. Either way, you'll need manual cleanup in Excel afterwards\n")
cat("\nFor Framingham clerk PDFs, expect:\n")
cat("- Headers may merge with data rows\n")
cat("- Multiple tables per page may not separate cleanly\n")
cat("- Column alignment may be off\n")
cat("- You'll need to standardize in Excel before R processing\n")
