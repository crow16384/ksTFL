###TEST 03 Unit

devtools::load_all()
suppressPackageStartupMessages({
  library(tidyr)
  library(dplyr)
  library(stringr)
})

source(file.path(getwd(), './inst/examples/manul_unit_tests/dummy_data.R')) ##sourcing dummy data definitions

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


#############################################
##Common doc headers/footers
tfl_reset_options()
tfl_set_options(
  add_header(c("Miracle Drug" , "CONFIDENTIAL", "KeyStat LLC.")),
  add_footer(c("Test Outputs", "Page {PAGE} of {NUMPAGES}")),
  add_footer(c("Program: test_03.R"))
)
###########################



### TEST 03_01
spec_03_01 <- create_table(whodd_tbl) %>% 
  add_title(c("Listing 3.1 WHO Drug Data", "Safety Population")) %>% 
  add_title(c("(Test unit 03)"), styleRef = "font_italic") %>% 
  add_footnote(c("This is the test unit 03 01", "Second line of footnote")) %>% 
  define_cols(Subject, label = 'Subject', colWidth = '2cm', labelStyleRef = 'font_bold', valueStyleRef = 'font_bold') %>% 
  define_cols(ATC_Level1, label = 'ATC Level 1', colWidth = '3cm') %>% 
  define_cols(ATC_Level2, label = 'ATC Level 2', colWidth = '3cm') %>% 
  define_cols(Preferred_Drug_Name, label = 'Description', colWidth = '3cm') 
  
report_03_01 <- create_report(spec_03_01)
save_and_render(report_03_01, "test_03_01")
