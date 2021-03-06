Framingham City Data (Unofficial)
================

This project aims to collect data about Framingham, Massachusetts and
wrangle it so it is in a form useful for analysis. I started it before
Framingham created its [Open Data
Framingham](https://data.framinghamma.gov/) portal. Since Open Data
Framingham does not include election results, for now I’m focused
largely on election results – more specifically local mayoral and City
Council races as well as turnout information. I also have the vote on
the city charter.

### Election data

Election data is in one of two structures – “tidy”, sometimes called
“long”, with one observation in each row; or more human-readable
format, with multiple data points per row. *Tidy election data files are
in the data/elections/tidy subdirectory.*

If you are doing analysis in R and other platforms (including as a basis
for Excel pivot tables), tidy format is more useful. If you want to
combine data sets, tidy is definitely more useful since most tidy data
sets have the same column names: **Candidate, District or Precinct,
Votes, Race, Year, Election**.

If you are just looking to see results, the non-tidy format will be more
useful. Those files are in the data/elections directory.

The data generally start in 2017 with Framingham’s transition from town
to city form of government, although I have a few raw data files from
earlier elections. I do not include preliminary elections unless they
are city-wide.

Source: Local election data generally come from PDFs of results provided
by the Framingham City Clerk’s office. Note that I have then extracted
data from PDFinto Excel files using the [CometDocs cloud
service](https://www.cometdocs.com/) and done a fair amount of data
wrangling on those results.

To come: Files in each directory explaining each data file.

### Available data so far

  - Election results from the November 2019 Framingham city election

  - Results of Framingham’s first-ever city general election in November
    2017

  - Results of Framingham’s first-ever city preliminary election in
    September 2017

  - 2017 property valuations from Open Data Framingham in the
    data/property subdirectory

  - GIS shapefiles for Framigham precincts.
    data/gis/Framingham\_Districts\_and\_Precincts\_2018.zip contains
    the most recent official shapefiles, which I downloaded from
    [Framingham Open
    Data](https://data.framinghamma.gov/Community-Development/Framingham-Districts-and-Precincts/9pzx-4i9g).
    There are also precinct files emailed to me by Geoffrey W. Kovar,
    Framingham GIS Manager, via email on July 14, 2017.

  - GIS shapefiles for all Framingham parcels, downloaded from [Open
    Data
    Framingham](https://data.framinghamma.gov/Community-Development/Framingham-Parcels/5vrm-nj3j)

  - CSV file of which district each precinct belongs to.

  - Some R files used to wrangle and analyze data.

### What’s where

  - Election data in human-friendly format is in the data/elections
    directory. Election data in analysis-friendly tidy format is in the
    data/elections/tidy subdirectory. Original election-result PDFs from
    the City Clerk’s office as well as Excel files created from those
    PDFs via CometDocs are in the data-raw/elections subdirectory.

  - GIS files and maps, such as precinct and district shapefiles, are in
    the data/gis subdirectory.

  - Property valuations are in the data/property subdirectory.

  - Some of the R files I used to reshape the data are in the R
    directory. In addition, the *config.R* file loads necessary packages
    for running the other files. And, *get\_turnouts.R* genreates a tidy
    data frame of all available election turnout data by precinct,
    stored in an R object called `all_turnout_data`.
    *framingham\_basemap.R* creates a map of Framingham precincts,
    colored by district, using the R leaflet package.

  - The CSV of which Framingham precincts make up each district is in
    the data directory.

R users: You can read shapefiles into R with the sf package, such as

``` r
library(sf)
framgeo <- sf::read_sf("data/gis/FramPrecincts/FramPrecincts.shp")
```

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

*R/election\_general\_2019.R* – R file to convert November 2017 official
results data to an analysis-friendly format.

*R/election\_helpers.R* – file with some useful functions for working
with Framingham election data.
