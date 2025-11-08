# Missing Election Files - Download Checklist

Based on the Framingham City Clerk's election results page, here are the elections you need to download:

## 🔴 MISSING - Need to Download (17 elections)

### 2025 Elections (2)
- [ ] **November 4, 2025** - City General Election (Unofficial)
- [ ] **September 16, 2025** - City Preliminary

### 2024 Elections (3)
- [ ] **November 5, 2024** - State General Election
- [ ] **September 3, 2024** - State Primary
- [ ] **March 5, 2024** - Presidential Primary

### 2023 Elections (1)
- [ ] **September 19, 2023** - City Preliminary

### 2022 Elections (1)
- [ ] **January 11, 2022** - Special City Election

### 2020 Elections (2)
- [ ] **November 3, 2020** - State General Election
- [ ] **March 3, 2020** - Presidential Primary

### 2019 Elections (1)
- [ ] **September 17, 2019** - City Preliminary

### 2018 Elections (3)
- [ ] **December 11, 2018** - Special Election
- [ ] **November 6, 2018** - State General Election
- [ ] **September 4, 2018** - State Primary

### 2016 Elections (2)
- [ ] **November 8, 2016** - State General Election
- [ ] **September 8, 2016** - State Primary

---

## ⚠️ PARTIAL - Need to Verify (2 elections)

These files exist but the dates don't match the clerk's list - need to verify:

- [ ] **September 26, 2017** - City Preliminary
  - You have: `election_preliminary_2017_framingham_raw.pdf/xlsx`
  - Clerk says: September 26, 2017
  - **Action**: Open the file and check if it's really from Sep 26 or a different date

- [ ] **March 29, 2016** - Town Election
  - You have: `pre-city/OfficialResultsLocal2016.pdf/xlsx`
  - Clerk says: March 29, 2016
  - File might say: April 5, 2016 (or similar)
  - **Action**: Check which date is correct - town meeting date vs election date?

---

## ✅ HAVE - Already Downloaded (20 elections with files)

### 2023
- ✅ November 7, 2023 - City General (PDF + Excel)

### 2022
- ✅ November 8, 2022 - State General (PDF only - **needs extraction to Excel**)
- ✅ September 6, 2022 - State Primary (PDF + Excel)

### 2021
- ✅ November 2, 2021 - City General (PDF + Excel)
- ✅ September 14, 2021 - City Preliminary (PDF + Excel)
- ✅ January 12, 2021 - Special District 3 Council (PDF + Excel)

### 2020
- ✅ September 1, 2020 - State Primary (PDF + Excel)

### 2019
- ✅ November 5, 2019 - City General (PDF + Excel)

### 2017
- ✅ November 7, 2017 - City General (PDF + Excel)
- ✅ November 7, 2017 - Charter Vote (Excel)
- ✅ September 2017 - City Preliminary (PDF + Excel - **date needs verification**)
- ✅ April 4, 2017 - Town Election (PDF)

### 2016
- ✅ March 1, 2016 - Presidential Primary (PDF + Excel)
- ✅ March 2016 - Town Election (PDF + Excel - **date needs verification**)

---

## 📊 Summary Statistics

- **Total elections on clerk site (2016-2025)**: 39
- **Elections you have files for**: 20 (51%)
- **Elections missing**: 17 (44%)
- **Elections needing verification**: 2 (5%)

---

## 🎯 Priority Actions

### High Priority (Recent Elections)
1. Download **2024 Presidential Primary** (March 5, 2024)
2. Download **2024 State Primary** (September 3, 2024)
3. Download **2024 State General** (November 5, 2024)
4. Download **2023 City Preliminary** (September 19, 2023)

### Medium Priority (Complete 2020-2022 coverage)
5. Download **2020 State General** (November 3, 2020)
6. Download **2020 Presidential Primary** (March 3, 2020)
7. Download **2022 Special City Election** (January 11, 2022)
8. Download **2019 City Preliminary** (September 17, 2019)

### Lower Priority (2018 & 2016)
9. Download all 2018 elections (3 total)
10. Download 2016 state elections (2 total)

### Immediate Tasks
11. **Extract PDF to Excel**: 2022-11-08 State General (you have PDF only)
12. **Verify dates**: 2017-09-26 City Preliminary, 2016-03-29 Town Election

---

## 💾 File Naming for Downloads

When you download these files, save them as:

**Format**: `YYYY-MM-DD_{level}_{type}_{status}_framingham.pdf`

Examples:
- `2024-11-05_state_general_official_framingham.pdf`
- `2024-09-03_state_primary_official_framingham.pdf`
- `2024-03-05_federal_primary_official_framingham.pdf`
- `2023-09-19_municipal_preliminary_official_framingham.pdf`

Or just download with original names and update `election_files_inventory_complete.csv` with the mapping.

---

## 📝 Next Steps

1. **Visit**: https://www.framinghamma.gov/3095/Election-Results
2. **Download** the 17 missing elections (prioritize 2024 and recent elections)
3. **Update** `election_files_inventory_complete.csv` with original filenames
4. **Verify** the 2 partial matches (check actual dates in files)
5. **Extract** 2022-11-08 State General PDF to Excel
6. **Run** the PDF extraction pipeline on all PDFs

Then you'll have a complete collection ready for processing into SQLite + Parquet!
