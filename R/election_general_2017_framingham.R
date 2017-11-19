source("R/config.R")
source("R/election_helpers.R")

working_directory <- getwd()
datafile <- paste0(working_directory, "/data-raw/elections/election_general_2017_framingham_raw.xlsx")

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

turnout_by_precinct <- turnout_tidy %>%
  select(Precinct, `Total Voter Turnout`, `Total Registered Voters`) %>%
  mutate(
    Turnout = round(`Total Voter Turnout` / `Total Registered Voters`, 3) * 100,
    Election = "General",
    Year = 2017
  ) %>%
  janitor::clean_names()


rio::export(turnout_by_precinct, file = "data/elections/turnout_election_general_2017_framingham.csv")

turnout_by_district <- turnout_tidy %>%
 janitor::clean_names() %>%
  select(district, total_voter_turnout, total_registered_voters) %>%
  group_by(district) %>%
  summarize(
    total_voter_turnout = sum(total_voter_turnout),
    total_registered_voters = sum(total_registered_voters),
    Turnout = round(total_voter_turnout / total_registered_voters, 3) * 100,
    Election = "General",
    Year = 2017
  )

rio::export(turnout_by_district, file = "data/elections/turnout_bydistrict_election_general_2017_framingham.csv")

election_general_2017_framingham_tidy <- bind_rows(mayor_tidy, atlarge_tidy, district_council_tidy, school_committee_tidy)

rio::export(election_general_2017_framingham_tidy, file = "data/elections/election_general_2017_framingham_tidy.csv")

election_bydistrict_general_2017_framingham_tidy <- election_general_2017_framingham_tidy %>%
  mutate(
    District = get_district(Precinct)
  ) %>%
  group_by(Race, Candidate, District, Year, Election) %>%
  summarize(
    Votes = sum(Votes, na.rm = TRUE)
  ) %>%
  select(Candidate, District, Votes, Race, Year, Election)

rio::export(election_bydistrict_general_2017_framingham_tidy, file = "data/elections/election_bydistrict_general_2017_framingham_tidy.csv")

mayor_summary <- mayor_tidy %>%
  select(Precinct, Candidate, Votes) %>%
  dcast(Precinct ~ Candidate, value.var = "Votes") %>%
  janitor::adorn_totals() %>%
  mutate(
    TotalVotesCast = `John A. Stefanini` + `Yvonne M. Spicer` + `Write-Ins`,
    SpicerPercent = round((`Yvonne M. Spicer` / TotalVotesCast) * 100, 1),
    StefaniniPercent = round((`John A. Stefanini` / TotalVotesCast) * 100, 1)
  )
  

mayor_summary_by_district <- mayor_summary %>%
  mutate(
    District = get_district(Precinct)
   ) %>%
  group_by(District) %>%
  summarize(
    Spicer = sum(`Yvonne M. Spicer`),
    Stefanini = sum(`John A. Stefanini`),
    TotalVotesCast = sum(TotalVotesCast),
    SpicerPct = round((Spicer / TotalVotesCast) * 100, 1),
    StefaniniPct = round((Stefanini / TotalVotesCast) * 100, 1)
  )
mayor_summary_by_district[10,1] <- "Total"

rio::export(mayor_summary, file = "data/elections/mayor_election_general_2017_framingham.csv")
rio::export(mayor_summary_by_district, file = "data/elections/mayor_bydistrict_election_general_2017_framingham.csv")

atlarge_summary <- atlarge_tidy %>%
  select(Precinct, Candidate, Votes) %>%
  dcast(Precinct ~ Candidate, value.var = "Votes") %>%
  janitor::adorn_totals() %>%
  select(Precinct, TullyStoll = `Cheryl Tully Stoll`, King = `George P. King, Jr.`,
         Long = `Christine A. Long`, Maia = `Pablo Maia`, WriteIns = `Write-Ins`) %>%
  mutate(
    TotalVotesCast = TullyStoll + King + Long + Maia + WriteIns,
    TullyStollPercent = round((TullyStoll / TotalVotesCast) * 100, 1),
    KingPercent = round((King / TotalVotesCast) * 100, 1),
    LongPercent = round((Long / TotalVotesCast) * 100, 1),
    MaiaPercent = round((Maia / TotalVotesCast) * 100, 1)
  )

atlarge_summary_by_district <- atlarge_summary %>%
  mutate(
    District = get_district(Precinct)
  ) %>%
  group_by(District) %>%
  summarize(
    TullyStoll = sum(TullyStoll),
    King = sum(King),
    Long = sum(Long),
    Maia = sum(Maia),
    TotalVotesCast = sum(TotalVotesCast)
  )
atlarge_summary_by_district[10,1] <- "Total" 

rio::export(atlarge_summary, file = "data/elections/atlarge_election_general_2017_framingham.csv")
rio::export(atlarge_summary_by_district, file = "data/elections/atlarge_bydistrict_election_general_2017_framingham.csv")

district_council_by_district_tidy <- district_council_tidy %>%
  mutate(
    District = get_district(Precinct)
  ) %>%
  group_by(Race, Candidate) %>%
    summarize(
      Votes = sum(Votes)
    ) %>%
  arrange(Race, desc(Votes))

rio::export(district_council_by_district_tidy, file = "data/elections/district_council_bydistrict_tidy_election_general_2017_framingham.csv")

school_committee_by_district_tidy <- school_committee_tidy %>%
  mutate(
    District = get_district(Precinct)
  ) %>%
  group_by(Race, Candidate) %>%
  summarize(
    Votes = sum(Votes)
  ) %>%
  arrange(Race, desc(Votes))

rio::export(school_committee_by_district_tidy, file = "data/elections/school_committee_bydistrict_tidy_election_general_2017_framingham.csv")
