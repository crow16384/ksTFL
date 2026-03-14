source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

mini <- tibble(
  PARAM = c("N", "Mean", "Median"),
  DrugA = c("120", "45.7", "44.9"),
  Placebo = c("118", "47.1", "46.3")
)

spec <- create_table(mini) %>%
  add_title(c("Table S4", "Metadata / Replay / Clean workflow"), toclevel = 1) %>%
  define_cols(PARAM, isID = TRUE, label = "Parameter") %>%
  define_cols(c(DrugA, Placebo), label = c("Drug A", "Placebo"), valueStyleRef = "text_center") %>%
  add_footnote("This example demonstrates save_report, list_reports, replay_report, clean_reports.")

rep <- create_report(spec)
meta <- save_report(rep,
  docFileName = "showcase_04_meta_replay_clean.docx",
  outDir = out_dir,
  metaPath = meta_dir,
  prettify = TRUE
)

cat("Saved spec JSON:", meta$spec_file, "\n")
cat("Known reports in metadata store:\n")
print(list_reports(meta_dir, sort_by = "datetime"))

# Replay into a new output path
replay_out <- file.path(out_dir, "replayed")
dir.create(replay_out, recursive = TRUE, showWarnings = FALSE)
replay_report(
  meta$spec_file,
  meta_dir = meta_dir,
  output_path = file.path(replay_out, "04_meta_replay_clean_replay.docx")
)

# Dry-run cleanup preview (keeps last 2 versions)
cat("Cleanup dry-run preview:\n")
print(clean_reports(meta_dir, keep_versions = 2, dry_run = TRUE))
