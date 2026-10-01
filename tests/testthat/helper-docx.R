# ============================================================================
# Shared DOCX inspection helpers for ksTFL tests
#
# These make the *generated document* a first-class test target without any
# external tooling: everything here works with base R (unz() + regex readers)
# plus {xml2} for structural queries (xml2 is in Suggests; tests that use the
# xpath helpers guard themselves with skip_if_not_installed("xml2")).
#
# Validation tiers (see test-suite review 2026-09-29):
#   A - generation validity ......... expect_docx_valid()
#   B - structure ................... docx_doc() counts / dimensions
#   C - semantics ................... docx_cells() text/attribute dumps
# ============================================================================

# ---- regex utilities (base R; capture groups via per-segment sub) -----------

#' All full matches of a perl regex in a single string.
rx_all <- function(text, pattern) {
  regmatches(text, gregexpr(pattern, text, perl = TRUE))[[1]]
}

#' All matches of `pattern` in `text`, returning capture group `group`.
rx_group <- function(text, pattern, group = 1L) {
  ms <- rx_all(text, pattern)
  if (!length(ms)) return(character(0))
  vapply(ms, function(m) sub(pattern, paste0("\\", group), m, perl = TRUE),
         character(1), USE.NAMES = FALSE)
}

# ---- part-level access ------------------------------------------------------

#' Names of all parts inside a .docx (ZIP) container
docx_parts <- function(path) {
  utils::unzip(path, list = TRUE)$Name
}

#' Raw text of one DOCX part (base R, no dependencies)
docx_part_text <- function(path, part = "word/document.xml") {
  con <- unz(path, part)
  on.exit(close(con), add = TRUE)
  paste(readLines(con, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

#' xml2 document for one DOCX part (callers must skip_if_not_installed("xml2"))
docx_doc <- function(path, part = "word/document.xml") {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    stop("docx_doc() requires the xml2 package")
  }
  xml2::read_xml(docx_part_text(path, part))
}

# ---- A-tier: generation validity -------------------------------------------

#' Tier A: the file exists, is a real ZIP with the mandatory OOXML parts, and
#' every XML part is well-formed (parsed with xml2 when available).
expect_docx_valid <- function(path) {
  expect_true(file.exists(path), label = paste0("DOCX exists: ", basename(path)))
  expect_gt(file.size(path), 1024, label = "DOCX is non-trivial size")
  hdr <- readBin(path, "raw", n = 2)
  expect_identical(hdr, as.raw(c(0x50, 0x4B)), info = "ZIP magic PK")

  parts <- docx_parts(path)
  expect_true("[Content_Types].xml" %in% parts, label = "[Content_Types].xml present")
  expect_true("word/document.xml" %in% parts, label = "word/document.xml present")
  expect_true("word/_rels/document.xml.rels" %in% parts, label = "document rels present")

  xml_parts <- parts[grepl("\\.(xml|rels)$", parts)]
  if (requireNamespace("xml2", quietly = TRUE)) {
    for (p in xml_parts) {
      ok <- tryCatch({ xml2::read_xml(docx_part_text(path, p)); TRUE },
                     error = function(e) FALSE)
      expect_true(ok, label = paste0("xml2 well-formed: ", p))
    }
  } else {
    for (p in xml_parts) {
      expect_match(docx_part_text(path, p), "^<\\?xml", label = paste0("XML decl: ", p))
    }
  }
  invisible(path)
}

# ---- C-tier: cell-level content dump ---------------------------------------
# ksTFL's emitter is deterministic; these regex readers extract OBSERVABLE
# document facts (text, spans, merges, bold, fill, color) per table cell.

#' Per-cell dump for every table row in document order.
#' Returns a list of rows; each row is a data.frame with columns
#' text, gridSpan (NA if absent), vMerge ('restart'|'continue'|NA),
#' bold, shd (fill color or NA), color (font color or NA).
docx_cells <- function(path, part = "word/document.xml") {
  x <- docx_part_text(path, part)
  tbls <- rx_all(x, "(?s)<w:tbl(?: [^>]*)?>.*?</w:tbl>")
  rows <- list()
  empty <- data.frame(text = character(0), gridSpan = integer(0), vMerge = character(0),
                      bold = logical(0), shd = character(0), color = character(0),
                      stringsAsFactors = FALSE)
  for (tbl in tbls) {
    trs <- rx_all(tbl, "(?s)<w:tr(?: [^>]*)?>.*?</w:tr>")
    for (tr in trs) {
      tcs <- rx_all(tr, "(?s)<w:tc(?: [^>]*)?>.*?</w:tc>")
      cells <- lapply(tcs, function(tc) {
        txt <- paste(rx_group(tc, "(?s)<w:t(?: [^>]*)?>([^<]*)</w:t>", 1), collapse = "")
        gs  <- rx_group(tc, 'gridSpan w:val="(\\d+)"', 1)
        vm  <- rx_all(tc, '<w:vMerge(?: w:val="[^"]*")?/>')
        vmv <- if (length(vm)) {
          v <- regmatches(vm[1], regexpr('w:val="[^"]*"', vm[1]))
          if (length(v) && nzchar(v)) gsub('w:val="([^"]*)"', "\\1", v) else "continue"
        } else NA_character_
        fl <- rx_group(tc, '<w:shd [^/]*w:fill="([^"]+)"', 1)
        cl <- rx_group(tc, '<w:color w:val="([^"]+)"', 1)
        data.frame(
          text     = txt,
          gridSpan = if (length(gs)) as.integer(gs[1]) else NA_integer_,
          vMerge   = vmv,
          bold     = any(grepl("<w:b/>|<w:b [^/]*/>", tc)),
          shd      = if (length(fl)) fl[1] else NA_character_,
          color    = if (length(cl)) cl[1] else NA_character_,
          stringsAsFactors = FALSE
        )
      })
      rows[[length(rows) + 1L]] <- if (length(cells)) do.call(rbind, cells) else empty
    }
  }
  rows
}

#' All visible text in document.xml, run-concatenated per paragraph.
docx_paragraph_texts <- function(path, part = "word/document.xml") {
  x <- docx_part_text(path, part)
  ps <- rx_all(x, "(?s)<w:p(?: [^>]*)?>.*?</w:p>")
  vapply(ps, function(p) paste(rx_group(p, "(?s)<w:t(?: [^>]*)?>([^<]*)</w:t>", 1), collapse = ""),
         character(1), USE.NAMES = FALSE)
}

# ---- local directories helper (moved from test-12) --------------------------

#' Register `call_expr` (a quoted call whose free variables you have already
#' embedded with bquote/.) to run at exit of frame `env` — base-R withr::defer.
#' IMPORTANT: embed values at CALL time (bquote + .(var)); a bare substitute()
#' of the caller's expression re-evaluates the symbols at exit time, by which
#' point a helper's locals (old settings, temp paths) are gone — the naive
#' variant silently stopped restoring state (review 2026-09-29).
defer_baked <- function(call_expr, env = parent.frame()) {
  do.call("on.exit", list(call_expr, add = TRUE), envir = env)
}

#' Create temp out/meta directories cleaned up with the calling test frame.
local_docx_dirs <- function(.env = parent.frame()) {
  root <- tempfile("ksTFL_t_")
  dir.create(root, recursive = TRUE)
  out <- file.path(root, "out"); meta <- file.path(root, "meta")
  dir.create(out); dir.create(meta)
  defer_baked(bquote(unlink(.(root), recursive = TRUE)), env = .env)
  list(root = root, out = out, meta = meta)
}

#' Hash-named spec JSON files in a meta dir (excludes data JSONs and _index).
spec_json_paths <- function(meta_dir) {
  cand <- setdiff(list.files(meta_dir, pattern = "^[a-f0-9]{16}\\.json$"),
                  "_index.json")
  cand[vapply(cand, function(f) {
    j <- tryCatch(jsonlite::fromJSON(file.path(meta_dir, f), simplifyVector = FALSE),
                  error = function(e) NULL)
    !is.null(j) && !is.null(j$`_metadata`)
  }, logical(1))]
}

# ---- shared tiny fixtures used across test files ------------------------------

#' 4-row frame: two groups, labels r1..r4, numeric v. Stable across tests.
act_df <- function() {
  data.frame(
    g   = c("A", "A", "B", "B"),
    lab = c("r1", "r2", "r3", "r4"),
    v   = c(1, 2, 3, 4),
    stringsAsFactors = FALSE
  )
}

#' create_report() + write_doc() into test-local dirs (auto-cleanup via .env).
render_spec <- function(spec, name, .env = parent.frame()) {
  dirs <- local_docx_dirs(.env = .env)
  write_doc(create_report(spec), name,
            outDir = dirs$out, metaPath = dirs$meta, verbose = FALSE)
}

#' Cell text matrix list from a DOCX (see docx_cells).
cell_texts <- function(path) {
  lapply(docx_cells(path), function(m) as.character(m$text))
}

#' Run an expression under session options reset to defaults, then restore.
with_clean_options <- function(expr, .env = parent.frame()) {
  old <- ksTFL::tfl_get_options()
  ksTFL::tfl_reset_options()
  defer_baked(bquote(ksTFL::tfl_set_options(.(old))), env = .env)
  force(expr)
}
