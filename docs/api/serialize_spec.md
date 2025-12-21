# serialize_spec(...)

Purpose: Validate a `TFL_report` object against the spec schema and prepare it for JSON serialization.

Parameters:
- `spec` `TFL_report` object (output from `create_report()`)
- `enforce_additional_properties` Logical (optional). If TRUE, enforce `additionalProperties` schema rules. Defaults to FALSE

Return Value:
List with two elements:
- `spec`: The original input `TFL_report` object
- `fixed`: The processed data structure with all schema validation applied, ready for JSON serialization

Key package callees and transitive chains:
- Loads JSON schema from package resources: `inst/schemas/spec_schema_v1.json`
- -> `.serialize_json_internal(spec, schema)` core validation engine:
  - Resolves all `$ref` pointers (via `.resolve_refs()`)
  - Merges `allOf` subschemas (via `.resolve_allOf()`)
  - Transforms data to match schema (via `.fix_types()`)
    - Converts all empty lists to NULL (prevents ambiguous JSON serialization)
    - Validates types, enums, patterns
    - Coerces values to correct types
    - Handles combinators (oneOf, anyOf, allOf)
  - Protects arrays from auto_unbox (via `.protect_arrays()`)
  - Unclasses all recursive objects (via `.unclass_recursive()`)

Direct package callees:
- `.serialize_json_internal`, `.resolve_refs`, `.resolve_allOf`, `.fix_types`, `.protect_arrays`, `.unclass_recursive`, `.load_schema`, `.allow_null`, `cli_abort`, `checkmate::assert_*`

Usage notes:
- Output `$fixed` object is what gets passed to `jsonlite::toJSON()` for JSON serialization
- Empty lists are unconditionally converted to NULL (no ambiguity in JSON)
- Schema cache prevents repeated file I/O for same schema
- Use `clear_schema_cache()` to reset schema cache if schema files change

