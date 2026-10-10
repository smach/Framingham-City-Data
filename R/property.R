# property.R --------------------------------------------------------------------
# Parcels and property assessments, from MassGIS.
#
# MassGIS publishes "Level 3 Standardized Assessors' Parcels" for every town:
# parcel boundaries plus a separate assessor table, refreshed when the town
# sends new data (roughly yearly). Framingham's town ID is 100.
#
#   fetch_massgis_parcels()  downloads the town's zip to data-raw/property/
#                            (the zip isn't committed -- see .gitignore)
#   build_property_files()   writes, from that zip:
#     data/property/assessments_fy<YEAR>.csv   one row per property: values,
#        use code, lot size, year built, units, owner, last sale date/price.
#        Join to parcels with LOC_ID.
#     data/property/parcels_fy<YEAR>.gpkg      parcel boundaries (LOC_ID etc.)
#
# MassGIS keeps only the LATEST snapshot for each town, so each run saves
# that year's file under its fiscal year instead of overwriting the last one.
# Over time this builds up a history. For earlier years, or for fields
# MassGIS doesn't include (bedrooms, condition, full sale history), you'd need
# a public records request to the Assessor's office.
#
# NOTE: the download address follows MassGIS's published pattern but hasn't
# been tested from this project yet. If it fails, download the Framingham
# zip by hand from MassGIS's "Property Tax Parcels" page and pass its path to
# build_property_files().

massgis_parcels_url <- function(town_id = 100, town = "Framingham") {
  sprintf("https://s3.us-east-1.amazonaws.com/download.massgis.digital.mass.gov/shapefiles/l3parcels/L3_SHP_M%03d_%s.zip",
          town_id, town)
}

#' Download Framingham's MassGIS parcel + assessor zip
#' @return The path of the downloaded zip.
fetch_massgis_parcels <- function(url = massgis_parcels_url(),
                                  dest_dir = proj_path("data-raw", "property")) {
  dir.create(dest_dir, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(dest_dir, basename(url))
  utils::download.file(url, dest, mode = "wb")
  dest
}

#' Write the assessments CSV and parcels GeoPackage from a MassGIS zip
#'
#' @param zip_path Path to the MassGIS L3 zip for Framingham.
#' @return The fiscal year of the data (invisibly).
build_property_files <- function(zip_path, out_dir = proj_path("data", "property")) {
  files <- utils::unzip(zip_path, list = TRUE)$Name
  assess_file <- grep("Assess.*\\.dbf$", files, value = TRUE, ignore.case = TRUE)[1]
  parcel_file <- grep("TaxPar.*\\.shp$", files, value = TRUE, ignore.case = TRUE)[1]
  if (is.na(assess_file) || is.na(parcel_file)) stop("Couldn't find the assessor table or parcel shapes in ", zip_path)

  # The assessor table is a .dbf (the attribute part of a shapefile)
  assess <- sf::st_drop_geometry(sf::read_sf(paste0("/vsizip/", zip_path, "/", assess_file)))
  # Fiscal year: from the FY column if present, else from the file name (..._FY25.dbf)
  fy <- if ("FY" %in% names(assess)) max(as.integer(assess$FY), na.rm = TRUE) else
    2000L + as.integer(sub(".*FY(\\d{2}).*", "\\1", assess_file))
  write_csv_stable(assess, file.path(out_dir, sprintf("assessments_fy%d.csv", fy)))

  parcels <- sf::read_sf(paste0("/vsizip/", zip_path, "/", parcel_file))
  parcels <- sf::st_transform(parcels, 4326)
  gpkg <- file.path(out_dir, sprintf("parcels_fy%d.gpkg", fy))
  if (file.exists(gpkg)) file.remove(gpkg)
  sf::write_sf(parcels, gpkg)
  message("Wrote assessments and parcels for fiscal year ", fy)
  invisible(fy)
}
