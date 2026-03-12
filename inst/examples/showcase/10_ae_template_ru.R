source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

set.seed(20260312)

# -----------------------------------------------------------------------------
# Showcase Example 10: Template-like AE frequency table (RU)
# Mirrors a submission-style layout with SOC/PT + severity rows and
# multi-level treatment/follow-up period headers.
# -----------------------------------------------------------------------------

severity_levels <- c(
  "1: Лёгкая",
  "2: Умеренная",
  "3: Тяжёлая",
  "4: Угр. жизни",
  "5: Смерть"
)

mk_block <- function(group_label, first_pt_label = NULL) {
  n_rows <- 1L + length(severity_levels)
  pt_col <- c(if (is.null(first_pt_label)) "" else first_pt_label, rep("", length(severity_levels)))

  tibble::tibble(
    SOC_GROUP = rep(group_label, n_rows),
    SOC_PT = pt_col,
    SEVERITY = c("", severity_levels),
    TRT_N = rep("xx (xx.x)", n_rows),
    TRT_E = rep("xx", n_rows),
    FU_0_6_N = rep("xx (xx.x)", n_rows),
    FU_0_6_E = rep("xx", n_rows),
    FU_GT6_N = rep("xx (xx.x)", n_rows),
    FU_GT6_E = rep("xx", n_rows),
    FU_0_8_N = rep("xx (xx.x)", n_rows),
    FU_0_8_E = rep("xx", n_rows),
    FU_GT8_N = rep("xx (xx.x)", n_rows),
    FU_GT8_E = rep("xx", n_rows),
    FU_TOTAL_N = rep("xx (xx.x)", n_rows),
    FU_TOTAL_E = rep("xx", n_rows),
    GRAND_N = rep("xx (xx.x)", n_rows),
    GRAND_E = rep("xx", n_rows),
    PB = c(is.null(first_pt_label), rep(FALSE, length(severity_levels)))
  )
}

tbl <- dplyr::bind_rows(
  mk_block("Любое НЯЛ", first_pt_label = "Любое НЯЛ"),
  mk_block("SOC1"),
  mk_block("SOC2")
)

spec <- create_table(tbl) %>%
  add_style("font_small", s_font(font_size = "8pt")) %>%
  add_title(c(
    "Таблица 11.32",
    "Частота НЯЛ по классу систем органов и предпочтительному термину и по степени тяжести.",
    "Подпопуляция SS Первичное включение в OLE"
  ), toclevel = 1) %>%
  add_subtitle(c("RPH-104", "N=XX")) %>%
  add_footer("", "Страница {PAGE} из {NUMPAGES}", "") %>%
  set_page_style(
    page = p_page(
      size = "A4",
      orientation = "landscape",
      margins = p_margins(
        top = "12mm",
        bottom = "12mm",
        left = "10mm",
        right = "10mm",
        header = "8mm",
        footer = "8mm"
      )
    )
  ) %>%
  define_cols(c(SOC_GROUP, PB), isVisible = FALSE) %>%
  define_cols(SOC_PT,
    label = "MedDRA SOC<br>MedDRA PT",
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
    labelStyleRef = "text_center",
    valueStyleRef = f_combine("text_center", "font_small"),
    colWidth = "4.3%"
  ) %>%
  add_span_header(
    cols = c(TRT_N, TRT_E),
    label = "Период терапии<br>n (%)",
    stubOrder = 0
  ) %>%
  add_span_header(
    cols = c(FU_0_6_N, FU_0_6_E, FU_GT6_N, FU_GT6_E, FU_0_8_N, FU_0_8_E, FU_GT8_N, FU_GT8_E, FU_TOTAL_N, FU_TOTAL_E),
    label = "Период наблюдения за безопасностью<br>n (%)",
    stubOrder = 0
  ) %>%
  add_span_header(
    cols = c(GRAND_N, GRAND_E),
    label = "Всего<br>n (%)",
    stubOrder = 0
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
    c_style(c(SOC_PT, SEVERITY), styleRef = "font_bold")
  )

create_report(spec) %>%
  write_doc("showcase_10_ae_template_ru", toc = FALSE, metaPath = meta_dir)
