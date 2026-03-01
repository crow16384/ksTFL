# Issues identified duirng manual testing

## General issues

1. ✅ **FIXED (2026-02-26)** By design the document headers/footers are created as like a three columns table.
The current implementation of rendering is alsomst correct, but the renderer should respect the number of values passed and place them accordingly.

Rule is:

a) when all three text parts are passed, then placement is left-center-right
b) when only two values are passed (e.g. add_footer(c("Test Outputs", "Page {PAGE} of {NUMPAGES}"))), then placement is left-right
c) when only one value, then placement is left.

**Fix**: `json_parser.cpp` `parse_header_footer()` — changed parsing so 2-element arrays map to left+right (not left+center). 1 value → left only; 3 values → left+center+right.


## Test unit 01: TEST 01_01 in .\test_01.R

1. ✅ **FIXED (2026-02-26)** Structural definition of the tables in not respected from global template.
Current definition is:
```
 "structural": {
      "header_top_border": {
        "color": "000000",
        "width": "1.5pt",
        "line_style": "single"
      },
      "header_bottom_border": {
        "color": "000000",
        "width": "1.5pt",
        "line_style": "single"
      },
      "table_bottom_border": {
        "color": "000000",
        "width": "1.5pt",
        "line_style": "single"
      }}
```
but properties "header_top_border", "header_bottom_border" are ignored in the output, 
 or probably re-written by the settings from "tableStyle"/"header" section of template. 
Expected behaviour: the "structural" definition has priority over the other table setting of template. 
 The options in the tablestyle/header section are related to rows other than structural.

**Fix**: `docx_emitter.cpp` `emit_table_header()` — after resolving cell style, structural `header_top_border` is forced onto the top border of cells in the first header row, and `header_bottom_border` onto the bottom border of cells in the last header row. These override any borders from tableStyle/header.

2. ✅ **FIXED (2026-02-26)** The value_from beahaviour is not implemented from dynamic addrow functionality of style rows. Plus the addrow is expected to add a single-line row where all cells are merged across all columns.
in current TEST 01_01 the styling for some rows are defined as 
```
"{\"add_row\":[{\"pos\":\"above\",\"value_from\":\"param\",\"styleRef\":\"font_bold\"}]}"
```
but just empty rows are created without values, and styleRef is not applied as well.
Expected behaviour: for each style row definition in the test a single-line row with value from a `param` column is added and style is correctly applied.

**Fix**: `logical_table.cpp` `apply_style_rows()` — addrow synthetic rows are now built as full-width merged rows (first cell = merge leader spanning all visible columns, text from `value_from` column via DataTable lookup). This also works when `value_from` references an invisible column. The `styleRef` is applied both to `row_style_ref` and the leader cell's `style_ref`. Also fixed the "below" position bug where value was lost after `std::move`.

3. ✅ **FIXED (2026-02-26)** issue with titles concatenation (soft with hard breaks).
current code defines two levels of titles:
```
add_title(c("Demographics Table", "Safety Population")) %>% 
add_title(c("Third separate title"), styleRef = "font_italic")
```
Expected behaviour: Titles defined in a single definition [c("Demographics Table", "Safety Population")] are concatenated using soft-break, but different levels of titles are separate paragraphs!

**Fix**: `docx_emitter.cpp` `emit_page()` — replaced `emit_text_groups_combined()` (single paragraph) with per-group paragraph emission. Each `add_title()` call now produces a separate paragraph; within a group, text lines are still joined with `<br>` soft breaks. Per-group `styleRef` correctly scoped. `paginator.cpp` title height measurement updated to match.


## Test unit 01: TEST 01_02 in .\test_01.R

1. ✅ **FIXED (2026-02-26)** the cell merge behaviour in style rows does not respect the invisible rows.
current code defines the merge as:
```
define_cols(param, isVisible = F) %>% 
  compute_cols(
    firstOf(param),
    c_merge(c(param, value))
  )
```
here the `param` is set to hidden from report, but c_merge defines to use it in the merging. This is the possible case and should be handled.
Expected behaviour: while the `param` column does not appear in the report, the rest of the listed column (in this case only one `value`) can still be merged and the values should be taken from first of the specified in the list (`param` in this case).
in other words - similar MS Word-like behaviour, but with possibility to bring the value from the hidden column as well.

**Fix**: `logical_table.cpp` `apply_style_rows()` — merge handler now: (1) accepts merges where some columns are invisible (filtered); (2) when the first column in the merge list is invisible, fetches its value from the DataTable and places it into the first visible column's cell; (3) applies merge across visible columns only; (4) if only 1 visible column remains, still applies the value and styleRef without merge markup. DataTable access added to function signature to support invisible column lookups.




