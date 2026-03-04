source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

set.seed(20260304)

n <- 180
listing <- tibble(
  SITE = sample(sprintf("SITE-%02d", 1:8), n, replace = TRUE),
  SUBJID = sprintf("SUBJ-%04d", sample(1:90, n, replace = TRUE)),
  VISIT = sample(c("Screening", "Baseline", "Week 2", "Week 4", "Week 8"), n, replace = TRUE),
  TEST = sample(c("ALT", "AST", "ALP", "Creatinine", "Glucose", "CRP"), n, replace = TRUE),
  UNIT = case_when(
    TEST %in% c("ALT", "AST", "ALP") ~ "U/L",
    TEST == "Creatinine" ~ "mg/dL",
    TEST == "Glucose" ~ "mg/dL",
    TRUE ~ "mg/L"
  ),
  VALUE = round(rlnorm(n, meanlog = 3.3, sdlog = 0.35), 2)
) %>%
  mutate(
    ULN = case_when(
      TEST == "ALT" ~ 40,
      TEST == "AST" ~ 40,
      TEST == "ALP" ~ 147,
      TEST == "Creatinine" ~ 1.2,
      TEST == "Glucose" ~ 100,
      TRUE ~ 10
    ),
    FLAG = case_when(
      VALUE >= ULN * 3 ~ "HIGH",
      VALUE >= ULN ~ "ABOVE ULN",
      TRUE ~ "NORMAL"
    ),
    RESULT_TXT = if_else(FLAG == "NORMAL", sprintf("%.2f", VALUE), sprintf("<b>%.2f</b> <i>↑</i>", VALUE))
  ) %>%
  arrange(VISIT, SITE, SUBJID, TEST)

spec <- create_table(listing,
  cols = c(SITE, SUBJID, VISIT, TEST, UNIT, RESULT_TXT, ULN, FLAG)
) %>%
  add_title(c("Listing S2", "Laboratory Listing with Grouping, Paging and Column Break"), toclevel = 1) %>%
  add_subtitle("Safety Analysis Set") %>%
  add_footnote(c(
    "Out-of-range values are shown in bold with upward flag.",
    "Column break starts at ULN to demonstrate horizontal pagination."
  )) %>%
  define_cols(SITE, label = "Site", isID = TRUE, isGrouping = TRUE, dedupe = TRUE) %>%
  define_cols(SUBJID, label = "Subject", isID = TRUE, dedupe = TRUE) %>%
  define_cols(VISIT, label = "Visit", isPaging = TRUE, dedupe = TRUE) %>%
  define_cols(TEST, label = "Analyte") %>%
  define_cols(UNIT, label = "Unit") %>%
  define_cols(RESULT_TXT, label = "Result", labelStyleRef = "text_left") %>%
  define_cols(ULN, label = "ULN", type = "numeric", format = "%.2f", isColBreak = TRUE, valueStyleRef = "text_center") %>%
  define_cols(FLAG, label = "Flag", valueStyleRef = "text_center") %>%
  compute_cols(
    firstOf(SITE),
    c_addrow("above", value_from = SITE, styleRef = f_combine("font_bold", "bt_th"))
  ) %>%
  compute_cols(
    FLAG != "NORMAL",
    c_style(c(RESULT_TXT, FLAG), styleRef = "font_bold")
  ) %>%
  set_document(contentWidth = "90%")

create_report(spec) %>% write_doc("showcase_02_listing_paging_colbreak", toc = TRUE, metaPath = meta_dir)
