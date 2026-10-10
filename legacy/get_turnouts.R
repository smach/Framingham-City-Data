# Combine all turnout data in all available election files with turnout by precinct
library(dplyr)
project_dir <- here::here()
setwd(project_dir)

turnout_data_files <- dir("data/elections", "turnout")

turnout_data_files <- turnout_data_files[!grepl("district", turnout_data_files)]
turnout_data_files <- turnout_data_files[!grepl("special", turnout_data_files)]
turnout_data_files <- turnout_data_files[turnout_data_files != "2021_general_turnout.csv"]

setwd("data/elections")

read_turnout_file <- function(myfilename){
  print(paste("Working on", myfilename))
  temp <- readr::read_csv(myfilename)
  temp <- janitor::clean_names(temp) 
  if("precinct" %in% names(temp)) {
    temp$precinct_or_district <- as.character(temp$precinct)
    temp <- temp |>
      dplyr::filter(precinct != "Total") |>
      dplyr::select(-precinct) |>
      dplyr::mutate(type = "Precinct")
  } else if("district" %in% names(temp)) {
    temp$precinct_or_district <- as.character(temp$district)
    temp <- temp |>
      dplyr::filter(district != "Total") |>
      dplyr::select(-district) |>
      dplyr::mutate(type = "District")
  }
  if("total_registered" %in% names(temp)) {
    temp <- dplyr::rename(temp, total_registered_voters = total_registered)
  }
  return(temp)
}


all_turnout_data <- purrr::map_df(turnout_data_files, read_turnout_file)

total_turnout_by_election <- all_turnout_data |>
  mutate(
    year = as.character(year)
  ) |>
  group_by(year, election) |>
  summarize(
    total_voted = sum(total_voter_turnout, na.rm = TRUE),
    total_registered = sum(total_registered_voters, na.rm = TRUE),
    turnout_pct = round((total_voted / total_registered) * 100, 1)
  ) |>
  ungroup() |>
  arrange(desc(year), election)



setwd(project_dir)
