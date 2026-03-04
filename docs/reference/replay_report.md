# Re-render a DOCX from Stored JSON

Re-renders a DOCX document entirely from JSON files stored in the meta
folder - no R spec objects or data frames required. Useful for
reproducing outputs after code changes or on a different machine.

## Usage

``` r
replay_report(
  spec_json,
  meta_dir = NULL,
  output_path = NULL,
  template_json = NULL,
  verbose = FALSE
)
```

## Arguments

- spec_json:

  Character string. Either:

  - A full path to a spec JSON file, or

  - A `doc_file` name (e.g. `"test_01.docx"`) - the most recent spec for
    that document is used.

- meta_dir:

  Character string. Path to the meta folder. Required when `spec_json`
  is a `doc_file` name rather than a full path.

- output_path:

  Character string. Override the output DOCX path. If `NULL` (default),
  the path stored in the spec's `_metadata` (`outDir/docFileName`) is
  used.

- template_json:

  Character string. Override the template JSON path. If `NULL`, resolved
  automatically from the spec.

- verbose:

  Logical. Print C++ pipeline diagnostics. Default `FALSE`.

## Value

Invisibly returns the path to the rendered DOCX file.

## Examples

``` r
if (FALSE) { # \dontrun{
# By doc name (uses latest spec)
replay_report("test_01.docx", meta_dir = "path/to/meta")

# By spec hash (exact version)
replay_report("abc123def456.json", meta_dir = "path/to/meta")

# Override output location
replay_report("test_01.docx", meta_dir = "path/to/meta",
              output_path = "~/Desktop/test_01_replay.docx")
} # }
```
