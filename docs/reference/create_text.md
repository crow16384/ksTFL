# Create a Text Document Specification

Create and initialize a TFL specification for narrative (text)
documents. This is a user-facing wrapper around the internal
`.tfl_init()` initializer and provides a clear, intention-revealing name
for creating text-only specifications. Text documents do not accept
`data` and will have `docType = "Text"` set on the resulting spec.

## Usage

``` r
create_text()
```

## Value

A `TFL_spec` object with `docType = "Text"`.

## Examples

``` r
if (FALSE) { # \dontrun{
## Create a simple text spec
spec <- create_text()
} # }
```
