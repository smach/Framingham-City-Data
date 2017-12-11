library(reshape2)
library(dplyr)
chartervote <- readxl::read_xlsx("data-raw/elections/election_charter_2017_framingham_raw.xlsx", skip = 1)
names(chartervote)[1] <- "Metric"
chartervote_long <- melt(chartervote, variable.name = "Precinct") %>%
  filter(Precinct != "Total") %>%
  mutate(
    Election = "Charter",
    Year = "2017"
  )

charter_results <- chartervote_long %>%
  filter(Metric %in% c("Yes", "No", "Blanks")) %>%
  dcast(Precinct ~ Metric) %>%
  select(Precinct, Yes, No, Blanks) %>%
  janitor::adorn_totals("col") %>%
  mutate(
    YesPct = round(Yes / (Yes + No),3) * 100,
    NoPct = round(No / (Yes + No), 3) * 100,
    YesMargin = Yes - No
    
  )

charter_turnout <- melt(chartervote, variable.name = "Precinct") %>%
  filter(Metric %in% c("Total Voter Turnout", "Total Registered Voters", "Percentage")) %>%
  dcast(Precinct ~ Metric) %>%
  select(Precinct, `Total Voter Turnout`, `Total Registered Voters`, Turnout = Percentage) %>%
  mutate(
    Election = "Charter",
    Year = "2017"
  )

rio::export(charter_turnout, "data/elections/2017_charter_turnout_framingham.csv")
rio::export(charter_results, "data/elections/2017_charter_results_framingham.csv")
rio::export(chartervote_long, "data/elections/2017_charter_results_tidy_framingham.csv")
