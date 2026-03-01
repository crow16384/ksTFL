
devtools::load_all()
suppressPackageStartupMessages({
  library(tidyr)
  library(dplyr)
  library(stringr)
  library(tictoc)
})


##paths
out_dir  <- file.path(getwd(), "tmp", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
meta_dir <- file.path(out_dir, "meta")
dir.create(meta_dir, showWarnings = FALSE, recursive = TRUE)

## =============================================================================
## Helper: save + render a report in one step
## =============================================================================
save_and_render <- function(report, name, verbose = TRUE) {
  docx_name <- paste0(name, ".docx")
  
  result <- save_report(
    report,
    docFileName = docx_name,
    metaPath    = meta_dir,
    prettify    = TRUE
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

fl <- list_reports(meta_dir, sort_by = "doc_file")

clean_reports(meta_dir, keep_versions=1, dry_run=F)

replay_report(spec_json, meta_dir = meta_dir, output_path = out_dir)
