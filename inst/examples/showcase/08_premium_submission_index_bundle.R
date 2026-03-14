source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

# -----------------------------------------------------------------------------
# Premium Example 08: Submission index + transfer bundle
# Collects premium DOCX outputs, builds index report, and assembles package.
# -----------------------------------------------------------------------------

output_dir <- out_dir
bundle_dir <- file.path(output_dir, "submission_bundle")
dir.create(bundle_dir, recursive = TRUE, showWarnings = FALSE)

# Collect premium documents
premium_docs <- list.files(
  output_dir,
  pattern = "^premium_.*\\.docx$",
  full.names = TRUE
)

if (length(premium_docs) == 0) {
  stop("No premium DOCX files found in: ", output_dir,
       "\nRun premium showcase scripts first (05/06/07).")
}

fmt_bytes <- function(x) {
  if (is.na(x) || x < 1024) return(paste0(x, " B"))
  if (x < 1024^2) return(sprintf("%.1f KB", x / 1024))
  sprintf("%.2f MB", x / (1024^2))
}

classify_doc <- function(name) {
  if (grepl("csr_bundle", name, ignore.case = TRUE)) return("CSR Bundle")
  if (grepl("qc_", name, ignore.case = TRUE)) return("QC / Repro")
  if (grepl("submission_", name, ignore.case = TRUE)) return("Multilang Template")
  "Premium"
}

manifest <- tibble::tibble(
  file_name = basename(premium_docs),
  abs_path = premium_docs,
  section = vapply(basename(premium_docs), classify_doc, character(1)),
  modified = as.character(file.info(premium_docs)$mtime),
  size_bytes = as.numeric(file.info(premium_docs)$size),
  size_human = vapply(as.numeric(file.info(premium_docs)$size), fmt_bytes, character(1)),
  md5 = unname(tools::md5sum(premium_docs))
) %>% dplyr::arrange(section, file_name)

# Save machine-readable manifests
write.csv(manifest, file.path(bundle_dir, "premium_manifest.csv"), row.names = FALSE)
write.csv(manifest[, c("file_name", "md5")], file.path(bundle_dir, "premium_checksums_md5.csv"), row.names = FALSE)

# Copy documents into bundle
bundle_docs_dir <- file.path(bundle_dir, "docs")
dir.create(bundle_docs_dir, recursive = TRUE, showWarnings = FALSE)
file.copy(premium_docs, file.path(bundle_docs_dir, basename(premium_docs)), overwrite = TRUE)

# Human-readable README for transfer package
readme_lines <- c(
  "ksTFL Premium Submission Bundle",
  "================================",
  paste0("Generated: ", as.character(Sys.time())),
  "",
  "Contents:",
  "- docs/: premium DOCX outputs",
  "- premium_manifest.csv: full manifest (size/time/hash)",
  "- premium_checksums_md5.csv: hash-only verification sheet",
  "",
  "Verification:",
  "1) Recompute MD5 for each file in docs/",
  "2) Compare against premium_checksums_md5.csv",
  "3) Ensure no mismatch before transfer"
)
writeLines(readme_lines, con = file.path(bundle_dir, "README_submission_bundle.txt"))

# Build DOCX index report
spec_idx <- create_table(manifest %>%
  dplyr::select(section, file_name, modified, size_human, md5)
) %>%
  add_title(c("Premium Submission Index", "Document Inventory and Integrity Manifest"), toclevel = 1) %>%
  add_subtitle("Generated from tmp/showcase_output") %>%
  add_footnote(c(
    "MD5 values are provided for transfer integrity checks.",
    "Use premium_manifest.csv for machine-readable processing."
  )) %>%
  define_cols(section, label = "Section", isID = TRUE, isGrouping = TRUE, dedupe = TRUE, colWidth = "20%") %>%
  define_cols(file_name, label = "Document", colWidth = "26%") %>%
  define_cols(modified, label = "Modified", valueStyleRef = "text_center", colWidth = "20%") %>%
  define_cols(size_human, label = "Size", valueStyleRef = "text_center", colWidth = "10%") %>%
  define_cols(md5, label = "MD5", valueStyleRef = "text_center", colWidth = "24%") %>%
  compute_cols(
    firstOf(section),
    c_addrow("above", value_from = section, styleRef = f_combine("font_bold", "bt_th"))
  ) %>%
  set_document(contentWidth = "95%")

spec_note <- create_text() %>%
  add_title("Transfer Notes", toclevel = 1) %>%
  add_body_text("Bundle can be transferred as-is from tmp/showcase_output/submission_bundle.") %>%
  add_body_text("Re-run this script after regenerating premium documents to refresh manifest and checksums.")

create_report(spec_idx, spec_note) %>%
  write_doc("premium_08_submission_index", toc = TRUE, metaPath = meta_dir)

cat("Submission bundle created:\n")
cat("- Bundle directory: ", bundle_dir, "\n", sep = "")
cat("- Documents copied: ", nrow(manifest), "\n", sep = "")
cat("- Index DOCX: ", file.path(output_dir, "08_submission_index.docx"), "\n", sep = "")
