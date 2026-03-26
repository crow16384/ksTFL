# Styling Guide (ksTFL)

![ksTFL logo](figures/ksTFL-logo.svg)

## Overview

This guide covers the complete styling system in ksTFL:

\- **Style primitives** (`s_*` helpers) for fonts, paragraphs, spacing,
indentation, tables, and borders

\- **Declaring named styles** with
[`add_style()`](https://example.com/reference/add_style.md)

\- **Referencing and combining styles** with style references and
[`f_combine()`](https://example.com/reference/f_combine.md)

\- **Applying styles** to columns, labels, stubs, and content

\- **Best practices** for maintainable, reusable style systems

For runnable reporting examples integrating styles see [Reporting
Examples](https://example.com/articles/Reporting_Examples_with_ksTFL.Rmd).
For a quick start see [Getting
Started](https://example.com/articles/Getting_Started_with_ksTFL.Rmd).

## Category and scope

This is a styling-system vignette.

- Audience: users defining reusable style systems for teams or studies
- Focus: style primitives, composition, references, and maintainable
  conventions
- Outcome: consistent style architecture across many reports

------------------------------------------------------------------------

## Styling philosophy and workflow

### Why declarative styles?

Professional clinical documents require:

\- **Consistency**: All headers look the same, all numeric columns align
right, all subtitles use the same font

\- **Maintainability**: Change one style definition, all references
update automatically

\- **Composability**: Build complex styles from simple building blocks
(font + paragraph alignment + table background)

\- **Separation of concerns**: Define styles once, apply them many times
without repeating details

ksTFL uses a **named style system**: you declare styles with
[`add_style()`](https://example.com/reference/add_style.md) giving each
an `id`, then reference them by name where needed. Styles are composable
([`f_combine()`](https://example.com/reference/f_combine.md)) and
consolidated automatically when you build reports.

### Best practices workflow

1.  **Define atomic styles first**: Create small, focused styles (bold
    headers, right-aligned text, light gray background)
2.  **Reference by name**: In
    [`define_cols()`](https://example.com/reference/define_cols.md),
    [`add_title()`](https://example.com/reference/add_title.md),
    [`add_span_header()`](https://example.com/reference/add_span_header.md)
    (with tidyselect support), use `labelStyleRef` or `valueStyleRef` to
    point to styles by id
3.  **Combine when needed**: Use
    [`f_combine()`](https://example.com/reference/f_combine.md) to merge
    multiple styles on-the-fly for ad-hoc combinations
4.  **Let
    [`create_report()`](https://example.com/reference/create_report.md)
    consolidate**: The report builder automatically merges combined
    styles so the renderer receives clean, consolidated styles
5.  **Never inspect internal fields**: Don’t manually look at
    `spec$attribs$styles` — let the package manage consolidation

------------------------------------------------------------------------

## Style primitives (s\_\* helpers)

All style primitives begin with `s_` and must be used **only inside
[`add_style()`](https://example.com/reference/add_style.md)**. The
helpers validate parameter names and values, raising informative errors
if used incorrectly.

### `s_font()` — Font properties

Control font appearance (name, size, weight, color, decorations).

**Parameters**:

\- `font_name`: Font family (e.g., “Arial”, “Courier New”, “Times New
Roman”, “Georgia”)

\- `font_size`: Size with units (e.g., “12pt”, “11pt”) - `bold`: Logical
(TRUE/FALSE)

\- `italic`: Logical (TRUE/FALSE)

\- `underline`: Logical (TRUE/FALSE)

\- `color`: Color as hex code (e.g., “#000000”, “#FF0000”) or color name
(e.g., “red”, “black”, “blue”)

\- `highlight`: Background highlight color as hex code or color name

**Example**:

``` r
spec <- create_table(mtcars)

# Bold, 12pt Arial, red text (using hex code)
spec <- add_style(spec, id = "header_bold_red",
  s_font(font_name = "Arial", font_size = "12pt", bold = TRUE, color = "#CC0000"))

# Underlined, 10pt monospace, blue text (using color name)
spec <- add_style(spec, id = "code_style",
  s_font(font_name = "Courier New", font_size = "10pt", underline = TRUE, color = "blue"))

# Yellow highlight with black text
spec <- add_style(spec, id = "highlighted",
  s_font(color = "black", highlight = "yellow"))
```

### `s_paragraph()` — Paragraph properties

Control text alignment, spacing before/after, line spacing, and
indentation.

**Parameters**:

\- `alignment`: Text alignment — “left”, “right”, “center”, “justify”,
“distributed”

\- `spacing`: Spacing before/after (use `s_spacing(...)`)

\- `indents`: Left/right indentation, first-line indent (use
`s_indents(...)`)

**Example**:

``` r
spec <- create_table(mtcars)

# Centered text with 6pt spacing before/after
spec <- add_style(spec, id = "centered_spaced",
  s_paragraph(alignment = "center", 
              spacing = s_spacing(before = "6pt", after = "6pt")))

# Right-aligned with left indent
spec <- add_style(spec, id = "right_indented",
  s_paragraph(alignment = "right",
              indents = s_indents(left = "10pt")))
```

### `s_spacing()` — Line and paragraph spacing

Controls spacing **before** a paragraph, **after** a paragraph, and
**between lines**.

**Parameters**:

\- `before`: Space before paragraph (e.g., “6pt”, “12pt”)

\- `after`: Space after paragraph (e.g., “6pt”, “12pt”)

\- `line_spacing`: Line spacing multiplier (e.g., 1.0, 1.5, 2.0 for
single/1.5-line/double spacing)

**Note**: [`s_spacing()`](https://example.com/reference/s_spacing.md) is
always used **inside
[`s_paragraph()`](https://example.com/reference/s_paragraph.md)**, never
standalone.

**Example**:

``` r
spec <- create_table(mtcars)

# Double-spaced with 12pt spacing after each paragraph
spec <- add_style(spec, id = "double_spaced",
  s_paragraph(spacing = s_spacing(after = "12pt", line_spacing = 2.0)))
```

### `s_indents()` — Indentation

Controls left/right margins and first-line indentation within a
paragraph.

**Parameters**:

\- `left`: Left indent (e.g., “10pt”, “1cm”)

\- `right`: Right indent (e.g., “10pt”)

\- `first_line`: First-line indent (e.g., “20pt” for hanging indent)

**Note**: [`s_indents()`](https://example.com/reference/s_indents.md) is
always used **inside
[`s_paragraph()`](https://example.com/reference/s_paragraph.md)**, never
standalone.

**Example**:

``` r
spec <- create_table(mtcars)

# Hanging indent (first line outdented, rest indented)
spec <- add_style(spec, id = "hanging_indent",
  s_paragraph(indents = s_indents(left = "20pt", first_line = "-20pt")))

# Left and right margins with left indent
spec <- add_style(spec, id = "block_indent",
  s_paragraph(indents = s_indents(left = "30pt", right = "30pt")))
```

### `s_table_style()` — Table cell properties

Control cell background, row height, vertical alignment, text
orientation, and borders.

**Parameters**:

\- `background_color`: Cell background color (hex, e.g., “#E8E8E8”)

\- `row_height`: Height of table row (e.g., “25pt”)

\- `topEmptyLine`: Optional empty spacer row after header (e.g., “6pt”,
use `NULL` or `0pt` to disable)

\- `bottomEmptyLine`: Optional empty spacer row before the bottom border
(e.g., “6pt”, use `NULL` or `0pt` to disable)

\- `vertical_alignment`: “top”, “center”, “bottom”

\- `text_orientation`: “horizontal”, “vertical_90”, “vertical_270”

\- `borders`: Border specification (use `s_borders(...)`)

**Example**:

``` r
spec <- create_table(mtcars)

# Light gray background, centered vertically, fixed row height
spec <- add_style(spec, id = "header_cell",
  s_table_style(background_color = "#F2F2F2",
                row_height = "30pt",
                vertical_alignment = "center"))

# Vertically rotated text (90 degrees)
spec <- add_style(spec, id = "rotated_header",
  s_table_style(text_orientation = "vertical_90"))

# Add table-level spacer rows via set_document()
spec <- set_document(
  spec,
  topEmptyLine = "6pt",
  bottomEmptyLine = "6pt"
)
```

### `s_borders()` — Border specifications

Define borders for all four sides of a cell. Each side takes
[`s_border()`](https://example.com/reference/s_border.md) with line
style, width, and color.

**Parameters** (each side):

\- `top`: Top border (use `s_border(...)`)

\- `bottom`: Bottom border (use `s_border(...)`)

\- `left`: Left border (use `s_border(...)`)

\- `right`: Right border (use `s_border(...)`)

**Note**: [`s_borders()`](https://example.com/reference/s_borders.md) is
always used **inside
[`s_table_style()`](https://example.com/reference/s_table_style.md)**,
never standalone.

### `s_border()` — Individual border line

Defines a single border line with style, width, and color.

**Parameters**:

\- `color`: Color as hex code (e.g., “#000000”) or color name (e.g.,
“black”, “red”)

\- `width`: Line width (e.g., “1pt”, “2pt”, “0.5pt”)

\- `line_style`: “single”, “double”, “dashed”, “dotted”, “thick”, “none”

**Example**:

``` r
spec <- create_table(mtcars)

# All borders: thin single lines in dark gray
spec <- add_style(spec, id = "all_borders",
  s_table_style(
    borders = s_borders(
      top = s_border(color = "grey40", width = "1pt", line_style = "single"),
      bottom = s_border(color = "grey40", width = "1pt", line_style = "single"),
      left = s_border(color = "grey40", width = "1pt", line_style = "single"),
      right = s_border(color = "grey40", width = "1pt", line_style = "single")
    )
  )
)

# Heavy bottom border in dark color (using hex code)
spec <- add_style(spec, id = "bottom_border_heavy",
  s_table_style(
    borders = s_borders(
      bottom = s_border(color = "#333333", width = "2pt", line_style = "thick")
    )
  )
)
```

------------------------------------------------------------------------

## Declaring named styles with `add_style()`

Named styles are the foundation of the ksTFL styling system. Each style
has a unique `id` and contains one or more style primitives.

### Basic syntax

``` r
spec <- add_style(spec, id = "style_name",
  s_font(...),
  s_paragraph(...),
  s_table_style(...)
)
```

**Parameters**:

\- `spec`: A `TFL_spec` object

\- `id`: Unique name for the style (e.g., “header_bold”,
“numeric_right”)

\- `...`: One or more style primitives
([`s_font()`](https://example.com/reference/s_font.md),
[`s_paragraph()`](https://example.com/reference/s_paragraph.md),
[`s_table_style()`](https://example.com/reference/s_table_style.md),
etc.)

### Example: Define a complete style

``` r
spec <- create_table(mtcars)

# Comprehensive header style: bold white text on gray background, centered
spec <- add_style(spec, id = "table_header",
  s_font(font_name = "Arial", font_size = "12pt", bold = TRUE, color = "#FFFFFF"),
  s_paragraph(alignment = "center", spacing = s_spacing(before = "6pt", after = "6pt")),
  s_table_style(background_color = "#333333", row_height = "30pt", vertical_alignment = "center")
)

# Simple numeric style: right-aligned
spec <- add_style(spec, id = "numeric_right",
  s_paragraph(alignment = "right")
)

# ID/key style: bold
spec <- add_style(spec, id = "id_bold",
  s_font(bold = TRUE)
)
```

### Multiple calls merge with last-win strategy

Calling [`add_style()`](https://example.com/reference/add_style.md)
multiple times with the same `id` merges the styles (last-win
semantics):

``` r
spec <- create_table(mtcars)

# First call: defines font
spec <- add_style(spec, id = "emphasis", s_font(bold = TRUE))

# Second call: adds paragraph alignment; bold is preserved
spec <- add_style(spec, id = "emphasis", s_paragraph(alignment = "center"))

# Result: "emphasis" has both bold font AND center alignment
```

------------------------------------------------------------------------

## Referencing and applying styles

Once you declare styles with
[`add_style()`](https://example.com/reference/add_style.md), reference
them by id in various places:

### 1. Column labels — `labelStyleRef` in `define_cols()`

Apply styles to **column header labels**:

``` r
spec <- create_table(mtcars)

spec <- add_style(spec, id = "header_bold", s_font(bold = TRUE, font_size = "12pt"))

# Apply to single column
spec <- define_cols(spec, mpg, label = "MPG (miles/gallon)", labelStyleRef = "header_bold")

# Apply to multiple columns with recycling
spec <- define_cols(spec, c(hp, cyl), label = c("HP", "Cylinders"), labelStyleRef = "header_bold")

# Different styles for different columns
spec <- define_cols(spec, c(mpg, hp),
  label = c("MPG", "HP"),
  labelStyleRef = c("header_bold", "header_italic"))
```

### 2. Column values — `valueStyleRef` in `define_cols()`

Apply styles to **data values** in a column:

``` r
spec <- create_table(mtcars)

spec <- add_style(spec, id = "numeric_right", s_paragraph(alignment = "right"))

# Right-align all numeric values in the mpg column
spec <- define_cols(spec, mpg, type = "numeric", valueStyleRef = "numeric_right")
```

### 3. Spanning headers — `labelStyleRef` in `add_span_header()`

Apply styles to **stub (spanning header) labels**:

``` r
spec <- create_table(mtcars)

spec <- add_style(spec, id = "stub_label",
  s_font(bold = TRUE, font_size = "11pt"),
  s_table_style(background_color = "#EFEFEF"))

spec <- add_span_header(spec, cols = c("mpg", "cyl"), label = "Engine",
  labelStyleRef = "stub_label")
```

### 4. Content — `styleRef` in `add_title()`, `add_footnote()`

Apply styles to titles, subtitles, footnotes:

``` r
spec <- create_table(mtcars)

spec <- add_style(spec, id = "title_style",
  s_font(bold = TRUE, font_size = "14pt"),
  s_paragraph(alignment = "center"))

spec <- add_title(spec, "Motor Trends Analysis", styleRef = "title_style")
```

------------------------------------------------------------------------

## Combining styles with `f_combine()`

[`f_combine()`](https://example.com/reference/f_combine.md) lets you
apply multiple styles to a single element without pre-defining a
combined style.

### Basic usage

``` r
spec <- create_table(mtcars)

spec <- add_style(spec, id = "bold", s_font(bold = TRUE))
spec <- add_style(spec, id = "red", s_font(color = "red"))  # Using color name
spec <- add_style(spec, id = "centered", s_paragraph(alignment = "center"))

# Apply bold + red + centered to a column header
spec <- define_cols(spec, mpg, label = "MPG",
  labelStyleRef = f_combine("bold", "red", "centered"))
```

### When to use `f_combine()` vs named styles

| Use Case                                     | Approach                                                                                |
|----------------------------------------------|-----------------------------------------------------------------------------------------|
| **Reusable style** (used in 3+ places)       | Define a named style with [`add_style()`](https://example.com/reference/add_style.md)   |
| **One-off combination** (used once or twice) | Use [`f_combine()`](https://example.com/reference/f_combine.md) inline                  |
| **Complex style** (many properties)          | Define named style, then optionally combine with others                                 |
| **Per-column variations**                    | Use [`f_combine()`](https://example.com/reference/f_combine.md) with per-column vectors |

### Combining with per-column mapping

Apply different combinations to different columns:

``` r
spec <- create_table(mtcars)

# Define base styles
spec <- add_style(spec, id = "bold", s_font(bold = TRUE))
spec <- add_style(spec, id = "italic", s_font(italic = TRUE))
spec <- add_style(spec, id = "centered", s_paragraph(alignment = "center"))
spec <- add_style(spec, id = "right", s_paragraph(alignment = "right"))

# Apply different combinations per column
spec <- define_cols(spec, c(mpg, cyl, hp),
  label = c("MPG", "Cylinders", "HP"),
  labelStyleRef = c(
    f_combine("bold", "centered"),      # mpg: bold + centered
    f_combine("italic", "right"),       # cyl: italic + right
    f_combine("bold", "italic", "centered")  # hp: bold + italic + centered
  )
)
```

------------------------------------------------------------------------

## Allowed values (enumerations)

### Color names

Color parameters accept both **hex codes** (e.g., `"#FF0000"`) and
**named colors**:

**Basic colors**: black, white, red, green, blue, yellow, orange,
purple, pink, brown, cyan, magenta, navy, teal, lime, maroon, olive,
silver, gold, coral, salmon, turquoise, violet, indigo, khaki, lavender,
plum, tan

**Grayscale**: grey10, grey20, grey30, grey40, grey60, grey70, grey80,
grey90 (or gray with ‘a’)

### Font names (common)

- Arial
- Courier New
- Times New Roman
- Georgia
- Verdana
- Trebuchet MS

### Alignment

- “left”
- “right”
- “center”
- “justify”
- “distributed”

### Border line styles

- “single” (solid line)
- “double” (two lines)
- “dashed” (dashed line)
- “dotted” (dotted line)
- “thick” (thicker solid line)
- “none” (no border)

### Vertical alignment

- “top”
- “center”
- “bottom”

### Text orientation

- “horizontal” (default)
- “vertical_90” (rotated 90° counter-clockwise)
- “vertical_270” (rotated 270° counter-clockwise)

------------------------------------------------------------------------

## Common styling patterns

### Pattern 1: Clinical table headers

``` r
spec <- create_table(my_data)

spec <- add_style(spec, id = "clinical_header",
  s_font(font_name = "Arial", font_size = "11pt", bold = TRUE, color = "#FFFFFF"),
  s_paragraph(alignment = "center"),
  s_table_style(background_color = "#003366", row_height = "28pt", vertical_alignment = "center")
)

spec <- define_cols(spec, c("col1", "col2", "col3"), labelStyleRef = "clinical_header")
```

### Pattern 2: Right-aligned numeric columns

``` r
spec <- add_style(spec, id = "numeric_format",
  s_font(font_name = "Courier New", font_size = "10pt"),
  s_paragraph(alignment = "right")
)

spec <- define_cols(spec, c(age, weight, dose), type = "numeric", valueStyleRef = "numeric_format")
```

### Pattern 3: ID/key columns (bold, wide)

``` r
spec <- add_style(spec, id = "id_column",
  s_font(bold = TRUE, font_size = "11pt"),
  s_paragraph(alignment = "left")
)

spec <- define_cols(spec, subject_id, 
  label = "Subject ID",
  labelStyleRef = "id_column",
  colWidth = "15%",
  isID = TRUE)
```

### Pattern 4: Multi-level headers with styled stubs

``` r
spec <- add_style(spec, id = "level1_stub",
  s_font(bold = TRUE, font_size = "12pt", color = "#FFFFFF"),
  s_table_style(background_color = "#666666", vertical_alignment = "center"))

spec <- add_style(spec, id = "level2_stub",
  s_font(bold = TRUE, font_size = "11pt"),
  s_table_style(background_color = "#CCCCCC", vertical_alignment = "center"))

spec <- add_span_header(spec, cols = c("var1", "var2", "var3"), label = "Baseline",
  stubOrder = 1, labelStyleRef = "level1_stub")

spec <- add_span_header(spec, cols = c("var1", "var2"), label = "Safety",
  stubOrder = 2, labelStyleRef = "level2_stub")
```

------------------------------------------------------------------------

## Troubleshooting

### Error: “Context error” or “can only be used inside add_style()”

**Problem**: You used an `s_*` helper outside
[`add_style()`](https://example.com/reference/add_style.md).

``` r
# WRONG
my_style <- s_font(bold = TRUE)  # ERROR

# CORRECT
spec <- add_style(spec, id = "my_style", s_font(bold = TRUE))
```

### Error: “Invalid parameter” or “Allowed values are…”

**Problem**: You used an invalid parameter value (e.g., “bolded” instead
of TRUE).

``` r
# WRONG
s_font(bold = "bolded")  # ERROR: must be TRUE/FALSE

# CORRECT
s_font(bold = TRUE)
```

### Styles not applied after `create_report()`

**Problem**: If you used
[`f_combine()`](https://example.com/reference/f_combine.md), you must
call [`create_report()`](https://example.com/reference/create_report.md)
before the styles are consolidated.

``` r
spec <- create_table(mtcars)
spec <- define_cols(spec, mpg, labelStyleRef = f_combine("bold", "red"))

# CORRECT: create_report() consolidates combined styles before rendering
report <- create_report(spec)  # Merges "bold" + "red" into a single resolved style
write_doc(report, name = "out", outDir = "./output", metaPath = tempdir())
```

### Styles looking different in renderer than expected

**Problem**: Renderer may override or ignore certain style properties
based on its own template system.

**Solution**: Test with simple styles first, then incrementally add
properties. Contact your renderer maintainer for constraints.

------------------------------------------------------------------------

## Advanced notes

### Style consolidation in `create_report()`

When you call
[`create_report()`](https://example.com/reference/create_report.md), the
package:

1\. Collects all specs

2\. For each spec, finds all style references used with
[`f_combine()`](https://example.com/reference/f_combine.md)

3\. Merges those combined styles into single consolidated styles

4\. Generates unique hash-based names for consolidated styles

5\. Updates all references to point to the consolidated style

You don’t need to inspect or manipulate `spec$attribs$styles` — the
consolidation is automatic and transparent.

### Style reference resolution

Style references are resolved in this order:

1\. **Named styles** defined in the same spec with
[`add_style()`](https://example.com/reference/add_style.md)

2\. **Built-in style atoms** shipped with the package (e.g., `"b"`,
`"tw_80"`, `"grp_hdr"`)

3\. **Error**: If reference not found,
[`create_report()`](https://example.com/reference/create_report.md) will
error with an informative message

------------------------------------------------------------------------

## Built-in style atoms

ksTFL ships a library of single-property style atoms accessible via
[`f_combine()`](https://example.com/reference/f_combine.md) or directly
as `styleRef` values. Each atom sets exactly one visual property;
compose them freely with
[`f_combine()`](https://example.com/reference/f_combine.md).

**Discovering atoms programmatically**: Use
[`tfl_print_style_atoms()`](https://example.com/reference/tfl_print_style_atoms.md)
(or its alias
[`tfl_style_atoms_catalog()`](https://example.com/reference/tfl_print_style_atoms.md))
to print all available atoms grouped by category with colour-coded
output in the console:

``` r
# Print all built-in atoms categorised and colour-coded
tfl_print_style_atoms()
```

### Complete atom reference

| Atom                                                               | Effect                                                                    |
|--------------------------------------------------------------------|---------------------------------------------------------------------------|
| **Font — decoration**                                              |                                                                           |
| `b` / `font_bold`                                                  | Bold                                                                      |
| `i` / `font_italic`                                                | Italic                                                                    |
| `u` / `font_underline`                                             | Underline                                                                 |
| **Font — family**                                                  |                                                                           |
| `font_arial`                                                       | Set `font_name = "Arial"`                                                 |
| `font_courier_new`                                                 | Set `font_name = "Courier New"`                                           |
| `font_times_new_roman`                                             | Set `font_name = "Times New Roman"`                                       |
| `font_georgia`                                                     | Set `font_name = "Georgia"`                                               |
| `font_verdana`                                                     | Set `font_name = "Verdana"`                                               |
| `font_trebuchet_ms`                                                | Set `font_name = "Trebuchet MS"`                                          |
| **Font — size**                                                    |                                                                           |
| `fs_7` … `fs_11`                                                   | Font size 7 pt … 11 pt                                                    |
| **Font — colour**                                                  |                                                                           |
| `fc_black`, `fc_red`, `fc_blue`, `fc_green`                        | Pure text colours                                                         |
| `fc_gray` / `fc_grey`                                              | Secondary / reference text (#595959)                                      |
| `fc_navy`, `fc_teal`, `fc_olive`, `fc_rust`, `fc_plum`, `fc_slate` | Muted clinical palette                                                    |
| **Text highlight (cell shading)**                                  |                                                                           |
| `hl_yellow`, `hl_red`, `hl_green`, `hl_gray` / `hl_grey`           | Strong highlight colours                                                  |
| `hl_peach`, `hl_mint`, `hl_sky`, `hl_lemon`, `hl_lilac`            | Pastel highlight palette                                                  |
| **Paragraph — alignment**                                          |                                                                           |
| `al` / `text_left`                                                 | Left-align                                                                |
| `ar` / `text_right`                                                | Right-align                                                               |
| `ac` / `text_center`                                               | Center-align                                                              |
| **Paragraph — left indentation**                                   |                                                                           |
| `ind0` / `indent_0`                                                | No indent (reset to left margin)                                          |
| `ind1` / `indent_1`                                                | 0.5 cm left indent (top-level category)                                   |
| `ind2` / `indent_2`                                                | 1.0 cm left indent (first sub-group)                                      |
| `ind3` / `indent_3`                                                | 1.5 cm left indent (second sub-group)                                     |
| `ind4` / `indent_4`                                                | 2.0 cm left indent (detail)                                               |
| **Paragraph — right indentation**                                  |                                                                           |
| `rind0` / `rindent_0`                                              | No right indent (reset to right margin)                                   |
| `rind1` / `rindent_1`                                              | 0.5 cm right indent                                                       |
| `rind2` / `rindent_2`                                              | 1.0 cm right indent                                                       |
| `rind3` / `rindent_3`                                              | 1.5 cm right indent                                                       |
| `rind4` / `rindent_4`                                              | 2.0 cm right indent                                                       |
| **Paragraph — table-width shrink**                                 |                                                                           |
| `tw_95` … `tw_50`                                                  | Symmetric left+right indent to match table at 95 %…50 % width (5 % steps) |
| **Paragraph — spacing**                                            |                                                                           |
| `sp_0`                                                             | No space before/after paragraph                                           |
| `sp_2`                                                             | 2 pt space before and after                                               |
| `sp_4`                                                             | 4 pt space before and after                                               |
| **Paragraph — pagination**                                         |                                                                           |
| `kl`                                                               | Keep all lines of a cell on the same page                                 |
| `kn`                                                               | Keep this row on the same page as the next row                            |
| **Group / category header composites**                             |                                                                           |
| `grp_hdr`                                                          | Bold + 4 pt space above + left indent reset (category header)             |
| `grp_hdr_i`                                                        | Bold + italic + 4 pt space above + left indent reset                      |
| **Cell — vertical alignment**                                      |                                                                           |
| `va_t` / `va_top`                                                  | Top                                                                       |
| `va_m` / `va_center`                                               | Middle                                                                    |
| `va_b` / `va_bottom`                                               | Bottom                                                                    |
| **Cell — text orientation**                                        |                                                                           |
| `to_h` / `text_horizontal`                                         | Horizontal (default)                                                      |
| `to_90` / `text_vertical_90`                                       | Rotated 90° (bottom-to-top)                                               |
| `to_270` / `text_vertical_270`                                     | Rotated 270° (top-to-bottom)                                              |
| **Cell — background colour**                                       |                                                                           |
| `bg_blue`, `bg_gray` / `bg_grey`                                   | Standard backgrounds                                                      |
| `bg_peach`, `bg_mint`, `bg_sky`, `bg_lemon`, `bg_lilac`            | Pastel backgrounds                                                        |
| `bg_navy`, `bg_slate`, `bg_steel`                                  | Dark/medium header backgrounds                                            |
| **Row height**                                                     |                                                                           |
| `row_h2`, `row_h4`, `row_h6`                                       | Row height 2 / 4 / 6 pt (separator rows)                                  |
| **Border — sides (1 pt black)**                                    |                                                                           |
| `bt`, `bb`, `bl`, `br`                                             | Top / bottom / left / right border                                        |
| **Border — thin sides (0.5 pt black)**                             |                                                                           |
| `bt_th`, `bb_th`                                                   | Thin top / bottom border                                                  |
| **Border — colour override**                                       |                                                                           |
| `bc_gray` / `bc_grey`                                              | All sides → medium gray (#AAAAAA)                                         |
| `bc_white`                                                         | All sides → white / none (suppress borders)                               |

**Usage:**

``` r
# Single atom as styleRef
spec <- add_footnote(spec, "Source: database.", styleRef = "tw_80")

# Combine atoms with f_combine()
spec <- define_cols(spec, value,
  valueStyleRef = f_combine("font_verdana", "ar", "fs_9"))

# Combine atoms with named styles
spec <- add_style(spec, id = "group_hdr",
  s_font(bold = TRUE),
  s_paragraph(spacing = s_spacing(before = "4pt")))
spec <- compute_cols(spec, firstOf(group),
  c_style(everything(), styleRef = f_combine("group_hdr", "bg_gray")))
```

### Table-width shrink atoms (`tw_*`)

When a table is narrower than the full content width, titles, subtitles,
footnotes, and body text will span the full page width by default —
wider than the table itself. The `tw_*` atoms apply symmetric left and
right paragraph indentation so that text blocks visually align with the
table edges.

Indent values are calculated for **A4 landscape with 0.5 in left/right
page margins** (content width ≈ 27.16 cm). Each 5 % step corresponds to
0.68 cm per side.

| Atom    | Table width | Indent each side |
|---------|-------------|------------------|
| `tw_95` | 95 %        | 0.68 cm          |
| `tw_90` | 90 %        | 1.36 cm          |
| `tw_85` | 85 %        | 2.04 cm          |
| `tw_80` | 80 %        | 2.72 cm          |
| `tw_75` | 75 %        | 3.40 cm          |
| `tw_70` | 70 %        | 4.07 cm          |
| `tw_65` | 65 %        | 4.75 cm          |
| `tw_60` | 60 %        | 5.43 cm          |
| `tw_55` | 55 %        | 6.11 cm          |
| `tw_50` | 50 %        | 6.79 cm          |

**Usage — match footnotes and titles to a narrower table:**

``` r
spec <- create_table(data) |>
  set_document(contentWidth = "80%") |>
  add_title("Demographics Table",   styleRef = "tw_80") |>
  add_subtitle("Safety Population", styleRef = "tw_80") |>
  add_footnote("Source: study database.", styleRef = "tw_80")
```

**Combine with other atoms** using
[`f_combine()`](https://example.com/reference/f_combine.md):

``` r
# Bold title, indented to match a 75 % table
spec <- add_title(spec, "Efficacy Summary",
                  styleRef = f_combine("b", "tw_75"))

# Small italic footnote, indented to match a 70 % table
spec <- add_footnote(spec, "Values are least-squares means.",
                     styleRef = f_combine("i", "fs_8", "tw_70"))
```

**Apply via a named style** for reuse across multiple specs:

``` r
# Define the style on each spec (or use a helper function to apply it)
add_footnote_80 <- function(spec, text) {
  spec <- add_style(spec, id = "fn_80",
    s_font(font_size = "8pt", italic = TRUE),
    s_paragraph(alignment = "left",
                indents = s_indents(left = "2.72cm", right = "2.72cm")))
  add_footnote(spec, text, styleRef = "fn_80")
}

spec1 <- add_footnote_80(spec1, "a. p < 0.05")
spec2 <- add_footnote_80(spec2, "b. LOCF imputation")
```

> **Note**: The indent values assume the default A4 landscape page with
> 0.5 in margins. If you use a different page size, orientation, or
> margins via
> [`set_page_style()`](https://example.com/reference/set_page_style.md),
> calculate your own indents with `s_indents(left = ..., right = ...)`
> inside [`add_style()`](https://example.com/reference/add_style.md).

------------------------------------------------------------------------

## See also

- Function documentation:
  [`?add_style`](https://example.com/reference/add_style.md),
  [`?s_font`](https://example.com/reference/s_font.md),
  [`?s_paragraph`](https://example.com/reference/s_paragraph.md),
  [`?f_combine`](https://example.com/reference/f_combine.md)
- [Reporting
  Examples](https://example.com/articles/Reporting_Examples_with_ksTFL.Rmd)
  — working examples with styles
- [Getting
  Started](https://example.com/articles/Getting_Started_with_ksTFL.Rmd)
  — quick overview
