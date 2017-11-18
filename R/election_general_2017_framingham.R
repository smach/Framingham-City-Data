source("R/election_helpers.R")

working_directory <- getwd()
datafile <- paste0(working_directory, "/data-raw/elections/election_general_2017_framingham.xlsx")

mayor <- readxl::read_xlsx(datafile, range = "A6:S9", col_names = election_wide_column_names)

mayor_tidy <- tidy_results(mayor) %>%
  add_cols_to_tidy_dataframe("Mayor", "General")

mayor$Totals <- apply(mayor[,-1], 1, sum)

atlarge <- readxl::read_xlsx(datafile, range = "A11:S16", col_names = election_wide_column_names)

atlarge_tidy <- tidy_results(atlarge) %>%
  add_cols_to_tidy_dataframe("AtLarge", "General")

atlarge$Totals <- apply(atlarge[,-1], 1, sum)

district_council <- readxl::read_xlsx(datafile, range = "A17:S64", col_names = election_wide_column_names)

district_council_tidy <- tidy_results(district_council) %>% 
  mutate(Votes = as.integer(Votes)) %>%
  filter(complete.cases(.)) %>%
  mutate(
    District = get_district(Precinct),
    Race = paste0("District ", District, " City Council"),
    Year = "2017",
    Election = "General",
    District = NULL
  ) %>%
  arrange(Race)

school_committee <- readxl::read_excel(datafile, range = "A66:S105", col_names = election_wide_column_names)

school_committee_tidy <- tidy_results(school_committee) %>% 
  mutate(Votes = as.integer(Votes)) %>%
  filter(complete.cases(.)) %>%
  mutate(
    District = get_district(Precinct),
    Race = paste0("District ", District, " School Commitee"),
    Year = "2017",
    Election = "General",
    District = NULL
  ) %>%
  arrange(Race)

turnout <- readxl::read_excel(datafile, range = "A110:S111", col_names = election_wide_column_names)
turnout_tidy <- tidy_results(turnout)
turnout_tidy <- dcast(turnout_tidy, Precinct ~ Candidate) %>%
  mutate(
    District = get_district(Precinct)
  )


