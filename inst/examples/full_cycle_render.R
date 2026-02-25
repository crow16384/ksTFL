## =============================================================================
## ksTFL Full-Cycle Rendering Examples
## =============================================================================
##
## This script exercises the COMPLETE pipeline from spec creation through
## C++ DOCX rendering. Each example builds a report and renders it.
##
## Prerequisites:
##   - ksTFL installed with C++ renderer compiled
##   - HarfBuzz / FreeType / minizip available (bundled in Docker image)
##
## Usage:
##   source(system.file("examples", "full_cycle_render.R", package = "ksTFL"))
##      -- OR --
##   Rscript inst/examples/full_cycle_render.R
## =============================================================================

library(ksTFL)

out_dir  <- file.path(getwd(), "tmp", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
meta_dir <- file.path(out_dir, "meta")
dir.create(meta_dir, showWarnings = FALSE, recursive = TRUE)

cat("Output directory:", out_dir, "\n")

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


## =============================================================================
## EXAMPLE 1: Minimal Table
## =============================================================================
cat("\n--- Example 1: Minimal table ------------------------------------------\n")

spec1 <- create_table(mtcars[1:10, ], docPrefix = "Table 1.1")
spec1 <- spec1 |>
  add_title("Motor Trend Car Road Tests", style="font_italic") |>
  add_title("Title2", style=f_combine("font_bold", "font_italic") ) |>
  add_subtitle("Subtitle", style="text_red") |>
  add_footnote("Source: 1974 Motor Trend US magazine.")

report1 <- create_report(spec1)
save_and_render(report1, "ex01_minimal_table")


## =============================================================================
## EXAMPLE 2: Styled Table with Custom Columns
## =============================================================================
cat("\n--- Example 2: Styled table with column definitions -------------------\n")

demo_data <- data.frame(
  SUBJID  = sprintf("SUBJ-%03d", 1:20),
  AGE     = sample(18:75, 20),
  SEX     = sample(c("Male", "Female"), 20, replace = TRUE),
  WEIGHT  = round(runif(20, 50, 120), 1),
  HEIGHT  = round(runif(20, 150, 195), 1),
  BMI     = round(runif(20, 18, 35), 2),
  stringsAsFactors = FALSE
)

spec2 <- create_table(demo_data, docPrefix = "Table 14.1.1")

# -- Styles --
spec2 <- spec2 |>
  add_style("hdr_bold",
    s_font(font_name = "Courier New", font_size = "9pt", bold = TRUE),
    s_paragraph(alignment = "center")
  ) |>
  add_style("body_right",
    s_paragraph(alignment = "right")
  ) |>
  add_style("body_center",
    s_paragraph(alignment = "center")
  ) |>
  add_style("id_col",
    s_paragraph(alignment = "left")
  ) |>
  add_style("highlight_row",
    s_font(bold = TRUE),
    s_table_style(
      background_color = "#FFF2CC",
      borders = s_borders(
        bottom = s_border(color = "#999999", width = "0.5pt", line_style = "single")
      )
    )
  )

# -- Columns --
spec2 <- spec2 |>
  define_cols(SUBJID,
    label         = "Subject ID",
    isID          = TRUE,
    colWidth      = "15%",
    labelStyleRef = "hdr_bold",
    valueStyleRef = "id_col"
  ) |>
  define_cols(c(AGE, WEIGHT, HEIGHT, BMI),
    label         = c("Age (yrs)", "Weight (kg)", "Height (cm)", "BMI"),
    type          = "numeric",
    format        = c("%.0f", "%.1f", "%.1f", "%.2f"),
    labelStyleRef = "hdr_bold",
    valueStyleRef = "body_right"
  ) |>
  define_cols(SEX,
    label         = "Sex",
    labelStyleRef = "hdr_bold",
    valueStyleRef = "body_center"
  )

# -- Content --
spec2 <- spec2 |>
  add_title(c("Study ABC-123", "Demographics and Baseline Characteristics")) |>
  add_subtitle("Full Analysis Set") |>
  add_footnote(c(
    "BMI = Body Mass Index (weight / height^2).",
    "Subjects with BMI > 30 are highlighted."
  ))

# -- Spanning header --
spec2 <- spec2 |>
  add_span_header(
    cols      = c("WEIGHT", "HEIGHT", "BMI"),
    label     = "Anthropometric Measures",
    stubOrder = 1
  )

# -- Document metadata --
spec2 <- spec2 |>
  set_document(
    docPrefix     = "Table 14.1.1",
    glueNumType   = TRUE,
    bodyTitles    = TRUE,
    bodyFootnotes = TRUE,
    hasData       = TRUE
  )

report2 <- create_report(spec2)
save_and_render(report2, "ex02_styled_demographics")


## =============================================================================
## EXAMPLE 3: Multi-Spec Report (Table + Text + Table)
## =============================================================================
cat("\n--- Example 3: Multi-spec report (Table + Text + Table) ---------------\n")

# --- First table: Summary statistics ---
summary_data <- data.frame(
  Parameter  = c("Systolic BP", "Systolic BP", "Systolic BP",
                  "Diastolic BP", "Diastolic BP", "Diastolic BP",
                  "Heart Rate", "Heart Rate", "Heart Rate"),
  Statistic  = rep(c("n", "Mean (SD)", "Median [Q1, Q3]"), 3),
  Placebo    = c("50", "132.4 (14.2)", "130 [122, 142]",
                 "50", "84.1 (9.3)",   "83 [78, 90]",
                 "50", "72.3 (8.1)",   "72 [66, 78]"),
  Treatment  = c("52", "125.8 (12.8)", "124 [117, 134]",
                 "52", "80.5 (8.7)",   "80 [74, 86]",
                 "52", "70.1 (7.5)",   "69 [64, 76]"),
  stringsAsFactors = FALSE
)

spec3a <- create_table(summary_data, docPrefix = "Table 14.2.1")
spec3a <- spec3a |>
  add_style("param_bold", s_font(bold = TRUE)) |>
  define_cols(Parameter,
    label    = "Parameter",
    isID     = TRUE,
    dedupe   = TRUE,
    colWidth = "25%"
  ) |>
  define_cols(Statistic,
    label = "Statistic",
    colWidth = "25%"
  ) |>
  define_cols(c(Placebo, Treatment),
    label = c("Placebo\n(N=50)", "Treatment\n(N=52)")
  ) |>
  add_title(c("Study ABC-123", "Summary of Vital Signs")) |>
  add_subtitle("Safety Analysis Set") |>
  add_footnote("BP = Blood Pressure; SD = Standard Deviation.")

# -- Conditional styling: bold the parameter name rows --
spec3a <- spec3a |>
  compute_cols(
    Statistic == "n",
    c_style(cols = c(Parameter, Statistic, Placebo, Treatment),
            styleRef = "param_bold")
  )

# --- Narrative text spec ---
spec3b <- create_text(docPrefix = "Listing 14.2.N1")
spec3b <- spec3b |>
  add_title(c("Study ABC-123", "Narrative Summary of Vital Signs")) |>
  add_body_text(paste(
    "Mean systolic blood pressure in the treatment group was 125.8 mmHg",
    "compared with 132.4 mmHg in the placebo group, a reduction of 6.6 mmHg.",
    "This difference was statistically significant (p < 0.001).",
    sep = " "
  )) |>
  add_body_text(paste(
    "No clinically significant changes were observed in diastolic blood",
    "pressure or heart rate between the two treatment groups.",
    sep = " "
  ))

# --- Second table: individual data ---
listing_data <- data.frame(
  SUBJID    = sprintf("SUBJ-%03d", 1:15),
  VISIT     = rep(c("Baseline", "Week 4", "Week 8"), 5),
  SBP       = sample(110:160, 15),
  DBP       = sample(60:100, 15),
  HR        = sample(55:100, 15),
  stringsAsFactors = FALSE
)

spec3c <- create_table(listing_data, docPrefix = "Listing 14.2.1")
spec3c <- spec3c |>
  define_cols(SUBJID,
    label  = "Subject",
    isID   = TRUE,
    dedupe = TRUE
  ) |>
  define_cols(c(SBP, DBP, HR),
    label = c("Systolic BP", "Diastolic BP", "Heart Rate"),
    type  = "numeric"
  ) |>
  add_title(c("Study ABC-123", "Listing of Vital Signs by Visit")) |>
  add_subtitle("Safety Analysis Set") |>
  add_footnote("All values in mmHg (BP) or bpm (HR).")

# --- Combine into one report ---
report3 <- create_report(spec3a, spec3b, spec3c)
save_and_render(report3, "ex03_multi_spec_report")


## =============================================================================
## EXAMPLE 4: Global Options & Page Layout (Landscape A4)
## =============================================================================
cat("\n--- Example 4: Global options & page layout ---------------------------\n")

# Reset options first to ensure a clean state
tfl_reset_options()

# Set session-wide defaults
tfl_set_options(
  add_header(c("KeyStat Solutions", "", "CONFIDENTIAL")),
  add_footer(c("Protocol ABC-123", "Page {PAGE} of {NUMPAGES}", "25FEB2026")),
  add_style("default_title",
    s_font(font_name = "Courier New", font_size = "10pt", bold = TRUE)
  ),
  set_page_style(
    page = p_page(
      size        = "A4",
      orientation = "landscape",
      margins     = p_margins(
        top    = "1.0in",
        bottom = "1.0in",
        left   = "0.75in",
        right  = "0.75in",
        header = "0.5in",
        footer = "0.5in"
      )
    )
  ),
  missings     = "--",
  gluePrefix   = TRUE
)

# Wide table data (many columns)
wide_data <- data.frame(
  TRT     = rep(c("Placebo", "Drug A", "Drug B"), each = 5),
  PARAM   = rep(c("ALT", "AST", "ALP", "TB", "Albumin"), 3),
  BASE    = round(rnorm(15, 25, 5), 1),
  WEEK4   = round(rnorm(15, 24, 5), 1),
  WEEK8   = round(rnorm(15, 23, 5), 1),
  WEEK12  = round(rnorm(15, 22, 5), 1),
  CHG4    = round(rnorm(15, -1, 2), 1),
  CHG8    = round(rnorm(15, -2, 2), 1),
  CHG12   = round(rnorm(15, -3, 2), 1),
  stringsAsFactors = FALSE
)

spec4 <- create_table(wide_data, docPrefix = "Table 14.3.1")
spec4 <- spec4 |>
  add_style("grp_break",
    s_table_style(
      borders = s_borders(
        top = s_border(color = "#666666", width = "0.5pt", line_style = "single")
      )
    )
  ) |>
  define_cols(TRT,
    label       = "Treatment",
    isID        = TRUE,
    isGrouping  = TRUE,
    dedupe      = TRUE,
    colWidth    = "12%"
  ) |>
  define_cols(PARAM,
    label    = "Parameter",
    colWidth = "10%"
  ) |>
  define_cols(c(BASE, WEEK4, WEEK8, WEEK12),
    label = c("Baseline", "Week 4", "Week 8", "Week 12"),
    type  = "numeric",
    format = "%.1f"
  ) |>
  define_cols(c(CHG4, CHG8, CHG12),
    label = c("Change Week 4", "Change Week 8", "Change Week 12"),
    type  = "numeric",
    format = "%.1f"
  ) |>
  add_span_header(
    cols      = c("BASE", "WEEK4", "WEEK8", "WEEK12"),
    label     = "Observed Values",
    stubOrder = 1
  ) |>
  add_span_header(
    cols      = c("CHG4", "CHG8", "CHG12"),
    label     = "Change from Baseline",
    stubOrder = 1
  ) |>
  add_title("Liver Function Tests by Treatment Group") |>
  add_subtitle("Safety Analysis Set") |>
  add_footnote(c(
    "ALT = Alanine Transaminase; AST = Aspartate Transaminase.",
    "ALP = Alkaline Phosphatase; TB = Total Bilirubin.",
    "Change = Post-baseline visit minus Baseline."
  )) |>
  set_document(
    glueNumType   = TRUE,
    bodyTitles    = TRUE,
    bodyFootnotes = TRUE,
    hasData       = TRUE
  )

# Conditional styling: add row separator between treatment groups
spec4 <- spec4 |>
  compute_cols(
    TRT != "",
    c_style(
      cols     = c(TRT, PARAM, BASE, WEEK4, WEEK8, WEEK12, CHG4, CHG8, CHG12),
      styleRef = "grp_break"
    )
  )

report4 <- create_report(spec4)
save_and_render(report4, "ex04_landscape_liver_function")

# Reset global options
tfl_reset_options()


## =============================================================================
## EXAMPLE 5: Column Breaks (Horizontal Pagination)
## =============================================================================
cat("\n--- Example 5: Column breaks for wide tables -------------------------\n")

# Wide AE table that should break into horizontal segments
ae_data <- data.frame(
  SUBJID    = sprintf("SUBJ-%03d", rep(1:10, each = 2)),
  AETERM    = sample(c("Headache", "Nausea", "Fatigue", "Dizziness",
                        "Insomnia", "Cough", "Back Pain", "Rash"), 20,
                     replace = TRUE),
  AESEV     = sample(c("Mild", "Moderate", "Severe"), 20, replace = TRUE),
  AESTDTC   = format(Sys.Date() - sample(1:180, 20), "%d%b%Y"),
  AEENDTC   = format(Sys.Date() - sample(0:90, 20), "%d%b%Y"),
  AESER     = sample(c("Y", "N"), 20, replace = TRUE, prob = c(0.1, 0.9)),
  AEREL     = sample(c("Related", "Not Related", "Possibly Related"), 20,
                     replace = TRUE),
  AEACN     = sample(c("None", "Dose Reduced", "Drug Withdrawn"), 20,
                     replace = TRUE, prob = c(0.7, 0.2, 0.1)),
  AEOUT     = sample(c("Resolved", "Ongoing", "Resolved with Sequelae"), 20,
                     replace = TRUE, prob = c(0.6, 0.3, 0.1)),
  stringsAsFactors = FALSE
)

spec5 <- create_table(ae_data, docPrefix = "Listing 16.2.7.1")
spec5 <- spec5 |>
  add_style("severe_row",
    s_font(bold = TRUE, color = "#CC0000"),
    s_table_style(background_color = "#FFE0E0")
  ) |>
  define_cols(SUBJID,
    label  = "Subject",
    isID   = TRUE,
    dedupe = TRUE
  ) |>
  define_cols(AETERM, label = "Adverse Event") |>
  define_cols(AESEV, label = "Severity") |>
  define_cols(AESTDTC, label = "Start Date") |>
  define_cols(AEENDTC, label = "End Date") |>
  define_cols(AESER,
    label      = "Serious",
    isColBreak = TRUE
  ) |>
  define_cols(AEREL, label = "Relationship") |>
  define_cols(AEACN, label = "Action Taken") |>
  define_cols(AEOUT, label = "Outcome") |>
  add_title(c("Study ABC-123",
              "Listing of Adverse Events")) |>
  add_subtitle("Safety Analysis Set") |>
  add_footnote("Events with Severity = Severe are highlighted in red.") |>
  set_document(hasData = TRUE, bodyTitles = TRUE, bodyFootnotes = TRUE)

# Highlight severe AEs
spec5 <- spec5 |>
  compute_cols(
    AESEV == "Severe",
    c_style(
      cols = c(SUBJID, AETERM, AESEV, AESTDTC, AEENDTC, AESER, AEREL, AEACN, AEOUT),
      styleRef = "severe_row"
    )
  )

report5 <- create_report(spec5)
save_and_render(report5, "ex05_ae_listing_colbreak")


## =============================================================================
## EXAMPLE 6: Row Actions — Merge, AddRow, PageBreak
## =============================================================================
cat("\n--- Example 6: Row actions (style, merge, addrow, pagebreak) ---------\n")

# Efficacy summary table
eff_data <- data.frame(
  Category  = c("Primary", "Primary", "Primary",
                "Secondary", "Secondary", "Secondary",
                "Exploratory", "Exploratory"),
  Endpoint  = c("ADAS-Cog", "ADAS-Cog", "ADAS-Cog",
                "CDR-SB", "CDR-SB", "CDR-SB",
                "MMSE", "MMSE"),
  Statistic = c("LSMean (SE)", "Difference", "p-value",
                "LSMean (SE)", "Difference", "p-value",
                "LSMean (SE)", "Difference"),
  Placebo   = c("-0.5 (0.4)", "", "",
                "-0.2 (0.3)", "", "",
                "0.1 (0.2)", ""),
  Treatment = c("-2.8 (0.4)", "-2.3 (0.5)", "0.0012",
                "-1.1 (0.3)", "-0.9 (0.4)", "0.0234",
                "-0.3 (0.2)", "-0.4 (0.3)"),
  stringsAsFactors = FALSE
)

spec6 <- create_table(eff_data, docPrefix = "Table 14.4.1")
spec6 <- spec6 |>
  add_style("cat_header",
    s_font(bold = TRUE),
    s_table_style(
      background_color = "#E8E8E8",
      borders = s_borders(
        top    = s_border(width = "1pt", line_style = "single"),
        bottom = s_border(width = "0.5pt", line_style = "single")
      )
    )
  ) |>
  add_style("pval_bold",
    s_font(bold = TRUE, color = "#006400")
  ) |>
  add_style("separator_line",
    s_table_style(
      borders = s_borders(
        bottom = s_border(color = "#AAAAAA", width = "0.5pt", line_style = "dashed")
      )
    )
  ) |>
  define_cols(Category,
    label      = "Category",
    isID       = TRUE,
    isGrouping = TRUE,
    dedupe     = TRUE,
    colWidth   = "15%"
  ) |>
  define_cols(Endpoint,
    label    = "Endpoint",
    dedupe   = TRUE,
    colWidth = "15%"
  ) |>
  define_cols(Statistic,
    label    = "Statistic",
    colWidth = "20%"
  ) |>
  define_cols(c(Placebo, Treatment),
    label = c("Placebo\n(N=100)", "Treatment\n(N=102)")
  ) |>
  add_title(c("Study ABC-123",
              "Summary of Efficacy Endpoints")) |>
  add_subtitle("Full Analysis Set — LOCF") |>
  add_footnote(c(
    "LSMean = Least Squares Mean; SE = Standard Error.",
    "p-values from ANCOVA model adjusted for baseline."
  )) |>
  set_document(
    glueNumType   = TRUE,
    bodyTitles    = TRUE,
    bodyFootnotes = TRUE,
    hasData       = TRUE
  )

# -- Row actions --
# Bold p-value rows with green color
spec6 <- spec6 |>
  compute_cols(
    Statistic == "p-value",
    c_style(cols = c(Statistic, Treatment), styleRef = "pval_bold")
  )

# Merge Category cells across columns when these are header rows
spec6 <- spec6 |>
  compute_cols(
    Statistic == "LSMean (SE)" & Category != "",
    c_addrow(pos = "above", styleRef = "cat_header")
  )

# Page break before "Exploratory" category
spec6 <- spec6 |>
  compute_cols(
    Category == "Exploratory" & Statistic == "LSMean (SE)",
    c_pageBreak()
  )

report6 <- create_report(spec6)
save_and_render(report6, "ex06_efficacy_row_actions")


## =============================================================================
## EXAMPLE 7: Text-Only Document
## =============================================================================
cat("\n--- Example 7: Text-only document -------------------------------------\n")

spec7 <- create_text(docPrefix = "Section 14.1")
spec7 <- spec7 |>
  add_style("section_title",
    s_font(font_name = "Arial", font_size = "14pt", bold = TRUE),
    s_paragraph(alignment = "center", spacing = s_spacing(after = "12pt"))
  ) |>
  add_style("body_italic",
    s_font(italic = TRUE)
  ) |>
  add_title("Summary of Clinical Study ABC-123", styleRef = "section_title") |>
  add_body_text(paste(
    "This was a Phase III, randomized, double-blind, placebo-controlled study",
    "to evaluate the efficacy and safety of Drug X in patients with moderate",
    "Alzheimer's disease. A total of 202 patients were randomized 1:1 to",
    "receive either Drug X 10 mg QD or matching placebo for 52 weeks.",
    sep = " "
  )) |>
  add_body_text(paste(
    "The primary endpoint was the change from baseline in ADAS-Cog 14 at",
    "Week 52. The key secondary endpoint was the change from baseline in",
    "CDR-SB at Week 52. Exploratory endpoints included MMSE and",
    "patient-reported Quality of Life (QoL) assessments.",
    sep = " "
  )) |>
  add_body_text(paste(
    "<b>Conclusion:</b> Drug X demonstrated a statistically significant",
    "improvement in the primary endpoint compared to placebo",
    "(p = 0.0012). The safety profile was consistent with known effects.",
    "No new safety signals were identified during the study.",
    sep = " "
  )) |>
  add_footnote("This summary is for illustrative purposes only.")

report7 <- create_report(spec7)
save_and_render(report7, "ex07_text_only")


## =============================================================================
## EXAMPLE 8: Combined Report — Table + Text + Listing (Full Clinical Package)
## =============================================================================
cat("\n--- Example 8: Full clinical package report ---------------------------\n")

# Reset options for clean state
tfl_reset_options()

# Set clinical defaults
tfl_set_options(
  add_header(c("KeyStat Solutions", "Study ABC-123", "CONFIDENTIAL")),
  add_footer(c("Source: ADSL, ADVS", "Page {PAGE} of {NUMPAGES}", "25FEB2026")),
  set_page_style(
    page = p_page(
      size        = "A4",
      orientation = "landscape",
      margins     = p_margins(
        top = "1.0in", bottom = "1.0in",
        left = "0.75in", right = "0.75in",
        header = "0.5in", footer = "0.5in"
      )
    )
  ),
  gluePrefix = TRUE,
  missings   = "--"
)

# --- Table 1: Demographics ---
adsl <- data.frame(
  TRT01P   = rep(c("Placebo", "Drug X 10mg"), each = 10),
  STAT     = rep(c("n", "Mean (SD)", "Median", "Min, Max", "n (%)", "n", "Mean (SD)", "Median", "Min, Max", "n (%)"), 2),
  PARAM    = rep(c(rep("Age (years)", 4), "Sex: Female",
                   rep("Age (years)", 4), "Sex: Female"), 1),
  VALUE    = c("100", "65.4 (8.2)", "66", "42, 85", "58 (58.0)",
               "102", "64.8 (7.9)", "65", "44, 82", "55 (53.9)"),
  stringsAsFactors = FALSE
)

tbl_demo <- create_table(adsl, docPrefix = "Table 14.1.1")
tbl_demo <- tbl_demo |>
  add_style("bold_val",
    s_font(bold = TRUE)
  ) |>
  define_cols(TRT01P,
    label      = "Treatment",
    isID       = TRUE,
    isGrouping = TRUE,
    dedupe     = TRUE
  ) |>
  define_cols(PARAM,
    label  = "Parameter",
    dedupe = TRUE
  ) |>
  define_cols(STAT,  label = "Statistic") |>
  define_cols(VALUE, label = "Value") |>
  add_title(c("Study ABC-123", "Demographic and Baseline Characteristics")) |>
  add_subtitle("Full Analysis Set") |>
  add_footnote("Percentages based on number of subjects in each treatment group.") |>
  set_document(
    glueNumType   = TRUE,
    bodyTitles    = TRUE,
    bodyFootnotes = TRUE,
    hasData       = TRUE
  )

# --- Text: Statistical Methods ---
txt_methods <- create_text(docPrefix = "Section 11.4")
txt_methods <- txt_methods |>
  add_title("Statistical Methods") |>
  add_body_text(paste(
    "Descriptive statistics (n, mean, SD, median, min, max) were provided",
    "for continuous variables. Frequencies and percentages were provided",
    "for categorical variables. The Full Analysis Set (FAS) included all",
    "randomized subjects who received at least one dose of study medication",
    "and had at least one post-baseline efficacy assessment.",
    sep = " "
  )) |>
  add_body_text(paste(
    "The primary analysis used a Mixed Model for Repeated Measures (MMRM)",
    "with treatment, visit, treatment-by-visit interaction, baseline score,",
    "and baseline-by-visit interaction as covariates.",
    sep = " "
  ))

# --- Listing: Subject-Level Data ---
adsl_listing <- data.frame(
  SUBJID  = sprintf("ABC-123-%04d", 1:25),
  TRT01P  = sample(c("Placebo", "Drug X 10mg"), 25, replace = TRUE),
  AGE     = sample(42:85, 25, replace = TRUE),
  SEX     = sample(c("M", "F"), 25, replace = TRUE, prob = c(0.45, 0.55)),
  RACE    = sample(c("White", "Black", "Asian", "Other"), 25,
                   replace = TRUE, prob = c(0.6, 0.2, 0.15, 0.05)),
  RANDDT  = format(as.Date("2024-01-15") + sample(0:90, 25), "%d%b%Y"),
  DCSREAS = sample(c("Completed", "Completed", "Completed",
                      "Adverse Event", "Withdrawal by Subject",
                      "Lost to Follow-up"), 25, replace = TRUE),
  stringsAsFactors = FALSE
)

lst_subj <- create_table(adsl_listing, docPrefix = "Listing 16.1.1")
lst_subj <- lst_subj |>
  add_style("dcsreas_red",
    s_font(color = "#CC0000", bold = TRUE)
  ) |>
  define_cols(SUBJID,
    label  = "Subject ID",
    isID   = TRUE
  ) |>
  define_cols(TRT01P, label = "Treatment") |>
  define_cols(AGE,
    label  = "Age",
    type   = "numeric",
    format = "%.0f"
  ) |>
  define_cols(SEX, label = "Sex") |>
  define_cols(RACE, label = "Race") |>
  define_cols(RANDDT, label = "Randomization\nDate") |>
  define_cols(DCSREAS, label = "Disposition") |>
  add_title(c("Study ABC-123", "Subject Disposition Listing")) |>
  add_subtitle("Full Analysis Set") |>
  add_footnote("Subjects who did not complete are highlighted.") |>
  set_document(
    glueNumType   = TRUE,
    bodyTitles    = TRUE,
    bodyFootnotes = TRUE,
    hasData       = TRUE
  )

# Highlight non-completers
lst_subj <- lst_subj |>
  compute_cols(
    DCSREAS != "Completed",
    c_style(
      cols = c(SUBJID, TRT01P, AGE, SEX, RACE, RANDDT, DCSREAS),
      styleRef = "dcsreas_red"
    )
  )

# --- Combine everything ---
full_report <- create_report(tbl_demo, txt_methods, lst_subj)
save_and_render(full_report, "ex08_full_clinical_package")

# Reset options
tfl_reset_options()


## =============================================================================
## EXAMPLE 9: isPaging — Very Long Table with Automatic Pagination
## =============================================================================
cat("\n--- Example 9: Long table with isPaging columns ----------------------\n")

# Generate large dataset
set.seed(42)
big_data <- data.frame(
  VISIT   = rep(paste("Visit", 1:10), each = 30),
  PARAM   = rep(rep(c("SBP", "DBP", "HR", "Temp", "Weight", "RR"), each = 5), 10),
  SUBJID  = sprintf("S%04d", rep(1:5, 60)),
  VALUE   = round(c(
    rnorm(50, 130, 15),  # SBP Visit 1-2
    rnorm(50, 82, 10),   # DBP
    rnorm(50, 74, 8),    # HR
    rnorm(50, 36.5, 0.5),# Temp
    rnorm(50, 75, 12),   # Weight
    rnorm(50, 16, 3)     # RR
  ), 1),
  stringsAsFactors = FALSE
)
# Replicate to ensure it's big enough to paginate
big_data <- rbind(big_data, big_data, big_data)

spec9 <- create_table(big_data, docPrefix = "Table 14.5.1")
spec9 <- spec9 |>
  define_cols(VISIT,
    label      = "Visit",
    isID       = TRUE,
    isPaging   = TRUE,
    dedupe     = TRUE
  ) |>
  define_cols(PARAM,
    label  = "Parameter",
    isID   = TRUE,
    dedupe = TRUE
  ) |>
  define_cols(SUBJID, label = "Subject") |>
  define_cols(VALUE,
    label  = "Value",
    type   = "numeric",
    format = "%.1f"
  ) |>
  add_title("Vital Signs by Visit and Parameter") |>
  add_subtitle("#ByGroup1 - #ByGroup2") |>
  add_footnote("Values shown as observed. No imputation applied.") |>
  set_document(
    glueNumType   = TRUE,
    bodyTitles    = TRUE,
    bodyFootnotes = TRUE,
    hasData       = TRUE
  )

report9 <- create_report(spec9)
save_and_render(report9, "ex09_long_paging_table")


## =============================================================================
## EXAMPLE 10: Rich Inline Markup
## =============================================================================
cat("\n--- Example 10: Rich inline markup in body text ----------------------\n")

spec10 <- create_text(docPrefix = "Note 1.1")
spec10 <- spec10 |>
  add_style("note_title",
    s_font(font_size = "12pt", bold = TRUE),
    s_paragraph(
      alignment = "center",
      spacing   = s_spacing(before = "6pt", after = "6pt")
    )
  ) |>
  add_title("Analysis Notes", styleRef = "note_title") |>
  add_body_text(paste0(
    "The <b>primary endpoint</b> was analyzed using an <i>MMRM model</i>. ",
    "Results showed a treatment effect of ",
    "<b>-2.3 points</b> (95% CI: -3.5, -1.1; ",
    "p = <b>0.0012</b>)."
  )) |>
  add_body_text(paste0(
    "Reference range for biomarker X: ",
    "2.5 <sup>a</sup> to 8.0 <sup>b</sup> mg/dL.<br>",
    "<sup>a</sup> Lower limit of normal.<br>",
    "<sup>b</sup> Upper limit of normal."
  )) |>
  add_body_text(paste0(
    "Chemical formula: H<sub>2</sub>O, CO<sub>2</sub>.<br>",
    "Concentration: 10<sup>-6</sup> mol/L."
  )) |>
  add_footnote("Inline tags supported: <b>, <i>, <u>, <sup>, <sub>, <br>, <p>.")

report10 <- create_report(spec10)
save_and_render(report10, "ex10_inline_markup")


## =============================================================================
## Summary
## =============================================================================
cat("\n========================================================================\n")
cat("Full-cycle rendering complete!\n")
cat("Output directory:", out_dir, "\n\n")

output_files <- list.files(out_dir, pattern = "\\.docx$", full.names = FALSE)
cat("Generated DOCX files:\n")
for (f in output_files) {
  fsize <- file.size(file.path(out_dir, f))
  cat(sprintf("  %-45s %s\n", f, format(fsize, big.mark = ",")))
}

meta_files <- list.files(meta_dir, full.names = FALSE)
cat(sprintf("\nMetadata files in %s: %d files\n", meta_dir, length(meta_files)))

cat("========================================================================\n")
