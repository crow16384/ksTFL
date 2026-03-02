
#library(ksTFL)
devtools::load_all()
suppressPackageStartupMessages({
  library(tidyr)
  library(dplyr)
  library(stringr)
})

out_dir  <- file.path(getwd(), "tmp", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
meta_dir <- file.path(out_dir, "meta")
dir.create(meta_dir, showWarnings = FALSE, recursive = TRUE)

cat("Output directory:", out_dir, "\n")

## =============================================================================
## Helper: save + render a report in one step                               ####
## =============================================================================
save_and_render <- function(report, name, verbose = TRUE, toc=F) {
  docx_name <- paste0(name, ".docx")

  result <- save_report(
    report,
    docFileName = docx_name,
    metaPath    = meta_dir,
    prettify    = TRUE,
    insertTOC = toc
  )

  spec_path   <- file.path(meta_dir, result$spec_file)
  output_path <- file.path(out_dir, docx_name)

  render_docx(
    spec_json   = spec_path,
    output_path = output_path,
    verbose     = verbose
  )

  cat(sprintf("  [OK] %s -> %s\n", name, output_path))
  invisible(output_path)
}
