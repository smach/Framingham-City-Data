Framingham City Data (Unofficial)
================

This project aims to collect important data about Framingham,
Massachusetts and wrangle it so it is in a form useful for analysis. I
started it before Framingham created its [Open Data
Framingham](https://data.framinghamma.gov/) portal. Since Open Data
Framingham does not include election results, for now I’m focused
largely on election results.

Election data may be in one of two formats – “tidy”, sometimes called
“long”, with one observation in each row; or more human-readable
format, with multiple data points per row.

If you are doing analysis in R and other platforms (including as a basis
for Excel pivot tables), tidy format is more useful. If you want to
combine data sets, tidy is definitely more useful since most tidy data
sets have the same column names: **Candidate, District or Precinct,
Votes, Race, Year, Election**.

*Tidy election data files are in the data/elections/tidy subdirectory.*

If you are just looking to see results, the non-tidy format will be more
useful. Those files are in the data/elections directory.

The data generally start in 2017 with Framingham’s transition from town
to city form of government, although I have a few raw data files from
earlier elections. I usually do not include preliminary elections unless
they are city-wide. Tidy data for preliminary and general elections
usually only include mayoral and City Council races.

Source: Election data generally come from PDFs of results provided by
the Framingham City Clerk’s office. Note that I have then pulled that
data from PDF into Excel and done a fair amount of data wrangling.

Data added so far:

  - Some election results from the 2019 general election

  - GIS shapefiles for Framigham precincts

  - Results of Framingham’s first-ever city general election in November
    2017

  - Results of Framingham’s first-ever city preliminary election in
    September 2017

A few notes on structure and format:

  - The data/gis subdirectory includes GIS files and maps, such as
    precinct and district shapefiles.

  - The data/elections subdirectory includes information about precinct
    polling places.

  - When initial data was not in a usable format for analysis, such as
    PDFs from the City Clerk’s office, the original data file is in the
    data-raw directory. *If you are looking for results from races not
    in my election CSV files, you can try looking at the raw data in the
    data-raw directory.*

  - PDFs were converted to Excel using the [CometDocs cloud
    service](https://www.cometdocs.com/).

  - Some R files used to reshape the data have been included in the R
    directory.

## Other available files

*data/district\_precinct\_info.csv* – which Framingham precincts make up
each district.

*data/gis/FramPrecincts/* - shapefile of Framingham precincts. Includes
District info. Shapefile wsd received from Geoffrey W. Kovar, Framingham
GIS Manager, via email on July 14, 2017.

Read shapefile into R with the tmaptools package:

``` r
library(sf)
framgeo <- tmaptools::read_shape("data/gis/FramPrecincts/FramPrecincts.shp", as.sf = TRUE)
```

*data/gis/framingham\_basemap.Rda* - A leaflet HTML widget of Framingham
districts and precincts that I created from Framingham precinct
shapefile.

### R files

*R/config.R* – Setup needed to run these scripts, including installing
packages not on your system. Running config.R will ensure you have all
necessary packages.

### For analysis

*R/get\_turnouts.R* – get a tidy data frame of all available election
turnout data by precinct, stored in an R object called
`all_turnout_data`.

## Info on reproducibility

These are the scripts I used to turn raw data into analysis-friendly
data, including:

*R/election\_general\_2017\_framingham.R* – R file to convert November
2017 official results spreadsheet to an analysis-friendly format.

*R/election\_preliminary\_2017\_framingham.R* – R file to convert
September 2017 official results spreadsheet to an analysis-friendly
format.

*R/election\_charter\_2017.R* – R file to convert April 2017 city
charter results to analysis-friendly format.

*R/election\_helpers.R* – file with some useful functions for working
with Framingham election data.
