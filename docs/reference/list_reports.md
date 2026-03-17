# List Saved Reports in a Meta Folder

Scans a meta folder produced by
[`save_report`](https://example.com/reference/save_report.md) and
returns a summary data frame with one row per spec JSON file. Uses
`_index.json` when available (fast); falls back to scanning every JSON
file otherwise.

## Usage

``` r
list_reports(
  meta_dir = tfl_get_option("meta_directory"),
  sort_by = c("datetime", "doc_file", "spec_file")
)
```

## Arguments

- meta_dir:

  Character string. Path to the meta folder. Defaults to
  `tfl_get_option("meta_directory")`. An error is raised when neither
  the argument nor the option is set.

- sort_by:

  Character string. Column to sort by: `"datetime"` (default, newest
  first), `"doc_file"`, or `"spec_file"`.

## Value

A data frame with columns:

- spec_file:

  Hash-named spec JSON filename.

- doc_file:

  Target DOCX filename stored at save time.

- datetime:

  ISO-8601 timestamp of when
  [`save_report()`](https://example.com/reference/save_report.md) was
  called.

- n_specs:

  Number of TFL specs inside the JSON.

- is_latest:

  Logical - `TRUE` for the most-recent entry per `doc_file`; older
  entries are `FALSE` (obsolete candidates).

- data_refs:

  Character vector of data JSON base-names referenced by this spec
  (without `.json` extension).

When no spec JSONs are found in `meta_dir`, returns
`invisible(empty_data_frame)` and prints an informational message.

## Examples

``` r
if (FALSE) { # \dontrun{
df <- list_reports("path/to/meta")
print(df[df$is_latest, c("doc_file", "datetime", "spec_file")])
} # }
```
