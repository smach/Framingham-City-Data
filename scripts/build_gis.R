# build_gis.R -------------------------------------------------------------------
# Rebuild the tidy boundary files in data/gis/ (precincts by map, with city
# districts; state House districts within Framingham; 2020 block groups).
#   Rscript scripts/build_gis.R

source(here::here("R/load.R"))
build_gis()
sf::write_sf(framingham_block_groups(), proj_path("data", "gis", "framingham_block_groups_2020.geojson"),
             delete_dsn = TRUE)
