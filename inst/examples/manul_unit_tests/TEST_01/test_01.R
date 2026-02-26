
library(ksTFL)
library(tidyverse)

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
  add_footer(c("Test Outputs", "Page {PAGE} of {NUMPAGES}"))
)
###########################


### TEST 01_01
spec_01_01 <- create_table(demography_tbl_01) %>% 
           add_title(c("Demographics Table", "Safety Population")) %>% 
           add_title(c("Third separate title"), styleRef = "font_italic") %>% 
           add_footnote(c("This is the test unit 01 01", "Second line of footnote")) %>% 
           define_cols(c(value, stat, trt_a, trt_b, trt_c),
                       label = c("Parameter<br>  Value", "Statistics", 
                                  "Miracle Drug 1\n(N=100)", "Miracle Drug 2\n(N=100)", "Placebo\n(N=100)")) %>% 
           define_cols(param, isVisible = F) %>% 
           define_cols(value, labelStyleRef = "text_left") %>% 
           compute_cols(
             firstOf(param),
             c_addrow("above", value_from = param, styleRef = "font_bold")
           )

report_01_01 <- create_report(spec_01_01)
save_and_render(report_01_01, "test_01_01")


### TEST 01_02
spec_01_02 <- create_table(demography_tbl_01) %>% 
  add_title(c("Demographics Table", "Safety Population")) %>% 
  add_title(c("Third separate title"), styleRef = "font_italic") %>% 
  add_footnote(c("This is the test unit 01 02", "Second line of footnote")) %>% 
  define_cols(c(value, stat, trt_a, trt_b, trt_c),
              label = c("Parameter\n  Value", "Statistics", 
                        "Miracle Drug 1\n(N=100)", "Miracle Drug 2\n(N=100)", "Placebo\n(N=100)")) %>% 
  define_cols(param, isVisible = F) %>% 
  compute_cols(
    firstOf(param),
    c_merge(c(param, value))
  )

report_01_02 <- create_report(spec_01_02)
save_and_render(report_01_02, "test_01_02")


### TEST 01_03 
#same as TEST 01_02 but with additional styling
spec_01_03 <- create_table(demography_tbl_01) %>% 
  add_title(c("Demographics Table", "Safety Population")) %>% 
  add_title(c("Third separate title"), styleRef = "font_italic") %>% 
  add_footnote(c("This is the test unit 01 03", "Second line of footnote")) %>% 
  define_cols(c(value, stat, trt_a, trt_b, trt_c),
              label = c("Parameter<br>  Value", "Statistics", 
                        "Miracle Drug 1<br>(N=100)", "Miracle Drug 2<br>(N=100)", "Placebo<br>(N=100)")) %>% 
  define_cols(c(trt_a, trt_b, trt_c), valueStyleRef = 'text_center') %>% 
  define_cols(param, isVisible = F) %>% 
  define_cols(value, labelStyleRef = "text_left") %>% 
  compute_cols(
    firstOf(param),
    c_merge(c(param, value), styleRef = 'font_bold')
  ) %>% 
  compute_cols(
    !is.na(value),
    c_style(value, styleRef = 'indent_1')
  )

report_01_03 <- create_report(spec_01_03)
save_and_render(report_01_03, "test_01_03")

