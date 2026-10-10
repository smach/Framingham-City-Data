if(!require(pacman)) {
  install.packages("pacman")
}

pacman::p_load(dplyr, readxl, tidyr, janitor)

raw19 <- readxl::read_xlsx("data-raw/elections/election_general_2019_framingham_raw.xlsx", skip = 4)

my_col_names <- c("Category", paste0("P", 1:18), "Total")
names(raw19) <- my_col_names

at_large <- raw19[1:5,] 

at_large_tidy <- at_large %>%
  select(-Total) %>%
  pivot_longer(P1:P18, names_to = "Precinct", values_to = "Votes")

at_large_tidy <- at_large_tidy %>%
  mutate(
    Precinct = as.numeric(stringr::str_replace_all(at_large_tidy$Precinct, "P", "")),
    Race = "AtLarge",
    Year = "2019",
    Election = "General"
  ) %>%
  rename(Candidate = Category)

at_large_general_by_precinct <- at_large_tidy %>%
  select(Candidate, Precinct, Votes) %>%
  pivot_wider(names_from = Candidate, values_from = Votes) 

at_large_by_precinct_with_winner <- at_large_tidy %>%
  dplyr::filter(Candidate != "Blanks" & Candidate != "Write-Ins") %>%
  group_by(Precinct) %>%
  mutate(
    Rank = rank(-Votes),
    Winner = Candidate[Rank == 1],
    Second = Candidate[Rank ==2]
  ) %>%
  select(Precinct, Candidate, Votes, Winner, Second) %>%
  pivot_wider(names_from = Candidate, values_from = Votes) %>%
  select(Precinct, King = `George P. King, Jr.`, Leombruno = `Janet Leombruno`, Pascual = `Gloria Pascual`, Winner, Second) %>%
  mutate(
    LeombrunoVsPascual = Leombruno - Pascual
  ) %>%
  janitor::adorn_totals()


fram_summary <- readxl::read_xlsx("data-raw/elections/election_general_2019_framingham_summaries.xlsx", skip = 1)
names(fram_summary) <- my_col_names

fram_summary_tidy <- fram_summary %>%
  select(-Total) %>%
  pivot_longer(P1:P18, names_to = "Precinct", values_to = "Value") %>%
  mutate(
    Precinct = as.numeric(stringr::str_replace(Precinct, "P", ""))
  ) %>%
  filter(Category != "Percentage")

fram_summary_general <- fram_summary_tidy %>%
  pivot_wider(names_from = Category, values_from = Value) %>%
  mutate(
    Percent = round(`Total Voter Turnout` / `Total Registered Voters`, 3)
  )
 
# rio::export(fram_summary_general, file = "../../../../www/district2/data/2019_election_turnout_summary.xlsx", overwrite = TRUE )

fram_turnout <- fram_summary_tidy %>%
  pivot_wider(names_from = Category, values_from = Value) %>%
  mutate(
    Turnout = `Total Voter Turnout` / `Total Registered Voters`,
    Election = "General",
    Year = 2019
  )

rio::export(fram_turnout, file = "data/elections/2019_general_turnout_framingham.csv")
