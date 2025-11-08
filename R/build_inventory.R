# Helper Functions to Build and Update Election Inventory

library(dplyr)
library(stringr)
library(readr)
library(here)

#' Parse election metadata from standardized filename
#'
#' @param filename Standardized filename (YYYY-MM-DD_level_type_status_framingham.xlsx)
#' @return List with election_date, election_level, election_type, status
#'
#' @examples
#' parse_standardized_filename("2023-11-07_municipal_general_unofficial_framingham.xlsx")
#' # Returns: list(election_date = "2023-11-07", election_level = "municipal",
#' #               election_type = "general", status = "unofficial")
parse_standardized_filename <- function(filename) {
  # Remove extension
  base <- tools::file_path_sans_ext(basename(filename))

  # Try to extract pattern: YYYY-MM-DD_level_type_status_framingham
  pattern <- "^(\\d{4}-\\d{2}-\\d{2})_([^_]+)_([^_]+)_([^_]+)_framingham$"

  if (str_detect(base, pattern)) {
    parts <- str_match(base, pattern)
    return(list(
      election_date = parts[2],
      election_level = parts[3],
      election_type = parts[4],
      status = parts[5]
    ))
  }

  # Fallback: try to extract at least the date
  date_match <- str_extract(base, "\\d{4}-\\d{2}-\\d{2}")
  if (!is.na(date_match)) {
    return(list(
      election_date = date_match,
      election_level = NA_character_,
      election_type = NA_character_,
      status = NA_character_
    ))
  }

  return(list(
    election_date = NA_character_,
    election_level = NA_character_,
    election_type = NA_character_,
    status = NA_character_
  ))
}

#' Scan directory and build inventory from existing files
#'
#' @param directory Directory to scan for election files
#' @param output_path Where to save the inventory CSV
#' @param overwrite If FALSE, merge with existing inventory
#'
#' @return Data frame of inventory
#'
#' @examples
#' inventory <- scan_and_build_inventory("data-raw/elections")
scan_and_build_inventory <- function(directory = "data-raw/elections",
                                      output_path = "data-raw/elections/election_files_inventory_auto.csv",
                                      overwrite = TRUE) {

  message("Scanning directory: ", directory)

  # Get all PDF and Excel files
  all_files <- c(
    list.files(directory, pattern = "\\.pdf$", full.names = FALSE, recursive = TRUE),
    list.files(directory, pattern = "\\.xlsx?$", full.names = FALSE, recursive = TRUE)
  )

  message("Found ", length(all_files), " files")

  # Build inventory
  inventory <- tibble(
    filename_original = all_files,
    file_format = tolower(tools::file_ext(all_files))
  )

  # Try to parse metadata from filenames
  metadata <- purrr::map_df(inventory$filename_original, function(f) {
    parsed <- parse_standardized_filename(f)
    tibble(
      election_date = parsed$election_date,
      election_level = parsed$election_level,
      election_type = parsed$election_type,
      status = parsed$status
    )
  })

  inventory <- bind_cols(inventory, metadata)

  # Add computed columns
  inventory <- inventory %>%
    mutate(
      have_file = "YES",
      filename_standardized = if_else(
        !is.na(election_date),
        paste0(election_date, "_",
               coalesce(election_level, "unknown"), "_",
               coalesce(election_type, "unknown"), "_",
               coalesce(status, "unknown"), "_framingham.",
               file_format),
        NA_character_
      ),
      has_been_processed = case_when(
        file_format == "xlsx" ~ TRUE,
        file_format == "pdf" ~ FALSE,
        TRUE ~ NA
      ),
      notes = case_when(
        file_format == "xlsx" ~ "Already converted to Excel",
        file_format == "pdf" ~ "Needs conversion to Excel",
        TRUE ~ ""
      )
    ) %>%
    # Reorder columns
    select(
      election_date, election_level, election_type, status,
      have_file, filename_original, filename_standardized, file_format,
      has_been_processed, notes
    ) %>%
    arrange(desc(election_date), election_type)

  # Save
  if (!is.null(output_path)) {
    write_csv(inventory, here(output_path))
    message("Inventory saved to: ", output_path)
  }

  return(inventory)
}

#' Update existing inventory with actual files in directory
#'
#' @param inventory_path Path to existing inventory CSV
#' @param directory Directory to scan
#' @param output_path Where to save updated inventory
#'
#' @return Updated inventory data frame
update_inventory_with_files <- function(inventory_path = "data-raw/elections/election_files_inventory_complete.csv",
                                         directory = "data-raw/elections",
                                         output_path = inventory_path) {

  message("Reading existing inventory: ", inventory_path)
  inventory <- read_csv(inventory_path, show_col_types = FALSE)

  message("Scanning directory: ", directory)

  # Get all files that actually exist
  existing_files <- c(
    list.files(directory, pattern = "\\.pdf$", full.names = FALSE, recursive = TRUE),
    list.files(directory, pattern = "\\.xlsx?$", full.names = FALSE, recursive = TRUE)
  )

  message("Found ", length(existing_files), " files in directory")

  # Update have_file status based on actual files
  inventory <- inventory %>%
    mutate(
      file_exists = filename_original %in% existing_files,
      have_file_updated = if_else(file_exists, "YES",
                                   if_else(is.na(filename_original), "NO", "MISSING"))
    )

  # Report changes
  changed <- inventory %>%
    filter(have_file != have_file_updated | is.na(have_file))

  if (nrow(changed) > 0) {
    message("\nUpdating status for ", nrow(changed), " files:")
    for (i in 1:nrow(changed)) {
      message("  - ", changed$filename_original[i], ": ",
              changed$have_file[i], " → ", changed$have_file_updated[i])
    }
  } else {
    message("\nNo changes needed - inventory matches directory")
  }

  # Replace old status with new
  inventory <- inventory %>%
    mutate(have_file = have_file_updated) %>%
    select(-file_exists, -have_file_updated)

  # Save
  if (!is.null(output_path)) {
    write_csv(inventory, here(output_path))
    message("\nUpdated inventory saved to: ", output_path)
  }

  return(inventory)
}

#' Show summary of inventory
summarize_inventory <- function(inventory_path = "data-raw/elections/election_files_inventory_complete.csv") {

  inventory <- read_csv(inventory_path, show_col_types = FALSE)

  message("========================================")
  message("ELECTION FILE INVENTORY SUMMARY")
  message("========================================\n")

  # Overall counts
  total <- nrow(inventory)
  have_files <- sum(inventory$have_file == "YES", na.rm = TRUE)
  missing <- sum(inventory$have_file == "NO" | is.na(inventory$have_file), na.rm = TRUE)

  message("Total elections: ", total)
  message("Files available: ", have_files, " (", round(100*have_files/total, 1), "%)")
  message("Missing files: ", missing, " (", round(100*missing/total, 1), "%)\n")

  # By format
  message("By file format:")
  inventory %>%
    filter(have_file == "YES") %>%
    count(file_format) %>%
    arrange(desc(n)) %>%
    {walk2(.$file_format, .$n, ~message("  ", .x, ": ", .y, " files"))}

  # By type
  message("\nBy election type:")
  inventory %>%
    filter(have_file == "YES") %>%
    count(election_type, election_level) %>%
    arrange(desc(n)) %>%
    {walk2(paste(.$election_type, .$election_level), .$n,
           ~message("  ", .x, ": ", .y, " elections"))}

  # Excel files ready for processing
  ready <- inventory %>%
    filter(have_file == "YES", file_format == "xlsx")

  message("\nReady for LLM processing:")
  message("  Excel files: ", nrow(ready))
  message("  Date range: ", min(ready$election_date, na.rm = TRUE),
          " to ", max(ready$election_date, na.rm = TRUE))

  # Missing metadata
  missing_metadata <- inventory %>%
    filter(have_file == "YES") %>%
    filter(is.na(election_date) | is.na(election_type) | is.na(election_level))

  if (nrow(missing_metadata) > 0) {
    message("\n⚠️  Files with missing metadata:")
    for (i in 1:nrow(missing_metadata)) {
      message("  - ", missing_metadata$filename_original[i])
    }
  }

  message("\n========================================\n")

  invisible(inventory)
}

# ============================================
# Example usage
# ============================================

if (FALSE) {  # Set to TRUE to run

  # Scan directory and auto-build inventory
  inventory <- scan_and_build_inventory("data-raw/elections")
  View(inventory)

  # Update existing inventory based on what files actually exist
  updated <- update_inventory_with_files()

  # Show summary
  summarize_inventory()
}
