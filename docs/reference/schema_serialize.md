# Schema serialization and validation (internal)

Module: JSON Schema Serialization for ksTFL

## Details

This internal module validates R objects against the package JSON
schemas and prepares them for JSON export. Key responsibilities:

- Resolve internal `$ref` references and `$defs`

- Merge `allOf` subschemas and handle combinators (`oneOf`, `anyOf`)

- Enforce `type`, `enum`, and `pattern` constraints and coerce values

- Provide detailed JSON Pointer-based error reporting for diagnostics

These helpers are internal and intended for `serialize_spec()` and
related serialization pipelines.
