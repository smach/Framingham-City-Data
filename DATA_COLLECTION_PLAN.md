# Framingham Election Data Collection & Processing Plan

## Step 1: File Naming Scheme

### Recommended Naming Convention

**Format**: `YYYY-MM-DD_{level}_{type}_{status}_framingham.{ext}`

**Components**:
- `YYYY-MM-DD`: Election date (ISO 8601 format for sorting)
- `{level}`: `municipal`, `state`, `federal`
- `{type}`: `general`, `preliminary`, `primary`, `special`, `charter`
- `{status}`: `official` or `unofficial`
- `{ext}`: `pdf`, `xlsx`, `csv`

**Examples**:
```
2023-11-07_municipal_general_unofficial_framingham.pdf
2023-11-07_municipal_general_unofficial_framingham.xlsx
2022-11-08_state_general_unofficial_framingham.pdf
2022-09-06_state_primary_unofficial_framingham.pdf
2021-11-02_municipal_general_official_framingham.pdf
2021-09-14_municipal_preliminary_official_framingham.pdf
2020-09-01_state_primary_official_framingham.pdf
2017-11-07_municipal_charter_official_framingham.pdf
```

### File Inventory Metadata

Create: `data-raw/elections/election_files_inventory.csv`

Columns:
- `filename_original`: Original filename from clerk
- `filename_standardized`: Standardized filename
- `election_date`: YYYY-MM-DD
- `election_level`: municipal/state/federal
- `election_type`: general/preliminary/primary/special/charter
- `status`: official/unofficial
- `file_format`: pdf/xlsx/csv
- `download_url`: URL from city website
- `download_date`: When file was downloaded
- `has_been_processed`: TRUE/FALSE
- `notes`: Any special notes

This CSV serves as your master index and makes it easy to track what you have and what needs processing.

---

## Step 2: PDF to Excel Conversion in R

### Recommended R Packages

#### Option 1: `pdftools` + `tabulizer` (Best for tabular data)

```r
# Install (tabulizer requires rJava)
install.packages("pdftools")
install.packages("tabulizer", repos = "http://datacube.wu.ac.at/")

# Usage
library(tabulizer)

# Extract tables from PDF
tables <- extract_tables("path/to/election.pdf")

# Convert to data frame
df <- as.data.frame(tables[[1]], stringsAsFactors = FALSE)

# Or extract specific pages
tables_p1 <- extract_tables("path/to/election.pdf", pages = 1)
```

**Pros**: Works well for simple tables
**Cons**: Requires Java, can struggle with complex layouts

#### Option 2: `pdftools` alone (Good for simple extraction)

```r
install.packages("pdftools")

library(pdftools)

# Extract text
text <- pdf_text("path/to/election.pdf")

# Extract tables (basic)
data <- pdf_data("path/to/election.pdf")
```

**Pros**: No Java dependency, fast
**Cons**: Requires more manual parsing

#### Option 3: `tesseract` (For scanned PDFs)

```r
install.packages("tesseract")
install.packages("pdftools")

library(tesseract)
library(pdftools)

# Convert PDF to images
pdf_convert("path/to/scanned.pdf", format = "png", dpi = 300)

# OCR each page
text <- ocr("path/to/page_1.png")
```

**Pros**: Works on scanned documents
**Cons**: Slower, may have OCR errors

#### Option 4: External tool - `tabula-java` via command line

```r
# Call tabula-java from R
system2("java", args = c(
  "-jar", "path/to/tabula-java.jar",
  "--pages", "all",
  "--format", "CSV",
  "--output", "output.csv",
  "input.pdf"
))
```

**Pros**: Very accurate table extraction
**Cons**: External dependency

### Recommended Approach

**Use a tiered approach**:

1. **Try `tabulizer` first** - usually works well for clerk-generated PDFs
2. **Fall back to `pdftools`** if tabulizer fails
3. **Manual conversion for problem files** - some PDFs are just too messy

### Implementation Script

**Create**: `R/pdf_extraction.R`

```r
library(tabulizer)
library(pdftools)
library(dplyr)
library(readr)
library(here)

#' Extract election data from PDF
#' @param pdf_path Path to PDF file
#' @param method "auto", "tabulizer", "pdftools", "manual"
#' @return List with extracted tables or NULL if failed
extract_election_pdf <- function(pdf_path, method = "auto") {

  message("Processing: ", basename(pdf_path))

  # Auto-detect method
  if (method == "auto") {
    # Try tabulizer first if available
    if (requireNamespace("tabulizer", quietly = TRUE)) {
      method <- "tabulizer"
    } else {
      method <- "pdftools"
    }
  }

  result <- tryCatch({
    if (method == "tabulizer") {
      extract_with_tabulizer(pdf_path)
    } else if (method == "pdftools") {
      extract_with_pdftools(pdf_path)
    } else {
      stop("Unknown method: ", method)
    }
  }, error = function(e) {
    warning("Extraction failed for ", pdf_path, ": ", e$message)
    NULL
  })

  return(result)
}

#' Extract using tabulizer
extract_with_tabulizer <- function(pdf_path) {
  tables <- tabulizer::extract_tables(pdf_path)

  # Convert to list of data frames
  dfs <- lapply(tables, function(tbl) {
    if (is.matrix(tbl) || is.data.frame(tbl)) {
      df <- as.data.frame(tbl, stringsAsFactors = FALSE)
      # First row often contains headers
      if (nrow(df) > 0) {
        names(df) <- as.character(df[1, ])
        df <- df[-1, ]
      }
      return(df)
    }
    return(NULL)
  })

  dfs[!sapply(dfs, is.null)]
}

#' Extract using pdftools
extract_with_pdftools <- function(pdf_path) {
  # Extract raw data (positions of text)
  data <- pdftools::pdf_data(pdf_path)

  # This requires custom parsing logic based on your PDF structure
  # Return raw data for now
  list(raw_data = data)
}

#' Save extracted data to Excel
#' @param data_list List of data frames
#' @param output_path Path for output Excel file
save_to_excel <- function(data_list, output_path) {
  if (length(data_list) == 1) {
    writexl::write_xlsx(data_list[[1]], output_path)
  } else {
    # Multiple sheets
    names(data_list) <- paste0("Page_", seq_along(data_list))
    writexl::write_xlsx(data_list, output_path)
  }
  message("Saved to: ", output_path)
}

#' Batch process all PDFs in a directory
#' @param input_dir Directory with PDF files
#' @param output_dir Directory for Excel files
#' @param force_reprocess If FALSE, skip files that already have Excel versions
process_all_pdfs <- function(input_dir = "data-raw/elections",
                              output_dir = "data-raw/elections/extracted",
                              force_reprocess = FALSE) {

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  pdf_files <- list.files(input_dir, pattern = "\\.pdf$",
                         full.names = TRUE, recursive = TRUE)

  results <- tibble(
    pdf_file = character(),
    xlsx_file = character(),
    success = logical(),
    error_message = character(),
    processed_date = character()
  )

  for (pdf_path in pdf_files) {
    # Generate output path
    base_name <- tools::file_path_sans_ext(basename(pdf_path))
    xlsx_path <- file.path(output_dir, paste0(base_name, "_extracted.xlsx"))

    # Skip if already processed
    if (!force_reprocess && file.exists(xlsx_path)) {
      message("Skipping (already exists): ", basename(pdf_path))
      next
    }

    # Extract
    extracted <- extract_election_pdf(pdf_path)

    # Save
    success <- FALSE
    error_msg <- NA_character_

    if (!is.null(extracted) && length(extracted) > 0) {
      tryCatch({
        save_to_excel(extracted, xlsx_path)
        success <- TRUE
      }, error = function(e) {
        error_msg <- e$message
      })
    } else {
      error_msg <- "No tables extracted"
    }

    # Record result
    results <- results %>%
      add_row(
        pdf_file = basename(pdf_path),
        xlsx_file = if(success) basename(xlsx_path) else NA_character_,
        success = success,
        error_message = error_msg,
        processed_date = as.character(Sys.Date())
      )
  }

  # Save processing log
  write_csv(results, file.path(output_dir, "extraction_log.csv"))

  message("\n=== Extraction Summary ===")
  message("Total PDFs: ", nrow(results))
  message("Successful: ", sum(results$success))
  message("Failed: ", sum(!results$success))

  return(results)
}
```

---

## Step 3: Tidy Data Conversion Pipeline

### Enhanced `election_helpers.R`

**Update**: `R/election_helpers.R` to handle standardized inputs

```r
#' Process raw Excel file to tidy format
#' @param excel_path Path to Excel file
#' @param election_date Date of election (YYYY-MM-DD)
#' @param election_level "municipal", "state", "federal"
#' @param election_type "general", "preliminary", "primary", "special", "charter"
#' @return Tidy data frame
process_raw_election <- function(excel_path, election_date,
                                 election_level, election_type) {

  # Read Excel file
  raw_data <- readxl::read_excel(excel_path)

  # Auto-detect structure and clean
  # This is custom to Framingham clerk format
  tidy_data <- raw_data %>%
    # Your specific cleaning logic here
    janitor::clean_names() %>%
    # ... more processing ...
    # Add metadata
    mutate(
      election_date = as.Date(election_date),
      election_year = lubridate::year(election_date),
      election_level = election_level,
      election_type = election_type
    )

  return(tidy_data)
}
```

---

## Step 4: Dual Storage (SQLite + Parquet)

### Why Parquet?

**Benefits**:
- **Column-oriented**: Very fast for analytical queries
- **Compressed**: Smaller file sizes than CSV
- **Type-safe**: Preserves data types (dates, integers, etc.)
- **R-friendly**: Excellent support via `arrow` package
- **Cross-platform**: Works with Python, R, DuckDB, etc.
- **Partitioned**: Can split large datasets by year/election

### Implementation

**Create**: `R/storage.R`

```r
library(DBI)
library(RSQLite)
library(arrow)
library(dplyr)
library(here)

#' Initialize dual storage (SQLite + Parquet)
initialize_storage <- function() {
  # Create SQLite database
  source(here("R/database.R"))
  initialize_database()

  # Create Parquet directory structure
  dir.create(here("data/parquet"), showWarnings = FALSE)
  dir.create(here("data/parquet/elections"), showWarnings = FALSE)
  dir.create(here("data/parquet/results"), showWarnings = FALSE)
  dir.create(here("data/parquet/turnout"), showWarnings = FALSE)

  message("Storage initialized")
}

#' Save data to both SQLite and Parquet
#' @param data Data frame to save
#' @param table_name Table name (e.g., "results", "turnout")
#' @param partition_cols Optional columns to partition by (for Parquet)
save_dual <- function(data, table_name, partition_cols = NULL) {

  # 1. Save to SQLite
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbWriteTable(con, table_name, data, append = TRUE)
  message("Saved to SQLite: ", table_name)

  # 2. Save to Parquet
  parquet_path <- here("data/parquet", table_name)

  if (!is.null(partition_cols)) {
    # Partitioned dataset (e.g., by year)
    arrow::write_dataset(
      data,
      parquet_path,
      format = "parquet",
      partitioning = partition_cols
    )
  } else {
    # Single file
    parquet_file <- paste0(parquet_path, ".parquet")
    arrow::write_parquet(data, parquet_file)
  }

  message("Saved to Parquet: ", parquet_path)
}

#' Read from Parquet (faster for large analytical queries)
#' @param table_name Table name
#' @param filter Optional filter expression
read_parquet <- function(table_name, filter = NULL) {
  parquet_path <- here("data/parquet", table_name)

  # Check if partitioned dataset
  if (dir.exists(parquet_path)) {
    ds <- arrow::open_dataset(parquet_path)

    if (!is.null(filter)) {
      ds <- ds %>% filter(!!rlang::parse_expr(filter))
    }

    return(ds %>% collect())
  } else {
    # Single file
    parquet_file <- paste0(parquet_path, ".parquet")
    arrow::read_parquet(parquet_file)
  }
}

#' Read from SQLite (better for joins and complex queries)
#' @param query SQL query string
read_sqlite <- function(query) {
  con <- get_db_connection()
  on.exit(DBI::dbDisconnect(con))

  DBI::dbGetQuery(con, query)
}

# Example: Save results with partitioning by year
# save_dual(results_data, "results", partition_cols = "election_year")

# Example: Read all results from 2023
# results_2023 <- read_parquet("results", filter = "election_year == 2023")
```

### Parquet Directory Structure

```
data/parquet/
├── elections.parquet           # Single file (small table)
├── results/                    # Partitioned by year
│   ├── election_year=2017/
│   │   └── part-0.parquet
│   ├── election_year=2019/
│   │   └── part-0.parquet
│   ├── election_year=2021/
│   │   └── part-0.parquet
│   └── election_year=2023/
│       └── part-0.parquet
└── turnout/                    # Partitioned by year
    ├── election_year=2017/
    ├── election_year=2019/
    └── ...
```

**Benefits of partitioning**:
- Only reads relevant files (faster queries)
- Easy to add new years
- Can delete old years if needed
- Works great with DuckDB for SQL queries on Parquet

---

## Complete Workflow

**Create**: `R/complete_pipeline.R`

```r
source(here::here("R/pdf_extraction.R"))
source(here::here("R/election_helpers.R"))
source(here::here("R/storage.R"))

#' Complete pipeline: PDF → Tidy Data → Dual Storage
#' @param inventory_csv Path to election_files_inventory.csv
process_all_elections <- function(inventory_csv = "data-raw/elections/election_files_inventory.csv") {

  # Read inventory
  inventory <- readr::read_csv(inventory_csv, show_col_types = FALSE)

  # Filter to unprocessed files
  to_process <- inventory %>%
    filter(!has_been_processed | is.na(has_been_processed))

  if (nrow(to_process) == 0) {
    message("All files already processed!")
    return(invisible(NULL))
  }

  message("Processing ", nrow(to_process), " elections...")

  # Initialize storage
  initialize_storage()

  # Process each election
  for (i in 1:nrow(to_process)) {
    row <- to_process[i, ]

    message("\n=== Processing ", row$filename_standardized, " ===")

    # 1. Extract PDF to Excel (if needed)
    if (row$file_format == "pdf") {
      pdf_path <- here("data-raw/elections", row$filename_original)
      xlsx_path <- here("data-raw/elections/extracted",
                       tools::file_path_sans_ext(row$filename_standardized),
                       ".xlsx")

      if (!file.exists(xlsx_path)) {
        extracted <- extract_election_pdf(pdf_path)
        if (!is.null(extracted)) {
          save_to_excel(extracted, xlsx_path)
        } else {
          warning("Failed to extract: ", row$filename_original)
          next
        }
      }
    } else {
      xlsx_path <- here("data-raw/elections", row$filename_original)
    }

    # 2. Convert to tidy data
    tidy_data <- process_raw_election(
      xlsx_path,
      election_date = row$election_date,
      election_level = row$election_level,
      election_type = row$election_type
    )

    # 3. Save to dual storage
    save_dual(tidy_data, "results", partition_cols = "election_year")

    # 4. Mark as processed in inventory
    inventory$has_been_processed[inventory$filename_original == row$filename_original] <- TRUE
    inventory$processed_date[inventory$filename_original == row$filename_original] <- as.character(Sys.Date())
  }

  # Save updated inventory
  readr::write_csv(inventory, inventory_csv)

  message("\n=== Pipeline Complete ===")
}
```

---

## Package Dependencies

Install all required packages:

```r
# PDF extraction
install.packages("pdftools")
install.packages("tabulizer", repos = "http://datacube.wu.ac.at/")

# Data manipulation
install.packages("dplyr")
install.packages("tidyr")
install.packages("readr")
install.packages("readxl")
install.packages("writexl")
install.packages("janitor")
install.packages("lubridate")
install.packages("here")

# Storage
install.packages("DBI")
install.packages("RSQLite")
install.packages("arrow")  # For Parquet

# Optional but useful
install.packages("tesseract")  # OCR for scanned PDFs
```

---

## Next Actions

1. **Create file inventory** - Manually catalog what you have and what's missing
2. **Test PDF extraction** - Try on 2-3 sample PDFs to see what works
3. **Standardize filenames** - Rename files following the new convention
4. **Build processing scripts** - Implement the R scripts above
5. **Run pipeline** - Process all historical elections
6. **Validate** - Check that SQLite and Parquet have same data
7. **Document** - Update README with new workflow

---

## Performance Notes

- **SQLite**: Best for joins, aggregations, complex queries
- **Parquet**: Best for large scans, column-based analytics, time series
- **CSV exports**: Best for sharing with Excel users
- **Storage overhead**: SQLite + Parquet together still very small (~10-20 MB for all elections)

You can query Parquet files with DuckDB for even faster analytics:
```r
library(duckdb)
con <- dbConnect(duckdb())
dbGetQuery(con, "SELECT * FROM read_parquet('data/parquet/results/**/*.parquet') WHERE election_year = 2023")
```
