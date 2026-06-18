source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

set.seed(20260312)

# -----------------------------------------------------------------------------
# Showcase Example 11: Template-like AE frequency table (RU, real counts)
# Computes n (%) and E from synthetic subject/event data while preserving
# the same submission-style multi-level header layout.
# -----------------------------------------------------------------------------

severity_levels <- c(
  "1: Лёгкая",
  "2: Умеренная",
  "3: Тяжёлая",
  "4: Угр. жизни",
  "5: Смерть"
)

N <- 180L
subj <- tibble::tibble(SUBJID = sprintf("SS-%03d", seq_len(N)))

events <- tibble::tibble(
  SUBJID = sample(subj$SUBJID, size = 520, replace = TRUE),
  SOC_GROUP = sample(c("SOC1", "SOC2"), size = 520, replace = TRUE, prob = c(0.58, 0.42)),
  SEVERITY = sample(severity_levels, size = 520, replace = TRUE, prob = c(0.44, 0.30, 0.17, 0.06, 0.03)),
  PHASE = sample(c("TRT", "FU"), size = 520, replace = TRUE, prob = c(0.64, 0.36)),
  FU_WEEK = sample(1:16, size = 520, replace = TRUE)
) %>%
  dplyr::mutate(FU_WEEK = ifelse(PHASE == "FU", FU_WEEK, NA_integer_))

fmt_npct <- function(n, denom) {
  sprintf("%d (%.1f)", n, 100 * n / denom)
}

cell_counts <- function(df, cond) {
  dd <- df[cond, , drop = FALSE]
  c(fmt_npct(dplyr::n_distinct(dd$SUBJID), N), as.character(nrow(dd)))
}

make_row <- function(group_label, first_pt_label = NULL, sev = NULL) {
  base <- if (group_label == "Любое НЯЛ") {
    events
  } else {
    dplyr::filter(events, SOC_GROUP == group_label)
  }

  if (!is.null(sev)) {
    base <- dplyr::filter(base, SEVERITY == sev)
  }

  trt <- cell_counts(base, base$PHASE == "TRT")
  fu_0_6 <- cell_counts(base, base$PHASE == "FU" & base$FU_WEEK <= 6)
  fu_gt6 <- cell_counts(base, base$PHASE == "FU" & base$FU_WEEK > 6)
  fu_0_8 <- cell_counts(base, base$PHASE == "FU" & base$FU_WEEK <= 8)
  fu_gt8 <- cell_counts(base, base$PHASE == "FU" & base$FU_WEEK > 8)
  fu_tot <- cell_counts(base, base$PHASE == "FU")
  grand <- cell_counts(base, rep(TRUE, nrow(base)))

  tibble::tibble(
    SOC_GROUP = group_label,
    SOC_PT = if (is.null(first_pt_label)) "" else first_pt_label,
    SEVERITY = if (is.null(sev)) "" else sev,
    TRT_N = trt[1],
    TRT_E = trt[2],
    FU_0_6_N = fu_0_6[1],
    FU_0_6_E = fu_0_6[2],
    FU_GT6_N = fu_gt6[1],
    FU_GT6_E = fu_gt6[2],
    FU_0_8_N = fu_0_8[1],
    FU_0_8_E = fu_0_8[2],
    FU_GT8_N = fu_gt8[1],
    FU_GT8_E = fu_gt8[2],
    FU_TOTAL_N = fu_tot[1],
    FU_TOTAL_E = fu_tot[2],
    GRAND_N = grand[1],
    GRAND_E = grand[2]
  )
}

mk_block <- function(group_label, first_pt_label = NULL) {
  rows <- c(
    list(make_row(group_label, first_pt_label = first_pt_label, sev = NULL)),
    lapply(severity_levels, function(s) make_row(group_label, sev = s))
  )
  dplyr::bind_rows(rows)
}

tbl <- dplyr::bind_rows(
  mk_block("Любое НЯЛ", first_pt_label = "Любое НЯЛ"),
  mk_block("SOC1", first_pt_label = "PT 1"),
  mk_block("SOC2", first_pt_label = "PT 2")
)

spec <- create_table(tbl) %>%
  add_style("font_small", s_font(font_size = "8pt")) %>%
  add_style("spacing_after10", s_paragraph(spacing = s_spacing(after = "10pt"))) %>%
  add_title(c(
    "Таблица 11.32",
    "Частота НЯЛ по классу систем органов и предпочтительному термину и по степени тяжести.",
    "Подпопуляция SS Первичное включение в OLE"
  ), toclevel = 1, styleRef = "spacing_after10") %>%
  add_footer("", "Страница {PAGE} из {NUMPAGES}", "") %>%
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
  define_cols(SOC_GROUP, isVisible = FALSE) %>%
  define_cols(SOC_PT,
    label = "MedDRA SOC<br>  PT",
    isID = TRUE,
    labelStyleRef = "text_left",
    valueStyleRef = f_combine("text_left", "font_small"),
    colWidth = "18%"
  ) %>%
  define_cols(SEVERITY,
    label = "Тяжесть",
    isID = TRUE,
    labelStyleRef = "text_left",
    valueStyleRef = f_combine("text_left", "font_small"),
    colWidth = "13%"
  ) %>%
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
  add_span_header(
    cols = c(TRT_N, TRT_E),
    label = "Период терапии<br>n (%)",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(GRAND_N, GRAND_E),
    label = "Всего<br>n (%)",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_0_6_N, FU_0_6_E),
    label = "0-6 нед. после<br>последней дозы",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_GT6_N, FU_GT6_E),
    label = ">6 нед. после<br>последней дозы",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_0_8_N, FU_0_8_E),
    label = "0-8 нед. после<br>последней дозы",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_GT8_N, FU_GT8_E),
    label = ">8 нед. после<br>последней дозы",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_TOTAL_N, FU_TOTAL_E),
    label = "Всего",
    stubOrder = 1
  ) %>%
  add_span_header(
    cols = c(FU_0_6_N, FU_0_6_E, FU_GT6_N, FU_GT6_E, 
             FU_0_8_N, FU_0_8_E, FU_GT8_N, FU_GT8_E, FU_TOTAL_N, FU_TOTAL_E),
    label = "Период наблюдения за безопасностью<br>n (%)",
    stubOrder = 2
  ) %>%
  add_span_header(
    cols = c(TRT_N, TRT_E, FU_0_6_N, FU_0_6_E, FU_GT6_N, FU_GT6_E, FU_0_8_N, FU_0_8_E, 
             FU_GT8_N, FU_GT8_E, FU_TOTAL_N, FU_TOTAL_E, GRAND_N, GRAND_E),
    label = c("DrugX", sprintf("N=%d", N)),
    stubOrder = 3) %>%
  compute_cols(
    firstOf(SOC_GROUP) & SOC_GROUP != "Любое НЯЛ",
    c_addrow("above", value_from = SOC_GROUP, styleRef = "font_bold")
  ) %>%
  compute_cols(
    SOC_GROUP == "SOC1" & firstOf(SOC_GROUP),
    c_pageBreak()
  ) %>%
  compute_cols(
    SEVERITY == "",
    c_merge(c(SOC_PT, SEVERITY), styleRef = f_combine('b', 'indent_1')),
    #c_style(c(SOC_PT, SEVERITY), styleRef = "font_bold")
  )

create_report(spec) %>%
  write_doc("10_ae_template_ru_real_counts", toc = T, metaPath = meta_dir)
