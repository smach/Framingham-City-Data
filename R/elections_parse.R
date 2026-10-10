# elections_parse.R -------------------------------------------------------------
# Read election results into one standard "extracted" layout.
#
# The City Clerk's results always look roughly like this, whether they come as
# a PDF, a spreadsheet converted from a PDF, or an LLM extraction:
#
#               1     2     3   ...   18   Total     <- precinct header row
#   Mayor (1 seat) for 2 years                      <- race header (no numbers)
#   Blanks      7     2     2   ...    0      48
#   Jane Doe  603   630   364   ...  237    6457    <- candidate rows
#   ...
#   Total Voter Turnout    1373  1478 ...           <- turnout rows
#   Total Registered Voters 2918 3235 ...
#
# Primaries add a party header ("Democratic") above each party's races, and
# long results repeat the precinct header at the top of every page.
#
# Instead of a new script per election with hard-coded cell ranges such as
# "A6:S9", parse_clerk_table() works out the layout itself:
#   * the precinct header row is a row whose first numbers are 1, 2, 3
#   * a row with a label but no precinct numbers is a race (or party) header
#   * every row below a race header belongs to that race until the next header
#   * rows whose label mentions turnout or registered voters are turnout data
#
# Every reader in this file returns the same "extracted" data frame, one row
# per number in the source table:
#   section    "results" or "turnout"
#   party      party for primaries, otherwise NA
#   race       race label as printed, e.g. "Mayor (1 seat) for 2 years"
#   candidate  candidate or row label, e.g. "Blanks", "Total Voter Turnout"
#   precinct   "1", "9A", ... or "Total" for the clerk's reported total
#   votes      the number
#
# Keeping the clerk's "Total" column lets validation check that the precinct
# numbers add up to it, which catches typos and extraction mistakes.

# Party header labels used in primary results
party_pattern <- paste0(
  "^(Democrat|Democratic|Republican|Libertarian|Green[- ]Rainbow|Green|",
  "United Independent|Working Families|Unenrolled)( Party)?$"
)

#' Read one sheet of a clerk spreadsheet as plain text
#'
#' Every cell is read as text with no header, because the header isn't on the
#' first row and numbers come in inconsistent formats. parse_clerk_table()
#' sorts it out.
read_clerk_sheet <- function(path, sheet = NULL) {
  if (is.null(sheet) || is.na(sheet) || sheet == "") sheet <- 1
  raw <- readxl::read_excel(path, sheet = sheet, col_names = FALSE,
                            col_types = "text", .name_repair = "minimal")
  raw <- as.data.frame(raw, stringsAsFactors = FALSE)
  names(raw) <- paste0("c", seq_along(raw))
  raw
}

#' Is this row the precinct header ("1 2 3 ... Total")?
#'
#' TRUE when the label cell is empty (or says "Candidate"/"Precinct") and the
#' first three numbers in the row are 1, 2, 3. Checking the label stops a
#' candidate who happened to get 1, 2 and 3 votes from counting as a header.
is_precinct_header <- function(row) {
  label <- clean_label(row[[1]])
  if (!(is.na(label) || label %in% c("", "Candidate", "Candidates", "Precinct"))) return(FALSE)
  nums <- as_number(unlist(row[-1]))
  nums <- nums[!is.na(nums)]
  length(nums) >= 3 && all(nums[1:3] == c(1, 2, 3))
}

#' Turn a raw clerk results table into the standard extracted layout
#'
#' @param raw A data frame of text cells, as from read_clerk_sheet().
#' @param default_race Race name for numbers that come before any race
#'   header. The 2017 charter vote sheet, for example, has Yes/No rows but no
#'   race header.
#' @return An extracted data frame (see the top of this file).
parse_clerk_table <- function(raw, default_race = NA_character_) {
  header_rows <- which(vapply(seq_len(nrow(raw)), function(i) is_precinct_header(raw[i, ]), logical(1)))
  if (length(header_rows) == 0) stop("Couldn't find a precinct header row (1, 2, 3, ...).")

  # --- Which column holds which precinct? Taken from the first header row. ---
  header <- unlist(raw[header_rows[1], ])
  precinct_of_col <- rep(NA_character_, ncol(raw))
  for (j in 2:ncol(raw)) {
    cell <- clean_label(header[j])
    if (is.na(cell) || cell == "") next
    num <- as_number(cell)
    precinct_of_col[j] <- if (!is.na(num)) as.character(as.integer(num))
                          else if (tolower(cell) %in% c("total", "totals")) "Total"
                          else cell                       # "9A", "21B", ...
  }
  data_cols <- which(!is.na(precinct_of_col))

  # --- Rows to skip: everything above the first header, the repeated page
  # headers, and page titles such as "City Election Official Results -
  # November 7, 2017" that repeat at the top of each page. Titles are spotted
  # by their wording rather than position: in 2023 a race header sits right
  # above a repeated page header and must be kept. ---
  skip <- rep(FALSE, nrow(raw))
  skip[seq_len(header_rows[1])] <- TRUE
  skip[header_rows] <- TRUE
  labels <- clean_label(raw[[1]])
  skip[grepl("results|election", labels, ignore.case = TRUE) &
         !grepl("turnout|registered", labels, ignore.case = TRUE)] <- TRUE
  # Older town results end with a "Validation" block that repeats office names
  # with numbers -- not results, so stop reading there.
  validation_row <- which(grepl("^Validation", clean_label(raw[[1]])))
  if (length(validation_row) > 0) skip[validation_row[1]:nrow(raw)] <- TRUE

  # --- Walk down the rows, tracking the current party and race. ---
  out <- vector("list", nrow(raw))
  current_party <- NA_character_
  current_race  <- NA_character_
  for (i in which(!skip)) {
    label <- clean_label(raw[i, 1])
    # PDF conversion sometimes shifts a race name into the second column
    if (is.na(label) || label == "") {
      shifted <- clean_label(raw[i, 2])
      if (!is.na(shifted) && is.na(as_number(shifted))) label <- shifted
    }
    if (is.na(label) || label == "") next

    vals <- as_number(unlist(raw[i, data_cols]))
    names(vals) <- precinct_of_col[data_cols]
    precinct_vals <- vals[names(vals) != "Total"]
    total_val <- if ("Total" %in% names(vals)) vals[["Total"]] else NA
    # A row with no precinct numbers is a header. (Empty rows in some
    # spreadsheets carry a 0 in the Total column from a SUM formula, so a
    # zero total alone doesn't count as data.)
    has_data <- any(!is.na(precinct_vals)) || (!is.na(total_val) && total_val != 0)

    if (!has_data) {
      if (grepl(party_pattern, label, ignore.case = TRUE)) {
        current_party <- label
        current_race  <- NA_character_
      } else {
        current_race <- label
      }
      next
    }

    if (grepl("^percent", label, ignore.case = TRUE)) next  # we recompute percentages ourselves
    is_turnout <- grepl("turnout|registered", label, ignore.case = TRUE)
    keep <- !is.na(vals)
    out[[i]] <- data.frame(
      section   = if (is_turnout) "turnout" else "results",
      party     = current_party,
      race      = if (is_turnout) NA_character_ else dplyr::coalesce(current_race, default_race),
      candidate = label,
      precinct  = names(vals)[keep],
      votes     = unname(vals[keep]),
      stringsAsFactors = FALSE
    )
  }
  dplyr::bind_rows(out)
}

#' Read an extracted.csv file (for example, one written by the LLM extractor)
#'
#' Same columns as parse_clerk_table() returns. Checks that the columns are
#' all there, so a malformed file fails loudly instead of quietly.
read_extracted_csv <- function(path) {
  x <- readr::read_csv(path, col_types = readr::cols(
    section = "c", party = "c", race = "c", candidate = "c", precinct = "c", votes = "d"
  ))
  needed <- c("section", "party", "race", "candidate", "precinct", "votes")
  missing <- setdiff(needed, names(x))
  if (length(missing) > 0) stop(path, " is missing columns: ", paste(missing, collapse = ", "))
  as.data.frame(x[, needed])
}

#' Read all raw files for one election into the extracted layout
#'
#' Uses the registry row to decide how:
#'   parser = "clerk_xlsx"    -> parse each spreadsheet in results_files and
#'                               turnout_files with parse_clerk_table()
#'   parser = "extracted_csv" -> read <election folder>/extracted.csv
#'
#' Multiple files are separated by ";" in the registry.
#'
#' @param meta One row of the registry (see read_registry()).
read_election_raw <- function(meta) {
  folder <- proj_path("data-raw", "elections", meta$election_id)
  split_files <- function(x) if (is.na(x) || x == "") character(0) else trimws(strsplit(x, ";")[[1]])

  if (meta$parser == "extracted_csv") {
    return(read_extracted_csv(file.path(folder, "extracted.csv")))
  }
  if (meta$parser != "clerk_xlsx") stop("Don't know how to read parser '", meta$parser, "'")

  results <- lapply(split_files(meta$results_files), function(f) {
    parse_clerk_table(read_clerk_sheet(file.path(folder, f), meta$sheet), meta$default_race)
  })
  # Turnout-only files (2019 has one) only contribute turnout rows
  turnout <- lapply(split_files(meta$turnout_files), function(f) {
    x <- parse_clerk_table(read_clerk_sheet(file.path(folder, f), meta$sheet))
    x[x$section == "turnout", ]
  })
  dplyr::bind_rows(c(results, turnout))
}
