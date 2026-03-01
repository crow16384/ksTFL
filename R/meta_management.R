## Meta folder management: list, replay, clean
##
## Three public functions for working with the JSON artefacts produced by
## save_report():
##
##   list_reports()  – scan a meta folder and return a summary data frame
##   replay_report() – re-render a DOCX from stored JSON without any R objects
##   clean_reports() – remove obsolete / orphaned JSON files
##
## Internal helpers:
##   .read_spec_index()   – parse _index.json (if present) or scan folder
##   .update_spec_index() – append / update a row in _index.json
##   .collect_spec_meta() – read _metadata + dataRef from one spec JSON

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

.const_index_file <- "_index.json"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

#' Read or rebuild the spec index for a meta folder
#' @keywords internal
#' @noRd
.read_spec_index <- function(meta_dir) {
  index_path <- file.path(meta_dir, .const_index_file)
  if (file.exists(index_path)) {
    tryCatch(
      jsonlite::fromJSON(index_path, simplifyDataFrame = TRUE),
      error = function(e) .scan_meta_folder(meta_dir)
    )
  } else {
    .scan_meta_folder(meta_dir)
  }
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
    datetime   = as.character(meta[["datetime"]]    %||% ""),
    n_specs    = length(spec_keys),
    data_refs  = data_refs
  )
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
    # Replace entry for same spec_file if it exists, otherwise append
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

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

#' List Saved Reports in a Meta Folder
#'
#' Scans a meta folder produced by \code{\link{save_report}} and returns a
#' summary data frame with one row per spec JSON file.  Uses \code{_index.json}
#' when available (fast); falls back to scanning every JSON file otherwise.
#'
#' @param meta_dir Character string. Path to the meta folder.
#' @param sort_by Character string. Column to sort by: \code{"datetime"}
#'   (default, newest first), \code{"doc_file"}, or \code{"spec_file"}.
#'
#' @return A data frame with columns:
#' \describe{
#'   \item{spec_file}{Hash-named spec JSON filename.}
#'   \item{doc_file}{Target DOCX filename stored at save time.}
#'   \item{datetime}{ISO-8601 timestamp of when \code{save_report()} was called.}
#'   \item{n_specs}{Number of TFL specs inside the JSON.}
#'   \item{is_latest}{Logical — \code{TRUE} for the most-recent entry per
#'     \code{doc_file}; older entries are \code{FALSE} (obsolete candidates).}
#'   \item{data_refs}{Character vector of data JSON base-names referenced by
#'     this spec (without \code{.json} extension).}
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' df <- list_reports("path/to/meta")
#' print(df[df$is_latest, c("doc_file", "datetime", "spec_file")])
#' }
list_reports <- function(meta_dir, sort_by = c("datetime", "doc_file", "spec_file")) {
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
  for (doc in unique(idx$doc_file)) {
    rows <- which(idx$doc_file == doc)
    # rows are already sorted newest-first for datetime sort
    latest_row <- rows[which.max(idx$datetime[rows])]
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

  cli::cli_alert_info(
    "Meta folder: {n_total} spec JSON{if(n_total!=1)'s' else ''} \u2014 {n_latest} latest, {n_obsolete} obsolete"
  )

  idx
}


#' Re-render a DOCX from Stored JSON
#'
#' Re-renders a DOCX document entirely from JSON files stored in the meta
#' folder — no R spec objects or data frames required.  Useful for
#' reproducing outputs after code changes or on a different machine.
#'
#' @param spec_json Character string. Either:
#'   \itemize{
#'     \item A full path to a spec JSON file, or
#'     \item A \code{doc_file} name (e.g. \code{"test_01.docx"}) — the most
#'       recent spec for that document is used.
#'   }
#' @param meta_dir Character string. Path to the meta folder.  Required when
#'   \code{spec_json} is a \code{doc_file} name rather than a full path.
#' @param output_path Character string. Override the output DOCX path.  If
#'   \code{NULL} (default), the path stored in the spec's \code{_metadata}
#'   (\code{outDir/docFileName}) is used.
#' @param template_json Character string. Override the template JSON path.
#'   If \code{NULL}, resolved automatically from the spec.
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
#' }
replay_report <- function(spec_json,
                           meta_dir   = NULL,
                           output_path  = NULL,
                           template_json = NULL,
                           verbose = FALSE) {
  checkmate::assert_string(spec_json)

  # --- Resolve spec JSON path ---
  spec_path <- .resolve_spec_path(spec_json, meta_dir)

  # --- Read _metadata for default output path ---
  meta <- tryCatch(.collect_spec_meta(spec_path), error = function(e) NULL)
  if (is.null(meta)) {
    cli::cli_abort(c(
      "{.path {spec_path}} does not appear to be a spec JSON.",
      i = "Expected a JSON with a {.field _metadata} key."
    ))
  }

  # --- Resolve output path ---
  if (is.null(output_path)) {
    d <- jsonlite::fromJSON(spec_path, simplifyVector = FALSE)
    stored_out_dir  <- d[["_metadata"]][["outDir"]]       %||% "."
    stored_doc_file <- d[["_metadata"]][["docFileName"]]  %||% "output.docx"
    output_path <- file.path(stored_out_dir, stored_doc_file)
  }
  checkmate::assert_string(output_path)

  cli::cli_alert_info("Replaying {.val {meta$doc_file}} from {.path {spec_path}}")

  render_docx(
    spec_json     = spec_path,
    template_json = template_json,
    output_path   = output_path,
    verbose       = verbose
  )
}

#' Resolve a spec JSON path from a name or path
#' @keywords internal
#' @noRd
.resolve_spec_path <- function(spec_json, meta_dir) {
  # Full path that exists — use directly
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

  # doc_file name — find latest spec for that document
  idx <- .read_spec_index(meta_dir)
  matches <- idx[idx$doc_file == spec_json, , drop = FALSE]
  if (nrow(matches) == 0) {
    cli::cli_abort(c(
      "No spec JSON found for {.val {spec_json}} in {.path {meta_dir}}.",
      i = "Use {.fn list_reports} to see available documents."
    ))
  }
  # Pick the most recent
  latest <- matches[which.max(matches$datetime), ]
  normalizePath(file.path(meta_dir, latest$spec_file))
}


#' Clean Obsolete and Orphaned JSON Files from a Meta Folder
#'
#' Removes two categories of stale files from a meta folder:
#' \enumerate{
#'   \item \strong{Obsolete spec JSONs} — older versions of a document when
#'     multiple spec JSONs exist for the same \code{doc_file}.  Only the
#'     most-recent spec per document is kept.
#'   \item \strong{Orphaned data JSONs} — data JSON files that are no longer
#'     referenced by any surviving spec JSON.
#' }
#'
#' By default the function runs in \strong{dry-run} mode and only reports what
#' would be deleted.  Pass \code{dry_run = FALSE} to actually delete files.
#'
#' @param meta_dir Character string. Path to the meta folder.
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
clean_reports <- function(meta_dir,
                           keep_versions = 1L,
                           dry_run = TRUE) {
  checkmate::assert_directory_exists(meta_dir)
  checkmate::assert_int(keep_versions, lower = 1L)
  checkmate::assert_flag(dry_run)

  keep_versions <- as.integer(keep_versions)

  idx <- .read_spec_index(meta_dir)

  # ---- 1. Identify obsolete spec JSONs ----
  obsolete_specs <- character(0)
  surviving_specs <- character(0)

  if (nrow(idx) > 0) {
    for (doc in unique(idx$doc_file)) {
      rows <- idx[idx$doc_file == doc, , drop = FALSE]
      # Sort newest first
      rows <- rows[order(rows$datetime, decreasing = TRUE), , drop = FALSE]
      if (nrow(rows) > keep_versions) {
        obsolete_specs  <- c(obsolete_specs,  rows$spec_file[seq(keep_versions + 1, nrow(rows))])
        surviving_specs <- c(surviving_specs, rows$spec_file[seq_len(keep_versions)])
      } else {
        surviving_specs <- c(surviving_specs, rows$spec_file)
      }
    }
  }

  # ---- 2. Identify orphaned data JSONs ----
  # Collect all dataRefs from SURVIVING specs
  live_refs <- character(0)
  for (sf in surviving_specs) {
    path <- file.path(meta_dir, sf)
    if (!file.exists(path)) next
    meta <- tryCatch(.collect_spec_meta(path), error = function(e) NULL)
    if (!is.null(meta)) {
      live_refs <- c(live_refs, paste0(meta$data_refs, ".json"))
    }
  }
  live_refs <- unique(live_refs)

  # All JSON files that are NOT spec JSONs and NOT the index
  all_json <- list.files(meta_dir, pattern = "\\.json$", full.names = FALSE)
  spec_files_set <- unique(c(idx$spec_file, .const_index_file))
  candidate_data <- setdiff(all_json, spec_files_set)

  orphaned_data <- setdiff(candidate_data, live_refs)

  # ---- 3. Also collect non-JSON orphaned assets (png, etc.) ----
  # Images referenced by surviving specs
  live_img_refs <- character(0)
  for (sf in surviving_specs) {
    path <- file.path(meta_dir, sf)
    if (!file.exists(path)) next
    d <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE),
                  error = function(e) NULL)
    if (is.null(d)) next
    for (k in setdiff(names(d), "_metadata")) {
      refs <- d[[k]][["dataRef"]]
      if (is.null(refs)) next
      for (ref in unlist(refs)) {
        # Figure files can be .png/.jpg/.svg — check all extensions
        for (ext in c("png", "jpg", "jpeg", "svg")) {
          live_img_refs <- c(live_img_refs, paste0(ref, ".", ext))
        }
      }
    }
  }
  live_img_refs <- unique(live_img_refs)

  all_files <- list.files(meta_dir, full.names = FALSE)
  non_json  <- setdiff(all_files, all_json)
  orphaned_imgs <- setdiff(non_json, c(live_img_refs, .const_index_file))

  # ---- 4. Report ----
  n_obs  <- length(obsolete_specs)
  n_data <- length(orphaned_data)
  n_img  <- length(orphaned_imgs)
  n_total <- n_obs + n_data + n_img

  if (n_total == 0) {
    cli::cli_alert_success("Meta folder is clean — nothing to remove.")
    return(invisible(list(obsolete_specs = character(0),
                          orphaned_data  = character(0),
                          orphaned_imgs  = character(0),
                          deleted        = character(0))))
  }

  if (dry_run) {
    cli::cli_alert_info(
      "Dry run \u2014 {n_total} file{if(n_total!=1)'s' else ''} would be removed (pass {.code dry_run = FALSE} to delete):"
    )
  } else {
    cli::cli_alert_info(
      "Removing {n_total} file{if(n_total!=1)'s' else ''}:"
    )
  }

  if (n_obs > 0) {
    cli::cli_alert_info("  {n_obs} obsolete spec JSON{if(n_obs!=1)'s' else ''}:")
    for (f in obsolete_specs) cli::cli_text("    {.file {f}}")
  }
  if (n_data > 0) {
    cli::cli_alert_info("  {n_data} orphaned data JSON{if(n_data!=1)'s' else ''}:")
    for (f in orphaned_data) cli::cli_text("    {.file {f}}")
  }
  if (n_img > 0) {
    cli::cli_alert_info("  {n_img} orphaned image file{if(n_img!=1)'s' else ''}:")
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
    if (nrow(new_idx) > 0) {
      index_path <- file.path(meta_dir, .const_index_file)
      # Convert to list-of-records for JSON
      records <- lapply(seq_len(nrow(new_idx)), function(i) {
        list(
          spec_file = new_idx$spec_file[i],
          doc_file  = new_idx$doc_file[i],
          datetime  = new_idx$datetime[i],
          n_specs   = new_idx$n_specs[i],
          data_refs = as.list(new_idx$data_refs[[i]])
        )
      })
      writeLines(
        jsonlite::toJSON(records, auto_unbox = TRUE, pretty = TRUE),
        con = index_path
      )
    }

    cli::cli_alert_success("Removed {length(deleted)} file{if(length(deleted)!=1)'s' else ''}.")
  }

  invisible(list(
    obsolete_specs = obsolete_specs,
    orphaned_data  = orphaned_data,
    orphaned_imgs  = orphaned_imgs,
    deleted        = deleted
  ))
}
