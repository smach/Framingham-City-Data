# Extract Race Metadata Using ellmer
# This script uses LLMs to extract structured race information from election Excel files
# Works with any Framingham election from 2016-2025

library(ellmer)
library(dplyr)
library(stringr)

# ============================================
# Define structured types for LLM extraction
# ============================================

#' Structured type for race metadata extraction
type_race_metadata <- type_object(
  race_standardized = type_string(
    "Standardized race code. Examples:
    - 'mayor' for Mayor
    - 'council_at_large' for City Council At-Large
    - 'council_1' for District 1 City Council
    - 'council_2' for District 2 City Council
    - 'sc_1' for District 1 School Committee
    - 'sc_at_large' for School Committee At-Large
    - 'library_1' for District 1 Library Trustee
    - 'president_d' for President (Democratic Primary)
    - 'president_r' for President (Republican Primary)
    - 'us_senate_d' for US Senate (Democratic Primary)
    - 'state_rep' for State Representative
    - 'governor' for Governor
    - 'ballot_question_1', 'ballot_question_2' for ballot questions
    - 'charter' for charter questions
    Use lowercase, underscores, append district number if applicable."
  ),
  race_display_name = type_string(
    "Clean display name for the race. Example: 'District 2 City Council' or 'Mayor' or 'Ballot Question 1'"
  ),
  num_winners = type_integer(
    "Number of winners for this race. Extract from text like 'Vote for not more than 3' or 'Vote for 2'.
    If not specified, return 1 for single-winner races like Mayor.
    For at-large races with multiple winners, extract the number."
  ),
  district = type_string(
    "District number if this is a district race (e.g., '1', '2', '3'), otherwise NULL.
    For at-large races, return 'at_large'.
    For citywide races like Mayor, return NULL."
  ),
  office_level = type_string(
    "Level of office: 'municipal', 'state', or 'federal'"
  ),
  is_primary = type_boolean(
    "TRUE if this is a primary election race (Democratic, Republican, etc.), FALSE otherwise"
  ),
  party = type_string(
    "Party affiliation if primary ('democratic', 'republican', 'libertarian'), otherwise NULL"
  )
)

#' Extract race metadata from office names using LLM
#'
#' @param office_names Character vector of office/race names from Excel file
#' @param chat ellmer chat object (defaults to GPT-4)
#' @param max_active Number of parallel requests
#' @return Data frame with structured race metadata
#'
#' @examples
#' office_names <- c(
#'   "Mayor (Vote for not more than 1)",
#'   "District 2 City Councilor (Vote for not more than 1)",
#'   "City Council At-Large (Vote for not more than 3)",
#'   "District 5 School Committee (Vote for 1)",
#'   "Question 1: Charter Amendment - City Council Districts"
#' )
#' metadata <- extract_race_metadata(office_names)
extract_race_metadata <- function(office_names,
                                   chat = NULL,
                                   max_active = 4) {

  if (is.null(chat)) {
    chat <- chat_openai(model = "gpt-4o-mini")  # Cheaper model is fine for this
  }

  # Remove duplicates for efficiency
  unique_offices <- unique(office_names)

  # Create prompts
  prompts <- interpolate(
    "Extract structured information about this election race/office:

    Race name: {{ unique_offices }}

    Provide:
    1. A standardized code name (e.g., 'mayor', 'council_2', 'sc_at_large')
    2. A clean display name
    3. Number of winners (from 'Vote for X' text, or 1 if not specified)
    4. District number if applicable (or 'at_large' for at-large races, or NULL for citywide)
    5. Office level: municipal, state, or federal
    6. Whether this is a primary election race
    7. Party if it's a primary (democratic, republican, etc.)
    "
  )

  # Extract metadata in parallel
  message("Extracting race metadata for ", length(unique_offices), " unique races...")

  metadata_list <- parallel_chat_structured(
    chat = chat,
    prompts = prompts,
    max_active = max_active,
    rpm = 100,
    type = type_race_metadata
  )

  # Convert to data frame
  metadata_df <- tibble(
    office_original = unique_offices
  ) %>%
    bind_cols(bind_rows(metadata_list))

  # Join back to original (including duplicates)
  result <- tibble(office_original = office_names) %>%
    left_join(metadata_df, by = "office_original")

  return(result)
}

#' Extract candidate last names (your existing approach)
#'
#' @param candidate_names Character vector of full candidate names
#' @param chat ellmer chat object
#' @param max_active Number of parallel requests
#' @return Data frame with extracted last names
extract_candidate_names <- function(candidate_names,
                                     chat = NULL,
                                     max_active = 4) {

  if (is.null(chat)) {
    chat <- chat_openai(model = "gpt-4o-mini")
  }

  type_candidate <- type_object(
    candidate_last_name = type_string(
      "Extracted last name from a candidate. If the text appears to be a ballot question
      and not a name, return the entire text."
    )
  )

  prompts <- interpolate(
    "Extract the person's last name from the text below.
    If the text appears to be a ballot question and not a name, return the entire text.

    Candidate: {{ candidate_names }}
    "
  )

  message("Extracting candidate names for ", length(candidate_names), " candidates...")

  names_list <- parallel_chat_structured(
    chat = chat,
    prompts = prompts,
    max_active = max_active,
    rpm = 100,
    type = type_candidate
  )

  tibble(
    candidate_full_name = candidate_names
  ) %>%
    bind_cols(bind_rows(names_list))
}

# ============================================
# Helper function to validate extractions
# ============================================

#' Validate and fix common extraction issues
validate_race_metadata <- function(metadata) {
  metadata %>%
    mutate(
      # Fix common issues
      race_standardized = tolower(race_standardized),
      race_standardized = str_replace_all(race_standardized, " ", "_"),

      # Validate num_winners
      num_winners = case_when(
        is.na(num_winners) ~ 1L,
        num_winners < 1 ~ 1L,
        num_winners > 20 ~ 1L,  # Sanity check
        TRUE ~ num_winners
      ),

      # Clean party
      party = if_else(is_primary, tolower(party), NA_character_),

      # Ensure district is character or NA
      district = case_when(
        district == "NULL" ~ NA_character_,
        district == "at_large" ~ "at_large",
        TRUE ~ district
      )
    )
}

# ============================================
# Example usage
# ============================================

if (FALSE) {  # Set to TRUE to run examples

  # Test with sample office names
  test_offices <- c(
    "Mayor (Vote for not more than 1)",
    "District 2 City Councilor (Vote for not more than 1)",
    "City Council At-Large (Vote for not more than 3)",
    "District 5 School Committee (Vote for 1)",
    "Library Trustee At-Large (Vote for not more than 2)",
    "Question 1: Charter Amendment - City Council Districts",
    "President of the United States (Democratic Primary)",
    "State Representative 6th Middlesex District"
  )

  metadata <- extract_race_metadata(test_offices)
  print(metadata)

  # Test with sample candidate names
  test_candidates <- c(
    "Yvonne M. Spicer",
    "John A. Stefanini",
    "White-Harvey, Janet",
    "YES on Question 1",
    "NO on Question 1"
  )

  names_df <- extract_candidate_names(test_candidates)
  print(names_df)
}
