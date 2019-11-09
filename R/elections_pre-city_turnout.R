# Get turnout info for get_turnouts.R

source("R/config.R")
source("R/election_helpers.R")

turnout <- readxl::read_xlsx("data-raw/elections/pre-city/OfficialResultsLocal2016.xlsx", range = "A675:S677")

names(turnout) <- precinct_col_names
turnout_tidy <- turnout %>%
  tidyr::pivot_longer(-Category, names_to = "Precinct", values_to = "Value")

turnout_for_data <- turnout_tidy %>%
  tidyr::pivot_wider(names_from = Category, values_from = Value) %>%
  mutate(
    Turnout = `Total Voter Turnout` / `Total Registered Voters`,
    Election = "General",
    Year = 2016
  )

rio::export(turnout_for_data, file = "data/elections/2016_general_turnout_framingham.csv")
