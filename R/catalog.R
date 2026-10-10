# catalog.R ---------------------------------------------------------------------
# The searchable list of files on the project website.
#
# The old site used a hand-maintained docs/file_index.csv that had to be
# edited every time a file was added. Now the list is built automatically:
# every file under data/ and data-raw/ is listed, and its description comes
# from the first matching pattern in docs/catalog_descriptions.csv. Raw
# election files also get the election's name from the registry. A new
# election's files show up on the site with no extra work.

#' Build the file catalog for the website
#' @return A data frame: File, Description, Category, Source.
build_file_catalog <- function(patterns_path = proj_path("docs", "catalog_descriptions.csv")) {
  root <- proj_path()
  files <- list.files(file.path(root, c("data", "data-raw")), recursive = TRUE,
                      full.names = TRUE, all.files = FALSE)
  rel <- sub(paste0("^", normalizePath(root), "/"), "", normalizePath(files))
  # Shapefiles come in 5-8 parts (.shp, .dbf, .prj...); list each set once
  rel <- rel[!grepl("\\.(dbf|prj|sbn|sbx|shx|cpg|CPG|shp\\.xml)$", rel)]
  rel <- rel[!grepl("README", rel)]

  patterns <- readr::read_csv(patterns_path, show_col_types = FALSE,
                              col_types = readr::cols(.default = readr::col_character()))
  first_match <- vapply(rel, function(f) {
    hit <- which(vapply(patterns$pattern, function(p) grepl(p, f, perl = TRUE), logical(1)))
    if (length(hit)) hit[1] else NA_integer_
  }, integer(1))

  catalog <- data.frame(
    File = rel,
    Description = ifelse(is.na(first_match), "", patterns$description[first_match]),
    Category = ifelse(is.na(first_match), "Other", patterns$category[first_match]),
    Source = ifelse(is.na(first_match), "", dplyr::coalesce(patterns$source[first_match], "")),
    stringsAsFactors = FALSE, row.names = NULL
  )

  # Name the election for files in data-raw/elections/<id>/ and by_election/
  registry <- read_registry()
  id <- stringr::str_match(rel, "(?:data-raw/elections/|by_election/)(\\d{4}-\\d{2}-\\d{2}_[^/]+?)(?:/|_results_wide)")[, 2]
  election_name <- registry$name[match(id, registry$election_id)]
  catalog$Description <- ifelse(is.na(election_name), catalog$Description,
                                paste0(election_name, ": ", catalog$Description))
  catalog[order(catalog$Category != "Elections", catalog$File), ]
}
