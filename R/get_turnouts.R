# Combine all turnout data in all available election files with turnout by precinct

project_dir <- here::here()

turnout_data_files <- dir("data/elections", ".*_turnout_")

turnout_data_files <- turnout_data_files[!grepl("district", turnout_data_files)]

setwd("data/elections")

read_turnout_file <- function(myfilename){
  temp <- readr::read_csv(myfilename)
  temp <- janitor::clean_names(temp) 
  temp$precinct <- as.character(temp$precinct)
  temp <- temp %>%
    filter(precinct != "Total")
  return(temp)
}


all_turnout_data <- purrr::map_df(turnout_data_files, read_turnout_file)

setwd(project_dir)
