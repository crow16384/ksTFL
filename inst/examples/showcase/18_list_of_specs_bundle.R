source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

set.seed(20260528)

# -----------------------------------------------------------------------------
# Example 18: Passing a named list of specs to create_report()
#
# Demonstrates building specs independently (e.g. in a loop or separate
# program files), collecting them into a named list, and then calling
# create_report(specs) in a single step instead of splicing each spec as
# a variadic argument.
#
# The three sections of the output document are:
#   t_dm   — Demographics summary table
#   t_ae   — Adverse events by SOC
#   l_subj — Subject disposition listing
# -----------------------------------------------------------------------------

# ---- Data -------------------------------------------------------------------

dm <- tibble::tibble(
  Parameter = c(
    "Age (years)",     "  Mean (SD)",   "  Median (range)",
    "Sex, n (%)",      "  Male",        "  Female",
    "Race, n (%)",     "  White",       "  Black or African American", "  Other"
  ),
  Placebo  = c("", "54.2 (11.3)", "55 (18-78)", "", "38 (47.5%)", "42 (52.5%)", "", "60 (75.0%)", "12 (15.0%)", "8 (10.0%)"),
  Active   = c("", "52.8 (12.1)", "53 (20-81)", "", "41 (51.2%)", "39 (48.8%)", "", "57 (71.2%)", "15 (18.8%)", "8 (10.0%)")
)

ae_raw <- tibble::tibble(
  SOC  = c(
    "Infections and infestations", "Infections and infestations",
    "Gastrointestinal disorders",  "Gastrointestinal disorders",
    "Nervous system disorders",    "Nervous system disorders"
  ),
  TERM = c(
    "Any infection",              "Upper respiratory tract infection",
    "Any GI disorder",            "Nausea",
    "Any nervous system disorder","Headache"
  ),
  Active  = c("52 (65.0%)", "22 (27.5%)", "48 (60.0%)", "18 (22.5%)", "31 (38.8%)", "19 (23.8%)"),
  Placebo = c("47 (58.8%)", "20 (25.0%)", "39 (48.8%)", "12 (15.0%)", "28 (35.0%)", "16 (20.0%)")
)

subj <- tibble::tibble(
  SITE   = rep(sprintf("SITE-%02d", 1:4), each = 10),
  SUBJID = sprintf("KS-%04d", 1:40),
  ARM    = sample(c("Placebo", "Active"), 40, replace = TRUE),
  AGE    = sample(18:82, 40, replace = TRUE),
  STATUS = sample(
    c("Completed", "Discontinued - AE", "Discontinued - Withdrawal"),
    40, replace = TRUE, prob = c(0.75, 0.15, 0.10)
  )
) |> dplyr::arrange(SITE, SUBJID)

# ---- Build specs independently ----------------------------------------------

t_dm <- create_table(dm) |>
  add_title(c("Table 18.1", "Demographic and Baseline Characteristics"),
            toclevel = 1) |>
  add_subtitle("Full Analysis Set") |>
  define_cols(Parameter,
    label         = "Parameter",
    isID          = TRUE,
    colWidth      = "50%",
    labelStyleRef = "text_left",
    valueStyleRef = "text_left"
  ) |>
  define_cols(c(Placebo, Active),
    label         = c("Placebo\n(N=80)", "Active\n(N=80)"),
    valueStyleRef = "text_center",
    colWidth       = "25%"
  ) |>
  add_footnote("SD = standard deviation.")

t_ae <- create_table(ae_raw) |>
  add_title(c("Table 18.2", "Adverse Events by System Organ Class"), toclevel = 1) |>
  add_subtitle("Safety Analysis Set") |>
  define_cols(SOC, isVisible = FALSE) |>
  define_cols(TERM,
    label         = "System Organ Class / Preferred Term",
    isID          = TRUE,
    colWidth      = "46%",
    valueStyleRef = "text_left"
  ) |>
  define_cols(c(Active, Placebo),
    label    = c("Active n (%)", "Placebo n (%)"),
    colWidth = "25%",
    valueStyleRef = "text_center"
  ) |>
  compute_cols(
    firstOf(SOC),
    c_addrow("above", value_from = SOC, styleRef = "font_bold")
  ) |>
  add_footnote("Each subject counted once per SOC/PT.")

l_subj <- create_table(subj) |>
  add_title(c("Listing 18.1", "Subject Disposition"), toclevel = 1) |>
  define_cols(SITE,
    label      = "Site",
    isID       = TRUE,
    isGrouping = TRUE,
    dedupe     = TRUE
  ) |>
  define_cols(SUBJID,
    label    = "Subject",
    isID     = TRUE,
    isPaging = TRUE
  ) |>
  define_cols(ARM,   label = "Treatment",  valueStyleRef = "text_center") |>
  define_cols(AGE,   label = "Age",   type = "numeric", format = "%.0f",
              valueStyleRef = "text_center") |>
  define_cols(STATUS, label = "Disposition Status") |>
  compute_cols(
    STATUS != "Completed",
    c_style(c(SUBJID, STATUS), styleRef = f_combine("font_bold", "fc_red"))
  )

# ---- Collect into a named list and create report in one step ----------------
#
# Typical pattern when specs come from separate program files or a loop:
#
#   specs <- list(t_dm = t_dm, t_ae = t_ae, l_subj = l_subj)
#   report <- create_report(specs)
#
# This is equivalent to create_report(t_dm, t_ae, l_subj) but lets you
# build the list dynamically and pass it as a single argument.

specs <- list(
  t_dm   = t_dm,
  t_ae   = t_ae,
  l_subj = l_subj
)

report <- create_report(specs, t_dm)

# The list names become the key prefixes:
#   names(report) -> c("t_dm_<hash>", "t_ae_<hash>", "l_subj_<hash>")
cat("Report keys:\n")
cat(paste(" ", names(report), collapse = "\n"), "\n")

write_doc(report, "showcase_18_list_of_specs", toc = TRUE, metaPath = meta_dir)
