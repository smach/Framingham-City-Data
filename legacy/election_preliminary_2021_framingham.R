# Generate tidy data file

source("R/config.R")
source("R/election_helpers.R")
library(dplyr)
library(tidyr)

working_directory <- getwd()
datafile <- "data-raw/elections/election_preliminary_2021_mayor_framingham.csv"
mayor <- readr::read_csv(datafile) %>%
  filter(!is.na(Candidate))

mayor_tidy <- tidy_results(mayor) %>%
  add_cols_to_tidy_dataframe("Mayor", "Preliminary", theyear = "2021")  

rio::export(mayor_tidy, file = "data/elections/2021_preliminary_mayor_tidy_framingham.csv")

# Working turnout

turnout <- readxl::read_excel("data-raw/elections/Official Results September 14, 2021.xlsx", range = "A16:S17", col_names = c("Category", as.character(1:18)))
turnout_tidy <- turnout %>%
  tidyr::pivot_longer(2:19)

turnout_tidy <- turnout_tidy %>%
  tidyr::pivot_wider(names_from = Category, values_from = value) %>%
  dplyr::rename(Precinct = name) %>%
  janitor::adorn_totals() %>%
  mutate(
    Turnout = round(`Total Voter Turnout` / `Total Registered Voters`, 2),
    Election = "Preliminary",
    Year = "2021"
  )
  


turnout_by_precinct <- turnout_tidy %>%
  select(Precinct, `Total Voter Turnout`, `Total Registered Voters`) %>%
  mutate(
    Turnout = round(`Total Voter Turnout` / `Total Registered Voters`, 3) * 100,
    Election = "Preliminary",
    Year = "2021"
  ) %>%
  janitor::clean_names()


rio::export(turnout_by_precinct, file = "data/elections/2021_preliminary_turnout_framingham.csv")

turnout_by_district <- turnout_tidy %>%
  janitor::clean_names() %>%
  mutate(
    district = get_district(precinct)
  ) %>%
  dplyr::select(district, total_voter_turnout, total_registered_voters) %>%
  dplyr::filter(!is.na(district)) %>%
  dplyr::group_by(district) %>%
  dplyr::summarize(
    total_voter_turnout = sum(total_voter_turnout, na.rm = TRUE),
    total_registered_voters = sum(total_registered_voters, na.rm = TRUE),
    Turnout = round(total_voter_turnout / total_registered_voters, 3) * 100,
    Election = "Preliminary",
    Year = 2021
  )

rio::export(mayor_tidy, "data/elections/tidy/2021_preliminary_mayor_tidy.csv")
rio::export(turnout_tidy, "data/elections/tidy/2021_preliminary_turnout_tidy.csv")
rio::export(turnout_by_district, "data/elections/2021_preliminary_turnout.csv")





