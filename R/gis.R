# gis.R -------------------------------------------------------------------------
# Precinct and district boundaries, in analysis-friendly form.
#
# The original shapefiles (as downloaded or emailed) stay in data/gis/ and
# data-raw/. build_gis() turns them into tidy, Framingham-only layers:
#
#   data/gis/framingham_precincts.gpkg      one layer per precinct map
#     layer "precincts_2012_2021"  18 precincts, used through Jan 2022
#     layer "precincts_2022"       27 precincts, used since Sept 2022
#     Columns: precinct, city_district, map_name. CRS is WGS84 (EPSG:4326),
#     the usual one for web maps.
#   data/gis/framingham_precincts_<map>.geojson   the same, as GeoJSON
#   data/gis/ma_house_districts_2022_framingham.geojson
#     the parts of the four state House districts that fall in Framingham
#
# A GeoPackage (.gpkg) is one modern file instead of a shapefile's 5-8 files.
# In R: sf::read_sf("data/gis/framingham_precincts.gpkg", layer = "precincts_2022")

#' Read a precinct shapefile and give it standard columns
read_precinct_shapes <- function(path, map_name, election_date) {
  x <- sf::read_sf(path)
  names(x) <- tolower(names(x))
  # Precinct IDs are "P6" in the old file and 6 in the new one
  x$precinct <- sub("^P", "", as.character(x$precinct))
  x$city_district <- get_district(x$precinct, election_date)
  x$map_name <- map_name
  x <- sf::st_transform(x[, c("precinct", "city_district", "map_name")], 4326)
  x[order(as.integer(x$precinct)), ]
}

#' Rebuild the tidy GIS layers in data/gis/ from the original files
build_gis <- function(out_dir = proj_path("data", "gis")) {
  gpkg <- file.path(out_dir, "framingham_precincts.gpkg")
  if (file.exists(gpkg)) file.remove(gpkg)

  old <- read_precinct_shapes(proj_path("data", "gis", "FramPrecinctsPre2021Redistricting", "FramPrecincts.shp"),
                              "2012-2021 precincts", "2021-11-02")
  new <- read_precinct_shapes(proj_path("data", "gis", "FramPrecincts", "FRAMINGHAM_proposed_2020_precincts.shp"),
                              "2022 precincts", "2023-11-07")
  sf::write_sf(old, gpkg, layer = "precincts_2012_2021")
  sf::write_sf(new, gpkg, layer = "precincts_2022", append = TRUE)
  for (layer in list(list(old, "2012_2021"), list(new, "2022"))) {
    f <- file.path(out_dir, paste0("framingham_precincts_", layer[[2]], ".geojson"))
    if (file.exists(f)) file.remove(f)
    sf::write_sf(layer[[1]], f)
  }

  # State House districts: the statewide 2021 plan is ~16 MB; keep only the
  # parts inside Framingham
  house <- sf::read_sf(paste0("/vsizip/", proj_path("data", "gis", "ShapefilesFullMAHouse-2021.zip"),
                              "/ShapefilesHouse-2021/Final House Plan Shapefile.shp"))
  house <- house[!is.na(house$NAME), c("DISTRICT", "NAME")]
  house <- sf::st_transform(house, 4326)
  framingham <- sf::st_union(sf::st_make_valid(new))
  suppressMessages(sf::sf_use_s2(FALSE))   # planar geometry avoids spurious slivers at this scale
  on.exit(suppressMessages(sf::sf_use_s2(TRUE)), add = TRUE)
  in_fram <- suppressMessages(suppressWarnings(sf::st_intersection(sf::st_make_valid(house), framingham)))
  # Intersections can return mixed "geometry collections"; keep just the polygons
  in_fram <- sf::st_cast(sf::st_collection_extract(in_fram, "POLYGON"), "MULTIPOLYGON")
  in_fram <- stats::aggregate(in_fram[, "geometry"], by = list(DISTRICT = in_fram$DISTRICT, NAME = in_fram$NAME),
                              FUN = function(x) x[1])
  # Drop tiny slivers where district lines and the town line nearly touch
  area <- as.numeric(sf::st_area(sf::st_transform(in_fram, 26986)))
  in_fram <- in_fram[area > 10000, ]
  names(in_fram)[1:2] <- c("house_district_code", "house_district")
  f <- file.path(out_dir, "ma_house_districts_2022_framingham.geojson")
  if (file.exists(f)) file.remove(f)
  sf::write_sf(in_fram, f)
  invisible(list(precincts_2012_2021 = old, precincts_2022 = new, house = in_fram))
}

#' Precinct boundaries in use on an election date
#'
#' @examples
#' p <- precinct_shapes("2023-11-07")
#' plot(p["city_district"])
precinct_shapes <- function(election_date, gpkg = proj_path("data", "gis", "framingham_precincts.gpkg")) {
  layer <- if (as.Date(election_date) < as.Date("2022-03-01")) "precincts_2012_2021" else "precincts_2022"
  sf::read_sf(gpkg, layer = layer)
}

#' Interactive map of precincts colored by city council district
#'
#' Replaces the three near-identical framingham_basemap_*.R scripts. Needs the
#' leaflet and leaflet.extras packages.
#'
#' @param election_date Which precinct map to show ("2021-11-02" for the old
#'   18 precincts, anything from 2022 on for the new 27).
#' @param show_house_districts Add the state House district outlines (2022 map only).
#' @examples
#' \dontrun{
#' make_precinct_map("2023-11-07", show_house_districts = TRUE)
#' }
make_precinct_map <- function(election_date = Sys.Date(), show_house_districts = FALSE) {
  p <- precinct_shapes(election_date)
  p$label <- sprintf("<strong>Precinct %s</strong><br/>District %s", p$precinct, p$city_district)
  pal <- leaflet::colorFactor("Set1", p$city_district)

  m <- leaflet::leaflet(p) |>
    leaflet::addProviderTiles("Esri.WorldStreetMap") |>
    leaflet::addPolygons(
      color = "#444444", weight = 1, opacity = 0.7, fillOpacity = 0.5,
      fillColor = ~pal(city_district),
      label = lapply(p$label, htmltools::HTML),
      highlightOptions = leaflet::highlightOptions(color = "black", weight = 3, bringToFront = TRUE),
      group = "Precincts"
    )
  if (show_house_districts) {
    h <- sf::read_sf(proj_path("data", "gis", "ma_house_districts_2022_framingham.geojson"))
    m <- m |> leaflet::addPolylines(data = h, color = "black", weight = 3, dashArray = "6",
                                    label = ~house_district, group = "State House districts") |>
      leaflet::addLayersControl(overlayGroups = c("Precincts", "State House districts"))
  }
  if (requireNamespace("leaflet.extras", quietly = TRUE)) {
    # Search by address, and a button to reset the view
    m <- m |> leaflet.extras::addResetMapButton() |>
      leaflet.extras::addSearchOSM(options = leaflet.extras::searchOptions(autoCollapse = TRUE, minLength = 2))
  }
  m
}
