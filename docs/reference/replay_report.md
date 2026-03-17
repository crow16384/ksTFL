# Re-render a DOCX from Stored JSON

Re-renders a DOCX document entirely from JSON files stored in the meta
folder - no R spec objects or data frames required. Useful for
reproducing outputs after code changes or on a different machine.

## Usage

``` r
replay_report(
  spec_json,
  meta_dir = tfl_get_option("meta_directory"),
  output_path = NULL,
  template_json = NULL,
  overrideTemplate = NULL,
  insertTOC = NULL,
  tocTitle = NULL,
  verbose = FALSE
)
```

## Arguments

- spec_json:

  Character string or character vector. Either:

  - A full path to a spec JSON file, or

  - A `doc_file` name (e.g. `"test_01.docx"`) - the most recent spec for
    that document is used.

  Multiple entries are allowed for merging several documents into one.

- meta_dir:

  Character string or character vector. Path(s) to the meta folder(s).
  Defaults to `tfl_get_option("meta_directory")`. An error is raised
  when neither the argument nor the option is set.

  - A single string is recycled for every element of `spec_json`.

  - A vector of the same length as `spec_json` provides a per-document
    meta folder.

  Required when any `spec_json` entry is a `doc_file` name rather than a
  full path.

- output_path:

  Character string. Override the output DOCX path. If `NULL` (default),
  the path stored in the spec's `_metadata` (`outDir/docFileName`) is
  used. **Required** when `length(spec_json) > 1`.

- template_json:

  Character string. Override the template JSON path. If `NULL`, resolved
  automatically from the spec.

- overrideTemplate:

  Character string. A bundled template name (e.g. `"Navy_Pro"`) or file
  path to a custom styles JSON. When non-`NULL`, this takes precedence
  over `template_json`. See
  [`tfl_list_templates()`](https://example.com/reference/tfl_list_templates.md)
  for available names.

- insertTOC:

  Logical. Insert a Table of Contents. `NULL` (default) inherits the
  value from the first document's metadata.

- tocTitle:

  Character string. TOC heading text. `NULL` (default) inherits from the
  first document.

- verbose:

  Logical. Print C++ pipeline diagnostics. Default `FALSE`.

## Value

Invisibly returns the path to the rendered DOCX file.

## Details

When a single `spec_json` is provided the function behaves exactly as
before. When a character vector of length \> 1 is given, the specs from
every document are merged into one combined JSON and rendered into a
single DOCX file. `output_path` is required in this case.

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

# Merge two documents from the same meta folder
replay_report(
  c("tables_01.docx", "listings_01.docx"),
  meta_dir    = "path/to/meta",
  output_path = "output/combined.docx"
)

# Merge documents from different meta folders
replay_report(
  c("path/to/meta_a/abc123.json", "path/to/meta_b/def456.json"),
  output_path = "output/combined.docx"
)
} # }
```
