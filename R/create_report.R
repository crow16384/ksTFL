#' Consolidate Styles in a TFL Specification
#'
#' Internal helper function that consolidates style references within a single spec:
#' \enumerate{
#'   \item Collects all referenced styles from all locations (labelStyleRef, valueStyleRef, styleRef)
#'   \item Identifies style combinations (character vectors with length > 1)
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
  
  # Step 1: Collect all referenced styles
  referenced_styles <- list()  # Will store style names and their references
  style_combinations <- list() # Will store combinations to be merged
  
  # Helper function to extract style refs from any object recursively
  .collect_style_refs <- function(obj, path = "") {
    if (is.null(obj)) {
      return()
    }
    
    if (is.list(obj)) {
      for (name in names(obj)) {
        current_path <- paste(path, name, sep = "$")
        
        # Check if this is a styleRef field
        if (name %in% c("labelStyleRef", "valueStyleRef", "styleRef")) {
          val <- obj[[name]]
          if (!is.null(val)) {
            if (is.character(val)) {
              # Store this reference
              if (length(val) == 1) {
                # Single style reference
                if (!(val %in% names(referenced_styles))) {
                  referenced_styles[[val]] <<- TRUE
                }
              } else if (length(val) > 1) {
                # Style combination
                sorted_combo <- sort(val)
                combo_str <- paste(sorted_combo, collapse = "|")
                if (!(combo_str %in% names(style_combinations))) {
                  style_combinations[[combo_str]] <<- list(
                    original = val,
                    sorted = sorted_combo
                  )
                }
                # Add all individual styles to referenced
                for (s in val) {
                  if (!(s %in% names(referenced_styles))) {
                    referenced_styles[[s]] <<- TRUE
                  }
                }
              }
            }
          }
        }
        
        # Recurse into nested lists
        if (is.list(obj[[name]]) && !is.null(names(obj[[name]]))) {
          .collect_style_refs(obj[[name]], current_path)
        }
      }
    }
  }
  
  # Collect all style references from the spec
  .collect_style_refs(spec$columns)
  .collect_style_refs(spec$stubColumns)
  .collect_style_refs(spec$titles)
  .collect_style_refs(spec$subtitles)
  .collect_style_refs(spec$footnotes)
  .collect_style_refs(spec$bodyText)
  .collect_style_refs(spec$headers)
  .collect_style_refs(spec$footers)
  
  # Step 2: Validate all referenced styles exist
  for (style_name in names(referenced_styles)) {
    if (!(style_name %in% names(spec$attribs$styles))) {
      cli_abort(c(
        "Referenced style {.str {style_name}} not found in spec",
        x = "All styles must be defined using add_style() before create_report()"
      ))
    }
  }
  
  # Step 3: Create merged styles for combinations
  merged_hashes <- list() # Maps combo_str -> hash
  
  for (combo_str in names(style_combinations)) {
    combo_info <- style_combinations[[combo_str]]
    sorted_combo <- combo_info$sorted
    
    # Generate hash from sorted combination
    combo_hash <- paste0("style_", .generate_hash(sorted_combo))
    merged_hashes[[combo_str]] <- combo_hash
    
    # Check if merged style already exists (shouldn't happen, but be safe)
    if (!(combo_hash %in% names(spec$attribs$styles))) {
      # Merge component styles
      merged_style <- list()
      
      for (style_name in sorted_combo) {
        base_style <- spec$attribs$styles[[style_name]]
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
      for (name in names(obj)) {
        if (name %in% c("labelStyleRef", "valueStyleRef", "styleRef")) {
          val <- obj[[name]]
          if (is.character(val) && length(val) > 1) {
            # This is a combination - replace with hash
            sorted_combo <- sort(val)
            combo_str <- paste(sorted_combo, collapse = "|")
            obj[[name]] <- merged_hashes[[combo_str]]
          }
        } else if (is.list(obj[[name]]) && !is.null(names(obj[[name]]))) {
          # Recurse
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
  
  # Step 5: Remove unreferenced styles
  # Build updated referenced list after combination replacements
  updated_referenced <- list()
  
  .collect_final_refs <- function(obj) {
    if (is.null(obj)) {
      return()
    }
    
    if (is.list(obj)) {
      for (name in names(obj)) {
        if (name %in% c("labelStyleRef", "valueStyleRef", "styleRef")) {
          val <- obj[[name]]
          if (is.character(val)) {
            if (length(val) == 1) {
              updated_referenced[[val]] <<- TRUE
            } else {
              # Should not happen after replacement, but handle it
              for (s in val) {
                updated_referenced[[s]] <<- TRUE
              }
            }
          }
        } else if (is.list(obj[[name]]) && !is.null(names(obj[[name]]))) {
          .collect_final_refs(obj[[name]])
        }
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
#'
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
#'
#' @export
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
    result[[item$key]] <- item$spec
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
