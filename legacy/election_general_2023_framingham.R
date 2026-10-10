# Wrangle 2023 general election data from City Clerk unofficial data
pacman::p_load(dplyr, tidyr, readxl, stringr)


# Read in original format and filter out any all-blank rows
raw_data <- readxl::read_xlsx("data-raw/elections/election_general_2023_framingham_raw_unofficial.xlsx") |>
  filter(!is.na(Candidate))

# Identify which rows are headers and not candidate results
data <- raw_data |>
  mutate(
    row_category = ifelse(is.na(Total), "Race", "Candidate")
  ) |>
  select(1, row_category, everything()) 

for (i in 3:ncol(data)) {
  data[[i]] <- as.numeric(data[[i]])
  
}
  
data <- data |>
  pivot_longer(cols = 3:ncol(data), names_to = "Precinct") |>
  filter(row_category == "Candidate" | Precinct == "1") |>
  mutate(
    Precinct = ifelse(row_category == "Race", NA, Precinct)
  ) |>
  filter(Candidate != "Blanks") |>
  filter(Candidate != "Write Ins") |>
  filter(!(row_category == "Candidate" & is.na(value)))


data$Race <- ""
for(i in 1:nrow(data)) {
  if(data$row_category[i] == "Race") {
    data$Race[i] <- data$Candidate[i]
  } else {
    data$Race[i] <- data$Race[i - 1]
  }
}


data <- data |>
  filter(
    row_category != "Race"
  )
data$row_category <- NULL 


# Tidy data frame should have columns
# Candidate, Precinct, Votes, Race, Year, Election



data_tidy  <- data |>
  select(Candidate, Precinct, Votes = value, Race) |>
  mutate(
    Year = "2023",
    Election = "General",
    Race = trimws(stringr::str_replace_all(Race, "^(.*?)\\(.*?$", "\\1"))
  )

rio::export(data_tidy, "data/elections/tidy/2023_framingham_general.csv")

d8_wide <- data_tidy |>
  filter(Race == "District 8 City Councilor") |>
  filter(Precinct != "Total") |>
  pivot_wider(names_from = Precinct, values_from = Votes) |>
  select(-Year, -Election, -Race)

d2_wide <- data_tidy |>
  filter(Race == "District 2 City Councilor") |>
  filter(Precinct != "Total") |>
  pivot_wider(names_from = Precinct, values_from = Votes) |>
  select(-Year, -Election, -Race)

library_wide <- data_tidy |>
  filter(Race == "Library Trustee") |>
  filter(Precinct != "Total") |>
  pivot_wider(names_from = Precinct, values_from = Votes) |>
  select(-Year, -Election, -Race)



rio::export(d2_wide, "data/elections/2023_framingham_district2_city_council_general.csv")
rio::export(d8_wide, "data/elections/2023_framingham_district8_city_council_general.csv")
rio::export(library_wide, "data/elections/2023_framingham_library_trustees_general.csv")

turnout <- raw_data |>
  filter(Candidate %in% c("Total Turnout", "Total Registered"))

for (i in 2:ncol(turnout)) {
  turnout[[i]] <- as.numeric(turnout[[i]])
  
}
  
turnout <- turnout |>
  pivot_longer(cols = !Candidate, names_to = "precinct" ) |>
  pivot_wider(names_from = Candidate) |>
  rename(total_voter_turnout = `Total Turnout`, total_registered = `Total Registered`) |>
  mutate(
    turnout = total_voter_turnout / total_registered,
    election = "General",
    year = "2023"
  )

rio::export(turnout, "data/elections/2023_general_turnout.csv")
  