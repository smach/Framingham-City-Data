source("R/config.R")
source("R/election_helpers.R")

working_directory <- getwd()
datafile <- paste0(working_directory, "/data-raw/elections/election_preliminary_2017_framingham_raw.xlsx")

mayor <- readxl::read_xlsx(datafile, range = "A6:S14", col_names = election_wide_column_names)

mayor_tidy <- tidy_results(mayor) %>%
  add_cols_to_tidy_dataframe("Mayor", "Preliminary")

mayor$Totals <- apply(mayor[,-1], 1, sum)

rio::export(mayor, file = "data/elections/2017_preliminary_mayor_framingham.csv")
rio::export(mayor_tidy, file = "data/elections/2017_preliminary_mayor_tidy_framingham.csv")

atlarge <- readxl::read_xlsx(datafile, range = "A16:S22", col_names = election_wide_column_names)

atlarge_tidy <- tidy_results(atlarge) %>%
  add_cols_to_tidy_dataframe("AtLarge", "Preliminary")

atlarge$Totals <- apply(atlarge[,-1], 1, sum)

rio::export(atlarge, file = "data/elections/2017_preliminary_atlarge_framingham.csv")
rio::export(atlarge_tidy, file = "data/elections/2017_preliminary_atlarge_framingham_tidy.csv")




district_council <- readxl::read_xlsx(datafile, range = "A24:S64", col_names = election_wide_column_names)

district_council_tidy <- tidy_results(district_council) %>% 
  mutate(Votes = as.integer(Votes)) %>%
  filter(complete.cases(.)) %>%
  mutate(
    District = get_district(Precinct),
    Race = paste0("District ", District, " City Council"),
    Year = "2017",
    Election = "Preliminary",
    District = NULL
  ) %>%
  arrange(Race)



turnout <- readxl::read_excel(datafile, range = "A65:S66", col_names = election_wide_column_names)
turnout_tidy <- tidy_results(turnout)
turnout_tidy <- dcast(turnout_tidy, Precinct ~ Candidate) %>%
  mutate(
    District = get_district(Precinct)
  )

turnout_by_precinct <- turnout_tidy %>%
  select(Precinct, `Total Voter Turnout`, `Total Registered Voters`) %>%
  mutate(
    Turnout = round(`Total Voter Turnout` / `Total Registered Voters`, 3) * 100,
    Election = "Preliminary",
    Year = 2017
  ) %>%
  janitor::clean_names()


rio::export(turnout_by_precinct, file = "data/elections/2017_preliminary_turnout_framingham.csv")

turnout_by_district <- turnout_tidy %>%
 janitor::clean_names() %>%
  select(district, total_voter_turnout, total_registered_voters) %>%
  group_by(district) %>%
  summarize(
    total_voter_turnout = sum(total_voter_turnout),
    total_registered_voters = sum(total_registered_voters),
    Turnout = round(total_voter_turnout / total_registered_voters, 3) * 100,
    Election = "Preliminary",
    Year = 2017
  )

rio::export(turnout_by_district, file = "data/elections/2017_preliminary_turnout_bydistrict_framingham.csv")

election_preliminary_2017_framingham_tidy <- bind_rows(mayor_tidy, atlarge_tidy, district_council_tidy)

rio::export(election_preliminary_2017_framingham_tidy, file = "data/elections/2017_preliminary_tidy_framingham.csv")

election_bydistrict_preliminary_2017_framingham_tidy <- election_preliminary_2017_framingham_tidy %>%
  mutate(
    District = get_district(Precinct)
  ) %>%
  group_by(Race, Candidate, District, Year, Election) %>%
  summarize(
    Votes = sum(Votes, na.rm = TRUE)
  ) %>%
  select(Candidate, District, Votes, Race, Year, Election)

rio::export(election_bydistrict_preliminary_2017_framingham_tidy, file = "data/elections/2017_preliminary_bydistrict_tidy_framingham.csv")


  


district_council_by_district_tidy <- district_council_tidy %>%
  mutate(
    District = get_district(Precinct)
  ) %>%
  group_by(Race, Candidate) %>%
    summarize(
      Votes = sum(Votes)
    ) %>%
  arrange(Race, desc(Votes))

rio::export(district_council_by_district_tidy, file = "data/elections/2017_preliminary_district_council_bydistrict_tidy_framingham.csv")

