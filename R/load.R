# load.R ------------------------------------------------------------------------
# Load all project functions. In RStudio, or at the top of a script:
#
#   source(here::here("R/load.R"))
#
# Each file only defines functions; nothing runs until you call one.

local({
  files <- list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE)
  files <- files[basename(files) != "load.R"]
  for (f in files) source(f)
})
