# Clean Obsolete and Orphaned JSON Files from a Meta Folder

Removes two categories of stale files from a meta folder:

1.  **Obsolete spec JSONs** - older versions of a document when multiple
    spec JSONs exist for the same `doc_file`. Only the most-recent spec
    per document is kept.

2.  **Orphaned data JSONs** - data JSON files that are no longer
    referenced by any surviving spec JSON.

## Usage

``` r
clean_reports(
  meta_dir = tfl_get_option("meta_directory"),
  keep_versions = 1L,
  dry_run = TRUE
)
```

## Arguments

- meta_dir:

  Character string. Path to the meta folder. Defaults to
  `tfl_get_option("meta_directory")`. An error is raised when neither
  the argument nor the option is set.

- keep_versions:

  Integer. Number of most-recent spec versions to keep per document.
  Default `1` (keep only the latest). Set to `2` to keep the latest and
  one previous version for rollback.

- dry_run:

  Logical. If `TRUE` (default), only report what would be deleted
  without removing anything.

## Value

Invisibly returns a list with elements `obsolete_specs`,
`orphaned_data`, and `deleted` (character vectors of filenames).

## Details

By default the function runs in **dry-run** mode and only reports what
would be deleted. Pass `dry_run = FALSE` to actually delete files.

## Examples

``` r
if (FALSE) { # \dontrun{
# Preview what would be removed
clean_reports("path/to/meta")

# Actually delete, keeping 1 version per document
clean_reports("path/to/meta", dry_run = FALSE)

# Keep 2 versions per document (latest + one rollback)
clean_reports("path/to/meta", keep_versions = 2, dry_run = FALSE)
} # }
```
