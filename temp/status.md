# Status: Framingham City Data restructure

Branch: `claude/eloquent-dijkstra-4nzy18` · Written October 10, 2026

The repo has been restructured so that one command rebuilds every election's data in about 6 seconds. Adding a new election is meant to be mostly automatic: Claude reads the clerk's PDF, R checks the numbers, and a GitHub Action opens a pull request for you to review. All 15 elections that have spreadsheets pass the automatic data checks, and the new code reproduces every vote and turnout number in the old output files.

**Not done yet:** nothing has been tested against a real results PDF (that needs your API key), and the website has never been rendered with Quarto (Quarto wasn't available where this was built). Both are first on the checklist below.

---

## Next steps on your machine

1. **Install packages** (once), from the project folder in R:
   ```r
   install.packages("pak")
   pak::local_install_deps(dependencies = TRUE)   # everything listed in DESCRIPTION
   ```
2. **Run the build and the tests** to confirm everything works on your computer:
   ```
   Rscript scripts/build_all.R      # should end with "0 failed checks"
   Rscript tests/testthat.R         # should end with "FAIL 0 | ... | PASS 68"
   ```
3. **Render the website with Quarto for the first time:** run `quarto render` in a terminal from the project folder, then open `docs/index.html`.
   - This is the first-ever Quarto render, so look it over. The page should have the file tables, the data dictionary, the turnout table, the election list and the searchable file list.
   - The `docs/index.html` currently in the repo is the old R Markdown version. Quarto replaces it and adds `docs/site_libs/` and `docs/search.json`. Commit all of `docs/`.
   - If anything breaks, the page source is `index.qmd` and the settings are in `_quarto.yml`.
4. **Try the Claude PDF extraction** on the November 2022 state election, which has never been converted:
   - Put `ANTHROPIC_API_KEY=...` in `~/.Renviron` (`usethis::edit_r_environ()`), then restart R.
   - Run:
     ```
     Rscript scripts/add_election.R 2022-11-08_state_general "data-raw/elections/2022-11-08_state_general/NOVEMBER 8, 2022 STATE ELECTION UNOFFICIAL RESULTS.pdf" unofficial
     ```
   - It prints the validation checks. A "fail" line names the race and precinct that don't add up. Compare it with the PDF, fix `data-raw/elections/2022-11-08_state_general/extracted.csv` by hand if needed, and rerun `Rscript scripts/build_all.R`.
   - The default model is `claude-opus-5-5` with effort "high". Both are arguments of `extract_results_llm()` in `R/elections_extract_llm.R`.
   - For a known-answer test, run it on a PDF that already has a spreadsheet (2023 general, for example) and compare. Do that in a scratch copy, or revert afterwards, because `add_election()` changes that election's registry row to use `extracted.csv`.
5. **Check the web addresses** that couldn't be reached from the build environment:
   - The clerk's results page in `R/elections_fetch.R` (`clerk_results_url`). Run `source("R/load.R"); check_clerk_page()` and see whether it lists the results PDFs.
   - MassGIS parcels in `R/property.R` (`massgis_parcels_url()`). This assumes Framingham's town ID is 100; check the URL, then run `Rscript scripts/update_property.R`.
   - Census data: set a Census API key, then run `fetch_acs_framingham(2023)` (see `R/census.R`).
   - The leaflet map: `make_precinct_map("2023-11-07", show_house_districts = TRUE)`. This needs leaflet and leaflet.extras, which weren't available for testing.
6. **Set up GitHub**, in the repository's Settings:
   - Secrets and variables → Actions → add the secret `ANTHROPIC_API_KEY`;
   - Actions → General → tick "Allow GitHub Actions to create and approve pull requests";
   - the three workflows have passed `actionlint` but have never actually run. After merging, use "Run workflow" on the Actions tab to try each one.
7. **Delete the old branch** `claude/repository-review-suggestions-…`. Its useful parts are already in the new structure.
8. **Collect missing elections.** `data/elections/elections.csv` lists 14 with `has_data = FALSE` (2016–2025). Some dates came from the old branch's inventory and are marked "verify". Two PDFs are already in the repo but not converted: 2012-04-03 and 2022-11-08.

---

## What was built

**One list of elections.** `data-raw/elections/elections.csv` has one row per election, including the ones not collected yet, so it doubles as a to-do list. Each election's original files are now in their own folder, e.g. `data-raw/elections/2023-11-07_municipal_general/`.

**One parser instead of 12 per-year scripts.** `parse_clerk_table()` in `R/elections_parse.R` reads any of the clerk's spreadsheets without hard-coded cell ranges. It handles:
- finding the precinct header row and race names on its own;
- party headers in primaries;
- the 27-precinct map with sub-precincts such as 9A;
- race names that the PDF conversion shifted into the wrong column;
- page headers that repeat on every page.

**Consistent output files in `data/elections/`.** They cover every election from 2008 to 2023 in one place, all with the same columns:
- `results_precinct.csv`;
- `results_district.csv`;
- `turnout_precinct.csv`, `turnout_district.csv` and `turnout_citywide.csv` (turnout is always a percent from 0 to 100);
- one readable, clerk-style file per election in `by_election/`.

**Automatic checks** (`R/elections_validate.R`). They are what make AI extraction safe to use; in a test, one misread digit (735 instead of 755) was caught.
- Each row's precinct numbers must add up to the clerk's Total.
- Ballots can't exceed registered voters.
- A one-seat race can't have more votes than ballots cast.
- Every precinct must exist on the map in use on that date.

The results are in `data/elections/validation_report.csv`.

**Claude reads PDFs** (`R/elections_extract_llm.R`, `scripts/add_election.R`). The PDF goes to Claude through ellmer, and the reply comes back as a plain CSV in the clerk's layout. It deliberately doesn't use ellmer's structured-output helper, because newer Claude models reject the "forced tool call" that some ellmer versions use for it. The CSV is saved and committed, so the API is only called once per election.

**GitHub Actions** (`.github/workflows/`):
- `check-elections.yml` runs weekly, and daily in September–November. It finds new results on the clerk's page, extracts and checks them, and opens a pull request.
- `test.yml` runs on every pull request. It rebuilds the data, fails if a check fails or if the committed data doesn't match the code, and runs the tests.
- `build-site.yml` renders the Quarto site into `docs/` and commits it. GitHub Pages keeps serving from `docs/`, so no settings change is needed.

**Website (Quarto).** The source is `index.qmd` and the settings are in `_quarto.yml`, both at the project root. The searchable file list is built automatically by `build_file_catalog()` in `R/catalog.R`, using pattern-based descriptions in `data-raw/catalog_descriptions.csv`, so there's no more hand-kept `file_index.csv`.

**Maps and other data:**
- `R/gis.R` / `scripts/build_gis.R`:
  - clean precinct files for both precinct maps, with city districts attached (`data/gis/framingham_precincts.gpkg` plus GeoJSON);
  - Framingham-only state House districts, replacing 16 MB of statewide shapefiles; the original zip is kept;
  - 2020 Census block groups in Framingham;
  - one `make_precinct_map()` function instead of three basemap scripts.
- `R/property.R` / `scripts/update_property.R`: MassGIS parcels, plus assessments as a separate CSV for each fiscal year (`data/property/assessments_fy<YEAR>.csv`, joined to parcels by `LOC_ID`). MassGIS keeps only the latest snapshot, so saving one file per year builds up a history. Earlier years, or fields MassGIS doesn't carry such as bedrooms, condition or full sale history, would need a public records request to the Assessor (M.G.L. c. 66 §10).
- `R/census.R`: ACS estimates for the city and its block groups via tidycensus.

**Old files.** The per-year scripts are deleted but remain in git history at commit `2a8ca16`. The old output CSVs are in `data/legacy/`, because the regression tests compare against them.

## Errors found in the old data, now fixed

- The 2022 state primary turnout was labeled `Year = 2020`.
- The "2021 special" City Council election actually took place on January 11, 2022, according to the clerk's own file.
- The "2016 general" turnout file was really the March 29, 2016 town election.
- `get_district()` used the pre-2022 precinct map for every year, which is wrong from 2022 on.
- The 2021-special turnout files were empty.
- The old 2023 tidy file had page-header rows mixed in as fake "candidates".
- Turnout was a fraction in some files and a percent in others, with column names that varied too.
- The committed CSVs had been edited by hand ("General Municipal"), so the scripts no longer reproduced them.
- `R/config.R` tried to install tidyr, readr and janitor under the wrong condition, so they were never installed.

## Departures from the original plan

- **Package management:** a `DESCRIPTION` file instead of renv. `pak::local_install_deps()` reads it, and so do the GitHub Actions. renv can be added later if you want pinned versions.
- **State election data:** pulling state and federal results from electionstats.state.ma.us isn't built yet, because the site couldn't be reached to confirm its download format. For now, state elections go through the same clerk-PDF route.
- **New data sources:** campaign finance (OCPF), municipal finances (DLS), schools (DESE) and party enrollment are ideas only; no code yet.

## Key files

| Task | File |
|---|---|
| Add or fix an election's metadata | `data-raw/elections/elections.csv` |
| Precinct-to-district map, by date | `data-raw/lookups/precinct_districts.csv` |
| Rebuild everything | `scripts/build_all.R` |
| Add an election from a PDF | `scripts/add_election.R` |
| How spreadsheets are read | `R/elections_parse.R` |
| Office names, turnout, wide tables | `R/elections_tidy.R` |
| Data checks | `R/elections_validate.R` |
| Claude extraction | `R/elections_extract_llm.R` |
| Clerk page checker, registry updates | `R/elections_fetch.R` |
| Website | `index.qmd`, `_quarto.yml`, `data-raw/catalog_descriptions.csv` |
| Tests | `tests/testthat/` (run `Rscript tests/testthat.R`) |
