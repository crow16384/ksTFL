##' Schema serialization and validation (internal)
##'
##' Module: JSON Schema Serialization for ksTFL
##'
##' This internal module validates R objects against the package JSON schemas
##' and prepares them for JSON export. Key responsibilities:
##' - Resolve internal `$ref` references and `$defs`
##' - Merge `allOf` subschemas and handle combinators (`oneOf`, `anyOf`)
##' - Enforce `type`, `enum`, and `pattern` constraints and coerce values
##' - Provide detailed JSON Pointer-based error reporting for diagnostics
##'
##' These helpers are internal and intended for `serialize_spec()` and
##' related serialization pipelines.
##'
##' @keywords internal
##' @name schema_serialize
NULL

################################################################################
 # TFL Framework - JSON Schema Serialization
 #
 # This module provides schema-driven validation and JSON serialization. It handles:
 # - Internal $ref/$defs resolution
 # - allOf, oneOf, anyOf combinators
 # - enum and pattern validation
 # - Type coercion and validation
 # - JSON Pointer paths for error reporting
 #
 # The serializer ensures R objects conform to their schema before JSON export.
################################################################################


################################################################################
# Schema Cache
################################################################################

# Global environment for caching loaded schemas
.schema_cache <- new.env(parent = emptyenv())

#' Load Schema with Caching
#'
#' @description Internal helper to load and cache JSON schemas.
#' Subsequent loads of the same schema file will use cached version.
#'
#' @param schema_path Path to JSON schema file
#'
#' @return Parsed schema as R list
#' @keywords internal
.load_schema <- function(schema_path) {
  # Normalize path for consistent caching
  schema_path <- normalizePath(schema_path, mustWork = FALSE)
  
  if (exists(schema_path, envir = .schema_cache)) {
    return(get(schema_path, envir = .schema_cache))
  }
  
  # Read file as text and remove BOM if present
  json_text <- readLines(schema_path, warn = FALSE, encoding = "UTF-8")
  json_text <- paste(json_text, collapse = "\n")
  
  # Remove UTF-8 BOM (U+FEFF) if present at start
  if (substr(json_text, 1, 1) == "\uFEFF") {
    json_text <- substring(json_text, 2)
  }
  
  schema <- jsonlite::fromJSON(json_text, simplifyVector = FALSE)
  assign(schema_path, schema, envir = .schema_cache)
  
  schema
}

#' Clear Schema Cache
#'
#' @description Clear all cached schemas. Useful for development or if schemas change.
#'
#' @return Invisibly returns TRUE
#' @export
#'
#' @examples
#' \dontrun{
#' clear_schema_cache()
#' }
clear_schema_cache <- function() {
  rm(list = ls(envir = .schema_cache), envir = .schema_cache)
  cli::cli_alert_success("Schema cache cleared")
  invisible(TRUE)
}


################################################################################
# Internal Helper Functions
################################################################################

#' Get Schema File Path from Package Resources
#'
#' @description Resolves a schema file name to its full path in package resources.
#' Validates that the file exists.
#'
#' @param schema_name Name of the schema file (e.g., from constants)
#'
#' @return Full path to schema file
#'
#' @keywords internal
#' @noRd
.get_schema_file_path <- function(schema_name) {
  checkmate::assert_string(schema_name)
  
  schema_file <- system.file(
    .const_schemas_dir,
    schema_name,
    package = "ksTFL"
  )
  
  if (schema_file == "") {
    cli::cli_abort(
      c(
        "Schema file not found in package resources",
        i = "Looking for: {.emph {schema_name}}"
      )
    )
  }
  
  schema_file
}

#' Normalize JSON Pointer Path Tokens
#'
#' @description Builds JSON Pointer path from tokens with proper escaping.
#' Handles root path and nested keys.
#'
#' @param tokens Character vector of tokens to join
#' @param is_root Logical. If TRUE, path starts empty; otherwise uses root "/"
#'
#' @return Character string of JSON Pointer path
#'
#' @keywords internal
#' @noRd
.normalize_json_pointer_path <- function(tokens, is_root = TRUE) {
  if (length(tokens) == 0) return(if (is_root) "" else "/")
  
  # Escape each token
  escaped <- vapply(tokens, .json_pointer_escape, character(1), USE.NAMES = FALSE)
  
  # Join with "/" prefix
  if (is_root) {
    paste0("/", paste(escaped, collapse = "/"))
  } else {
    paste(escaped, collapse = "/")
  }
}

#' Validate and Normalize Schema Input
#'
#' @description Ensures schema is either a valid list or a path to a schema file.
#' Loads file if path provided. Uses cache for efficiency.
#'
#' @param schema Schema as R list or file path (character)
#'
#' @return Parsed schema as R list
#'
#' @keywords internal
#' @noRd
.validate_schema_input <- function(schema) {
  if (missing(schema) || is.null(schema)) {
    cli::cli_abort("schema must be provided as R list or JSON file path")
  }
  
  # If character path, load from file
  if (is.character(schema)) {
    checkmate::assert_string(schema, .var.name = "schema")
    
    if (!file.exists(schema)) {
      cli::cli_abort(
        c(
          "Schema file not found",
          x = "Path: {.file {schema}}"
        )
      )
    }
    
    tryCatch({
      schema <- .load_schema(schema)
    }, error = function(e) {
      cli::cli_abort(
        c(
          "Failed to parse schema file",
          x = "Error: {e$message}"
        )
      )
    })
  }
  
  # Validate it's a list
  if (!is.list(schema)) {
    cli::cli_abort("schema must be R list or valid file path")
  }
  
  # Validate as list structure
  checkmate::assert_list(schema, .var.name = "schema")
  
  schema
}

#' Check if Schema Has Combinator
#'
#' @description Tests if schema has oneOf or anyOf combinators
#'
#' @param schema Schema fragment
#' @param combinator Type of combinator: "any" (both), "one" (oneOf), or "any" (anyOf)
#'
#' @return Logical TRUE/FALSE or character string for "any" mode
#'
#' @keywords internal
#' @noRd
.has_combinator <- function(schema, combinator = "any") {
  if (!is.list(schema)) return(FALSE)
  
  has_any_of <- !is.null(schema[[.const_schema_keywords$anyOf]])
  has_one_of <- !is.null(schema[[.const_schema_keywords$oneOf]])
  
  switch(combinator,
    "any" = has_any_of || has_one_of,
    "one" = has_one_of,
    "anyOf" = has_any_of,
    FALSE
  )
}

#' Get Combinator Variants
#'
#' @description Extracts oneOf or anyOf variants from schema
#'
#' @param schema Schema with combinators
#'
#' @return List of variant schemas, or NULL if no combinators
#'
#' @keywords internal
#' @noRd
.get_combinator_variants <- function(schema) {
  if (!is.list(schema)) return(NULL)
  
  schema[[.const_schema_keywords$anyOf]] %||% 
    schema[[.const_schema_keywords$oneOf]]
}


################################################################################
# Public API
################################################################################

#' Serialize TFL Specification to JSON
#'
#' @description Takes a TFL_report object created by `create_report()`, validates it
#' against the spec schema, and returns both the original spec and the processed
#' data structure ready for JSON serialization.
#'
#' @param spec A TFL_report object (output from `create_report()`)
#' @param enforce_additional_properties Logical. If TRUE, enforce `additionalProperties`
#'   rules from schema. Default: FALSE
#'
#' @details The function:
#' - Validates the spec class is TFL_report
#' - Loads the spec schema from package resources
#' - Resolves all `$ref` pointers and merges `allOf` schemas
#' - Validates types, enums, and patterns
#' - Coerces values to correct types
#' - Returns both original and processed data for external serialization
#'
#' @return A list with two elements:
#'   - `spec`: The original TFL_report object
#'   - `fixed`: The processed data structure ready for JSON serialization
#'
#' @export
#'
#' @examples
#' \dontrun{
#' spec1 <- create_table(mtcars)
#' spec2 <- create_text()
#' report <- create_report(spec1, spec2)
#' result <- serialize_spec(report)
#' # result$fixed is now ready for JSON serialization
#' }
serialize_spec <- function(spec, enforce_additional_properties = FALSE) {
  # Validate input is a TFL_report
  if (!inherits(spec, "TFL_report")) {
    cli::cli_abort(
      c(
        "spec must be a TFL_report object",
        x = "Got object of class {.cls {class(spec)}}"
      )
    )
  }

  # Get schema file path from package resources
  schema_file <- .get_schema_file_path(.const_spec_schema_file)

  # Process the spec using internal serialization function
  fixed <- .serialize_json_internal(
    spec,
    schema_file,
    enforce_additional_properties = enforce_additional_properties
  )

  # Return both original and processed data
  list(spec = spec, fixed = fixed)
}

#' Internal JSON Serialization Engine
#'
#' @description Validate and normalize an R object to conform to a JSON Schema
#' (Draft-07 compatible), then serialize to JSON using jsonlite.
#'
#' @param data R object to serialize (usually a list matching schema structure)
#' @param schema Schema as either:
#'   - An R list (parsed JSON schema)
#'   - A character string (path to JSON schema file)
#' @param enforce_additional_properties Logical. If TRUE, enforce `additionalProperties`
#'   rules from schema. Default: FALSE (allows extra keys)
#'
#' @details The serializer:
#' - Resolves all internal `$ref` pointers (#/path/to/def)
#' - Merges `allOf` subschemas
#' - Validates against type, enum, and pattern constraints
#' - Coerces values to correct types
#' - Reports errors with JSON Pointer paths for debugging
#'
#' Supports JSON Schema features:
#' - `type`: scalar or array of types (string, number, integer, boolean, array, object, null)
#' - `enum`: enumeration of valid values
#' - `pattern`: regular expression for string values
#' - `properties`: object property definitions
#' - `items`: array element schema
#' - `patternProperties`: regex-matched property validation
#' - `allOf`, `oneOf`, `anyOf`: combinators
#'
#' @return Processed data structure (not JSON string)
#'
#' @keywords internal
#' @examples
#' \dontrun{
#' # Simple schema and data
#' schema <- list(
#'   type = "object",
#'   properties = list(
#'     name = list(type = "string"),
#'     age = list(type = "integer")
#'   )
#' )
#'
#' data <- list(name = "John", age = 30)
#' fixed <- .serialize_json_internal(data, schema)
#' }
.serialize_json_internal <- function(data, schema, enforce_additional_properties = FALSE) {
  # Validate and normalize schema input using helper
  schema <- .validate_schema_input(schema)
  
  # Resolve schema references
  schema_resolved <- .resolve_refs(schema)
  schema_expanded <- .resolve_allOf(schema_resolved)
  
  # Transform data to match schema
  fixed <- .fix_types(data, schema_expanded, path = "", 
                      enforce_additional_properties = enforce_additional_properties)
  
  # Protect arrays from auto_unbox (pass root schema for ref resolution)
  fixed <- .protect_arrays(fixed, schema_expanded, root_schema = schema_expanded)
  
  # Return processed data structure (caller handles JSON serialization)

  fixed <- .unclass_recursive(fixed)
  fixed
}

#' Protect arrays from auto_unbox by wrapping with AsIs
#' @description Walks through data and schema, wrapping arrays with I()
#' so auto_unbox won't convert length-1 arrays to scalars
#' @keywords internal
#' @noRd
.protect_arrays <- function(data, schema, root_schema = NULL) {
  if (is.null(schema) || is.null(data)) return(data)
  
  # Use schema as root if not provided
  if (is.null(root_schema)) root_schema <- schema
  
  # Handle combinators - select the matching variant
  if (.has_combinator(schema)) {
    variants <- .get_combinator_variants(schema)
    
    # Find matching variant based on type discriminator
    if (is.list(data) && !is.null(data$type) && is.character(data$type)) {
      for (i in seq_along(variants)) {
        variant <- variants[[i]]
        
        # Resolve $ref if present
        if (!is.null(variant[[.const_schema_keywords$ref]])) {
          variant <- .resolve_refs(variant, root_schema)
        }
        
        # Check if this variant's type.const matches data$type
        type_schema <- variant[[.const_schema_keywords$properties]][[.const_schema_keywords$type]]
        if (!is.null(type_schema[[.const_schema_keywords$const]]) && 
            type_schema[[.const_schema_keywords$const]] == data$type) {
          schema <- variant
          break
        }
      }
    }
    
    # If still has combinators after matching, use first variant as fallback
    if (.has_combinator(schema)) {
      variant <- variants[[1]]
      if (!is.null(variant[[.const_schema_keywords$ref]])) {
        variant <- .resolve_refs(variant, root_schema)
      }
      schema <- variant
    }
  }
  
  schema_type <- schema[[.const_schema_keywords$type]]
  if (is.null(schema_type)) return(data)
  
  # If schema says array, wrap with AsIs to prevent unboxing
  if ("array" %in% schema_type) {
    if (!is.list(data)) {
      data <- as.list(data)
    }
    
    # Process array items recursively
    if (!is.null(schema[[.const_schema_keywords$items]])) {
      data <- lapply(seq_along(data), function(i) {
        .protect_arrays(data[[i]], schema[[.const_schema_keywords$items]], root_schema)
      })
    }
    
    # Wrap with AsIs to prevent auto_unbox
    return(I(data))
  }
  
  # If schema says object, process properties
  if ("object" %in% schema_type) {
    if (!is.list(data)) return(data)
    
    props <- schema[[.const_schema_keywords$properties]]
    if (!is.null(props)) {
      for (p in names(props)) {
        if (!is.null(data[[p]])) {
          data[[p]] <- .protect_arrays(data[[p]], props[[p]], root_schema)
        }
      }
    }
    
    return(data)
  }
  
  # For scalar types, return as-is (auto_unbox will handle them)
  data
}

################################################################################
# Internal Schema Resolution and Transformation
################################################################################

#' Escape JSON Pointer Token
#'
#' @description Escape a single token for JSON Pointer (RFC 6901).
#' Replaces: ~ -> ~0, / -> ~1
#'
#' @param token Character token
#'
#' @return Escaped token
#'
#' @keywords internal
#' @noRd
.json_pointer_escape <- function(token) {
  checkmate::assert_string(token)
  token <- gsub("~", "~0", token, fixed = TRUE)
  gsub("/", "~1", token, fixed = TRUE)
}

#' Resolve Schema $ref References
#'
#' @description Recursively resolve internal `$ref` pointers (#/path/to/def).
#' Supports `$defs` and other top-level containers. Uses caching to avoid cycles.
#'
#' @param schema Schema fragment (or complete schema)
#' @param root Root schema (for reference resolution)
#' @param cache Environment used for caching resolved refs
#'
#' @return Schema with $ref pointers resolved
#'
#' @keywords internal
#' @noRd
.resolve_refs <- function(schema, root = schema, cache = new.env(parent = emptyenv())) {
  if (!is.list(schema)) return(schema)
  
  # Handle $ref at this level
  ref_key <- .const_schema_keywords$ref
  if (!is.null(schema[[ref_key]])) {
    ref <- schema[[ref_key]]
    
    # Check cache first
    if (exists(ref, envir = cache, inherits = FALSE)) {
      return(get(ref, envir = cache, inherits = FALSE))
    }
    
    # Resolve internal reference
    if (startsWith(ref, .const_json_pointer_prefix)) {
      path_tokens <- strsplit(sub(paste0("^", .const_json_pointer_prefix), "", ref), "/")[[1]]
      node <- root
      
      for (p in path_tokens) {
        if (is.null(node[[p]])) {
          cli::cli_abort(
            c(
              "Schema reference not found",
              x = "Reference: {.field {ref}}"
            )
          )
        }
        node <- node[[p]]
      }
      
      resolved <- .resolve_refs(node, root, cache)
      assign(ref, resolved, envir = cache)
      return(resolved)
    } else {
      cli::cli_abort(
        c(
          "External schema references not supported",
          i = "Only internal references (starting with '#/') are allowed"
        )
      )
    }
  }
  
  # Recursively resolve children
  out <- schema
  for (k in names(schema)) {
    out[[k]] <- .resolve_refs(schema[[k]], root, cache)
  }
  out
}

#' Resolve and Merge allOf Schemas
#'
#' @description Apply `allOf` by deep-merging subschemas.
#' Recurses into child elements.
#'
#' @param schema Schema fragment
#'
#' @return Schema with allOf merged in-place
#'
#' @keywords internal
#' @noRd
.resolve_allOf <- function(schema) {
  if (!is.list(schema)) return(schema)
  
  allOf_key <- .const_schema_keywords$allOf
  if (!is.null(schema[[allOf_key]])) {
    merged <- list()
    for (sub in schema[[allOf_key]]) {
      merged <- .merge_recursive(merged, .resolve_allOf(sub))
    }
    schema[[allOf_key]] <- NULL
    schema <- .merge_recursive(schema, merged)
  }
  
  # Recurse into nested structures
  for (k in names(schema)) {
    if (is.list(schema[[k]])) {
      schema[[k]] <- .resolve_allOf(schema[[k]])
    }
  }
  schema
}


################################################################################
# Type Matching and Coercion
################################################################################

#' Check if Value Matches Schema Type
#'
#' @description Lightweight type matching for JSON Schema types.
#' Supports: string, number, integer, boolean, array, object, null
#'
#' @param value R value to check
#' @param type_decl Type(s) from schema (string or vector of strings)
#'
#' @return Logical TRUE/FALSE (best-effort matching)
#'
#' @keywords internal
#' @noRd
.match_type <- function(value, type_decl) {
  if (is.null(type_decl)) return(TRUE)
  
  types <- if (is.character(type_decl)) type_decl else as.character(type_decl)
  
  # Null handling
  if (is.null(value)) {
    return("null" %in% types)
  }
  
  # Scalar type checks
  if ("string" %in% types && is.character(value) && length(value) == 1) return(TRUE)
  if ("number" %in% types && is.numeric(value) && !is.integer(value) && length(value) == 1) return(TRUE)
  if ("integer" %in% types && is.numeric(value) && length(value) == 1 && value == as.integer(value)) return(TRUE)
  if ("boolean" %in% types && is.logical(value) && length(value) == 1) return(TRUE)
  
  # Collection type checks
  if ("array" %in% types && (is.list(value) || (is.atomic(value) && length(value) > 1))) return(TRUE)
  if ("object" %in% types && is.list(value) && !is.null(names(value))) return(TRUE)
  
  # Numeric flexibility
  if (is.numeric(value) && length(value) == 1 && ("number" %in% types || "integer" %in% types)) return(TRUE)
  
  FALSE
}

#' Coerce Scalar Value to Schema Type
#'
#' @description Strict coercion rules:
#' - integer: as.integer (error if NA)
#' - number: as.numeric (error if NA)
#' - boolean: accepts logical, "true"/"false", "1"/"0", 1/0
#' - string: as.character
#'
#' @param value R value to coerce
#' @param type_decl Type(s) from schema
#'
#' @return Coerced value
#'
#' @keywords internal
#' @noRd
.coerce_value <- function(value, type_decl) {
  if (is.null(type_decl)) return(value)
  
  types <- if (is.character(type_decl)) type_decl else as.character(type_decl)
  
  # Null handling
  if (is.null(value) && "null" %in% types) return(NULL)
  
  # Get non-null types
  prims <- setdiff(types, "null")
  if (length(prims) == 0) {
    if (is.null(value)) return(NULL)
    cli::cli_abort("Value must be null per schema definition")
  }
  
  primary <- prims[1]
  
  # Type-specific coercion
  if (primary == "string") {
    return(as.character(value))
  }
  
  if (primary == "number") {
    v <- suppressWarnings(as.numeric(value))
    if (is.na(v) && !is.nan(v)) {
      cli::cli_abort(c(
        "Cannot coerce to number",
        x = "Value: {.val {value}}"
      ))
    }
    return(v)
  }
  
  if (primary == "integer") {
    v <- suppressWarnings(as.integer(value))
    if (is.na(v)) {
      cli::cli_abort(c(
        "Cannot coerce to integer",
        x = "Value: {.val {value}}"
      ))
    }
    return(v)
  }
  
  if (primary == "boolean") {
    if (is.logical(value)) return(value)
    if (is.character(value)) {
      lv <- tolower(value)
      if (lv %in% c("true", "1")) return(TRUE)
      if (lv %in% c("false", "0")) return(FALSE)
      cli::cli_abort(c(
        "Cannot coerce string to boolean",
        x = "Value: {.val {value}}"
      ))
    }
    if (is.numeric(value)) {
      if (value == 1) return(TRUE)
      if (value == 0) return(FALSE)
      cli::cli_abort(c(
        "Cannot coerce numeric to boolean",
        x = "Value: {.val {value}}"
      ))
    }
  }
  
  value
}

#' Check Enum Constraint
#'
#' @description Validate value against enum constraint (after coercion).
#'
#' @param value Value to check
#' @param schema Schema fragment with enum field
#' @param path JSON Pointer for error messages
#'
#' @return Value if valid
#'
#' @keywords internal
#' @noRd
.check_enum <- function(value, schema, path = "") {
  if (is.null(schema$enum)) return(value)
  
  allowed <- schema$enum
  
  # Check for NULL
  if (is.null(value)) {
    for (e in allowed) {
      if (is.null(e)) return(value)
    }
    enum_str <- paste(sapply(allowed, function(x) if (is.null(x)) "null" else as.character(x)), collapse = ", ")
    cli::cli_abort(sprintf("Value null not in enum: [%s]", enum_str))
  }
  
  # Check non-null values
  if (is.atomic(value) && length(value) == 1) {
    for (e in allowed) {
      if (is.null(e)) next
      if (is.character(value) && is.character(e) && as.character(e) == value) return(value)
      if (is.numeric(value)) {
        vnum <- suppressWarnings(as.numeric(e))
        if (!is.na(vnum) && vnum == value) return(value)
      }
      if (is.logical(value)) {
        lval <- tolower(as.character(e))
        if ((value && lval %in% c("true", "1")) ||
            (!value && lval %in% c("false", "0"))) return(value)
      }
      if (identical(e, value)) return(value)
    }
  } else {
    for (e in allowed) {
      if (identical(e, value)) return(value)
    }
  }
  
  enum_str <- paste(sapply(allowed, function(x) if (is.null(x)) "null" else as.character(x)), collapse = ", ")
  cli::cli_abort(sprintf("Value '%s' not in enum: [%s]", paste(value, collapse = ","), enum_str))
}

#' Check String Pattern
#'
#' @description Validate string value against regex pattern.
#'
#' @param value Value to check
#' @param schema Schema fragment with pattern field
#'
#' @return Value if matches pattern
#'
#' @keywords internal
#' @noRd
.check_pattern <- function(value, schema) {
  pattern_key <- .const_schema_keywords$pattern
  if (is.null(schema[[pattern_key]])) return(value)
  if (is.null(value) || !is.character(value)) return(value)
  
  rx <- schema[[pattern_key]]
  if (!grepl(rx, value, perl = TRUE)) {
    cli::cli_abort(c(
      "Value does not match required pattern",
      x = "Value: {.val {value}}",
      i = "Pattern: /{rx}/"
    ))
  }
  value
}

#' Apply patternProperties
#'
#' @description Apply schema rules from patternProperties to matching keys.
#'
#' @param data Named list
#' @param schema Schema with patternProperties
#' @param enforce_additional_properties Logical flag
#'
#' @return Transformed data
#'
#' @keywords internal
#' @noRd
.apply_pattern_properties <- function(data, schema, enforce_additional_properties = FALSE) {
  pattern_props_key <- .const_schema_keywords$patternProperties
  if (is.null(schema[[pattern_props_key]]) || is.null(names(data))) return(data)
  
  for (key in names(data)) {
    for (rx in names(schema[[pattern_props_key]])) {
      if (grepl(rx, key, perl = TRUE)) {
        subschema <- schema[[pattern_props_key]][[rx]]
        data[[key]] <- .fix_types(data[[key]], subschema,
                                  enforce_additional_properties = enforce_additional_properties)
      }
    }
  }
  data
}

#' Resolve oneOf/anyOf Combinator
#'
#' @description Find matching subschema from oneOf or anyOf.
#' - oneOf: exactly one match required
#' - anyOf: first matching variant
#'
#' @param value Value to test
#' @param schema Schema with combinator
#'
#' @return Integer index (1-based) of matching variant
#'
#' @keywords internal
#' @noRd
.resolve_combinator_type <- function(value, schema) {
  one_of <- !is.null(schema[[.const_schema_keywords$oneOf]])
  any_of <- !is.null(schema[[.const_schema_keywords$anyOf]])
  
  if (!one_of && !any_of) {
    cli::cli_abort(c(
      "Invalid schema: missing combinators",
      i = "Expected oneOf or anyOf"
    ))
  }
  
  variants <- if (one_of) schema[[.const_schema_keywords$oneOf]] else schema[[.const_schema_keywords$anyOf]]
  matches <- logical(length(variants))
  
  for (i in seq_along(variants)) {
    subs <- variants[[i]]
    type_key <- .const_schema_keywords$type
    enum_key <- .const_schema_keywords$enum
    
    matches[i] <- if (!is.null(subs[[type_key]])) {
      tryCatch(.match_type(value, subs[[type_key]]), error = function(e) FALSE)
    } else {
      TRUE
    }
    
    # Check enum constraint
    if (matches[i] && !is.null(subs[[enum_key]])) {
      vco <- tryCatch({
        if (!is.null(subs[[type_key]]) && length(setdiff(subs[[type_key]], "null")) > 0 && !is.null(value)) {
          .coerce_value(value, subs[[type_key]])
        } else {
          value
        }
      }, error = function(e) value)
      if (!(vco %in% subs[[enum_key]])) matches[i] <- FALSE
    }
  }
  
  match_idx <- which(matches)
  
  if (one_of) {
    if (length(match_idx) == 1) return(match_idx)
    if (length(match_idx) == 0) {
      cli::cli_abort("Value does not match any schema in oneOf")
    }
    cli::cli_abort(c(
      "Ambiguous value",
      i = "Value matches multiple schemas in oneOf"
    ))
  }
  
  if (any_of) {
    if (length(match_idx) == 0) {
      cli::cli_abort("Value does not match any schema in anyOf")
    }
    return(match_idx[1])
  }
  
  NULL
}

################################################################################
# Core Type Fixing Engine
################################################################################

#' Transform Data to Match Schema
#'
#' @description Recursively normalize data to conform to schema.
#' Handles arrays, objects, scalars, patterns, enums, patternProperties,
#' and combinators.
#'
#' @param data R value
#' @param schema Schema fragment
#' @param path JSON Pointer to data (root is "")
#' @param enforce_additional_properties Logical flag
#'
#' @return Normalized R value ready for JSON serialization
#'
#' @keywords internal
#' @noRd
.fix_types <- function(data, schema, path = "", enforce_additional_properties = FALSE) {
  if (is.null(schema)) return(data)
  
  # Handle combinators
  if (!is.null(schema$oneOf) || !is.null(schema$anyOf)) {
    idx <- .resolve_combinator_type(data, schema)
    if (!is.null(idx)) {
      variants <- if (!is.null(schema$oneOf)) schema$oneOf else schema$anyOf
      schema <- variants[[idx]]
      schema <- .resolve_allOf(schema)
    }
  }
  
  # Check pattern early for strings
  if (!is.null(schema$pattern) && !is.null(data) && is.character(data)) {
    .check_pattern(data, schema)
  }
  
  # Handle null
  if (is.null(data)) {
    if (!is.null(schema$type) && "null" %in% schema$type) return(NULL)
    return(NULL)
  }
  
  # Handle arrays
  if (!is.null(schema$type) && "array" %in% schema$type) {
    # Convert to list if needed
    if (!is.list(data)) {
      data <- as.list(data)
    } else if (is.atomic(data)) {
      data <- as.list(data)
    }
    
    items <- schema$items
    if (is.null(items)) {
      return(data)
    }
    
    result <- lapply(seq_along(data), function(i) {
      el <- data[[i]]
      subpath <- if (identical(path, "") || is.null(path)) {
        paste0("/", i - 1)
      } else {
        paste0(path, "/", i - 1)
      }
      .fix_types(el, items, path = subpath,
                 enforce_additional_properties = enforce_additional_properties)
    })
    
    return(result)
  }
  
  # Handle objects
  if (!is.null(schema$type) && "object" %in% schema$type) {
    if (!is.list(data)) {
      cli::cli_abort("Expected object (named list) per schema")
    }
    
    # Transform known properties
    props <- schema$properties
    if (!is.null(props)) {
      for (p in names(props)) {
        if (!is.null(data[[p]])) {
          subpath <- if (identical(path, "") || is.null(path)) {
            paste0("/", .json_pointer_escape(p))
          } else {
            paste0(path, "/", .json_pointer_escape(p))
          }
          data[[p]] <- .fix_types(data[[p]], props[[p]], path = subpath,
                                  enforce_additional_properties = enforce_additional_properties)
        }
      }
    }
    
    # Apply patternProperties
    data <- .apply_pattern_properties(data, schema,
                                      enforce_additional_properties = enforce_additional_properties)
    
    # Enforce additionalProperties
    if (isTRUE(enforce_additional_properties)) {
      allowed_keys <- character()
      if (!is.null(props)) allowed_keys <- names(props)
      
      keys <- names(data)
      unmatched <- setdiff(keys, allowed_keys)
      
      # Check against patternProperties
      if (!is.null(schema$patternProperties) && length(unmatched) > 0) {
        pmatches <- c()
        for (k in unmatched) {
          for (rx in names(schema$patternProperties)) {
            if (grepl(rx, k, perl = TRUE)) {
              pmatches <- c(pmatches, k)
              break
            }
          }
        }
        unmatched <- setdiff(unmatched, pmatches)
      }
      
      if (length(unmatched) > 0) {
        ap <- schema$additionalProperties
        if (is.logical(ap) && isFALSE(ap)) {
          cli::cli_abort(sprintf("Extra properties not allowed: %s", paste(unmatched, collapse = ", ")))
        } else if (is.list(ap)) {
          for (k in unmatched) {
            subpath <- if (identical(path, "") || is.null(path)) {
              paste0("/", .json_pointer_escape(k))
            } else {
              paste0(path, "/", .json_pointer_escape(k))
            }
            data[[k]] <- .fix_types(data[[k]], ap, path = subpath,
                                    enforce_additional_properties = enforce_additional_properties)
          }
        }
      }
    }
    
    return(data)
  }
  
  # Handle scalars
  if (!is.null(schema$type) && !("array" %in% schema$type) && !("object" %in% schema$type)) {
    if (is.list(data) && length(data) == 1) data <- data[[1]]
    coerced <- .coerce_value(data, schema$type)
    if (!is.null(schema$pattern) && is.character(coerced)) {
      .check_pattern(coerced, schema)
    }
    coerced <- .check_enum(coerced, schema)
    return(coerced)
  }
  
  # No explicit type: recurse into properties if present
  if (is.list(data) && !is.null(schema$properties)) {
    for (p in names(schema$properties)) {
      if (!is.null(data[[p]])) {
        subpath <- if (identical(path, "") || is.null(path)) {
          paste0("/", .json_pointer_escape(p))
        } else {
          paste0(path, "/", .json_pointer_escape(p))
        }
        data[[p]] <- .fix_types(data[[p]], schema$properties[[p]], path = subpath,
                                enforce_additional_properties = enforce_additional_properties)
      }
    }
  }
  
  data
}
