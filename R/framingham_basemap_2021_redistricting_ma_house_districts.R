# Post-2021 redistricting map of precincts and MA house districts that include Framingham
# 6th Middlesex
# 7th Middlesex
# 4th Middlesex
# 19th Worcester
# Want both boundaries on same layer https://datacarpentry.org/r-raster-vector-geospatial/08-vector-plot-shapefiles-custom-legend/

if(!require(pacman)) {
  install.packages("pacman")
}
pacman::p_load(sf, leaflet, leaflet.extras, glue, htmltools, dplyr, ggplot2)


pctgeo_sf <- read_sf("data/gis/FramPrecincts/FRAMINGHAM_proposed_2020_precincts.shp")

pctgeo_sf <- st_transform(pctgeo_sf, 4326)

all_ma_house <- read_sf("data/gis/ShapefilesFullMAHouse-2021/Final House Plan Shapefile.shp")

fram_house_districts <- all_ma_house[all_ma_house$NAME %in% c("6th Middlesex", "7th Middlesex", "4th Middlesex", "19th Worcester"), ]
fram_house_districts <- st_transform(fram_house_districts, 4326)

only_framingham <- st_intersection(fram_house_districts, pctgeo_sf)

# code to remove intersection from this StackOverflow post
# https://stackoverflow.com/questions/71289669/intersection-keeping-non-intersecting-polygons-in-sf-r
# works for ggplot but not leaflet
not_framingham <- st_difference(fram_house_districts, st_union(st_geometry(only_framingham)))
  
ggplot() +
  geom_sf(data = not_framingham, aes(fill = DISTRICT)) +
  geom_sf(data = only_framingham, aes(fill = DISTRICT))


mylabels_framingham <- glue::glue("<strong>Precinct {only_framingham$PRECINCT}</strong><br />{only_framingham$NAME}") %>%
  lapply(htmltools::HTML)

mylabels_notframingham <- glue::glue("{fram_house_districts$NAME}") %>%
  lapply(htmltools::HTML)

mypopups_framingham <- mylabels_framingham
mypopups_notframingham <- mylabels_notframingham
mycolors <- c('#1b9e77','#d95f02','#7570b3','#e7298a')

mypalette_framingham <- colorFactor(mycolors, sort(only_framingham$NAME))
mypalette_notframingham <- colorFactor(mycolors, sort(fram_house_districts$NAME))



leaflet() %>%
  setView(-71.4366, 42.3011, 12) %>%
  addProviderTiles(providers$Esri.WorldStreetMap) %>%
  addPolygons(data = fram_house_districts, color = "#444444", 
              weight = 1, 
              smoothFactor = 0.5, 
              opacity = 1, 
              fillOpacity = 0.65,
              fillColor =  ~mypalette_notframingham(NAME), 
              highlightOptions = highlightOptions(
                color = "black", 
                weight = 3, 
                bringToFront = TRUE),
              label = mylabels_notframingham,
              labelOptions = labelOptions(
                style = list("font-weight" = "normal", padding = "3px 8px"),
                textsize = "15px",
                direction = "auto")) %>%
  addPolygons(data = only_framingham, group = "Show Framingham Precincts", color = "#444444", 
              weight = 1, 
              smoothFactor = 0.5, 
              opacity = 1, 
              fillOpacity = 0.65,
              fillColor =  ~mypalette_framingham(NAME), 
              highlightOptions = highlightOptions(
                color = "black", 
                weight = 3, 
                bringToFront = TRUE),
              label = mylabels_framingham,
              labelOptions = labelOptions(
                style = list("font-weight" = "normal", padding = "3px 8px"),
                textsize = "15px",
                direction = "auto")) %>%
  addResetMapButton() %>%
  addSearchOSM(options = searchOptions(autoCollapse = TRUE, minLength = 2)) %>%
  addLayersControl(overlayGroups = c("Show Framingham Precincts"), options = layersControlOptions((collapssed = FALSE)))




