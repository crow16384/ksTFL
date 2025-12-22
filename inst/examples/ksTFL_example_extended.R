# ksTFL extended examples: stubs and options
# Run in an R session where ksTFL is installed

library(ksTFL)

# Demonstrate stub (spanning) columns
spec_stub <- create_table(mtcars)
spec_stub <- spec_stub |> define_cols(c(mpg, hp, wt), label = c("MPG","HP","Weight"))

# Add a stub spanning mpg+hp and another for wt
spec_stub <- spec_stub |> add_stub_column(cols = c("mpg", "hp"), label = "Engine metrics")
spec_stub <- spec_stub |> add_stub_column(cols = "wt", label = "Mass")

cat("Stub columns defined:\n")
print(spec_stub$stubColumns)

# Demonstrate session options (defaults) + per-spec override
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
