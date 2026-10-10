# census.R ----------------------------------------------------------------------
# Census data for Framingham.
#
#   framingham_block_groups()  2020 block groups that are inside Framingham,
#                              using the Census boundary file already in
#                              data/gis/ (no internet needed)
#   fetch_acs_framingham()     American Community Survey estimates for the
#                              whole city and for each block group, via the
#                              tidycensus package
#
# tidycensus needs a free Census API key: get one at
# https://api.census.gov/data/key_signup.html, then run once:
#   tidycensus::census_api_key("YOUR KEY", install = TRUE)

#' Default ACS variables: a small, commonly used starter set. Add your own;
#' look them up with tidycensus::load_variables(2023, "acs5").
acs_starter_variables <- c(
  total_population      = "B01003_001",
  median_household_inc  = "B19013_001",
  median_age            = "B01002_001",
  housing_units         = "B25001_001",
  renter_occupied       = "B25003_003",
  owner_occupied        = "B25003_002",
  foreign_born          = "B05002_013",
  hispanic_or_latino    = "B03003_003",
  speak_only_english    = "C16001_002",
  # Bachelor's degree only, age 25+; graduate degrees are B15003_023 to _025
  bachelors_degree_25plus = "B15003_022"
)

#' 2020 Census block groups inside Framingham
#'
#' A block group counts as "inside" when most of its area is in the city
#' (block groups follow city lines, so this is just to ignore edge slivers).
#' @return An sf object with GEOID and geometry (WGS84).
framingham_block_groups <- function() {
  zip <- proj_path("data", "gis", "cb_2020_25_bg_500k.zip")
  bg <- sf::read_sf(paste0("/vsizip/", zip, "/cb_2020_25_bg_500k.shp"))
  bg <- sf::st_transform(bg[bg$COUNTYFP == "017", ], 26986)   # Middlesex County; MA state plane (meters)
  city <- sf::st_union(sf::st_transform(precinct_shapes("2023-11-07"), 26986))
  inside <- suppressWarnings(sf::st_intersection(bg, city))
  share <- as.numeric(sf::st_area(inside)) /
    as.numeric(sf::st_area(bg[match(inside$GEOID, bg$GEOID), ]))
  keep <- inside$GEOID[share > 0.5]
  sf::st_transform(bg[bg$GEOID %in% keep, c("GEOID", "NAMELSAD")], 4326)
}

#' Download ACS 5-year estimates for Framingham
#'
#' Writes data/census/acs5_<year>_framingham_city.csv and
#' acs5_<year>_framingham_block_groups.csv. Each has estimate and margin of
#' error (moe) columns.
#'
#' @param year Last year of the 5-year ACS period, e.g. 2023 for 2019-2023.
fetch_acs_framingham <- function(year, variables = acs_starter_variables,
                                 out_dir = proj_path("data", "census")) {
  city <- tidycensus::get_acs(geography = "county subdivision", state = "MA", county = "Middlesex",
                              variables = variables, year = year, survey = "acs5", output = "wide")
  city <- city[grepl("^Framingham", city$NAME), ]
  write_csv_stable(city, file.path(out_dir, sprintf("acs5_%d_framingham_city.csv", year)))

  bgs <- tidycensus::get_acs(geography = "block group", state = "MA", county = "Middlesex",
                             variables = variables, year = year, survey = "acs5", output = "wide")
  bgs <- bgs[bgs$GEOID %in% framingham_block_groups()$GEOID, ]
  write_csv_stable(bgs, file.path(out_dir, sprintf("acs5_%d_framingham_block_groups.csv", year)))
  invisible(list(city = city, block_groups = bgs))
}
