## Meta folder management: list, replay, clean
##
## Three public functions for working with the JSON artefacts produced by
## save_report():
##
##   list_reports()  - scan a meta folder and return a summary data frame
##   replay_report() - re-render a DOCX from stored JSON without any R objects
##   clean_reports() - remove obsolete / orphaned JSON files
##
## Internal helpers:
##   .read_spec_index()        - parse _index.json (if present) or scan folder
##   .normalize_data_refs()    - ensure data_refs is always a list-column
##   .write_spec_index()       - write an index data frame to _index.json
##   .update_spec_index()      - append / update a row in _index.json
##   .collect_spec_meta()      - read _metadata + dataRef from one spec JSON
##   .identify_obsolete_specs()- split index into obsolete / surviving specs
##   .collect_live_refs()      - gather data + image refs from surviving specs

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

#' Read or rebuild the spec index for a meta folder
#' @keywords internal
#' @noRd
.read_spec_index <- function(meta_dir) {
  index_path <- file.path(meta_dir, .const_index_file)
  if (file.exists(index_path)) {
    idx <- tryCatch(
      jsonlite::fromJSON(index_path, simplifyDataFrame = TRUE),
      error = function(e) .scan_meta_folder(meta_dir)
    )
  } else {
    idx <- .scan_meta_folder(meta_dir)
  }
  .normalize_data_refs(idx)
}

#' Ensure data_refs is always a list-column of character vectors
#'
#' jsonlite::fromJSON(simplifyDataFrame = TRUE) may flatten data_refs into a
#' matrix when every row has the same number of refs.  This normalizer
#' guarantees the column is an I()-wrapped list of character vectors.
#' @keywords internal
#' @noRd
.normalize_data_refs <- function(idx) {
  if (nrow(idx) == 0 || is.null(idx[["data_refs"]])) return(idx)
  dr <- idx[["data_refs"]]
  if (is.list(dr) && !is.data.frame(dr)) {
    idx[["data_refs"]] <- I(lapply(dr, function(x) as.character(unlist(x))))
  } else {
    idx[["data_refs"]] <- I(lapply(seq_len(nrow(idx)), function(i) {
      as.character(unlist(dr[i, , drop = TRUE]))
    }))
  }
  idx
}

#' Scan a meta folder and build an index data frame from spec JSONs
#' @keywords internal
#' @noRd
.scan_meta_folder <- function(meta_dir) {
  json_files <- list.files(meta_dir, pattern = "\\.json$", full.names = FALSE)
  json_files <- setdiff(json_files, .const_index_file)

  rows <- lapply(json_files, function(fn) {
    path <- file.path(meta_dir, fn)
    meta <- tryCatch(.collect_spec_meta(path), error = function(e) NULL)
    if (is.null(meta)) return(NULL)
    data.frame(
      spec_file  = fn,
      doc_file   = meta$doc_file,
      datetime   = meta$datetime,
      n_specs    = meta$n_specs,
      data_refs  = I(list(meta$data_refs)),
      stringsAsFactors = FALSE
    )
  })

  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) {
    return(data.frame(
      spec_file  = character(0),
      doc_file   = character(0),
      datetime   = character(0),
      n_specs    = integer(0),
      data_refs  = I(list()),
      stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}

#' Extract _metadata + dataRef list from a single spec JSON file.
#' Returns NULL if the file is a data JSON (no _metadata key).
#' @keywords internal
#' @noRd
.collect_spec_meta <- function(path) {
  d <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (is.null(d) || is.null(d[["_metadata"]])) return(NULL)

  meta    <- d[["_metadata"]]
  spec_keys <- setdiff(names(d), "_metadata")

  data_refs <- unique(unlist(lapply(spec_keys, function(k) {
    refs <- d[[k]][["dataRef"]]
    if (is.null(refs)) character(0) else as.character(unlist(refs))
  })))

  list(
    doc_file   = as.character(meta[["docFileName"]] %||% ""),
    out_dir    = as.character(meta[["outDir"]]      %||% "."),
    datetime   = as.character(meta[["datetime"]]    %||% ""),
    n_specs    = length(spec_keys),
    data_refs  = data_refs
  )
}

#' Write a spec index data frame to _index.json
#' @keywords internal
#' @noRd
.write_spec_index <- function(meta_dir, idx_df) {
  index_path <- file.path(meta_dir, .const_index_file)
  records <- lapply(seq_len(nrow(idx_df)), function(i) {
    list(
      spec_file = idx_df$spec_file[i],
      doc_file  = idx_df$doc_file[i],
      datetime  = idx_df$datetime[i],
      n_specs   = idx_df$n_specs[i],
      data_refs = as.list(idx_df$data_refs[[i]])
    )
  })
  writeLines(
    jsonlite::toJSON(records, auto_unbox = TRUE, pretty = TRUE),
    con = index_path
  )
  invisible(NULL)
}

#' Append or update a row in _index.json
#' @keywords internal
#' @noRd
.update_spec_index <- function(meta_dir, spec_file, doc_file, datetime,
                                n_specs, data_refs) {
  index_path <- file.path(meta_dir, .const_index_file)

  new_row <- list(
    spec_file = spec_file,
    doc_file  = doc_file,
    datetime  = datetime,
    n_specs   = n_specs,
    data_refs = as.list(data_refs)
  )

  if (file.exists(index_path)) {
    existing <- tryCatch(
      jsonlite::fromJSON(index_path, simplifyVector = FALSE),
      error = function(e) list()
    )
    if (!is.list(existing)) existing <- list()
    idx <- which(vapply(existing, function(x) identical(x$spec_file, spec_file),
                        logical(1)))
    if (length(idx) > 0) {
      existing[[idx[1]]] <- new_row
    } else {
      existing <- c(existing, list(new_row))
    }
    entries <- existing
  } else {
    entries <- list(new_row)
  }

  writeLines(
    jsonlite::toJSON(entries, auto_unbox = TRUE, pretty = TRUE),
    con = index_path
  )
  invisible(NULL)
}

#' Split an index into obsolete and surviving spec files
#' @return list(obsolete, surviving) - character vectors of spec_file names
#' @keywords internal
#' @noRd
.identify_obsolete_specs <- function(idx, keep_versions) {
  obsolete  <- character(0)
  surviving <- character(0)
  if (nrow(idx) == 0) return(list(obsolete = obsolete, surviving = surviving))

  for (doc in unique(idx$doc_file)) {
    rows <- idx[idx$doc_file == doc, , drop = FALSE]
    rows <- rows[order(rows$datetime, decreasing = TRUE), , drop = FALSE]
    if (nrow(rows) > keep_versions) {
      obsolete  <- c(obsolete,  rows$spec_file[seq(keep_versions + 1, nrow(rows))])
      surviving <- c(surviving, rows$spec_file[seq_len(keep_versions)])
    } else {
      surviving <- c(surviving, rows$spec_file)
    }
  }
  list(obsolete = obsolete, surviving = surviving)
}

#' Collect all live data-ref and image-ref filenames from surviving specs
#'
#' Reads each surviving spec JSON once and returns both data JSON refs and
#' image asset refs.
#' @return list(data_refs, img_refs) - character vectors of filenames
#' @keywords internal
#' @noRd
.collect_live_refs <- function(meta_dir, surviving_specs) {
  data_refs <- character(0)
  img_refs  <- character(0)

  for (sf in surviving_specs) {
    path <- file.path(meta_dir, sf)
    if (!file.exists(path)) next
    d <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                  error = function(e) NULL)
    if (is.null(d)) next

    for (k in setdiff(names(d), "_metadata")) {
      refs <- d[[k]][["dataRef"]]
      if (is.null(refs)) next
      for (ref in as.character(unlist(refs))) {
        data_refs <- c(data_refs, paste0(ref, ".json"))
        for (ext in .const_asset_extensions) {
          img_refs <- c(img_refs, paste0(ref, ".", ext))
        }
      }
    }
  }

  list(data_refs = unique(data_refs), img_refs = unique(img_refs))
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

#' List Saved Reports in a Meta Folder
#'
#' Scans a meta folder produced by \code{\link{save_report}} and returns a
#' summary data frame with one row per spec JSON file.  Uses \code{_index.json}
#' when available (fast); falls back to scanning every JSON file otherwise.
#'
#' @param meta_dir Character string. Path to the meta folder.  Defaults to
#'   \code{tfl_get_option("meta_directory")}.  An error is raised when neither
#'   the argument nor the option is set.
#' @param sort_by Character string. Column to sort by: \code{"datetime"}
#'   (default, newest first), \code{"doc_file"}, or \code{"spec_file"}.
#'
#' @return A data frame with columns:
#' \describe{
#'   \item{spec_file}{Hash-named spec JSON filename.}
#'   \item{doc_file}{Target DOCX filename stored at save time.}
#'   \item{datetime}{ISO-8601 timestamp of when \code{save_report()} was called.}
#'   \item{n_specs}{Number of TFL specs inside the JSON.}
#'   \item{is_latest}{Logical - \code{TRUE} for the most-recent entry per
#'     \code{doc_file}; older entries are \code{FALSE} (obsolete candidates).}
#'   \item{data_refs}{Character vector of data JSON base-names referenced by
#'     this spec (without \code{.json} extension).}
#' }
#' When no spec JSONs are found in \code{meta_dir}, returns
#' \code{invisible(empty_data_frame)} and prints an informational message.
#'
#' @export
#' @examples
#' \dontrun{
#' df <- list_reports("path/to/meta")
#' print(df[df$is_latest, c("doc_file", "datetime", "spec_file")])
#' }
list_reports <- function(meta_dir = tfl_get_option("meta_directory"),
                         sort_by = c("datetime", "doc_file", "spec_file")) {
  if (is.null(meta_dir)) {
    cli::cli_abort(c(
      "{.arg meta_dir} is required.",
      i = "Provide the path directly or set it via {.fn tfl_set_options} with {.arg meta_directory}."
    ))
  }
  checkmate::assert_directory_exists(meta_dir)
  sort_by <- match.arg(sort_by)

  idx <- .read_spec_index(meta_dir)

  if (nrow(idx) == 0) {
    cli::cli_alert_info("No spec JSONs found in {.path {meta_dir}}")
    return(invisible(idx))
  }

  # Sort
  ord <- switch(sort_by,
    datetime  = order(idx$datetime, decreasing = TRUE),
    doc_file  = order(idx$doc_file, idx$datetime, decreasing = c(FALSE, TRUE),
                      method = "radix"),
    spec_file = order(idx$spec_file)
  )
  idx <- idx[ord, , drop = FALSE]
  rownames(idx) <- NULL

  # Mark latest entry per doc_file
  idx$is_latest <- FALSE
  # Parse ISO-8601 datetimes once to avoid numeric coercion warnings in which.max()
  dt_parsed <- as.POSIXct(idx$datetime, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  for (doc in unique(idx$doc_file)) {
    rows <- which(idx$doc_file == doc)
    if (length(rows) == 0) next
    rows_dt <- dt_parsed[rows]
    # Prefer the row with the latest parsed datetime; if all are NA, fall back to
    # the first row for that document (which respects the chosen sort order).
    if (all(is.na(rows_dt))) {
      latest_row <- rows[1L]
    } else {
      latest_row <- rows[which.max(rows_dt)]
    }
    idx$is_latest[latest_row] <- TRUE
  }

  # Reorder columns for readability
  col_order <- c("doc_file", "datetime", "is_latest", "n_specs",
                 "spec_file", "data_refs")
  col_order <- intersect(col_order, names(idx))
  idx <- idx[, col_order, drop = FALSE]

  n_total   <- nrow(idx)
  n_latest  <- sum(idx$is_latest)
  n_obsolete <- n_total - n_latest
  pl_total  <- if (n_total != 1) "s" else ""

  cli::cli_alert_info(
    "Meta folder: {n_total} spec JSON{pl_total} \u2014 {n_latest} latest, {n_obsolete} obsolete"
  )

  idx
}


#' Re-render a DOCX from Stored JSON
#'
#' Re-renders a DOCX document entirely from JSON files stored in the meta
#' folder - no R spec objects or data frames required.  Useful for
#' reproducing outputs after code changes or on a different machine.
#'
#' When a single \code{spec_json} is provided the function behaves exactly
#' as before.
#' When a character vector of length > 1 is given, the specs from every
#' document are merged into one combined JSON and rendered into a single
#' DOCX file.  \code{output_path} is required in this case.
#'
#' @param spec_json Character string or character vector. Either:
#'   \itemize{
#'     \item A full path to a spec JSON file, or
#'     \item A \code{doc_file} name (e.g. \code{"test_01.docx"}) - the most
#'       recent spec for that document is used.
#'   }
#'   Multiple entries are allowed for merging several documents into one.
#' @param meta_dir Character string or character vector. Path(s) to the meta
#'   folder(s).  Defaults to \code{tfl_get_option("meta_directory")}.
#'   An error is raised when neither the argument nor the option is set.
#'   \itemize{
#'     \item A single string is recycled for every element of \code{spec_json}.
#'     \item A vector of the same length as \code{spec_json} provides a
#'       per-document meta folder.
#'   }
#'   Required when any \code{spec_json} entry is a \code{doc_file} name
#'   rather than a full path.
#' @param output_path Character string. Override the output DOCX path.  If
#'   \code{NULL} (default), the path stored in the spec's \code{_metadata}
#'   (\code{outDir/docFileName}) is used.  \strong{Required} when
#'   \code{length(spec_json) > 1}.
#' @param template_json Character string. Override the template JSON path.
#'   If \code{NULL}, resolved automatically from the spec.
#' @param overrideTemplate Character string.  A bundled template name
#'   (e.g. \code{"Navy_Pro"}) or file path to a custom styles JSON.
#'   When non-\code{NULL}, this takes precedence over \code{template_json}.
#'   See \code{\link{tfl_list_templates}()} for available names.
#' @param insertTOC Logical. Insert a Table of Contents.  \code{NULL}
#'   (default) inherits the value from the first document's metadata.
#' @param tocTitle Character string.  TOC heading text.  \code{NULL}
#'   (default) inherits from the first document.
#' @param verbose Logical. Print C++ pipeline diagnostics. Default \code{FALSE}.
#'
#' @return Invisibly returns the path to the rendered DOCX file.
#' @export
#' @examples
#' \dontrun{
#' # By doc name (uses latest spec)
#' replay_report("test_01.docx", meta_dir = "path/to/meta")
#'
#' # By spec hash (exact version)
#' replay_report("abc123def456.json", meta_dir = "path/to/meta")
#'
#' # Override output location
#' replay_report("test_01.docx", meta_dir = "path/to/meta",
#'               output_path = "~/Desktop/test_01_replay.docx")
#'
#' # Merge two documents from the same meta folder
#' replay_report(
#'   c("tables_01.docx", "listings_01.docx"),
#'   meta_dir    = "path/to/meta",
#'   output_path = "output/combined.docx"
#' )
#'
#' # Merge documents from different meta folders
#' replay_report(
#'   c("path/to/meta_a/abc123.json", "path/to/meta_b/def456.json"),
#'   output_path = "output/combined.docx"
#' )
#' }
replay_report <- function(spec_json,
                           meta_dir   = tfl_get_option("meta_directory"),
                           output_path  = NULL,
                           template_json = NULL,
                           overrideTemplate = NULL,
                           insertTOC  = NULL,
                           tocTitle   = NULL,
                           verbose = FALSE) {
  checkmate::assert_character(spec_json, min.len = 1L, any.missing = FALSE)

  # --- Resolve overrideTemplate (bundled name or path) ---
  if (!is.null(overrideTemplate)) {
    checkmate::assert_string(overrideTemplate)
    template_json <- .resolve_template_value(overrideTemplate,
                                             spec_key = "replay_report")
  }

  # --- Validate meta_dir ---
  if (is.null(meta_dir)) {
    cli::cli_abort(c(
      "{.arg meta_dir} is required.",
      i = "Provide the path directly or set it via {.fn tfl_set_options} with {.arg meta_directory}."
    ))
  }

  # --- Recycle / validate meta_dir ---
  if (!is.null(meta_dir)) {
    checkmate::assert_character(meta_dir, min.len = 1L, any.missing = FALSE)
    if (length(meta_dir) == 1L) {
      meta_dir <- rep(meta_dir, length(spec_json))
    }
    if (length(meta_dir) != length(spec_json)) {
      cli::cli_abort(
        "{.arg meta_dir} must be length 1 (recycled) or the same length as {.arg spec_json}."
      )
    }
  }

  # ----- Single-document path (original behaviour) ------
  if (length(spec_json) == 1L) {
    md <- if (!is.null(meta_dir)) meta_dir[[1L]] else NULL
    spec_path <- .resolve_spec_path(spec_json, md)

    meta <- tryCatch(.collect_spec_meta(spec_path), error = function(e) NULL)
    if (is.null(meta)) {
      cli::cli_abort(c(
        "{.path {spec_path}} does not appear to be a spec JSON.",
        i = "Expected a JSON with a {.field _metadata} key."
      ))
    }

    if (is.null(output_path)) {
      output_path <- file.path(meta$out_dir, meta$doc_file)
    }
    checkmate::assert_string(output_path)

    cli::cli_alert_info("Replaying {.val {meta$doc_file}} from {.path {spec_path}}")

    render_docx(
      spec_json     = spec_path,
      template_json = template_json,
      output_path   = output_path,
      verbose       = verbose
    )

    return(invisible(output_path))
  }

  # ----- Multi-document merge path -----
  if (is.null(output_path)) {
    cli::cli_abort(
      "{.arg output_path} is required when merging multiple documents."
    )
  }
  checkmate::assert_string(output_path)

  # Build a per-element meta_dir vector (NULLs where not needed)
  md_vec <- if (!is.null(meta_dir)) meta_dir else rep(list(NULL), length(spec_json))

  combined_json <- .merge_spec_jsons(
    spec_jsons = spec_json,
    meta_dirs  = md_vec,
    insertTOC  = insertTOC,
    tocTitle   = tocTitle,
    output_path = output_path
  )
  on.exit(unlink(combined_json), add = TRUE)

  n_inputs <- length(spec_json)
  cli::cli_alert_info(
    "Merging {n_inputs} document{?s} into {.path {output_path}}"
  )

  render_docx(
    spec_json     = combined_json,
    template_json = template_json,
    output_path   = output_path,
    data_dir      = "",
    verbose       = verbose
  )

  invisible(output_path)
}


#' Merge multiple spec JSONs into a single combined JSON
#'
#' Reads each spec JSON, makes dataRef paths absolute, renumbers docOrder
#' sequentially, and writes one combined JSON to a temp file.
#' @keywords internal
#' @noRd
.merge_spec_jsons <- function(spec_jsons, meta_dirs, insertTOC, tocTitle,
                              output_path) {
  all_specs    <- list()
  first_meta   <- NULL

  for (i in seq_along(spec_jsons)) {
    md <- if (is.character(meta_dirs)) meta_dirs[[i]] else meta_dirs[[i]]
    spec_path <- .resolve_spec_path(spec_jsons[[i]], md)

    d <- jsonlite::fromJSON(spec_path, simplifyVector = FALSE)
    if (is.null(d[["_metadata"]])) {
      cli::cli_abort(c(
        "{.path {spec_path}} does not appear to be a spec JSON.",
        i = "Expected a JSON with a {.field _metadata} key."
      ))
    }

    if (is.null(first_meta)) first_meta <- d[["_metadata"]]
    spec_data_dir <- dirname(spec_path)
    spec_keys <- setdiff(names(d), "_metadata")

    for (k in spec_keys) {
      entry <- d[[k]]

      # Make dataRef absolute so the C++ renderer finds files
      # regardless of which meta folder they came from.
      # Keep as list so jsonlite serializes as JSON array (not scalar).
      if (!is.null(entry[["dataRef"]])) {
        entry[["dataRef"]] <- lapply(entry[["dataRef"]], function(ref) {
          abs_path <- file.path(spec_data_dir, ref)
          # Check base name, .json suffix, and common image extensions
          candidates <- c(abs_path, paste0(abs_path, ".json"),
                          paste0(abs_path, c(".png", ".jpg", ".jpeg", ".svg")))
          if (any(file.exists(candidates))) {
            normalizePath(abs_path, mustWork = FALSE)
          } else {
            ref
          }
        })
      }

      # Ensure unique key across reports
      final_key <- k
      if (final_key %in% names(all_specs)) {
        final_key <- paste0(final_key, "_r", i)
      }
      all_specs[[final_key]] <- entry
    }
  }

  # Renumber docOrder sequentially (C++ sorts by this field)
  for (j in seq_along(all_specs)) {
    all_specs[[j]][["document"]][["docOrder"]] <- j
  }

  # Build combined _metadata
  combined_meta <- first_meta
  combined_meta[["docFileName"]] <- basename(output_path)
  combined_meta[["outDir"]]      <- normalizePath(dirname(output_path),
                                                   mustWork = FALSE)
  combined_meta[["datetime"]]    <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
  if (!is.null(insertTOC)) combined_meta[["insertTOC"]] <- insertTOC
  if (!is.null(tocTitle))  combined_meta[["tocTitle"]]  <- tocTitle

  final <- c(list(`_metadata` = combined_meta), all_specs)

  tmp <- tempfile(fileext = ".json")
  json_out <- jsonlite::toJSON(final, auto_unbox = TRUE, digits = NA,
                               null = "null")
  writeLines(json_out, con = tmp)
  tmp
}

#' Resolve a spec JSON path from a name or path
#' @keywords internal
#' @noRd
.resolve_spec_path <- function(spec_json, meta_dir) {
  # Full path that exists - use directly
  if (file.exists(spec_json)) return(normalizePath(spec_json))

  if (is.null(meta_dir)) {
    cli::cli_abort(c(
      "{.arg meta_dir} is required when {.arg spec_json} is not a full path.",
      i = "Provide the meta folder path or a full path to the spec JSON."
    ))
  }
  checkmate::assert_directory_exists(meta_dir)

  # Hash filename (ends with .json, no path separators)
  if (grepl("\\.json$", spec_json, ignore.case = TRUE) &&
      !grepl("[/\\\\]", spec_json)) {
    candidate <- file.path(meta_dir, spec_json)
    if (file.exists(candidate)) return(normalizePath(candidate))
  }

  # doc_file name - find latest spec for that document
  idx <- .read_spec_index(meta_dir)
  matches <- idx[idx$doc_file == spec_json, , drop = FALSE]
  if (nrow(matches) == 0) {
    cli::cli_abort(c(
      "No spec JSON found for {.val {spec_json}} in {.path {meta_dir}}.",
      i = "Use {.fn list_reports} to see available documents."
    ))
  }
  # Pick the most recent (datetime is ISO-8601, lexicographic order works)
  latest <- matches[order(matches$datetime, decreasing = TRUE)[1L], ]
  normalizePath(file.path(meta_dir, latest$spec_file))
}


#' Clean Obsolete and Orphaned JSON Files from a Meta Folder
#'
#' Removes two categories of stale files from a meta folder:
#' \enumerate{
#'   \item \strong{Obsolete spec JSONs} - older versions of a document when
#'     multiple spec JSONs exist for the same \code{doc_file}.  Only the
#'     most-recent spec per document is kept.
#'   \item \strong{Orphaned data JSONs} - data JSON files that are no longer
#'     referenced by any surviving spec JSON.
#' }
#'
#' By default the function runs in \strong{dry-run} mode and only reports what
#' would be deleted.  Pass \code{dry_run = FALSE} to actually delete files.
#'
#' @param meta_dir Character string. Path to the meta folder.  Defaults to
#'   \code{tfl_get_option("meta_directory")}.  An error is raised when neither
#'   the argument nor the option is set.
#' @param keep_versions Integer. Number of most-recent spec versions to keep
#'   per document. Default \code{1} (keep only the latest).  Set to \code{2}
#'   to keep the latest and one previous version for rollback.
#' @param dry_run Logical. If \code{TRUE} (default), only report what would be
#'   deleted without removing anything.
#'
#' @return Invisibly returns a list with elements \code{obsolete_specs},
#'   \code{orphaned_data}, and \code{deleted} (character vectors of filenames).
#' @export
#' @examples
#' \dontrun{
#' # Preview what would be removed
#' clean_reports("path/to/meta")
#'
#' # Actually delete, keeping 1 version per document
#' clean_reports("path/to/meta", dry_run = FALSE)
#'
#' # Keep 2 versions per document (latest + one rollback)
#' clean_reports("path/to/meta", keep_versions = 2, dry_run = FALSE)
#' }
clean_reports <- function(meta_dir = tfl_get_option("meta_directory"),
                           keep_versions = 1L,
                           dry_run = TRUE) {
  if (is.null(meta_dir)) {
    cli::cli_abort(c(
      "{.arg meta_dir} is required.",
      i = "Provide the path directly or set it via {.fn tfl_set_options} with {.arg meta_directory}."
    ))
  }
  checkmate::assert_directory_exists(meta_dir)
  checkmate::assert_int(keep_versions, lower = 1L)
  checkmate::assert_flag(dry_run)

  keep_versions <- as.integer(keep_versions)

  idx <- .read_spec_index(meta_dir)

  # ---- 1. Identify obsolete spec JSONs ----
  split <- .identify_obsolete_specs(idx, keep_versions)
  obsolete_specs  <- split$obsolete
  surviving_specs <- split$surviving

  # ---- 2. Collect live refs (single pass over surviving specs) ----
  live <- .collect_live_refs(meta_dir, surviving_specs)

  # ---- 3. Identify orphaned data JSONs ----
  all_json <- list.files(meta_dir, pattern = "\\.json$", full.names = FALSE)
  spec_files_set <- unique(c(idx$spec_file, .const_index_file))
  candidate_data <- setdiff(all_json, spec_files_set)
  orphaned_data  <- setdiff(candidate_data, live$data_refs)

  # ---- 4. Identify orphaned image/asset files ----
  all_files <- list.files(meta_dir, full.names = FALSE)
  non_json  <- setdiff(all_files, all_json)
  asset_pattern <- paste0("\\.(", paste(.const_asset_extensions, collapse = "|"), ")$")
  non_json  <- non_json[grepl(asset_pattern, non_json, ignore.case = TRUE)]
  orphaned_imgs <- setdiff(non_json, live$img_refs)

  # ---- 5. Report ----
  n_obs  <- length(obsolete_specs)
  n_data <- length(orphaned_data)
  n_img  <- length(orphaned_imgs)
  n_total <- n_obs + n_data + n_img

  if (n_total == 0) {
    cli::cli_alert_success("Meta folder is clean - nothing to remove.")
    return(invisible(list(obsolete_specs = character(0),
                          orphaned_data  = character(0),
                          orphaned_imgs  = character(0),
                          deleted        = character(0))))
  }

  pl_total <- if (n_total != 1) "s" else ""
  pl_obs   <- if (n_obs   != 1) "s" else ""
  pl_data  <- if (n_data  != 1) "s" else ""
  pl_img   <- if (n_img   != 1) "s" else ""

  if (dry_run) {
    cli::cli_alert_info(
      "Dry run \u2014 {n_total} file{pl_total} would be removed (pass {.code dry_run = FALSE} to delete):"
    )
  } else {
    cli::cli_alert_info(
      "Removing {n_total} file{pl_total}:"
    )
  }

  if (n_obs > 0) {
    cli::cli_alert_info("  {n_obs} obsolete spec JSON{pl_obs}:")
    for (f in obsolete_specs) cli::cli_text("    {.file {f}}")
  }
  if (n_data > 0) {
    cli::cli_alert_info("  {n_data} orphaned data JSON{pl_data}:")
    for (f in orphaned_data) cli::cli_text("    {.file {f}}")
  }
  if (n_img > 0) {
    cli::cli_alert_info("  {n_img} orphaned image file{pl_img}:")
    for (f in orphaned_imgs) cli::cli_text("    {.file {f}}")
  }

  deleted <- character(0)

  if (!dry_run) {
    to_delete <- c(obsolete_specs, orphaned_data, orphaned_imgs)
    for (f in to_delete) {
      path <- file.path(meta_dir, f)
      if (file.exists(path)) {
        file.remove(path)
        deleted <- c(deleted, f)
      }
    }

    # Rebuild index after deletion
    new_idx <- .scan_meta_folder(meta_dir)
    index_path <- file.path(meta_dir, .const_index_file)
    if (nrow(new_idx) > 0) {
      .write_spec_index(meta_dir, new_idx)
    } else if (file.exists(index_path)) {
      file.remove(index_path)
    }

    n_del  <- length(deleted)
    pl_del <- if (n_del != 1) "s" else ""
    cli::cli_alert_success("Removed {n_del} file{pl_del}.")
  }

  invisible(list(
    obsolete_specs = obsolete_specs,
    orphaned_data  = orphaned_data,
    orphaned_imgs  = orphaned_imgs,
    deleted        = deleted
  ))
}
