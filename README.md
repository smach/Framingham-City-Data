Framingham City Data (Unofficial)
================
Sharon Machlis
November 9, 2017

This project aims to collect important data about Framingham,
Massachusetts and wrangle it so it is in a form useful for analysis.
Data may be in one of two conceptual formats – “tidy”, sometimes called
“long”, with one observation in each row. This is useful for analysis
in R and other platforms (including as a basis for Excel pivot tables).
Or, it may be in more human-readable format, with multiple data points
per row.

The data generally start in 2017 with Framingham’s transition from town
to city form of government.

This data compendium is currently in its early stages. I hopte ventually
to post usable data on data.world and/or datahub.io in addition to the
full project with code here.

The first groups of data added: \* GIS files for precincts in new city
districts \* Results of Framingham’s first-ever city general election in
November 2017 \* Results of Framingham’s first-ever city preliminary
election in September 2017

A few notes on structure and format:

  - The data directory includes data in usable format for analysis.

  - The data gis subdirectory includes GIS files and maps, such as
    precinct/district shapefiles.

  - The data elections subdirectory includes, not surprisingly,
    information about election results but also precinct polling places.

  - When initial data was not in a usable format for analysis, the
    original data file is in the data-raw directory.

  - R files used to reshape the data are in the R directory.

  - PDFs were converted to Excel using the [CometDocs cloud
    service](https://www.cometdocs.com/).)

## Data files

*data/district\_precinct\_info.csv* – which Framingham precincts make up
each district.

### elections

All election results data come from the Framingham Clerk’s office.

#### 2017 general on Nov. 7

*data/elections/2017\_general\_turnout\_framingham.csv* – turnout by
precinct <br />
*data/elections/2017\_general\_turnout\_bydistrict\_framingham.csv* –
turnout by district <br />
*data/elections/2017\_general\_tidy\_framingham.csv* <br /> – complete
results file (excluding turnout) by precinct in “tidy”/long format ready
for analysis in R, Excel pivot tables, or other platforms.
*data/elections/2017\_general\_bydistrict\_tidy\_framingham\_tidy.csv* –
complete results file (excluding turnout) by district in “tidy”/long
format ready for analysis in R, Excel pivot tables, or other
platforms.<br /> *data/elections/2017\_general\_mayor\_framingham.csv*
<br />
*data/elections/2017\_general\_mayor\_bydistrict\_framingham.csv*<br />
*data/elections/2017\_general\_atlarge\_framingham.csv* <br />
*data/elections/2017\_general\_atlarge\_bydistrict\_framingham.csv*
<br />
*data/elections/2017\_general\_district\_council\_bydistrict\_tidy\_framingham.csv*
<br />
*data/elections/2017\_general\_school\_committee\_bydistrict\_tidy\_framingham.csv*

#### 2017 preliminary on Sept. 26

*data/elections/2017\_preliminary\_turnout\_framingham.csv* – turnout by
precinct <br />
*data/elections/2017\_preliminary\_turnout\_bydistrict\_framingham.csv*
– turnout by district <br />
*data/elections/2017\_preliminary\_tidy\_framingham.csv* <br /> –
complete results file (excluding turnout) by precinct in “tidy”/long
format ready for analysis in R, Excel pivot tables, or other platforms.
*data/elections/2017\_preliminary\_bydistrict\_tidy\_framingham.csv* –
complete results file (excluding turnout) by district in “tidy”/long
format ready for analysis in R, Excel pivot tables, or other
platforms.<br />
*data/elections/2017\_preliminary\_mayor\_framingham.csv* <br />
*data/elections/2017\_preliminary\_mayor\_framingham\_tidy.csv* <br />
*data/elections/2017\_preliminary\_atlarge\_framingham.csv* <br />
*data/elections/2017\_preliminary\_atlarge\_framingham\_tidy.csv* <br />
*data/elections/2017\_preliminary\_district\_council\_bydistrict\_tidy\_framingham.csv*

#### 2017 vote on city charter April 4

*data/elections/2017\_charter\_turnout\_framingham.csv*<br />
*data/elections/2017\_charter\_results\_framingham.csv*<br />
*data/elections/2017\_charter\_results\_tidy\_framingham.csv* – complete
vote and turnout by precinct including turnout in “tidy”/long format
ready for analysis in R, Excel pivot tables, or other platforms.

## Raw data files

*data-raw/elections/election\_general\_2017\_framingham\_raw.pdf* – PDF
of official Framingham November 2017 election results. [File posted on
the Framingham
website](http://www.framinghamma.gov/DocumentCenter/View/28924).

*data-raw/elections/election\_general\_2017\_framingham\_raw.xlsx* –
Official Framingham November 2017 election results converted from PDF to
Excel by [CometDocs](https://www.cometdocs.com/).

*data-raw/elections/election\_preliminary\_2017\_framingham\_raw.pdf* –
Official Framingham September 2017 preliminary election results
converted from PDF to Excel by [CometDocs](https://www.cometdocs.com/).

*data-raw/elections/election\_preliminary\_2017\_framingham\_raw.xlsx* –
Official Framingham September 2017 preliminary election results
converted from PDF to Excel by [CometDocs](https://www.cometdocs.com/).

*data-raw/elections/election\_charter\_2017\_framingham\_raw.xlsx* –
results of the April 2017 vote on the city charter.

*data-raw/elections/election-town-2017\_framingham-raw.pdf* – Official
Framingham April 2017 town election results.

## GIS files

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

## R files

*R/config.R* – Setup needed to run these scripts, including installing
packages not on your system. **Run config.R before trying to run any
other R scripts in this project.**

### For analysis

*R/get\_turnouts.R* – get a tidy data frame of all available election
turnout data by precinct, stored in an R object called
`all_turnout_data`.

### For reproducibility

These are the scripts I used to turn raw data into analysis-friendly
data.

*R/election\_general\_2017\_framingham.R* – R file to convert November
2017 official results spreadsheet to an analysis-friendly format.

*R/election\_preliminary\_2017\_framingham.R* – R file to convert
September 2017 official results spreadsheet to an analysis-friendly
format.

*R/election\_charter\_2017.R* – R file to convert April 2017 city
charter results to analysis-friendly format.

*R/election\_helpers.R* – file with some useful functions for working
with Framingham election data.
