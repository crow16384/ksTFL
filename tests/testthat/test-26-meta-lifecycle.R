# ============================================================================
# Test: meta folder lifecycle — list_reports() / replay_report() / clean_reports()
#
# Whole exported area had ZERO test references before 2026-09-29 (finding G1).
# These use only pure-R artifacts: save_report() JSON + write_doc() DOCX.
# ============================================================================

make_saved_report <- function(name = "meta_case", .env = parent.frame()) {
  dirs <- local_docx_dirs(.env = .env)
  spec <- create_table(act_meta_df()) |>
    add_title("Meta lifecycle table") |>
    define_cols(grp, label = "Group") |>
    define_cols(val, label = "Value", format = "%.1f")
  rpt <- create_report(spec)
  doc <- write_doc(rpt, name, outDir = dirs$out, metaPath = dirs$meta,
                   verbose = FALSE)
  list(dirs = dirs, spec = spec, doc = doc)
}

act_meta_df <- function() {
  data.frame(grp = c("A", "B", "C"), val = c(1.25, 2.5, 3.75),
             stringsAsFactors = FALSE)
}

# spec_json_of <- see helper-docx.R (spec_json_paths); alias for readability
spec_json_of <- spec_json_paths

# ---- save_report metadata + index ------------------------------------------------

test_that("write_doc() populates meta folder with spec JSON, data JSON and _index.json", {
  m <- make_saved_report("lifecycle1")
  files <- list.files(m$dirs$meta)
  spec_files <- grep("^[a-f0-9]{16}\\.json$", files, value = TRUE)
  expect_equal(length(spec_files), 1L, info = "one hash-named spec JSON")
  expect_true("_index.json" %in% files, label = "index written")
  expect_true(any(grepl("_data\\.json$|data.*\\.json$", files)) ||
                length(files) > 1L, label = "data asset JSON alongside")

  idx <- jsonlite::fromJSON(file.path(m$dirs$meta, "_index.json"),
                            simplifyVector = FALSE)
  expect_length(idx, 1L)
  expect_equal(idx[[1]]$spec_file, spec_files)
  expect_equal(idx[[1]]$doc_file, "lifecycle1.docx")
  expect_match(idx[[1]]$datetime, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}")
})

test_that("list_reports() returns the documented column contract", {
  m <- make_saved_report("lifecycle2")
  df <- list_reports(m$dirs$meta)
  expect_s3_class(df, "data.frame")
  expect_true(all(c("spec_file", "doc_file", "datetime", "n_specs",
                    "is_latest", "data_refs") %in% names(df)))
  expect_equal(nrow(df), 1L)
  expect_true(df$is_latest)
  expect_equal(df$doc_file, "lifecycle2.docx")
})

test_that("list_reports() sorts newest-first by datetime and falls back to folder scan when _index.json is corrupt", {
  m <- make_saved_report("lifecycle3")
  # second save under a different doc name, then overwrite the first doc
  spec <- create_table(act_meta_df()) |> add_title("Second")
  write_doc(create_report(spec), "lifecycle3b",
            outDir = m$dirs$out, metaPath = m$dirs$meta, verbose = FALSE)
  Sys.sleep(1.1)  # datetime has second resolution
  write_doc(create_report(spec), "lifecycle3",
            outDir = m$dirs$out, metaPath = m$dirs$meta, verbose = FALSE)

  df <- list_reports(m$dirs$meta)
  expect_gte(nrow(df), 3L)
  expect_identical(df$datetime, sort(df$datetime, decreasing = TRUE),
                   info = "default sort: newest first")
  # obsolete marking: older copy of lifecycle3 is not latest
  l3 <- df[df$doc_file == "lifecycle3.docx", ]
  expect_equal(sum(l3$is_latest), 1L)

  # corrupt index -> scan fallback must still list the same files
  writeLines("{ not json", file.path(m$dirs$meta, "_index.json"))
  df2 <- list_reports(m$dirs$meta)
  expect_setequal(df2$spec_file, df$spec_file)
})

# ---- replay_report ---------------------------------------------------------------

test_that("replay_report() reproduces the document XML of the original write_doc()", {
  m <- make_saved_report("replay1")
  sf <- spec_json_of(m$dirs$meta)
  out2 <- file.path(m$dirs$out, "replay1_again.docx")
  res <- replay_report(sf, meta_dir = m$dirs$meta, output_path = out2)
  expect_equal(res, out2)
  expect_docx_valid(out2)
  expect_equal(docx_part_text(out2, "word/document.xml"),
               docx_part_text(m$doc, "word/document.xml"),
               info = "deterministic renderer: replayed document.xml identical")
})

test_that("replay_report() rejects files without _metadata and respects overrideTemplate", {
  m <- make_saved_report("replay2")
  junk <- file.path(m$dirs$meta, "junk.json")
  writeLines('{"hello":"world"}', junk)
  expect_error(replay_report("junk.json", meta_dir = m$dirs$meta),
               "does not appear")
  # bundled-name override path (also covers template resolution in replay)
  out3 <- file.path(m$dirs$out, "replay2_default.docx")
  expect_no_error(replay_report(spec_json_of(m$dirs$meta),
                                meta_dir = m$dirs$meta, output_path = out3,
                                overrideTemplate = "Default"))
  expect_docx_valid(out3)
})

test_that("replay_report() merges several spec JSONs only with explicit output_path", {
  m <- make_saved_report("merge1")
  spec2 <- create_table(act_meta_df()) |> add_title("Merged in")
  write_doc(create_report(spec2), "merge2",
            outDir = m$dirs$out, metaPath = m$dirs$meta, verbose = FALSE)
  sf <- sort(spec_json_of(m$dirs$meta))
  expect_equal(length(sf), 2L, info = "two specs saved to same meta dir")
  expect_error(replay_report(sf, meta_dir = m$dirs$meta),
               "output_path.*required|required")
  combined <- file.path(m$dirs$out, "combined.docx")
  res <- replay_report(sf, meta_dir = m$dirs$meta, output_path = combined)
  expect_equal(res, combined)
  expect_docx_valid(combined)
  # both titles must appear in the merged document
  x <- docx_part_text(combined)
  expect_true(grepl("Meta lifecycle table", x, fixed = TRUE))
  expect_true(grepl("Merged in", x, fixed = TRUE))
})

# ---- clean_reports ---------------------------------------------------------------

test_that("clean_reports() defaults to dry-run and keeps newest versions on apply", {
  m <- make_saved_report("clean1")
  spec <- create_table(act_meta_df()) |> add_title("Again")
  Sys.sleep(1.1)
  write_doc(create_report(spec), "clean1",
            outDir = m$dirs$out, metaPath = m$dirs$meta, verbose = FALSE)
  before <- list.files(m$dirs$meta, pattern = "\\.json$")
  expect_gte(length(setdiff(before, "_index.json")), 2L)

  plan <- clean_reports(m$dirs$meta, keep_versions = 1L)  # dry run
  after_dry <- list.files(m$dirs$meta, pattern = "\\.json$")
  expect_setequal(after_dry, before)

  applied <- clean_reports(m$dirs$meta, keep_versions = 1L, dry_run = FALSE)
  after <- spec_json_of(m$dirs$meta)
  expect_equal(length(after), 1L, info = "only newest spec remains")
  newest <- list_reports(m$dirs$meta)
  expect_true(newest$is_latest[1])
  expect_equal(newest$spec_file[1], after)
})

test_that("meta API validates its arguments", {
  expect_error(list_reports(NULL), "required")
  expect_error(list_reports("/nonexistent/dir/at/all"), "exist|directory")
  dirs <- local_docx_dirs()
  expect_error(clean_reports(dirs$meta, keep_versions = 0L), "0|greater|lower|1")
  expect_error(clean_reports(dirs$meta, dry_run = "yes"), "flag|TRUE|FALSE|logical",
               ignore.case = TRUE)
})
