# Generalized Election Processing with LLM Extraction
# Based on your excellent 2025 script, but works for ANY election file
# Extracts race metadata automatically using ellmer

source(here::here("R/load_packages.R"))
source(here::here("R/functions_helpers.R"))
source(here::here("R/extract_race_metadata.R"))

#' Process a single election Excel file into tidy format with LLM extraction
#'
#' @param excel_path Path to Excel file (from Adobe PDF conversion)
#' @param election_date Date of election (YYYY-MM-DD)
#' @param election_type Type: "general", "preliminary", "primary", "special"
#' @param election_level Level: "municipal", "state", "federal"
#' @param use_llm Whether to use LLM for race extraction (TRUE) or manual patterns (FALSE)
#' @param chat Optional ellmer chat object (reuse across calls for efficiency)
#'
#' @return List with tidy_results and turnout data frames
#'
#' @examples
#' result <- process_election_file(
#'   excel_path = "data-raw/elections/2023-11-07_municipal_general_unofficial_framingham.xlsx",
#'   election_date = "2023-11-07",
#'   election_type = "general",
#'   election_level = "municipal",
#'   use_llm = TRUE
#' )
process_election_file <- function(excel_path,
                                   election_date,
                                   election_type = c("general", "preliminary", "primary", "special", "charter"),
                                   election_level = c("municipal", "state", "federal"),
                                   use_llm = TRUE,
                                   chat = NULL,
                                   races_to_exclude = c("library", "cemetery")) {

  election_type <- match.arg(election_type)
  election_level <- match.arg(election_level)
  election_year <- lubridate::year(as.Date(election_date))

  message("========================================")
  message("Processing: ", basename(excel_path))
  message("Date: ", election_date, " | Type: ", election_type, " | Level: ", election_level)
  message("========================================")

  # ============================================
  # Step 1: Import Excel file
  # ============================================
  results <- rio::import(excel_path)
  names(results)[1] <- "Candidate"

  # Save raw for turnout extraction
  results_raw <- results

  # ============================================
  # Step 2: Remove blanks, write-ins, turnout rows
  # ============================================
  results <- results %>%
    filter(!str_detect(tolower(Candidate), "\\bblanks\\b")) %>%
    filter(!str_detect(tolower(Candidate), "write.?in")) %>%
    filter(!str_detect(tolower(Candidate), "candidate")) %>%
    filter(!str_detect(tolower(Candidate), "turnout")) %>%
    filter(!str_detect(tolower(Candidate), "registered")) %>%
    filter(!str_detect(tolower(Candidate), "percentage"))

  # ============================================
  # Step 3: Identify race headers vs candidates
  # ============================================
  results <- results %>%
    mutate(
      Type = if_else(is.na(Total), "Election", "Person"),
      Office = case_when(
        Type == "Election" ~ Candidate,
        TRUE ~ NA_character_
      )
    ) %>%
    fill(Office, .direction = "down")

  # ============================================
  # Step 4: Filter to candidate rows and pivot longer
  # ============================================
  results_tidy <- results %>%
    filter(Type == "Person") %>%
    select(-Type, -Total) %>%
    mutate(across(-c(Candidate, Office), as.numeric)) %>%
    pivot_longer(
      cols = -c(Candidate, Office),
      names_to = "Precinct",
      values_to = "Votes"
    ) %>%
    mutate(
      Office = str_squish(str_replace_all(Office, "\\p{Z}+", " "))
    )

  # ============================================
  # Step 5: Extract race metadata using LLM
  # ============================================
  if (use_llm) {
    message("\n--- Using LLM to extract race metadata ---")

    if (is.null(chat)) {
      chat <- chat_openai(model = "gpt-4o-mini")
    }

    # Get unique office names
    unique_offices <- unique(results_tidy$Office)

    # Extract metadata
    race_metadata <- extract_race_metadata(unique_offices, chat = chat)

    # Validate and clean
    race_metadata <- validate_race_metadata(race_metadata)

    # Join to results
    results_tidy <- results_tidy %>%
      left_join(
        race_metadata %>% select(office_original, race_standardized, race_display_name,
                                 num_winners, district, office_level, is_primary, party),
        by = c("Office" = "office_original")
      ) %>%
      rename(
        Race = race_standardized,
        RaceName = race_display_name
      )

  } else {
    # ============================================
    # Step 5 (Alternative): Manual regex patterns (your original approach)
    # ============================================
    message("\n--- Using manual regex patterns for race extraction ---")

    results_tidy <- results_tidy %>%
      mutate(
        Race = case_when(
          str_detect(Office, fixed("Mayor")) ~ "mayor",
          str_detect(Office, ".*At.Large.*Council") ~ "council_at_large",
          str_detect(Office, ".*At.Large.*School") ~ "sc_at_large",
          str_detect(Office, "Library") ~ "library",
          str_detect(Office, "Cemetery") ~ "cemetery",
          str_detect(Office, "Charter") ~ "charter",
          str_detect(Office, "Question \\d+") ~ paste0("ballot_question_",
                                                        str_extract(Office, "Question (\\d+)", group = 1)),
          str_detect(Office, "District \\d+ City Council") ~
            str_c("council_", str_extract(Office, "District (\\d+)", group = 1)),
          str_detect(Office, "District \\d+ School Committee") ~
            str_c("sc_", str_extract(Office, "District (\\d+)", group = 1)),
          str_detect(Office, "President.*Democratic") ~ "president_d",
          str_detect(Office, "President.*Republican") ~ "president_r",
          TRUE ~ NA_character_
        ),
        RaceName = trimws(sub("\\(.*", "", Office)),
        # Extract num_winners from "Vote for X" patterns
        num_winners = as.integer(str_extract(Office, "(?i)vote for (?:not more than )?(\\d+)", group = 1)),
        num_winners = if_else(is.na(num_winners), 1L, num_winners)
      )
  }

  # ============================================
  # Step 6: Extract candidate names using LLM
  # ============================================
  message("\n--- Extracting candidate names ---")

  if (is.null(chat)) {
    chat <- chat_openai(model = "gpt-4o-mini")
  }

  candidate_names <- extract_candidate_names(results_tidy$Candidate, chat = chat)

  results_tidy <- results_tidy %>%
    bind_cols(candidate_names %>% select(candidate_last_name)) %>%
    rename(
      CandidateName = Candidate,
      Candidate = candidate_last_name
    )

  # ============================================
  # Step 7: Clean and filter
  # ============================================
  results_tidy <- results_tidy %>%
    filter(!is.na(Race)) %>%
    filter(!is.na(Votes)) %>%
    filter(!(Race %in% races_to_exclude)) %>%
    mutate(
      Votes = as.integer(Votes),
      # Fix known name issues
      CandidateName = str_replace(CandidateName, fixed("White-Harvey"), "White Harvey"),
      Candidate = str_replace(Candidate, fixed("White-Harvey"), "White Harvey"),
      # Add election metadata
      ElectionDate = as.Date(election_date),
      ElectionYear = election_year,
      ElectionType = election_type,
      ElectionLevel = election_level
    )

  # ============================================
  # Step 8: Extract turnout data
  # ============================================
  message("\n--- Extracting turnout data ---")

  turnout <- results_raw %>%
    filter(str_detect(Candidate, "Turnout|Registered")) %>%
    mutate(across(-c(Candidate), as.character)) %>%
    pivot_longer(
      cols = -c(Candidate),
      names_to = "Precinct",
      values_to = "Voters"
    ) %>%
    mutate(Voters = as.integer(as.numeric(Voters))) %>%
    pivot_wider(
      id_cols = Precinct,
      names_from = Candidate,
      values_from = Voters
    )

  # Handle different column name variations
  turnout <- turnout %>%
    rename_with(~"Votes_Cast", matches("(?i)total turnout|votes cast")) %>%
    rename_with(~"Total_Registered", matches("(?i)total registered|registered voters")) %>%
    mutate(
      Pct_Turnout = round(Votes_Cast / Total_Registered, 3),
      ElectionDate = as.Date(election_date),
      ElectionYear = election_year,
      ElectionType = election_type,
      ElectionLevel = election_level
    )

  # ============================================
  # Step 9: Final column selection
  # ============================================
  results_final <- results_tidy %>%
    select(
      ElectionDate, ElectionYear, ElectionType, ElectionLevel,
      Race, RaceName, Office,
      Precinct, Candidate, CandidateName, Votes,
      # Include LLM-extracted metadata if available
      any_of(c("num_winners", "district", "office_level", "is_primary", "party"))
    )

  turnout_final <- turnout %>%
    select(
      ElectionDate, ElectionYear, ElectionType, ElectionLevel,
      Precinct, Votes_Cast, Total_Registered, Pct_Turnout
    )

  message("\n--- Processing complete! ---")
  message("Results extracted:")
  message("  Races: ", length(unique(results_final$Race)))
  message("  Candidates: ", nrow(results_final))
  message("  Precincts: ", length(unique(results_final$Precinct)))
  message("Turnout extracted:")
  message("  Precincts: ", nrow(turnout_final))
  message("  Total votes: ", format(sum(turnout_final$Votes_Cast, na.rm = TRUE), big.mark = ","))
  message("  Avg turnout: ", round(mean(turnout_final$Pct_Turnout, na.rm = TRUE) * 100, 1), "%")

  return(list(
    results = results_final,
    turnout = turnout_final,
    metadata = list(
      election_date = election_date,
      election_type = election_type,
      election_level = election_level,
      n_races = length(unique(results_final$Race)),
      n_candidates = nrow(results_final),
      n_precincts = length(unique(results_final$Precinct))
    )
  ))
}

#' Process all elections from inventory CSV
#'
#' @param inventory_path Path to election_files_inventory_complete.csv
#' @param use_llm Use LLM for race extraction
#' @param save_output Save results to parquet files
#' @param output_dir Directory for output files
#' @param process_all If TRUE, process all Excel files; if FALSE, only unprocessed ones
#'
#' @return List of all processed elections
process_all_elections_batch <- function(inventory_path = "data-raw/elections/election_files_inventory_complete.csv",
                                         use_llm = TRUE,
                                         save_output = TRUE,
                                         output_dir = "data/elections/processed",
                                         process_all = TRUE) {

  # Read inventory
  inventory <- readr::read_csv(inventory_path, show_col_types = FALSE)

  # Filter to files that exist and have Excel format
  # Date, type, and level are pulled from CSV columns!
  to_process <- inventory %>%
    filter(have_file == "YES") %>%
    filter(file_format == "xlsx") %>%
    filter(!is.na(filename_original)) %>%
    # Only process files with valid metadata
    filter(!is.na(election_date), !is.na(election_type), !is.na(election_level))

  # Optionally filter to only unprocessed files
  if (!process_all) {
    to_process <- to_process %>%
      filter(has_been_processed == FALSE | is.na(has_been_processed))
  }

  message("========================================")
  message("BATCH PROCESSING: ", nrow(to_process), " elections")
  message("Reading metadata from inventory CSV")
  message("========================================\n")

  # Create output directory
  if (save_output) {
    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  }

  # Create reusable chat object for efficiency
  chat <- chat_openai(model = "gpt-4o-mini")

  # Process each election
  all_results <- list()
  all_turnout <- list()

  for (i in 1:nrow(to_process)) {
    row <- to_process[i, ]

    tryCatch({
      # Construct file path
      excel_path <- here::here("data-raw/elections", row$filename_original)

      # Check if file exists
      if (!file.exists(excel_path)) {
        warning("File not found: ", excel_path)
        next
      }

      # Get metadata from CSV (not from filename!)
      election_date <- as.character(row$election_date)
      election_type <- as.character(row$election_type)
      election_level <- as.character(row$election_level)

      message("\n[", i, "/", nrow(to_process), "] ", basename(excel_path))
      message("  Date: ", election_date, " | Type: ", election_type, " | Level: ", election_level)

      # Process election
      processed <- process_election_file(
        excel_path = excel_path,
        election_date = election_date,
        election_type = election_type,
        election_level = election_level,
        use_llm = use_llm,
        chat = chat  # Reuse chat object
      )

      # Save to parquet
      if (save_output) {
        results_file <- file.path(output_dir, paste0(
          format(as.Date(row$election_date), "%Y-%m-%d"), "_",
          row$election_level, "_",
          row$election_type, "_results.parquet"
        ))

        turnout_file <- file.path(output_dir, paste0(
          format(as.Date(row$election_date), "%Y-%m-%d"), "_",
          row$election_level, "_",
          row$election_type, "_turnout.parquet"
        ))

        arrow::write_parquet(processed$results, results_file)
        arrow::write_parquet(processed$turnout, turnout_file)

        message("  ✓ Saved results: ", basename(results_file))
        message("  ✓ Saved turnout: ", basename(turnout_file))
      }

      # Store in lists
      all_results[[i]] <- processed$results
      all_turnout[[i]] <- processed$turnout

    }, error = function(e) {
      warning("Failed to process ", row$filename_original, ": ", e$message)
    })

    # Pause to respect rate limits
    Sys.sleep(0.5)
  }

  # Combine all results
  combined_results <- bind_rows(all_results)
  combined_turnout <- bind_rows(all_turnout)

  message("\n========================================")
  message("BATCH COMPLETE!")
  message("========================================")
  message("Results data:")
  message("  Total rows: ", format(nrow(combined_results), big.mark = ","))
  message("  Elections: ", n_distinct(combined_results$ElectionDate))
  message("  Races: ", n_distinct(combined_results$Race))
  message("Turnout data:")
  message("  Total rows: ", format(nrow(combined_turnout), big.mark = ","))
  message("  Elections: ", n_distinct(combined_turnout$ElectionDate))
  message("  Date range: ", min(combined_turnout$ElectionDate), " to ", max(combined_turnout$ElectionDate))
  message("========================================")

  return(list(
    results = combined_results,
    turnout = combined_turnout
  ))
}

# ============================================
# Example usage
# ============================================

if (FALSE) {  # Set to TRUE to run

  # Process single election
  result_2023 <- process_election_file(
    excel_path = "data-raw/elections/election_general_2023_framingham_raw_unofficial.xlsx",
    election_date = "2023-11-07",
    election_type = "general",
    election_level = "municipal",
    use_llm = TRUE
  )

  View(result_2023$results)
  View(result_2023$turnout)

  # Process all elections
  all_elections <- process_all_elections_batch(use_llm = TRUE)

  # Save combined file
  arrow::write_parquet(all_elections$results, "data/elections/all_results_2016_2025.parquet")
  arrow::write_parquet(all_elections$turnout, "data/elections/all_turnout_2016_2025.parquet")
}
