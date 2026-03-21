# Real Examples — ksTFL

![ksTFL logo](figures/ksTFL-logo.svg)

## Purpose

This vignette presents real-world clinical reporting examples built with
ksTFL. Each example walks through the complete pipeline — from raw input
data, through the R code that constructs the specification object, to
the final rendered document — so you can see exactly what goes in and
what comes out.

The examples are ordered by complexity: we start with a demographics
table that introduces core concepts (invisible columns, conditional
formatting, section headers), then move on to multi-language support,
complex spanning headers, data listings with grouping, and finally
figure output.

All code chunks use `eval = FALSE`; the rendered PDFs were pre-generated
and are embedded below. To reproduce any example locally, copy the code
into an R session with ksTFL loaded and run it.

## How examples are organised

Every example follows the same structure:

1.  **Input data** — the data frame that feeds
    [`create_table()`](https://example.com/reference/create_table.md) or
    [`create_figure()`](https://example.com/reference/create_figure.md)
2.  **Spec-building pipeline** — the ksTFL calls that define the
    document (with inline comments explaining each step)
3.  **Rendered output** — the resulting document embedded as PDF

A shared **session setup** block at the top configures page headers,
footers, and output defaults so individual examples stay focused on
their unique logic.

**Related vignettes:**

- [Getting
  Started](https://example.com/articles/Getting_Started_with_ksTFL.Rmd)
  — pipeline overview and core concepts
- [Reporting
  Examples](https://example.com/articles/Reporting_Examples_with_ksTFL.Rmd)
  — simpler worked examples covering each feature in isolation
- [Styling
  Guide](https://example.com/articles/Styling_Guide_with_ksTFL.Rmd) —
  style primitives and templates
- [Advanced
  StyleRows](https://example.com/articles/Advanced_StyleRows.Rmd) — deep
  dive into
  [`compute_cols()`](https://example.com/reference/compute_cols.md),
  [`c_glue()`](https://example.com/reference/c_glue.md),
  [`c_clear()`](https://example.com/reference/c_clear.md)

------------------------------------------------------------------------

## Session setup (shared across examples)

Every example in this vignette assumes the following session-wide
settings are in place. The
[`tfl_set_options()`](https://example.com/reference/tfl_set_options.md)
call registers default page headers (company name, confidentiality
notice, page numbering), a study-level sub-header, and page footers. It
also sets the output directory and footnote placement strategy. Because
these options are set once at the session level, individual specs don’t
need to repeat them — they inherit the defaults automatically:

``` r
library(ksTFL)
library(dplyr)

tfl_reset_options()
tfl_set_options(
  add_header(c("CRO Example LLC.", "CONFIDENTIAL",
               "Page {PAGE} of {NUMPAGES}")),
  add_header("Study: Miracle Drug 001"),
  add_footer(c("Showcase examples", "Program: inst/examples/showcase")),
  output_directory = '.',
  footnotePlace = "repeated"
)
```

------------------------------------------------------------------------

## Example 1 — Demographics table with conditional formatting

Demographics tables are among the most common deliverables in clinical
reporting. They summarise baseline patient characteristics by treatment
arm and typically include section headers, summary statistics, and
inferential test results.

This example shows how ksTFL handles all of that declaratively. The key
techniques demonstrated here are:

- **Invisible helper columns** — `SECTION`, `SECTION_ID`, and `MODELVAL`
  are kept out of the rendered document but drive conditional logic via
  [`compute_cols()`](https://example.com/reference/compute_cols.md).
  This is a core ksTFL pattern: your data frame can carry metadata
  columns that the rendering engine never prints but uses to control
  formatting.
- **[`c_addrow()`](https://example.com/reference/c_addrow.md)** —
  inserts bold section headers (Age, Sex, Race) above the first row of
  each group, pulling values directly from the hidden `SECTION` column.
- **[`c_merge()`](https://example.com/reference/c_merge.md) +
  [`c_glue()`](https://example.com/reference/c_glue.md)** — on p-value
  rows the treatment columns are merged into one cell and the p-value is
  appended, creating the typical “p = 0.041” display.
- **[`c_pageBreak()`](https://example.com/reference/c_pageBreak.md)** —
  forces a page break before the “Race” section for readability.
- **Spacer rows** — `c_addrow("below")` with `row_h4` adds visual
  separation between sections.

### Input data

The data frame has three demographic sections (Age, Sex, Race), each
containing summary statistics and an optional p-value stored in the
`MODELVAL` column. Note that `MODELVAL` is only populated on the p-value
rows — it is `NA` everywhere else, which is how we target those rows in
[`compute_cols()`](https://example.com/reference/compute_cols.md). The
`SECTION_ID` column is derived from the grouping and used for spacing
and page-break logic:

``` r
raw <- tibble(
  SECTION = c(
    rep("Age (years)", 6),
    rep("Sex", 3),
    rep("Race", 4)
  ),
  STAT = c(
    "n", "Mean (SD)", "Median", "Q1; Q3", "Min; Max", "p-value (ANOVA)",
    "Female", "Male", "p-value (Fisher)",
    "White", "Asian", "Black", "p-value (Fisher)"
  ),
  DRUGX = c("160", "55.2 (12.4)", "54.0", "47.0; 64.0", "18; 82", "",
            "88 (55.0%)", "72 (45.0%)", "",
            "130 (81.2%)", "18 (11.2%)", "12 (7.5%)", ""),
  PLCB  = c("158", "56.0 (11.9)", "55.0", "48.0; 63.0", "20; 81", "",
            "90 (57.0%)", "68 (43.0%)", "",
            "124 (78.5%)", "22 (13.9%)", "12 (7.6%)", ""),
  TOTAL = c("318", "55.6 (12.1)", "54.0", "47.5; 63.5", "18; 82", "",
            "178 (56.0%)", "140 (44.0%)", "",
            "254 (79.9%)", "40 (12.6%)", "24 (7.5%)", ""),
  MODELVAL = c(NA, NA, NA, NA, NA, "0.041",
               NA, NA, ">0.999",
               NA, NA, NA, "0.772")
) %>%
  group_by(SECTION) %>%
  mutate(SECTION_ID = cur_group_id()) %>%
  ungroup()
```

The first few rows of `raw`:

    # A tibble: 13 × 7
       SECTION      STAT             DRUGX          PLCB           TOTAL          MODELVAL SECTION_ID
       <chr>        <chr>            <chr>          <chr>          <chr>          <chr>         <int>
     1 Age (years)  n                160            158            318            NA                1
     2 Age (years)  Mean (SD)        55.2 (12.4)    56.0 (11.9)    55.6 (12.1)    NA                1
     3 Age (years)  Median           54.0           55.0           54.0           NA                1
     4 Age (years)  Q1; Q3           47.0; 64.0     48.0; 63.0     47.5; 63.5     NA                1
     5 Age (years)  Min; Max         18; 82         20; 81         18; 82         NA                1
     6 Age (years)  p-value (ANOVA)                                               0.041             1
     7 Sex          Female           88 (55.0%)     90 (57.0%)     178 (56.0%)    NA                2
     8 Sex          Male             72 (45.0%)     68 (43.0%)     140 (44.0%)    NA                2
     9 Sex          p-value (Fisher)                                              >0.999            2
    10 Race         White            130 (81.2%)    124 (78.5%)    254 (79.9%)    NA                3
    11 Race         Asian            18 (11.2%)     22 (13.9%)     40 (12.6%)     NA                3
    12 Race         Black            12 (7.5%)      12 (7.6%)      24 (7.5%)      NA                3
    13 Race         p-value (Fisher)                                              0.772             3

### Building the specification

``` r
spec <- create_table(raw) %>%

  # --- Titles and footnotes ---
  # Multi-line title: table number on first line, description on second.
  # toclevel = 1 makes this entry appear in the Table of Contents.
  add_title(
    c("Table S1",
      "Demographic and Baseline Characteristics"),
    toclevel = 1
  ) %>%
  # Secondary title in italics for the analysis population label
  add_title("Full Analysis Set", styleRef = "font_italic") %>%
  add_footnote(c(
    "Values are shown as n (%), mean (SD), median, or quartiles.",
    "P-values shown for section-level inferential tests."
  )) %>%

  # --- Column definitions ---
  # Hide helper columns: they won't appear in the document, but remain
  # available for compute_cols() conditions. This is the "invisible column"
  # pattern — SECTION drives group headers, SECTION_ID drives spacing and
  # page breaks, MODELVAL carries p-values for conditional formatting.
  define_cols(c(SECTION, SECTION_ID, MODELVAL), isVisible = FALSE) %>%

  # The statistics column: left-aligned header, values indented one level
  # to sit beneath the bold section headers inserted by c_addrow() below.
  define_cols(STAT,
    label     = "Parameter<br>  Statistic",
    labelStyleRef = "text_left",
    valueStyleRef = "indent_1"
  ) %>%

  # Treatment-arm columns: centred values, equal width, with N in the header.
  define_cols(c(DRUGX, PLCB, TOTAL),
    label     = c("DrugX<br>(N=160)", "Placebo<br>(N=158)", "Total<br>(N=318)"),
    valueStyleRef = "text_center",
    colWidth  = "16%"
  ) %>%

  # --- Conditional row actions (compute_cols) ---

  # 1. Section headers: for the first row of each SECTION
  #    group, insert a bold header row above it, pulling the
  #    text from the hidden SECTION column.
  compute_cols(
    firstOf(SECTION),
    c_addrow("above", value_from = SECTION, styleRef = "font_bold")
  ) %>%

  # 2. P-value rows: when MODELVAL is not NA, merge the DrugX and Placebo
  #    cells into one (with a thin top border and centred italic text),
  #    italicise the STAT label, and append the p-value after the merged cell.
  compute_cols(
    !is.na(MODELVAL),
    c_merge(c(DRUGX, PLCB), styleRef = f_combine("text_center", "bt_th", "i")),
    c_style(STAT, "i"),
    c_glue(DRUGX, "after", glue_col = MODELVAL)
  ) %>%

  # 3. Spacers: insert a thin empty row below each section for visual separation
  compute_cols(
    lastOf(SECTION_ID),
    c_addrow("below", styleRef = "row_h4")
  ) %>%

  # 4. Page break: force a new page before the Race section (group 3)
  compute_cols(
    SECTION_ID == 3 & firstOf(SECTION_ID),
    c_pageBreak()
  ) %>%

  # Document-level settings: narrow content area, no extra spacing
  set_document(
    contentWidth = "75%",
    topEmptyLine = "0pt",
    bottomEmptyLine = "0pt"
  )
```

### Render

``` r
create_report(spec) %>% write_doc("example_01")
```

### Rendered output

[Download
example_01.pdf](https://example.com/articles/pdf/example_01.pdf)

### Switching style templates

The example above uses the default embedded style template. One of
ksTFL’s design principles is that **content and styling are separate**:
you can switch to a completely different visual theme by changing a
single parameter on an already-built spec, without touching any of the
data or conditional logic:

``` r
spec <- set_document(spec, docTemplate = 'Navy_Pro')
create_report(spec) %>% write_doc("example_01_navy")
```

The same table is now rendered with the “Navy_Pro” template — different
fonts, colours, and border styles, but identical content and structure:

[Download
example_01_navy.pdf](https://example.com/articles/pdf/example_01_navy.pdf)

**Key take-aways from this example:**

- **Invisible columns** — `SECTION`, `SECTION_ID`, and `MODELVAL` never
  appear in the document, yet they drive all conditional logic. This is
  the core “metadata column” pattern.
- **`c_addrow(value_from = ...)`** pulls text from a hidden column into
  a dynamically inserted header row — no manual string duplication
  needed.
- **[`c_merge()`](https://example.com/reference/c_merge.md) +
  [`c_glue()`](https://example.com/reference/c_glue.md)** combine cells
  and append content from another column in a single
  [`compute_cols()`](https://example.com/reference/compute_cols.md)
  call, producing the merged p-value display.
- **[`c_pageBreak()`](https://example.com/reference/c_pageBreak.md)**
  gives fine-grained control over pagination.
- **Template switching** — `set_document(docTemplate = ...)` re-skins
  the entire output without modifying the spec pipeline.

## Example 2 — Demographics table (UTF-8 encoding support)

Clinical trials run in many countries, and regulatory submissions often
require documents in local languages. ksTFL has full UTF-8 support —
titles, footnotes, column labels, and data values can all contain
non-Latin characters without any special configuration.

This example reproduces the same demographics table structure from
Example 1, but entirely in Russian. The code also serves as a detailed
walkthrough of the spec-building pipeline, with comments explaining
every step.

### Input data

    # A tibble: 32 × 7
       CAT1          CAT2                     RPH104        PLCB          TOTAL         modelval SECTORD1
       <chr>         <chr>                    <chr>         <chr>         <chr>         <chr>       <dbl>
     1 Возраст (лет) n                        "16"          "17"          "33"          NA              1
     2 Возраст (лет) Сред. (СО)               "30.9 (11.3)" "41.6 (11.9)" "36.4 (12.6)" NA              1
     3 Возраст (лет) Медиана                  "28.0"        "40.0"        "33.0"        NA              1
     4 Возраст (лет) Q1; Q3                   "22.5; 36.5"  "33.0; 48.0"  "26.0; 45.0"  NA              1
     5 Возраст (лет) Мин.; Макс.              "18; 57"      "21; 59"      "18; 59"      NA              1
     6 Возраст (лет) p-величина (ANOVA μ₁=μ₂) ""            ""            ""            0.013           1
     7 Пол           Женский                  " 6 ( 37.5%)" " 7 ( 41.2%)" "13 ( 39.4%)" NA              2
     8 Пол           Мужской                  "10 ( 62.5%)" "10 ( 58.8%)" "20 ( 60.6%)" NA              2
     9 Пол           p-величина (Фишер)       ""            ""            ""            >0.999          2
    10 Раса          Белые                    "16 (100.0%)" "17 (100.0%)" "33 (100.0%)" NA              3

### Code

The pipeline follows the same pattern as Example 1: create table →
titles/footnotes → hide helper columns → define visible columns →
conditional row transforms → document settings. Reading the inline
comments below alongside Example 1 will help you see the one-to-one
correspondence:

``` r
### Build the specification object

drg_N   <- 16
plcb_N  <- 17
total_N <- 33

spec_dm_01 <- create_table(data) %>% 
  add_title(
    c("Таблица 1.2",
      "Демографические и другие исходные характеристики"),
    toclevel = 1
  ) %>% 
  add_title("Популяция FAS", styleRef = 'font_italic') %>% 
  add_footnote('Источник: Перечень 16.3; Перечень 16.33') %>% 
  # The CAT1 variable holds the category name. We want those
  # names to appear in the CAT2 column as section headers,
  # so we hide CAT1. We also hide the helper columns SECTORD1
  # and modelval (whose values we place into other cells):
  
  define_cols(c(CAT1, SECTORD1, modelval), isVisible = F) %>% 
  # First value of each CAT1 group becomes an extra header row:
  compute_cols(
    # built-in helper: first value within a group
    # (can also define composite groups from several variables)
    firstOf(CAT1),
    # Insert a bold row above with the value from CAT1
    c_addrow('above',
             value_from = CAT1,
             styleRef = 'font_bold')
  ) %>% 
  ## Indent CAT2 values to the right relative to the header.
  ## This can be done in two ways...
  # Method 1: via a per-row rule:
  #   compute_cols(!is.na(CAT2), c_style(CAT2, 'indent_1'))
  # Method 2: by setting the column style directly.
  #   Method 2 is preferable here because we apply the same
  #   style to every value in the column; doing it per-row via
  #   compute_cols creates unnecessary rendering overhead.
  # We also define the column label and header style:
  define_cols(CAT2,
              label = 'Параметр<br>  Статистика',
              valueStyleRef = 'indent_1',
              labelStyleRef = 'text_left') %>% 
  # Labels for the remaining treatment-arm columns:
  define_cols(c(RPH104, PLCB, TOTAL),
              label = c(
                paste0('Drug-001', '<br>(N=', drg_N, ')'),
                paste0('Плацебо', '<br>(N=', plcb_N, ')'),
                paste0('Всего', '<br>(N=', total_N, ')')
              ),
              # indent numbers from cell borders
              valueStyleRef = 'indent_1',
              colWidth = '15%'
  ) %>% 
  define_cols(everything(), valueStyleRef = 'fs_8') %>% 
  # Display modelval in a merged cell spanning RPH104 + PLCB:
  compute_cols(
    !is.na(modelval),
    # Merge cells; centre the value and draw a thin top border
    # to show it relates to both treatment columns:
    c_merge(c(RPH104, PLCB),
            styleRef = f_combine('text_center', 'bt_th', 'i')),
    c_style(CAT2, 'i'),
    # Append modelval into the merged cell
    c_glue(RPH104, 'after', glue_col = modelval)
  ) %>% 
  # Separators between groups
  compute_cols(
    lastOf(SECTORD1),
    c_addrow('below', styleRef = 'row_h4')
  ) %>% 
  # Manual page break: first 3 categories on page one,
  # the rest on page two:
  compute_cols(
    SECTORD1 == 4 & firstOf(SECTORD1),
    c_pageBreak()
  ) %>% 
  set_document(
    contentWidth = '75%',
    # Place footnotes in the document footer section
    footnotePlace = 'doc_footer',
    # Use an alternative embedded template
    docTemplate = 'Classic_landscape_times'
  ) 

  create_report(spec_dm_01) %>% write_doc("example_02_demog")
```

### Rendered output

[Download
example_02_demog.pdf](https://example.com/articles/pdf/example_02_demog.pdf)

## Example 3 — Adverse Events table with complex spanning headers

Adverse Event (AE) frequency tables are a staple of clinical safety
reporting. They often have many columns (treatment periods, follow-up
windows, overall totals) arranged under multi-level spanning headers.

This example demonstrates:

- **Three-tier spanning headers** via
  [`add_span_header()`](https://example.com/reference/add_span_header.md)
  with `stubOrder` to stack period sub-headers, a follow-up banner, and
  a top-level drug-arm header.
- **Custom page layout** — landscape A4 with tight margins to fit 14
  numeric columns plus two identifier columns.
- **`isID = TRUE`** — marks columns that should repeat on every page
  when the table spans multiple pages.
- **Conditional formatting** — bold SOC-level totals, inserted header
  rows per System Organ Class, and a forced page break between the “Any
  AE” summary and per-SOC detail.

### Input data

    # A tibble: 18 × 17
       SOC_GROUP SOC_PT  SEVERITY TRT_N TRT_E FU_0_6_N FU_0_6_E FU_GT6_N FU_GT6_E FU_0_8_N FU_0_8_E FU_GT8_N FU_GT8_E FU_TOTAL_N FU_TOTAL_E
       <chr>     <chr>   <chr>    <chr> <chr> <chr>    <chr>    <chr>    <chr>    <chr>    <chr>    <chr>    <chr>    <chr>      <chr>     
     1 Any AE    "Any A… ""       142 … 327   56 (31.… 71       93 (51.… 122      77 (42.… 103      75 (41.… 90       121 (67.2) 193       
     2 Any AE    ""      "1: Mil… 110 … 159   31 (17.… 34       59 (32.… 67       42 (23.… 49       46 (25.… 52       84 (46.7)  101       
     3 Any AE    ""      "2: Mod… 75 (… 94    17 (9.4) 18       25 (13.… 26       24 (13.… 25       18 (10.… 19       38 (21.1)  44        
     4 Any AE    ""      "3: Sev… 48 (… 51    12 (6.7) 12       17 (9.4) 18       20 (11.… 20       10 (5.6) 10       27 (15.0)  30        
     5 Any AE    ""      "4: Lif… 12 (… 13    4 (2.2)  4        7 (3.9)  7        5 (2.8)  5        6 (3.3)  6        11 (6.1)   11        
     6 Any AE    ""      "5: Dea… 9 (5… 10    3 (1.7)  3        4 (2.2)  4        4 (2.2)  4        3 (1.7)  3        7 (3.9)    7         
     7 SOC1      ""      ""       117 … 206   34 (18.… 35       60 (33.… 71       47 (26.… 55       46 (25.… 51       82 (45.6)  106       
     8 SOC1      ""      "1: Mil… 74 (… 101   18 (10.… 18       37 (20.… 39       23 (12.… 25       30 (16.… 32       52 (28.9)  57        
     9 SOC1      ""      "2: Mod… 50 (… 57    9 (5.0)  9        15 (8.3) 15       15 (8.3) 15       9 (5.0)  9        23 (12.8)  24        
    10 SOC1      ""      "3: Sev… 31 (… 33    6 (3.3)  6        11 (6.1) 12       13 (7.2) 13       5 (2.8)  5        16 (8.9)   18        
    11 SOC1      ""      "4: Lif… 8 (4… 8     0 (0.0)  0        3 (1.7)  3        0 (0.0)  0        3 (1.7)  3        3 (1.7)    3         
    12 SOC1      ""      "5: Dea… 7 (3… 7     2 (1.1)  2        2 (1.1)  2        2 (1.1)  2        2 (1.1)  2        4 (2.2)    4         
    13 SOC2      ""      ""       89 (… 121   31 (17.… 36       44 (24.… 51       40 (22.… 48       34 (18.… 39       68 (37.8)  87        
    14 SOC2      ""      "1: Mil… 54 (… 58    13 (7.2) 16       26 (14.… 28       20 (11.… 24       18 (10.… 20       38 (21.1)  44        
    15 SOC2      ""      "2: Mod… 32 (… 37    9 (5.0)  9        10 (5.6) 11       10 (5.6) 10       9 (5.0)  10       18 (10.0)  20        
    16 SOC2      ""      "3: Sev… 18 (… 18    6 (3.3)  6        6 (3.3)  6        7 (3.9)  7        5 (2.8)  5        11 (6.1)   12        
    17 SOC2      ""      "4: Lif… 5 (2… 5     4 (2.2)  4        4 (2.2)  4        5 (2.8)  5        3 (1.7)  3        8 (4.4)    8         
    18 SOC2      ""      "5: Dea… 2 (1… 3     1 (0.6)  1        2 (1.1)  2        2 (1.1)  2        1 (0.6)  1        3 (1.7)    3         

### Code

``` r
# --- Build the table specification ---
spec <- create_table(tbl) %>%

  # --- Custom styles ---
  # Define a smaller font size for the dense numeric columns,
  # and extra spacing after the title block for readability.
  add_style("font_small", s_font(font_size = "8pt")) %>%
  add_style("spacing_after10",
    s_paragraph(spacing = s_spacing(after = "10pt"))
  ) %>%

  # --- Title block ---
  # Three-line title: table number, full description, and population label.
  # toclevel = 1 adds it to the Table of Contents.
  add_title(c(
    "Table 11.32",
    "Frequency of AEs by System Organ Class, and Severity.",
    "SS Sub-population, Primary Enrolment into OLE"
  ), toclevel = 1, styleRef = "spacing_after10") %>%

  # --- Page layout ---
  # Dynamic page numbering in the footer
  add_footer("", "Page {PAGE} of {NUMPAGES}", "") %>%
  # Landscape A4 with tight margins — necessary to fit 16 columns
  set_page_style(
    page = p_page(
      size = "A4",
      orientation = "landscape",
      margins = p_margins(
        top = "12mm",
        bottom = "12mm",
        left = "5mm",
        right = "5mm",
        header = "8mm",
        footer = "8mm"
      )
    )
  ) %>%

  # --- Column definitions ---
  # Hide SOC_GROUP — it is used only by compute_cols() to insert
  # bold SOC header rows and trigger page breaks between groups.
  define_cols(SOC_GROUP, isVisible = FALSE) %>%

  # SOC / Preferred Term: left-aligned, repeats on page breaks (isID = TRUE)
  # so readers always know which SOC they are looking at.
  define_cols(SOC_PT,
              label = "MedDRA SOC",
              isID = TRUE,
              labelStyleRef = "text_left",
              valueStyleRef = f_combine("text_left", "font_small"),
              colWidth = "18%"
  ) %>%
  # Severity column: also repeats on continuation pages.
  define_cols(SEVERITY,
              label = "Severity",
              isID = TRUE,
              labelStyleRef = "text_left",
              valueStyleRef = f_combine("text_left", "font_small"),
              colWidth = "13%"
  ) %>%
  # All 14 numeric columns share the same layout: centred, small font,
  # equal width. The label vector alternates "n (%)" and "E" (events).
  define_cols(
    c(
      TRT_N, TRT_E,
      FU_0_6_N, FU_0_6_E,
      FU_GT6_N, FU_GT6_E,
      FU_0_8_N, FU_0_8_E,
      FU_GT8_N, FU_GT8_E,
      FU_TOTAL_N, FU_TOTAL_E,
      GRAND_N, GRAND_E
    ),
    label = rep(c("n (%)", "E"), 7),
    #labelStyleRef = f_combine("text_center","to_90"),
    labelStyleRef = "text_center",
    valueStyleRef = f_combine("text_center", "font_small"),
    colWidth = "4.3%"
  ) %>%

  # --- Multi-level spanning headers (3 tiers) ---
  # Spanning headers group columns visually. stubOrder controls the
  # vertical stacking order (1 = closest to column labels, 3 = top).

  # Tier 1 (stubOrder = 1): individual period sub-headers
  add_span_header(
    cols = c(TRT_N, TRT_E),
    label = "Treatment Period<br>n (%)",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(GRAND_N, GRAND_E),
    label = "Overall<br>n (%)",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_0_6_N, FU_0_6_E),
    label = "0-6 wks after<br>last dose",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_GT6_N, FU_GT6_E),
    label = ">6 wks after<br>last dose",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_0_8_N, FU_0_8_E),
    label = "0-8 wks after<br>last dose",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_GT8_N, FU_GT8_E),
    label = ">8 wks after<br>last dose",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_TOTAL_N, FU_TOTAL_E),
    label = "Total",
    stubOrder = 1
  ) %>%
  # Tier 2 (stubOrder = 2): groups all follow-up sub-periods under one
  # banner, making it clear that the five sub-columns all belong to
  # the Safety Follow-up Period.
  add_span_header(
    cols = c(FU_0_6_N, FU_0_6_E, FU_GT6_N, FU_GT6_E, 
             FU_0_8_N, FU_0_8_E, FU_GT8_N, FU_GT8_E, FU_TOTAL_N, FU_TOTAL_E),
    label = "Safety Follow-up Period<br>n (%)",
    stubOrder = 2
  ) %>%
  # Tier 3 (stubOrder = 3): top-level drug arm header spanning all
  # numeric columns. The label is a two-element vector (drug name + N).
  add_span_header(
    cols = c(
      TRT_N, TRT_E,
      FU_0_6_N, FU_0_6_E, FU_GT6_N, FU_GT6_E,
      FU_0_8_N, FU_0_8_E, FU_GT8_N, FU_GT8_E,
      FU_TOTAL_N, FU_TOTAL_E,
      GRAND_N, GRAND_E
    ),
    label = c("DrugX", sprintf("N=%d", N)),
    stubOrder = 3) %>%

  # --- Conditional row actions ---
  # Insert a bold SOC header row above the first row of each SOC group.
  # The "Any AE" group already has its own label in the data, so we skip it.
  compute_cols(
    firstOf(SOC_GROUP) & SOC_GROUP != "Any AE",
    c_addrow("above", value_from = SOC_GROUP, styleRef = "font_bold")
  ) %>%
  # Force a page break before SOC1 so the "Any AE" summary stands alone
  # on the first page and per-SOC detail starts on a fresh page.
  compute_cols(
    SOC_GROUP == "SOC1" & firstOf(SOC_GROUP),
    c_pageBreak()
  ) %>%
  # Bold the SOC-level totals: rows where SEVERITY is blank represent
  # the overall count for that SOC (not broken down by severity grade).
  compute_cols(
    SEVERITY == "",
    c_style(c(SOC_PT, SEVERITY), styleRef = "font_bold")
  ) %>%
  # Use a regulatory-style template (Arial font, conservative borders)
  set_document(docTemplate = 'Regulatory_Arial')

## Write the document
create_report(spec) %>% write_doc("example_03_ae")
```

### Rendered output

[Download
example_03_ae.pdf](https://example.com/articles/pdf/example_03_ae.pdf)

## Example 4 — Data listing with automatic two-level TOC

Data listings present individual patient records with minimal
aggregation. They often run to hundreds of pages, so navigation features
become essential. This example demonstrates:

- **`isGrouping = TRUE`** — marks columns as grouping variables. When
  grouping columns change value, ksTFL inserts a page break and
  generates a new sub-entry in the Table of Contents.
- **Dynamic subtitles** — `#ByGroup1`, `#ByGroup2`, etc. are
  placeholders that get replaced with the current group values,
  producing “Subject: 01001, Sex: M, Age (years): 26” automatically.
- **Two-level TOC** — the title and subtitle together create a nested
  TOC: listing title at level 1, per-subject entries at level 2.
- **Value-dependent formatting** —
  [`compute_cols()`](https://example.com/reference/compute_cols.md)
  flags pH values above 5.5 in red with a checkmark symbol.
- **Rotated column labels** — `to_90` rotates headers 90° to save
  horizontal space for the many narrow lab-parameter columns.

### Input data

    # A tibble: 164 × 15
       col_01 col_02 col_03 col_04          col_05    col_06     BILIU GLUCU KETONES NITRITE PH    PROTU RBCU  SPGRAV WBCU 
       <chr>  <chr>  <chr>  <chr>           <chr>     <chr>      <chr> <chr> <chr>   <chr>   <chr> <chr> <chr> <chr>  <chr>
     1 01001  26     M      Placebo         Screening 21-05-2021 -     -     -       -       5.5   -     -     1.030  -    
     2 01001  26     M      Placebo         Baseline  08-06-2021 -     -     -       -       6.0   -     -     1.025  -    
     3 01001  26     M      Placebo         Visit 2   15-06-2021 -     -     -       -       5.5   -     -     1.030  -    
     4 01001  26     M      Placebo + DrugX Baseline  15-06-2021 -     -     -       -       5.5   -     -     1.030  -    
     5 01001  26     M      Placebo + DrugX Visit 3   22-06-2021 -     -     -       -       6.0   -     -     1.030  -    
     6 01001  26     M      Placebo + DrugX Visit 4   05-07-2021 -     -     -       -       5.0   -     -     1.030  -    
     7 01001  26     M      Placebo + DrugX Visit 5   23-07-2021 -     -     -       -       5.5   -     -     1.030  -    
     8 01001  26     M      Placebo + DrugX Visit 6   02-08-2021 -     -     -       -       5.0   -     -     1.025  -    
     9 01001  26     M      Placebo + DrugX Visit 7   17-08-2021 -     -     -       -       5.5   -     -     1.030  -    
    10 01001  26     M      Placebo + DrugX Visit 8   02-09-2021 -     -     -       -       6.0   -     -     1.025  -    

### Code

``` r
spec_lbl_01 <- create_table(data) %>%

  # --- Title and dynamic subtitle ---
  # toclevel = 1 creates the top-level TOC entry for this listing.
  add_title(c("Listing 16.1", "Laboratory Data"), toclevel = 1) %>%
  # Dynamic subtitle: #ByGroup1/2/3 are replaced at render time with the
  # current values of the grouping columns (col_01, col_02, col_03).
  # toclevel = 2 creates a nested TOC entry per subject.
  add_subtitle(
    "Subject: #ByGroup1, Sex: #ByGroup2, Age (years): #ByGroup3",
    toclevel = 2
  ) %>%
  add_footnote('✓ - Value Outside Normal Ranges') %>%

  # --- Column definitions ---
  # Hide subject-level columns and mark them as grouping variables.
  # isGrouping = TRUE triggers automatic page breaks when any of these
  # columns change value, and populates the #ByGroupN placeholders.
  define_cols(
    c(col_01, col_02, col_03),
    isVisible = FALSE, isGrouping = TRUE
  ) %>%

  # Lab parameter columns: rotated 90° headers (to_90), left-aligned,
  # top-aligned (va_t), with a small indent.
  define_cols(
    !starts_with('col_'),
    labelStyleRef = f_combine(
      'al', 'va_t', 'to_90', 'indent_1'
    )
  ) %>%

  # Identifier columns: Treatment, Visit, Date repeat on
  # every page (isID = TRUE)
  # so the reader always knows the context.
  define_cols(c(col_04, col_05, col_06),
              label = c('Treatment', 'Visit', 'Date'),
              isID = TRUE
  ) %>%
  # Italicise Treatment and Visit values for visual distinction
  define_cols(c(col_04, col_05), valueStyleRef = 'i') %>%
  # Fix Date column width to prevent it from stretching
  define_cols(col_06, colWidth = '10%') %>%

  # Lab parameter columns (positions 7-15): narrow equal
  # widths, descriptive labels
  define_cols(7:15,
              colWidth = '6%',
              label = c(
                'Bilirubin', 'Glucose', 'Ketones',
                'Nitrites', 'pH', 'Protein',
                'Red Blood Cells',
                'Specific<br>Gravity',
                'White Blood Cells'
              )
  ) %>%

  # --- Conditional formatting ---
  # Flag abnormal pH values: if pH > 5.5, colour the cell red and
  # append a checkmark. replace_na(FALSE) prevents NA rows from matching.
  compute_cols(
    (as.numeric(PH) > 5.5) %>% replace_na(FALSE),
    c_style(PH, styleRef = 'fc_red'),
    c_glue(PH, 'after', text = '✓')
  ) %>%

  # --- Document settings ---
  # Use the Listings template (optimised for dense tabular data)
  set_document(
    docTemplate = 'Listings',
    topEmptyLine = '6pt',
    bottomEmptyLine = '6pt'
  )

## Write the document with a Table of Contents page
create_report(spec_lbl_01) %>% write_doc("example_04_list", toc = TRUE)
```

### Rendered output

[Download
example_04_list.pdf](https://example.com/articles/pdf/example_04_list.pdf)

### Splitting long tables across pages

When a table has too many columns to fit on one page, ksTFL can
automatically split the columns across multiple pages. The `isColBreak`
parameter on
[`define_cols()`](https://example.com/reference/define_cols.md) tells
the engine where to start a new column page. Columns marked with
`isID = TRUE` repeat on every column-page, ensuring the reader always
sees the identifying context.

For example, adding a column break at `PH` splits the listing into two
column groups — Bilirubin through Nitrites on the first page, and pH
through White Blood Cells on the second:

``` r
spec_lbl_02 <- spec_lbl_01 %>%
  # Add a column break at PH — all columns from PH onward move to a new page.
  # The Treatment, Visit, and Date columns (isID = TRUE) repeat automatically.
  define_cols(PH, isColBreak = TRUE)

create_report(spec_lbl_02) %>% write_doc("example_04_list_colbr", toc = TRUE)
```

### Split rendered output

[Download
example_04_list_colbr.pdf](https://example.com/articles/pdf/example_04_list_colbr.pdf)

## Example 5 — Figures and combined multi-spec reports with TOC

ksTFL is not limited to tables. The
[`create_figure()`](https://example.com/reference/create_figure.md)
function wraps a ggplot2 object (or an image file path) into a
`TFL_spec`, which can then receive titles, subtitles, footnotes, and
document settings just like a table.

The real power shows when you combine multiple specs into a single
document.
[`create_report()`](https://example.com/reference/create_report.md)
accepts any number of `TFL_spec` objects — tables, figures, and text —
and merges them into one report. When
[`write_doc()`](https://example.com/reference/write_doc.md) is called
with `toc = TRUE`, a Table of Contents is generated automatically from
the `toclevel` values set in titles.

This example creates three ggplot2 figures and writes them into a single
landscape document with a TOC page.

### Code

``` r
library(ggplot2)

# --- Figure 1: Fuel efficiency scatter plot from mtcars ---
# A straightforward scatter plot coloured by cylinder count.
t.fig <- ggplot(mtcars, aes(x = wt, y = mpg, colour = factor(cyl))) +
  geom_point(size = 3, alpha = 0.8) +
  scale_colour_manual(
    name   = "Cylinders",
    values = c("4" = "#2166AC", "6" = "#F4A582", "8" = "#D6604D")
  ) +
  labs(
    x = "Weight (1000 lbs)",
    y = "Miles per Gallon"
  ) +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom")

# Wrap the ggplot in a figure spec, then add titles and footnotes.
# toclevel = 1 adds this figure to the TOC.
t.fig.spec <- t.fig %>% create_figure() %>%
  add_title(
    c("Study Motor Trend",
      "Figure 1: Fuel Efficiency by Vehicle Weight"),
    toclevel = 1
  ) %>%
  add_subtitle("All vehicles, 1974") |>
  add_footnote("Source: 1974 Motor Trend US magazine (n = 32 vehicles).")

# figureScaleMode = "fitPage" scales the image to fill the available area.
t.fig.spec <- t.fig.spec %>%
  set_document(figureScaleMode = "fitPage",
               docTemplate = "Classic_landscape")

# --- Figure 2: Iris petal dimensions by species (violin + jitter) ---
# Violin plots show the distribution shape; jittered points show
# individual observations. Legend is turned off because species
# identity is clear from the x-axis labels.
t.fig2 <- ggplot(iris, aes(x = Species, y = Petal.Length, fill = Species)) +
  geom_violin(alpha = 0.4, colour = NA) +
  geom_jitter(aes(colour = Species), width = 0.15, size = 1.5, alpha = 0.7) +
  scale_fill_manual(values = c("setosa" = "#66C2A5", "versicolor" = "#FC8D62",
                                "virginica" = "#8DA0CB")) +
  scale_colour_manual(values = c("setosa" = "#66C2A5", "versicolor" = "#FC8D62",
                                  "virginica" = "#8DA0CB")) +
  labs(x = NULL, y = "Petal Length (cm)") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "none")

t.fig.spec2 <- t.fig2 %>% create_figure() %>%
  add_title(
    c("Study Iris",
      "Figure 2: Petal Length Distribution by Species"),
    toclevel = 1
  ) %>%
  add_subtitle("Anderson's Iris data set (n = 150)") |>
  add_footnote(
    "Each point represents one flower. Violin width shows density."
  ) %>%
  set_document(figureScaleMode = "fitPage",
               docTemplate = "Classic_landscape")

# --- Figure 3: Displacement vs horsepower (bubble + LOESS smooth) ---
# Bubble size encodes quarter-mile time; fill colour encodes transmission
# type (automatic vs manual). A LOESS curve with 95% CI ribbon shows
# the overall trend.
t.fig3 <- ggplot(mtcars, aes(x = disp, y = hp)) +
  geom_smooth(method = "loess", formula = y ~ x,
              se = TRUE, colour = "#B2182B", fill = "#FDDBC7", alpha = 0.3) +
  geom_point(aes(size = qsec, fill = factor(am)),
             shape = 21, alpha = 0.75, colour = "grey30") +
  scale_fill_manual(name = "Transmission",
                    values = c("0" = "#4393C3", "1" = "#D6604D"),
                    labels = c("0" = "Automatic", "1" = "Manual")) +
  scale_size_continuous(name = "1/4 Mile Time (s)", range = c(2, 8)) +
  labs(x = "Displacement (cu. in.)", y = "Horsepower") +
  theme_bw(base_size = 11) +
  theme(legend.position = "bottom",
        legend.box = "vertical",
        legend.margin = margin(t = 2, b = 2),
        legend.spacing.y = unit(2, "pt"))

t.fig.spec3 <- t.fig3 %>% create_figure() %>%
  add_title(c("Study Motor Trend",
              "Figure 3: Displacement vs Horsepower"), toclevel = 1) %>%
  add_subtitle("Bubble size = quarter-mile time; colour = transmission type") |>
  add_footnote(
    paste("LOESS curve with 95% CI shown in red.",
          "Source: 1974 Motor Trend US magazine.")
  ) %>%
  set_document(figureScaleMode = "fitPage",
               docTemplate = "Classic_landscape")

# --- Combine all three figures into a single document ---
# create_report() accepts any number of TFL_spec objects.
# write_doc() with toc = TRUE generates a Table of Contents from
# the toclevel values set in each spec's title.
t.fig.report <- create_report(t.fig.spec, t.fig.spec2, t.fig.spec3)

write_doc(t.fig.report, "figures_single_doc_toc", toc = TRUE)
```

### Rendered output

The resulting document contains a TOC page listing all three figures,
followed by one page per figure. Each figure fills the landscape page
thanks to `figureScaleMode = "fitPage"`.

[Download
figures_single_doc_toc.pdf](https://example.com/articles/pdf/figures_single_doc_toc.pdf)
