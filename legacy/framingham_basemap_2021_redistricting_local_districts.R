# Post-2021 redistricting map of precincts and local districts

if(!require(pacman)) {
  install.packages("pacman")
}
pacman::p_load(sf, leaflet, leaflet.extras, glue, htmltools, dplyr)

pctgeo_sf <- read_sf("data/gis/FramPrecincts/FRAMINGHAM_proposed_2020_precincts.shp")

pctgeo_sf <- st_transform(pctgeo_sf, 4326)

districts <- rio::import("data/gis/FramPrecincts/DistrictPrecincts2022.xlsx") |>
  mutate_all(as.character)

pctgeo_sf$Precinct <- as.character(pctgeo_sf$PRECINCT)

pctgeo_sf <- merge(pctgeo_sf, districts, by = "Precinct", all.x = TRUE, all.y = FALSE)

pctgeo_sf$Dist <- paste0("District ", pctgeo_sf$District)
pctgeo_sf$Pct <- paste0("Precinct ", pctgeo_sf$Precinct)


mycolors <- topo.colors(9)
mycolors[9] <- "coral3"
mycolors[8] <- "dodgerblue"
mycolors[7] <- "lightpink2"

mypalette <- colorFactor(mycolors, pctgeo_sf$Dist)
mylabels <- glue::glue("<strong>{pctgeo_sf$Pct}<br />{pctgeo_sf$Dist}") %>%
  lapply(htmltools::HTML)


mypopups <- mylabels



leaflet(pctgeo_sf) %>%
  setView(-71.4366, 42.3011, 13) %>%
  addProviderTiles(providers$Esri.WorldStreetMap) %>%
  addPolygons(color = "#444444", 
              weight = 1, 
              smoothFactor = 0.5, 
              opacity = .7, 
              fillColor =  ~mypalette(Dist), 
              highlightOptions = highlightOptions(
                color = "black", 
                weight = 3, 
                bringToFront = TRUE),
              label = mylabels,
              labelOptions = labelOptions(
                style = list("font-weight" = "normal", padding = "3px 8px"),
                textsize = "15px",
                direction = "auto")) %>%
  addResetMapButton() %>%
  addSearchOSM(options = searchOptions(autoCollapse = TRUE, minLength = 2))




