# Issues identified duirng manual testing

## General issues:
1. By design the document headers/footers are created as like a three columns table. 
The current implementation of rendering is alsomst correct, but the renderer should respect the number of values passed and place them accordingly.
Rule is: 
a) when all three text parts are passed, then placement is left-center-right
b) when only two values are passed (e.g. add_footer(c("Test Outputs", "Page {PAGE} of {NUMPAGES}"))), then placement is left-right
c) when only one value, then placement is left.


## Test unit 01: TEST 01_01 in .\test_01.R

1. Structural definition of the tables in not respected from global template.
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

2. The value_from beahaviour is not implemented from dynamic addrow functionality of style rows. Plus the addrow is expected to add a single-line row where all cells are merged across all columns.
in current TEST 01_01 the styling for some rows are defined as 
```
"{\"add_row\":[{\"pos\":\"above\",\"value_from\":\"param\",\"styleRef\":\"font_bold\"}]}"
```
but just empty rows are created without values, and styleRef is not applied as well.
Expected behaviour: for each style row definition in the test a single-line row with value from a `param` column is added and style is correctly applied.

3. issue with titles concatenation (soft with hard breaks).
current code defines two levels of titles:
```
add_title(c("Demographics Table", "Safety Population")) %>% 
add_title(c("Third separate title"), styleRef = "font_italic")
```
Expected behaviour: Titles defined in a single definition [c("Demographics Table", "Safety Population")] are concatenated using soft-break, but different levels of titles are separate paragraphs!

4. The '\n' [standard new-line control] should be respected in the texts. Currently it is ignored.


## Test unit 01: TEST 01_02 in .\test_01.R

1. the cell merge behaviour in style rows does not respect the invisible rows.
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




