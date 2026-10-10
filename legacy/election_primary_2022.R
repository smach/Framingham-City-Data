# Wrangle 2022 Primary data from City Clerk unofficial data
pacman::p_load(dplyr, tidyr, readxl, stringr)



raw_data <- readxl::read_xlsx("data-raw/elections/State_Primary_Election_Unofficial_Results_Sept_6_2022_2.xlsx") |>
  filter(!is.na(Candidate))

not_all_na <- function(x) any(!is.na(x))

sixth_middlesex_dem_tidy <- raw_data |>
  slice(51:55) |>
  select(where(not_all_na)) |>
  mutate(`9B` = as.numeric(`9B`),
         Total = as.numeric(Total)
         ) |>
  pivot_longer(cols = 2:18, names_to = "Precinct", values_to = "Votes")

sixth_middlesex_dem_wide <- sixth_middlesex_dem_tidy |>
  pivot_wider(names_from = "Candidate", values_from = "Votes")

sixth_middlesex_dem_tidy <- sixth_middlesex_dem_tidy |>
  filter(Precinct != "Total") |>
  mutate(
    Race = "6th Middlesex House",
    Year = 2022,
    Election = "Democratic Primary"
  )

rio::export(sixth_middlesex_dem_tidy, "data/elections/tidy/2022_6th_middlesex_democratic_primary.csv")

turnout_tidy <- raw_data |>
  slice(130:133) |>
  select(1:31) |>
  mutate(across(.cols = -Candidate, ~ as.numeric(.x, na.rm = TRUE))) |>
  pivot_longer(2:31, names_to = "Precinct", values_to = "Voters") |>
  rename(Category = Candidate)

turnout_wide <- turnout_tidy |>
  filter(str_detect(Category, "Total")) |>
  pivot_wider(names_from = "Category", values_from = "Voters") |>
  mutate(
    Turnout = round(`Total Turnout` / `Total Registered`, 3),
    Election = "State Primary",
    Year = 2020
  ) |>
  rename(
    `Total Voter Turnout` = `Total Turnout`,
    `Total Registered Voters` = `Total Registered`
  )

rio::export(turnout_wide, "data/elections/2022_state_primary_turnout.csv")


  