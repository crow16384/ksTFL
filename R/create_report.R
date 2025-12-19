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

#' Combine Multiple TFL Specifications into a Single Report
#'
#' This function takes multiple TFL specification objects and combines them into
#' a single report object matching the spec_schema_v1 structure. Each spec is
#' keyed by a combination of its variable name and metadata hash.
#'
#' @param ... One or more objects of class `TFL_spec` to be combined.
#' \itemize{
#'   \item Each argument must be a `TFL_spec` produced by `create_table()`, `create_text()` or `create_figure()`.
#'   \item Arguments are keyed in the resulting report by the argument name combined with the spec metadata hash (see return value).
#' }
#'
#' @details
#' The function performs the following operations:
#' \enumerate{
#'   \item Validates that all inputs are of class `TFL_spec`
#'   \item Consolidates styles within each spec (merges combinations, removes unreferenced styles)
#'   \item Assigns a `docOrder` integer (1, 2, 3, ...) based on input position
#'   \item Updates each spec's `dataRef` to `<hash>_0001`, `<hash>_0002`, etc.
#'   \item Returns a named list keyed by `<varname>_<hash>`
#' }
#'
#' @return A named list where each element is a modified TFL_spec object,
#'   keyed by the pattern `<variable_name>_<hash>`.
#'
#' @examples
#' \dontrun{
#' spec1 <- create_table(mtcars)
#' spec2 <- create_text()
#' final_report <- create_report(spec1, spec2)
#' }
#'
#' @export
create_report <- function(...) {
  # Capture all arguments and their names
  specs_list <- list(...)
  spec_names <- as.character(substitute(list(...)))[-1]  # Remove 'list' element

  # Validate input is not empty
  if (length(specs_list) == 0) {
    cli_abort("create_report() requires at least one TFL_spec object")
  }

  # Validate all objects are TFL_spec
  for (i in seq_along(specs_list)) {
    if (!inherits(specs_list[[i]], "TFL_spec")) {
      cli_abort(c(
        "All arguments to create_report() must be of class TFL_spec",
        x = "Argument {i} ({.val {spec_names[[i]]}}) is of class {.cls {class(specs_list[[i]])}}"
      ))
    }
  }

  # Process each spec
  result <- list()

  for (i in seq_along(specs_list)) {
    spec <- specs_list[[i]]
    var_name <- spec_names[[i]]
    
    # Consolidate styles before processing
    spec <- ._consolidate_styles_in_spec(spec)
    
    hash <- spec$.metadata$hash

    # Validate hash exists
    if (is.null(hash) || !is.character(hash) || hash == "") {
      cli_abort(c(
        "Spec object {.val {var_name}} has invalid or missing metadata hash",
        i = "Ensure the spec was properly initialized with create_table(), create_text(), or create_figure()"
      ))
    }

    # Create the key: <varname>_<hash>
    key <- paste0(var_name, "_", hash)

    # Update docOrder: 1-based index
    spec$document$docOrder <- as.integer(i)

    # Update dataRef: <hash>_<docOrder with 4-digit padding>
    doc_order_padded <- sprintf("%04d", i)
    spec$dataRef <- c(paste0(doc_order_padded, "_", hash))

    # Add to result list with the key
    result[[key]] <- spec
  }

  class(result) <- c("TFL_report", "list")
  return(result)
}
