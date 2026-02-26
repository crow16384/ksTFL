## Issues identified duirng manual testing with TEST_02 (script inst/examples/manual_unit_tests/TEST_02/test_02.r)

1. TEST 02_01: add_span_header with stubOrder = 2 and above breaks non-spanned header cells (the value is duplicated). [picture 1]

2. TEST 02_02: the table row_height parameter is not respected in rendering. e.g. s_table_style(row_height = "0.2cm") is ignored.
Expected: when row_height is specified as table cell/row style the height of the row should be set to exact value specified.

3. TEST 02_02: The whole table alignment on the page is not respected from global template.
Ensure that the following properties are implemented:
```
"tableStyle": {
    "layout": {
      "allow_row_break_across_pages": false,
      "repeat_header_on_each_page": true,
      "prevent_header_row_break": true,
      "table_alignment": "center"
    }
```    
Expected: "table_alignment": "center" - produce output with table aligned on the center of the page.

3. TEST_02_03: define_cols() should define values of only the columns listed in its parameters. 
Currently for some reasons the `valueStyleRef` style `indent_2` specified in the define_cols somehow also applied to the value of first virtual add_row. 
[picture 2 - bold values should not be indented by spec definition in the script]


