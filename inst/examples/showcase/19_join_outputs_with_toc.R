source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

# -----------------------------------------------------------------------------
# Example 19: Join multiple saved outputs into a single document with TOC
#
# Workflow:
#   1. Read META folder index via list_reports() and keep only the latest
#      entry per output document (is_latest == TRUE).
#   2. Scan the output folder for .docx files that are physically present.
#   3. Inner-join the two sets: only documents that exist on disk AND have
#      live metadata are included.
#   4. Call replay_report() with the matched vector of spec JSON files to
#      produce one combined DOCX with a Table of Contents.
#
# Run prerequisite examples first to populate the output/meta folders:
#   source("inst/examples/showcase/12_ae_table.R")
#   source("inst/examples/showcase/13_dm_table.R")
#   source("inst/examples/showcase/11_listing.R")
# -----------------------------------------------------------------------------

# ---- Step 1: Read META index and keep only latest entries ------------------

meta_index <- list_reports(meta_dir, sort_by = "doc_file")

latest <- dplyr::filter(meta_index, is_latest)

if (nrow(latest) == 0L) {
  stop(
    "No latest spec JSONs found in META folder: ", meta_dir, "\n",
    "Run some showcase examples first (e.g. 11, 12, 13) to generate metadata."
  )
}

cat(sprintf("META: %d latest spec JSON(s) covering %d unique document(s)\n",
            nrow(latest), length(unique(latest$doc_file))))

# ---- Step 2: Scan output folder for .docx files ----------------------------

docx_on_disk <- list.files(out_dir, pattern = "\\.docx$",
                           full.names = FALSE, recursive = FALSE)
docx_on_disk <- docx_on_disk[!startsWith(docx_on_disk, "~$")]

cat(sprintf("Output folder: %d .docx file(s) found\n", length(docx_on_disk)))

# ---- Step 3: Inner-join — keep entries that exist both on disk and in META -

matched <- dplyr::inner_join(
  latest,
  tibble::tibble(doc_file = docx_on_disk),
  by = "doc_file"
)

if (nrow(matched) == 0L) {
  stop(
    "No overlap between META latest entries and .docx files in output folder.\n",
    "Ensure the same out_dir and meta_dir were used when running prior examples."
  )
}

cat(sprintf("Matched: %d document(s) will be merged\n", nrow(matched)))
cat("Documents (in TOC order):\n")
for (i in seq_len(nrow(matched))) {
  cat(sprintf("  %2d. %s  [%s]\n", i, matched$doc_file[i], matched$datetime[i]))
}

# ---- Step 4: Merge matched documents into a single DOCX with TOC -----------

output_file <- file.path(out_dir, "19_combined_toc_bundle.docx")

replay_report(
  spec_json    = matched$spec_file,
  meta_dir     = meta_dir,
  output_path  = output_file,
  insertTOC    = TRUE,
  tocTitle     = "Table of Contents"
)

cat("Combined output written to:", output_file, "\n")
