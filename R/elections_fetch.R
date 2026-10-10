# elections_fetch.R -------------------------------------------------------------
# Find, download and register new election results.
#
#   check_clerk_page()   list results PDFs on the City Clerk's page
#   find_new_results()   which of those aren't in the registry yet
#   register_election()  add or update a row in the registry
#   add_election()       add an election from an Acrobat spreadsheet, rebuild
#
# The scheduled GitHub Action (.github/workflows/check-elections.yml) uses
# these to open an issue whenever the clerk posts new results.
#
# NOTE: The clerk's page address and link format below are based on
# framinghamma.gov's usual layout but have NOT been tested yet (the server
# these functions were written on couldn't reach the site). The first run of
# check_clerk_page() on your computer will show whether they need adjusting.

clerk_results_url <- "https://www.framinghamma.gov/3095/Election-Results"

#' List results PDFs linked from the City Clerk's election results page
#'
#' @return A data frame with link_text, url and a guessed election_date.
check_clerk_page <- function(url = clerk_results_url) {
  page <- rvest::read_html(url)
  links <- rvest::html_elements(page, "a")
  out <- data.frame(
    link_text = clean_label(rvest::html_text2(links)),
    url = xml2::url_absolute(rvest::html_attr(links, "href"), url),
    stringsAsFactors = FALSE
  )
  # Results documents: PDFs or the city's DocumentCenter links whose text
  # mentions results or an election
  is_doc <- grepl("\\.pdf($|\\?)|DocumentCenter/View", out$url, ignore.case = TRUE)
  is_results <- grepl("result|election|primary|preliminary", out$link_text, ignore.case = TRUE)
  out <- unique(out[is_doc & is_results & !is.na(out$url), ])
  out$election_date <- guess_date(out$link_text)
  out
}

#' Guess a date from text like "November 4, 2025 City Election" or "11/4/2025"
guess_date <- function(text) {
  pattern <- "(January|February|March|April|May|June|July|August|September|October|November|December)\\.? \\d{1,2},? \\d{4}"
  found <- stringr::str_extract(text, stringr::regex(pattern, ignore_case = TRUE))
  d <- as.Date(found, tryFormats = c("%B %d, %Y", "%B %d %Y"), optional = TRUE)
  numeric <- stringr::str_extract(text, "\\d{1,2}/\\d{1,2}/\\d{4}")
  d[is.na(d)] <- as.Date(numeric[is.na(d)], format = "%m/%d/%Y")
  d
}

#' Guess level and type from a link title
guess_election_kind <- function(text) {
  t <- tolower(text)
  type <- dplyr::case_when(
    grepl("presidential", t) ~ "presidential-primary",
    grepl("special", t) & grepl("primary", t) ~ "special-primary",
    grepl("primary", t) ~ "primary",
    grepl("preliminary", t) ~ "preliminary",
    grepl("special", t) ~ "special",
    grepl("town", t) ~ "town",            # pre-2018 annual town elections
    TRUE ~ "general"
  )
  level <- ifelse(grepl("state|primary|presidential", t), "state", "municipal")
  data.frame(level = level, type = type, stringsAsFactors = FALSE)
}

#' Which links on the clerk's page aren't in the registry yet?
#'
#' A link counts as known when its URL is in the registry's source_url column
#' (one election can list several URLs separated by ";", e.g. unofficial
#' then official results).
find_new_results <- function(links = check_clerk_page(), registry = read_registry()) {
  known <- trimws(unlist(strsplit(stats::na.omit(registry$source_url), ";")))
  links[!links$url %in% known, ]
}

#' Add a new election to the registry, or update an existing one
#'
#' @param election_id e.g. "2025-11-04_municipal_general". The pattern is
#'   date_level_type.
#' @param ... Columns to set, e.g. status = "official", parser = "extracted_csv".
#' @param path The registry file.
register_election <- function(election_id, ..., path = proj_path("data-raw", "elections", "elections.csv")) {
  reg <- read_registry(path)
  values <- list(...)
  if (!election_id %in% reg$election_id) {
    parts <- strsplit(election_id, "_")[[1]]
    new <- data.frame(election_id = election_id, election_date = as.Date(parts[1]),
                      level = parts[2], type = parts[3], stringsAsFactors = FALSE)
    reg <- dplyr::bind_rows(reg, new)
  }
  i <- which(reg$election_id == election_id)
  for (col in names(values)) {
    if (!col %in% names(reg)) stop("The registry has no column called ", col)
    reg[[col]][i] <- if (col == "election_date") as.Date(values[[col]]) else as.character(values[[col]])
  }
  reg <- reg[order(reg$parser %in% "not_collected", reg$election_date), ]
  reg$election_date <- as.character(reg$election_date)
  write_csv_stable(reg, path)
  invisible(reg[i, ])
}

#' Add one election from a spreadsheet converted in Adobe Acrobat
#'
#' Convert the clerk's results PDF to Excel by hand in Acrobat first (see the
#' README). This copies the spreadsheet, and the PDF if you give it, into
#' data-raw/elections/<election_id>/, registers the election and rebuilds.
#'
#' @param election_id e.g. "2025-11-04_municipal_general".
#' @param xlsx Path to the Acrobat spreadsheet.
#' @param status "unofficial" or "official".
#' @param pdf Optional path to the clerk's PDF, kept next to the spreadsheet.
#' @param source_url Optional web address of the PDF on the clerk's page, so
#'   the weekly check knows it's been collected.
#' @param name Readable name, e.g. "November 4 2025 City Election".
#' @return That election's validation checks, so you can see right away
#'   whether the conversion is trustworthy.
add_election <- function(election_id, xlsx, status = "unofficial", pdf = NA,
                         source_url = NA, name = NA) {
  folder <- proj_path("data-raw", "elections", election_id)
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  for (f in stats::na.omit(c(xlsx, pdf))) {
    dest <- file.path(folder, basename(f))
    if (normalizePath(f) != normalizePath(dest, mustWork = FALSE)) file.copy(f, dest, overwrite = TRUE)
  }

  # Keep any web addresses already recorded (e.g. unofficial, then official)
  reg <- read_registry()
  old_urls <- reg$source_url[reg$election_id == election_id]
  urls <- unique(stats::na.omit(c(trimws(unlist(strsplit(if (length(old_urls)) old_urls else NA, ";"))),
                                  source_url)))
  register_election(
    election_id, status = status, parser = "clerk_xlsx", results_files = basename(xlsx),
    name = if (is.na(name)) reg$name[reg$election_id == election_id][1] else name,
    source_url = if (length(urls)) paste(urls, collapse = ";") else NA,
    notes = paste0("Converted from the clerk's PDF with Adobe Acrobat on ", Sys.Date(), ".")
  )
  checks <- build_all(quiet = TRUE)
  checks[checks$election_id == election_id, ]
}
