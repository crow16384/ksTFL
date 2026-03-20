# Add body text

Add body text (e.g., when no data to display)

## Usage

``` r
add_body_text(
  spec = NULL,
  text = NULL,
  id = NULL,
  styleRef = NULL,
  order = NULL
)
```

## Arguments

- spec:

  Spec object (dispatches on class)

- text:

  Character vector of body text lines

- id:

  Body text identifier (auto-generated if NULL)

- styleRef:

  Character vector of style names or result of
  [`f_combine()`](https://example.com/reference/f_combine.md). Merged
  with last-win strategy.

- order:

  Order of body text group (auto-assigned if NULL)

## Value

Updated spec object

## Details

Generic function to add body text. Dispatches to class-specific methods,
allowing different spec classes to implement their own body text
handling.

Multiple calls add multiple text groups. Calling with the same ID merges
with last-win strategy.

## Examples

``` r
if (FALSE) { # \dontrun{
# Text-only spec with body text
spec <- create_text() |>
  set_document(hasData = FALSE) |>
  add_body_text("No data available for the specified criteria.")

# Table spec with body text as fallback when no data rows
spec <- create_table(empty_df) |>
  set_document(hasData = FALSE) |>
  add_body_text("No adverse events were reported.",
                styleRef = f_combine("b", "fc_red"))
} # }
```
