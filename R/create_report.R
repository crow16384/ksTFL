#' Consolidate Styles in a TFL Specification
#'
#' Internal helper function that consolidates style references within a single spec:
#' \enumerate{
#'   \item Collects all referenced styles from all locations (labelStyleRef, valueStyleRef, styleRef)
#'   \item Identifies style combinations (character vectors with length \code{>} 1)
#'   \item For each combination, merges component styles into one combined style
#'   \item Replaces all references with the new combined style hash
#'   \item Validates that all referenced styles exist
#'   \item Removes unreferenced styles from the spec
#' }
#'
#' @param spec A TFL_spec object
#'
#' @return Updated spec with consolidated styles
#' @keywords internal
#' @noRd
._consolidate_styles_in_spec <- function(spec) {
  if (!inherits(spec, "TFL_spec")) {
    cli_abort("Input must be a TFL_spec object")
  }
  
  # Step 1: Collect all referenced styles AND compute hashes for combinations
  # Do this completely inline to avoid nested function scope issues
  referenced_styles <- list()
  style_combinations <- list()
  
  # Helper to collect styles from a single list object (inline recursion below)
  # Returns list of (combo_str, original, sorted) tuples found at this level
  extract_style_refs_from_obj <- function(obj) {
    if (is.null(obj) || !is.list(obj)) return(list())
    
    combos_found <- list()
    
    # Handle unnamed lists (like styleRows which is list(list(...), list(...), ...))
    if (is.null(names(obj)) || all(names(obj) == "")) {
      # Unnamed list - iterate through elements
      for (item in obj) {
        if (is.list(item)) {
          extract_style_refs_from_obj(item)
        }
      }
      return(combos_found)
    }
    
    # Named list - process fields
    for (name in names(obj)) {
      val <- obj[[name]]
      if (is.null(val)) next
      
      if (name %in% c("labelStyleRef", "valueStyleRef", "styleRef")) {
        # These fields should contain style references (character vectors)
        if (is.character(val)) {
          if (length(val) == 1) {
            if (!(val %in% names(referenced_styles))) {
              referenced_styles[[val]] <<- TRUE
            }
          } else if (length(val) > 1) {
            sorted_combo <- sort(val)
            combo_str <- paste(sorted_combo, collapse = "|")
            if (!(combo_str %in% names(style_combinations))) {
              style_combinations[[combo_str]] <<- list(
                original = val, sorted = sorted_combo, hash = NA_character_
              )
            }
            combos_found[[length(combos_found) + 1]] <- list(combo = combo_str, sorted = sorted_combo)
            for (s in val) {
              if (!(s %in% names(referenced_styles))) {
                referenced_styles[[s]] <<- TRUE
              }
            }
          }
        }
      } else if (name == "style") {
        # Handle "style" field which can be:
        # 1. A character vector with style references: c("style1", "style2")
        # 2. A list of action objects: list(list(cols=..., style=c(...)), ...)
        if (is.character(val)) {
          # Direct character style reference
          if (length(val) == 1) {
            if (!(val %in% names(referenced_styles))) {
              referenced_styles[[val]] <<- TRUE
            }
          } else if (length(val) > 1) {
            # Direct combination
            sorted_combo <- sort(val)
            combo_str <- paste(sorted_combo, collapse = "|")
            if (!(combo_str %in% names(style_combinations))) {
              style_combinations[[combo_str]] <<- list(
                original = val, sorted = sorted_combo, hash = NA_character_
              )
            }
            for (s in val) {
              if (!(s %in% names(referenced_styles))) {
                referenced_styles[[s]] <<- TRUE
              }
            }
          }
        } else if (is.list(val) && length(val) > 0) {
          # List of action objects - recurse into them
          if (!is.null(names(val))) {
            # Named list - recurse directly
            extract_style_refs_from_obj(val)
          } else if (all(sapply(val, is.list))) {
            # Unnamed list of lists (style actions array)
            for (action_obj in val) {
              if (is.list(action_obj)) {
                extract_style_refs_from_obj(action_obj)
              }
            }
          }
        }
      }
    }
    combos_found
  }
  
  # Process each major spec field
  # For each, recursively search all nested lists
  process_spec_field <- function(field_obj, max_depth = 5) {
    if (is.null(field_obj)) return()
    
    # Process current level
    extract_style_refs_from_obj(field_obj)
    
    # Recursively process nested lists
    if (is.list(field_obj) && max_depth > 0) {
      for (name in names(field_obj)) {
        val <- field_obj[[name]]
        if (is.list(val) && length(val) > 0) {
          # If it's a list with names, recurse
          if (!is.null(names(val))) {
            process_spec_field(val, max_depth - 1)
          } else if (all(sapply(val, is.list))) {
            # If it's unnamed list of lists, process each
            for (item in val) {
              if (is.list(item)) {
                extract_style_refs_from_obj(item)
                process_spec_field(item, max_depth - 1)
              }
            }
          }
        }
      }
    }
  }
  
  # Collect from all spec fields
  process_spec_field(spec$columns)
  process_spec_field(spec$stubColumns)
  process_spec_field(spec$titles)
  process_spec_field(spec$subtitles)
  process_spec_field(spec$footnotes)
  process_spec_field(spec$bodyText)
  process_spec_field(spec$headers)
  process_spec_field(spec$footers)
  process_spec_field(spec$styleRows)
  
  # Now compute hashes and update referenced_styles
  for (combo_str in names(style_combinations)) {
    sorted_combo <- style_combinations[[combo_str]]$sorted
    combo_hash <- paste0("style_", .generate_hash(sorted_combo))
    style_combinations[[combo_str]]$hash <- combo_hash
    # Update referenced: remove combo_str placeholder, add hash
    referenced_styles[[combo_str]] <- NULL
    referenced_styles[[combo_hash]] <- TRUE
  }
  
  # Step 2: Skip validation for now - we'll validate after creating consolidated styles in Step 3
  
  # Step 3: Create merged styles for combinations
  merged_hashes <- list() # Maps combo_str -> hash
  
  for (combo_str in names(style_combinations)) {
    combo_info <- style_combinations[[combo_str]]
    sorted_combo <- combo_info$sorted
    
    # Use the hash that was computed and stored in collection phase
    combo_hash <- combo_info$hash
    merged_hashes[[combo_str]] <- combo_hash
    
    # Check if merged style already exists (shouldn't happen, but be safe)
    if (!(combo_hash %in% names(spec$attribs$styles))) {
      # Merge component styles
      merged_style <- list()
      
      for (style_name in sorted_combo) {
        # Get style from spec if it exists, otherwise create empty
        base_style <- spec$attribs$styles[[style_name]]
        if (is.null(base_style)) {
          # Style reference doesn't exist - create empty placeholder
          # (This allows f_combine() to reference non-existent styles gracefully)
          base_style <- list()
        }
        merged_style <- .merge_recursive(merged_style, base_style)
      }
      
      # Add merged style to spec
      spec$attribs$styles[[combo_hash]] <- merged_style
    }
  }
  
  # Step 4: Replace all style combination references with merged hashes
  .replace_style_refs <- function(obj) {
    if (is.null(obj)) {
      return(obj)
    }
    
    if (is.list(obj)) {
      # Check if this is a list of lists (like styleRows action arrays)
      # If all elements are lists, iterate and recurse on each
      if (length(obj) > 0 && all(sapply(obj, is.list))) {
        return(lapply(obj, .replace_style_refs))
      }
      
      # Otherwise, process this list's named fields
      for (name in names(obj)) {
        if (name %in% c("labelStyleRef", "valueStyleRef", "styleRef", "style")) {
          val <- obj[[name]]
          if (is.character(val) && length(val) > 1) {
            # This is a combination - replace with hash
            sorted_combo <- sort(val)
            combo_str <- paste(sorted_combo, collapse = "|")
            if (!is.null(merged_hashes[[combo_str]])) {
              obj[[name]] <- merged_hashes[[combo_str]]
            }
          } else if (is.list(val)) {
            # Recurse into list values (for nested style action objects)
            obj[[name]] <- .replace_style_refs(val)
          }
        } else if (is.list(obj[[name]])) {
          # Recurse into other list fields
          obj[[name]] <- .replace_style_refs(obj[[name]])
        }
      }
    }
    
    obj
  }
  
  # Apply replacements
  spec$columns <- .replace_style_refs(spec$columns)
  spec$stubColumns <- .replace_style_refs(spec$stubColumns)
  spec$titles <- .replace_style_refs(spec$titles)
  spec$subtitles <- .replace_style_refs(spec$subtitles)
  spec$footnotes <- .replace_style_refs(spec$footnotes)
  spec$bodyText <- .replace_style_refs(spec$bodyText)
  spec$headers <- .replace_style_refs(spec$headers)
  spec$footers <- .replace_style_refs(spec$footers)
  
  # Also replace style combinations in styleRows (now R list structures)
  if (!is.null(spec$styleRows) && length(spec$styleRows) > 0) {
    for (i in seq_along(spec$styleRows)) {
      if (!is.null(spec$styleRows[[i]])) {
        spec$styleRows[[i]] <- .replace_style_refs(spec$styleRows[[i]])
      }
    }
  }
  
  # Step 5: Remove unreferenced styles
  # Build updated referenced list after combination replacements
  updated_referenced <- list()
  
  .collect_final_refs <- function(obj) {
    if (is.null(obj)) {
      return()
    }
    
    if (!is.list(obj)) {
      return()
    }
    
    # Handle unnamed lists (iterate through all elements)
    if (is.null(names(obj)) || all(names(obj) == "")) {
      for (item in obj) {
        if (is.list(item)) {
          .collect_final_refs(item)
        }
      }
      return()
    }
    
    # Named list - process fields
    for (name in names(obj)) {
      val <- obj[[name]]
      if (is.null(val)) next
      
      if (name %in% c("labelStyleRef", "valueStyleRef", "styleRef")) {
        if (is.character(val) && length(val) >= 1) {
          for (s in val) {
            if (!is.na(s) && nzchar(s)) {
              updated_referenced[[s]] <<- TRUE
            }
          }
        }
      } else if (name == "style") {
        # Handle style field - can be character vector or list of action objects
        if (is.character(val) && length(val) >= 1) {
          for (s in val) {
            if (!is.na(s) && nzchar(s)) {
              updated_referenced[[s]] <<- TRUE
            }
          }
        } else if (is.list(val)) {
          # Recurse into style list
          .collect_final_refs(val)
        }
      } else if (is.list(val)) {
        # Recurse into other list fields
        .collect_final_refs(val)
      }
    }
  }
  
  .collect_final_refs(spec$columns)
  .collect_final_refs(spec$stubColumns)
  .collect_final_refs(spec$titles)
  .collect_final_refs(spec$subtitles)
  .collect_final_refs(spec$footnotes)
  .collect_final_refs(spec$bodyText)
  .collect_final_refs(spec$headers)
  .collect_final_refs(spec$footers)
  .collect_final_refs(spec$styleRows)
  
  # Keep only referenced styles
  spec$attribs$styles <- spec$attribs$styles[names(spec$attribs$styles) %in% names(updated_referenced)]
  
  spec
}

#' Combine Multiple TFL Specifications and/or Reports into a Single Report
#'
#' This function takes multiple TFL specification objects and/or previously created
#' TFL report objects and combines them into a single report object matching the
#' spec_schema_v1 structure. Each spec is keyed by a combination of its variable
#' name and metadata hash (for direct specs) or preserves original keys (for specs
#' from reports).
#'
#' @param ... One or more objects of class `TFL_spec` or `TFL_report` to be combined.
#' \itemize{
#'   \item `TFL_spec` objects produced by `create_table()`, `create_text()` or `create_figure()`.
#'   \item `TFL_report` objects produced by previous calls to `create_report()`.
#'   \item Arguments are processed in order; each new `TFL_spec` is keyed by the
#'         argument name combined with the spec metadata hash.
#'   \item `TFL_report` objects are flattened and their spec keys are preserved.
#' }
#'
#' @details
#' The function performs the following operations:
#' \enumerate{
#'   \item Flattens all inputs (extracts specs from `TFL_report` objects)
#'   \item Validates that no duplicate spec keys exist across all inputs
#'   \item Consolidates styles within newly-added `TFL_spec` objects only
#'         (specs from `TFL_report` are already consolidated)
#'   \item Assigns a global `docOrder` integer (1, 2, 3, ...) based on final position
#'   \item Preserves existing `dataRef` values and warns if duplicates detected
#'   \item Returns a named list keyed by `<variable_name>_<hash>` or original report keys
#' }
#'
#' @return A named list where each element is a TFL_spec object,
#'   keyed by the pattern `<variable_name>_<hash>` for direct specs, or
#'   original keys for specs extracted from input reports.
#'   Result has class `TFL_report`.
#' @export
#' @examples
#' \dontrun{
#' spec1 <- create_table(mtcars)
#' spec2 <- create_text()
#' final_report <- create_report(spec1, spec2)
#'
#' # Combining with a previous report
#' spec3 <- create_figure("path/to/image.png")
#' combined <- create_report(final_report, spec3)
#' }
create_report <- function(...) {
  # Capture all arguments and their names
  specs_list <- list(...)
  spec_names <- as.character(substitute(list(...)))[-1]  # Remove 'list' element

  # Validate input is not empty
  if (length(specs_list) == 0) {
    cli_abort("create_report() requires at least one TFL_spec or TFL_report object")
  }

  # ---- PHASE 1: Flatten inputs (order-preserving) ----
  flattened <- list()  # Will store list of (key, spec, is_new) tuples
  
  for (i in seq_along(specs_list)) {
    obj <- specs_list[[i]]
    obj_name <- spec_names[[i]]
    
    if (inherits(obj, "TFL_report")) {
      # Extract all specs from the report with their keys
      for (report_key in names(obj)) {
        spec <- obj[[report_key]]
        flattened[[length(flattened) + 1]] <- list(
          key = report_key,
          spec = spec,
          is_new = FALSE  # Pre-consolidated
        )
      }
    } else if (inherits(obj, "TFL_spec")) {
      # Compute key for direct spec
      hash <- obj$.metadata$hash
      if (is.null(hash) || !is.character(hash) || hash == "") {
        cli_abort(c(
          "Spec object {.val {obj_name}} has invalid or missing metadata hash",
          i = "Ensure the spec was properly initialized with create_table(), create_text(), or create_figure()"
        ))
      }
      
      key <- paste0(obj_name, "_", hash)
      flattened[[length(flattened) + 1]] <- list(
        key = key,
        spec = obj,
        is_new = TRUE  # Needs style consolidation
      )
    } else {
      cli_abort(c(
        "All arguments to create_report() must be of class TFL_spec or TFL_report",
        x = "Argument {i} ({.val {obj_name}}) is of class {.cls {class(obj)}}"
      ))
    }
  }

  # ---- PHASE 2: Validate duplicate keys ----
  all_keys <- vapply(flattened, function(x) x$key, character(1))
  duplicate_keys <- all_keys[duplicated(all_keys)]
  
  if (length(duplicate_keys) > 0) {
    cli_abort(c(
      "Duplicate spec keys detected across inputs",
      x = "The following keys appear multiple times: {.str {unique(duplicate_keys)}}",
      i = "This indicates specs with identical content; ensure each spec is unique"
    ))
  }

  # ---- PHASE 2.5: Finalize compute_cols actions (evaluate conditions and build rowstyle) ----
  for (i in seq_along(flattened)) {
    if (flattened[[i]]$is_new) {
      spec <- flattened[[i]]$spec
      # Only finalize if spec has compute_cols metadata
      if (!is.null(spec$.metadata$compute_cols) && length(spec$.metadata$compute_cols) > 0) {
        spec <- .finalize_compute_cols(spec)
        flattened[[i]]$spec <- spec
      }
    }
  }

  # ---- PHASE 3: Style consolidation (only for new specs) ----
  for (i in seq_along(flattened)) {
    if (flattened[[i]]$is_new) {
      flattened[[i]]$spec <- ._consolidate_styles_in_spec(flattened[[i]]$spec)
    }
  }

  # ---- PHASE 4: Renumber docOrder globally and create dataRef for new specs ----
  for (i in seq_along(flattened)) {
    flattened[[i]]$spec$document$docOrder <- as.integer(i)
    
    # Create dataRef for new specs (direct TFL_spec objects)
    # For specs from TFL_report, preserve existing dataRef
    if (flattened[[i]]$is_new) {
      hash <- flattened[[i]]$spec$.metadata$hash
      doc_order_padded <- sprintf("%04d", i)
      flattened[[i]]$spec$dataRef <- c(paste0(doc_order_padded, "_", hash))
    }
  }

  # ---- PHASE 5: Validate dataRef (collect all warnings) ----
  all_data_refs <- list()
  warnings_to_issue <- character(0)
  
  for (i in seq_along(flattened)) {
    spec <- flattened[[i]]$spec
    key <- flattened[[i]]$key
    
    data_refs <- spec$dataRef
    if (!is.null(data_refs) && length(data_refs) > 0) {
      for (ref in data_refs) {
        if (is.null(all_data_refs[[ref]])) {
          all_data_refs[[ref]] <- list()
        }
        all_data_refs[[ref]] <- c(all_data_refs[[ref]], key)
      }
    }
  }
  
  # Identify duplicate dataRef values
  for (ref in names(all_data_refs)) {
    if (length(all_data_refs[[ref]]) > 1) {
      specs_with_ref <- paste(all_data_refs[[ref]], collapse = ", ")
      warnings_to_issue <- c(
        warnings_to_issue,
        paste0(ref, " \u2192 ", specs_with_ref)
      )
    }
  }

  # ---- PHASE 6: Build result ----
  result <- list()
  
  for (item in flattened) {
    spec <- item$spec
    
    # Serialize styleRows from R list objects to JSON strings
    if (!is.null(spec$styleRows) && length(spec$styleRows) > 0) {
      spec$styleRows <- sapply(spec$styleRows, function(row_obj) {
        if (is.null(row_obj)) {
          return("{}")  # Empty string for no actions
        }
        jsonlite::toJSON(row_obj, auto_unbox = TRUE)
      }, USE.NAMES = FALSE)
    }
    
    result[[item$key]] <- spec
  }

  class(result) <- c("TFL_report", "list")
  
  # Issue collected dataRef warnings (if any)
  if (length(warnings_to_issue) > 0) {
    warning_message <- c(
      "The following dataRef values are referenced by multiple specs:",
      stats::setNames(warnings_to_issue, rep("*", length(warnings_to_issue))),
      i = "This may indicate shared data files across documents"
    )
    cli_warn(warning_message)
  }

  return(result)
}
