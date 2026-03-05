suppressPackageStartupMessages({
  library(ksTFL)
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(stringr)
})

out_dir <- file.path(getwd(), "tmp", "showcase_output")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
meta_dir <- file.path(out_dir, "meta")
dir.create(meta_dir, recursive = TRUE, showWarnings = FALSE)

tfl_reset_options()
tfl_set_options(
  add_header(c("CRO Example LLC.", "CONFIDENTIAL", "Page {PAGE} of {NUMPAGES}")),
  add_header("Study: Miracle Drug 001"),
  add_footer(c("Showcase examples", "Program: inst/examples/showcase")),
  output_directory = out_dir,
  footnotePlace = "repeated"
)

cat("Showcase output:", out_dir, "\n")
