source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

# -----------------------------------------------------------------------------
# Premium Example 06: QC reproducibility workflow
# Demonstrates deterministic build, dual-run metadata, replay and cleanup preview
# -----------------------------------------------------------------------------

build_qc_report <- function(seed = 20260304) {
  set.seed(seed)

  qc <- tibble::tibble(
    PARAM = c("N", "Mean (SD)", "Median", "Q1;Q3", "Min;Max", "Missing"),
    Active = c("162", "45.2 (11.6)", "44.0", "37.0;52.0", "18;78", "2"),
    Placebo = c("159", "46.1 (11.8)", "45.0", "38.0;53.0", "19;80", "1"),
    Diff = c("", "-0.9", "-1.0", "", "", "")
  )

  spec_tbl <- create_table(qc) %>%
    add_title(c("Table P6.1", "QC Reproducibility Control Table"), toclevel = 1) %>%
    add_subtitle("Deterministic seed-controlled input") %>%
    define_cols(PARAM, label = "Parameter", isID = TRUE, colWidth = "38%") %>%
    define_cols(c(Active, Placebo), label = c("Active", "Placebo"), valueStyleRef = "text_center", colWidth = "20%") %>%
    define_cols(Diff, label = "Difference", valueStyleRef = "text_center", colWidth = "16%") %>%
    compute_cols(PARAM == "Mean (SD)", c_style(c(PARAM, Diff), styleRef = "font_bold")) %>%
    add_footnote("Seed fixed for reproducibility: 20260304")

  spec_txt <- create_text() %>%
    add_title("QC Notes", toclevel = 1) %>%
    add_body_text("This report is generated twice from identical deterministic input and compared via metadata references.")

  create_report(spec_tbl, spec_txt)
}

report <- build_qc_report()

run1 <- save_report(
  report,
  docFileName = "premium_06_qc_run1.docx",
  outDir = out_dir,
  metaPath = meta_dir,
  prettify = TRUE
)

run2 <- save_report(
  report,
  docFileName = "premium_06_qc_run2.docx",
  outDir = out_dir,
  metaPath = meta_dir,
  prettify = TRUE
)

cat("Run 1 spec:", run1$spec_file, "\n")
cat("Run 2 spec:", run2$spec_file, "\n")
cat("Same spec hash:", identical(run1$spec_file, run2$spec_file), "\n")

cat("\nLatest metadata entries:\n")
lr <- list_reports(meta_dir, sort_by = "datetime")
print(lr)

qc_rows <- lr[lr$doc_file %in% c("premium_06_qc_run1.docx", "premium_06_qc_run2.docx"), , drop = FALSE]
if (nrow(qc_rows) >= 2) {
  qc_rows <- qc_rows[order(qc_rows$datetime, decreasing = TRUE), , drop = FALSE]
  same_data_refs <- identical(qc_rows$data_refs[1], qc_rows$data_refs[2])
  cat("QC data_refs equal:", same_data_refs, "\n")
}

replay_dir <- file.path(out_dir, "replayed")
dir.create(replay_dir, recursive = TRUE, showWarnings = FALSE)
replay_path <- file.path(replay_dir, "premium_06_qc_replay.docx")
replay_report(run1$spec_file, meta_dir = meta_dir, output_path = replay_path)

cat("\nCleanup dry-run (keep latest 3 versions):\n")
print(clean_reports(meta_dir, keep_versions = 3, dry_run = TRUE))
