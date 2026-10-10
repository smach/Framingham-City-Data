framingham_precincts_as_factor <- factor(as.character(1:18), levels = as.character(1:18), ordered = TRUE)

framingham_districts_as_factor <- factor(as.character(1:9), levels = as.character(1:9), ordered = TRUE)

framingham_precincts_as_character <- as.character(1:18)

framingham_districts_as_character <- as.character(1:9)

election_wide_column_names <- c("Candidate", framingham_precincts_as_character)

# This function turns a spreadsheet of election results in typical Town-Clerk-provided format into a basic tidy data frame.
tidy_results <- function(thedf){
  tidydf <- reshape2::melt(thedf, id.vars = "Candidate", variable.name = "Precinct", value.name = "Votes")
  
}

# This function adds columns for race (such as "Mayor" or "AtLarge"), election (such as "General" or "Preliminary") and year to a tidy election frame.
add_cols_to_tidy_dataframe <- function(thedf, therace, theelection, theyear = "2017"){
  possible_elections <- c("Preliminary", "General", "Charter", "Special")
  if(!theelection %in% possible_elections){
    warning("therace must be either Preliminary, General, Special, or Charter")
    stop()
  } else {
    newdf <- thedf %>%
      mutate(
        Race = therace,
        Year = theyear,
        Election = theelection
      )
    return(newdf)
  }
}

# This code creates a district lookup for a precinct.



get_district <- function(precinct, district_info_file = "data/district_precinct_info.csv"){

  district_info <- read.csv(district_info_file, colClasses = c("character", "character"), col.names = c("precinct", "district"))
  district_lookup_table <- district_info$district
  names(district_lookup_table) <- district_info$precinct
  thevec = district_lookup_table
  thedist <- unname(thevec[precinct])
  return(thedist)
  
}


# Turn numeric column names for Precincts into characters
precinct_col_names <- c("Category", as.character(1:18))
