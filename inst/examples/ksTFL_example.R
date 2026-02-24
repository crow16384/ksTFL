## ksTFL example script
# This script demonstrates the core pipeline of ksTFL. Run in an R session
# with ksTFL installed. It is intentionally standalone so users can copy and run.

library(ksTFL)

# 1. Create a table spec from built-in data
spec_tbl <- create_table(mtcars)
## ksTFL example script
# This script demonstrates the core pipeline of ksTFL. Run in an R session
# with ksTFL installed. It is intentionally standalone so users can copy and run.

library(ksTFL)

# 1. Create a table spec from built-in data
spec_tbl <- create_table(mtcars)

# 2. Define styles
spec_tbl <- spec_tbl |> 
  add_style("title_header_style",
            s_font(font_name = "Arial", font_size = "12pt", bold = TRUE),
            s_paragraph(alignment = "center"),
            s_table_style(background_color = "#F2F2F2")
  ) |> 
  add_style("numeric_right", s_paragraph(alignment = "right"))

spec_tbl <- spec_tbl |> s_table_style(background_color = "#F2F2F2")

# Example: combine simple styles and apply using `f_combine()`
spec_tbl <- spec_tbl |> 
  add_style("bold_em", s_font(bold = TRUE)) |> 
  add_style("red_text", s_font(color = "#FF0000"))

# Apply combined style to a column label using f_combine()
spec_tbl <- spec_tbl |> define_cols(c(disp), label = "Displacement", labelStyleRef = f_combine("bold_em", "red_text"))

# 3. Lock a single column width and set formats for others
## 3a. Lock a single column width and set formats for others
# Note: use c(...) or unquoted column names per tidyselect rules
spec_tbl <- spec_tbl |> define_cols(c(cyl), label = "Cylinders", type = "numeric", colWidth = "20%")
spec_tbl <- spec_tbl |> define_cols(c(mpg, hp), label = c("MPG", "Horsepower"), type = c("numeric", "numeric"), format = c("%.1f", "%.0f"), valueStyleRef = "numeric_right")

# 4. Add titles and footnotes
spec_tbl <- spec_tbl |> add_title(c("Study ABC-123", "Demographics"), styleRef = "title_header_style") |> add_footnote("Data are shown as mean (SD).")

# 5. Create text spec and combine
spec_text <- create_text(docPrefix = "Narrative 1.1")
report <- create_report(spec_tbl, spec_text)

# 6. Save report metadata and data files
## Example: set package-level options (affects defaults used by tfl_init)
# This shows how to set the default output directory for `save_report()`; options persist
# only in the R session and are applied when specs are initialized.
tfl_set_options(output_directory = file.path(getwd(), "out"))

out <- save_report(report, docFileName = "example_report.docx", outDir = "./out", metaPath = tempdir(), prettify = TRUE)

# Inspect results
# The TFL_spec print method is implemented in the package and provides
# a readable preview. Call it directly on a spec object:
print(spec_tbl)

# `save_report()` returns a small metadata list invisibly; inspect known elements:
print(out$spec_file)
print(out$metaPath)

# Optionally list files written to the metaPath
cat("Files written:\n")
print(list.files(out$metaPath, full.names = TRUE))

# End of example

## Additional runnable snippets: stub columns and option overrides

# 7. Demonstrate stub (spanning) columns
spec_stub <- create_table(mtcars)
spec_stub <- spec_stub |> define_cols(c(mpg, hp, wt), label = c("MPG","HP","Weight"))

# Multi-level stubs example:
#  - top-level stub spans all three columns (stubOrder = 1)
#  - second-level stubs create two spans on the next row (stubOrder = 2)
spec_stub <- spec_stub |> add_span_header(cols = c("mpg", "hp", "wt"), label = "Vitals", stubOrder = 1)
spec_stub <- spec_stub |> add_span_header(cols = c("mpg", "hp"), label = "Engine metrics", stubOrder = 2)
spec_stub <- spec_stub |> add_span_header(cols = "wt", label = "Mass", stubOrder = 2)

# style for stub labels
spec_stub <- spec_stub |> add_style("stub_label", s_font(bold = TRUE))
# apply style by re-adding a stub with labelStyleRef (shows labelStyleRef usage)
spec_stub <- spec_stub |> add_span_header(cols = "wt", label = "Mass", stubOrder = 2, labelStyleRef = "stub_label")

cat("Multi-level stub columns defined:\n")
print(spec_stub$stubColumns)

# 8. Demonstrate session options (defaults) + per-spec override
tfl_set_options(
  add_header(c("Default Study", "", "CONFIDENTIAL")),
  add_footer(c("Company", "Page {PAGE} of {NUMPAGES}")),
  missings = "N/A"
)

# New spec will inherit defaults
spec_a <- create_table(mtcars)
cat("Default headers for new spec:\n")
print(spec_a$headers)

# Override header for this spec only
spec_a <- spec_a |> add_header(c("Special report", "", ""))
cat("Headers after per-spec override:\n")
print(spec_a$headers)

# Save a small report with stub spec to inspect files
spec_text <- create_text(docPrefix = "Narrative") |> add_body_text("Example body text")
report2 <- create_report(spec_stub, spec_text)
res2 <- save_report(report2, docFileName = "example_stub_report.docx", outDir = "./out", metaPath = tempdir(), prettify = TRUE)
cat("Saved stub report files:\n")
print(res2)

