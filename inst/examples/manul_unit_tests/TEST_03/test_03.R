###TEST 03 Unit

devtools::load_all()
suppressPackageStartupMessages({
  library(tidyr)
  library(dplyr)
  library(stringr)
  library(tictoc)
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
  define_cols(Preferred_Drug_Name, label = 'Description', colWidth = '1.5cm') 
  
report_03_01 <- create_report(spec_03_01)
save_and_render(report_03_01, "test_03_01")



### TEST 03_02
tic()
spec_03_02 <- create_table(big_listing) %>% 
  add_title(c("Listing 3.1 WHO Drug Data", "Safety Population")) %>% 
  add_title(c("(Test unit 03)"), styleRef = "font_italic") %>% 
  add_footnote(c("This is the test unit 03 01", "Second line of footnote")) %>% 
  define_cols(Subject, label = 'Subject', colWidth = '2cm', labelStyleRef = 'font_bold', valueStyleRef = 'font_bold') %>% 
  define_cols(ATC_Level1, label = 'ATC Level 1', colWidth = '3cm') %>% 
  define_cols(ATC_Level2, label = 'ATC Level 2', colWidth = '3cm') %>% 
  define_cols(Preferred_Drug_Name, label = 'Description', colWidth = '5cm') 

report_03_02 <- create_report(spec_03_02)
save_and_render(report_03_02, "test_03_02",verbose = F)
toc()



### TEST 03_03

spec_03_03 <- create_table(stat_table_01) %>%
  set_page_style(
    page = p_page(
      size = "A4",
      orientation = "portrait",
      margins = p_margins(
        top = "10mm", bottom = "10mm",
        left = "5mm", right = "5mm",
        header = "5mm", footer = "5mm"
      )
    )
  ) %>% 
  add_style(id = "header_style",
            s_table_style(background_color = "#2C7E8B",
                          vertical_alignment = "center"),
            s_font(font_name = 'Calibri', font_size = '9pt', color = '#FFFFFF')) %>% 
  add_style(id = "body_style1",
            s_table_style(background_color = "#D9D4C7",
                          vertical_alignment = "center"),
            s_font(font_name = 'Calibri', font_size = '9pt')) %>% 
  add_style(id = "body_style2",
            s_table_style(background_color = "#E7E3D8",
                          vertical_alignment = "center"),
            s_font(font_name = 'Calibri', font_size = '9pt')) %>% 
  add_style(id = 'font_calibri', s_font(font_name = 'Calibri', font_size = '9pt')) %>% 
  add_title(c("Table 3.3: 30-days and 1-year Clinical Results"), styleRef = f_combine('text_left', 'font_bold', 'font_calibri')) %>%  
  add_footnote(c("*in some cases patients experienced a target vessel as well as a non-target vessel MI at 1 year (n=4 for non-complex group, n=1 for complex group).
Target lesion failure: composite of cardiac death, myocardial infarction that could not be clearly attributed to a vessel other than the target vessel and
clinically driven target lesion revascularisation. Target vessel failure: composite of cardiac death, target vessel MI and TVR. Patient-oriented composite
endpoint: composite of any death, any MI and any coronary revascularisation. BARC: Bleeding Academic Research Consortium")) %>% 
  define_cols(c(section, endpoint, `complex_pci_30-day`, `non_complex_pci_30-day`, `p_value_30-day`, `complex_pci_1-year`, `non_complex_pci_1-year`, `p_value_1-year`),
              label = c(' ', ' ', "Complex PCI<p>(N=10,119)", "Non-complex<p>PCI (N=26,485)", "<i>p</i>-value", 
                                   "Complex PCI<p>(N=9,793)", "Non-complex<p>PCI (N=25,596)", "<i>p</i>-value"), 
               labelStyleRef = 'header_style', valueStyleRef = 'body_style1') %>% 
  define_cols(c( section, `complex_pci_30-day`, `non_complex_pci_30-day`, `p_value_30-day`, `complex_pci_1-year`, `non_complex_pci_1-year`, `p_value_1-year`),
                colWidth = c('13%', '12%','12%','9%','12%','12%','9%')) %>% 
  define_cols(c(`complex_pci_30-day`, `non_complex_pci_30-day`, `complex_pci_1-year`, `non_complex_pci_1-year`),
              labelStyleRef = f_combine('header_style'), valueStyleRef = f_combine('body_style1', 'indent_1')) %>% 
  define_cols(section, dedupe = T) %>% 
  add_span_header(c(`complex_pci_30-day`, `non_complex_pci_30-day`, `p_value_30-day`), label = '30-day', labelStyleRef = 'header_style') %>% 
  add_span_header(c(`complex_pci_1-year`, `non_complex_pci_1-year`, `p_value_1-year`), label = '1-year', labelStyleRef = 'header_style', stubOrder = 1) %>% 
  compute_cols(everyNth(2), c_style(everything(), 'body_style2')) %>% 
  set_document(contentWidth = '95%')

report_03_03 <- create_report(spec_03_03)
save_and_render(report_03_03, "test_03_03")

### TEST 03_04

spec_03_04 <- create_table(stat_table_02) %>%
  set_page_style(
    page = p_page(
      size = "A4",
      orientation = "portrait",
      margins = p_margins(
        top = "10mm", bottom = "10mm",
        left = "10mm", right = "10mm",
        header = "10mm", footer = "10mm"
      )
    )
  ) %>% 
  add_style(id = "header_style",
            s_table_style(background_color = "#2C7E8B",
                          vertical_alignment = "center",
                          borders = s_borders(
                            top = s_border(color = "#FFFFFF", width = "1pt", line_style = "single"),
                            bottom = s_border(color = "#FFFFFF", width = "1pt", line_style = "single"),
                            left = s_border(color = "#FFFFFF", width = "1pt", line_style = "single"),
                            right = s_border(color = "#FFFFFF", width = "1pt", line_style = "single")
                          )),
            s_font(font_name = 'Calibri', font_size = '9pt', color = '#FFFFFF')) %>% 
  add_style(id = "body_style1",
            s_table_style(background_color = "#D9D4C7",
                          vertical_alignment = "center",
                          borders = s_borders(
                            top = s_border(color = "#000000", width = "1pt", line_style = "single"),
                            bottom = s_border(color = "#000000", width = "1pt", line_style = "single"),
                            left = s_border(color = "#000000", width = "1pt", line_style = "single"),
                            right = s_border(color = "#000000", width = "1pt", line_style = "single")
                          )),
            s_font(font_name = 'Calibri', font_size = '9pt')) %>% 
  add_style(id = "body_style2",
            s_table_style(background_color = "#E7E3D8",
                          vertical_alignment = "center"),
            s_font(font_name = 'Calibri', font_size = '9pt')) %>% 
  add_style(id = 'font_calibri', s_font(font_name = 'Calibri', font_size = '9pt')) %>% 
  add_title(c("Table 1. Baseline clinical characteristics for population divided into two groups: complex PCI and non-complex PCI."), styleRef = f_combine('text_left', 'font_bold', 'font_calibri')) %>%  
  add_footnote(c("*renal impartment was defined as a glomerular filtration rate of <60 mL/min/1.73 m<sub>2</sub>. CABG: coronary artery bypass graft(ing); LVEF: left ventricular ejection fraction; N: number of patients; PTCA: percutaneous transluminal coronary angioplasty; SD: standard deviation")) %>% 
  define_cols(c(parameter, subgroup, complex_pci, non_complex_pci, p_value),
              label = c(' ', ' ', "Complex PCI<p>(N=10,241)", "Non-complex<p>PCI (N=26,957)", "<i>p</i>-value"), 
              labelStyleRef = 'header_style', valueStyleRef = 'body_style1') %>% 
  define_cols(c(subgroup, complex_pci, non_complex_pci, p_value),
              colWidth = c('20%', '20%','20%','11%')) %>% 
  define_cols(c(complex_pci, non_complex_pci, p_value),
              labelStyleRef = f_combine('header_style'), valueStyleRef = f_combine('body_style1', 'indent_1')) %>% 
  define_cols(parameter, dedupe = T) %>% 
  compute_cols(everyNth(2), c_style(everything(), 'body_style2')) %>% 
  compute_cols(parameter != 'Clinical presentation', c_merge(c(parameter, subgroup))) %>% 
  set_document(contentWidth = '95%') 

report_03_04 <- create_report(spec_03_04)
save_and_render(report_03_04, "test_03_04")



### TEST 03_05 
spec_03_05 <- create_table(demography_tbl_01) %>% 
  add_title(c("Demographics Table", "Safety Population")) %>% 
  add_title(c("Third separate title"), styleRef = "font_italic") %>% 
  add_footnote(c("This is the test unit 01 03", "When < sign the <sup> tags parsing </sup> is broken")) %>% ##Issue with <> signs in the text with tags
  define_cols(c(value, stat, trt_a, trt_b, trt_c),
              label = c("Parameter<br>  Value", "Statistics", 
                        "Miracle Drug 1<br>(N=100)", "Miracle Drug 2<br>(N=100)", "Placebo<br>(N=100)")) %>% 
  define_cols(c(trt_a, trt_b, trt_c), valueStyleRef = 'text_center') %>% 
  define_cols(param, isVisible = F) %>% 
  define_cols(value, labelStyleRef = "text_left", colWidth = '5cm') %>% ###ISSUE: Width is broken in renderer when column is specified in fixed units.
  compute_cols(
    firstOf(param),
    c_merge(c(param, value), styleRef = 'font_bold')
  ) %>% 
  compute_cols(
    !is.na(value),
    c_style(value, styleRef = 'indent_1')
  ) %>% set_document(contentWidth = '90%')

print(spec_03_05)
report_03_05 <- create_report(spec_03_05)
save_and_render(report_03_05, "test_03_05")


### TEST 03_06 
spec_03_06_a <- create_table(demography_tbl_01) %>% 
  add_title(c("Demographics Table", "Safety Population")) %>% 
  add_title(c("Third separate title"), styleRef = "font_italic") %>% 
  add_footnote(c("This is the test unit 01 03", "When < sign the <sup> tags parsing </sup> is broken")) %>% 
  define_cols(c(value, stat, trt_a, trt_b, trt_c),
              label = c("Parameter<br>  Value", "Statistics", 
                        "Miracle Drug 1<br>(N=100)", "Miracle Drug 2<br>(N=100)", "Placebo<br>(N=100)")) %>% 
  define_cols(c(trt_a, trt_b, trt_c), valueStyleRef = 'text_center') %>% 
  define_cols(param, isVisible = F) %>% 
  define_cols(value, labelStyleRef = "text_left", colWidth = '15%') %>% 
  compute_cols(
    firstOf(param),
    c_merge(c(param, value), styleRef = 'font_bold')
  ) %>% 
  compute_cols(
    !is.na(value),
    c_style(value, styleRef = 'indent_1')
  ) %>% set_document(contentWidth = '90%')

spec_03_06 <- spec_03_06_a %>% set_page_style(docTemplate = 'Navy_Pro') 

report_03_06 <- create_report(spec_03_06)
save_and_render(report_03_06, "test_03_06")

spec_03_07 <- spec_03_06_a %>% set_page_style(docTemplate = 'Classic_landscape') 

report_03_07 <- create_report(spec_03_07)
save_and_render(report_03_07, "test_03_07")

spec_03_08 <- spec_03_06_a %>% set_page_style(docTemplate = 'Listings') 

report_03_08 <- create_report(spec_03_08)
save_and_render(report_03_08, "test_03_08")

spec_03_09 <- spec_03_06_a %>% set_page_style(docTemplate = 'Regulatory_Arial') 

report_03_09 <- create_report(spec_03_09)
save_and_render(report_03_09, "test_03_09")

spec_03_10 <- spec_03_06_a %>% set_page_style(docTemplate = 'Sage_Report') 

report_03_10 <- create_report(spec_03_10)
save_and_render(report_03_10, "test_03_10")

spec_03_11 <- spec_03_06_a %>% set_page_style(docTemplate = 'Warm_Slate') 

report_03_11 <- create_report(spec_03_11)
save_and_render(report_03_11, "test_03_11")

spec_03_12 <- spec_03_06_a %>% set_page_style(docTemplate = 'Carbon_Dark') 

report_03_12 <- create_report(spec_03_12)
save_and_render(report_03_12, "test_03_12")

spec_03_13 <- spec_03_06_a %>% set_page_style(docTemplate = 'Graphite_Rule') 

report_03_13 <- create_report(spec_03_13)
save_and_render(report_03_13, "test_03_13")

spec_03_14 <- spec_03_06_a %>% set_page_style(docTemplate = 'Silver_Grid') 

report_03_14 <- create_report(spec_03_14)
save_and_render(report_03_14, "test_03_14")
