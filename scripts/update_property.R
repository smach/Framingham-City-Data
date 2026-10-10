# update_property.R -------------------------------------------------------------
# Download the latest MassGIS parcels + assessor table for Framingham and
# write data/property/assessments_fy<YEAR>.csv and parcels_fy<YEAR>.gpkg.
#   Rscript scripts/update_property.R
# Run it about once a year (MassGIS updates each town roughly yearly).

source(here::here("R/load.R"))
zip <- fetch_massgis_parcels()
build_property_files(zip)
