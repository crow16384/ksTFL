source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

# ---------------------------------------------------------------------------
# Reproducible example: allow_row_break_across_pages + repeat_header_on_each_page
# ---------------------------------------------------------------------------
# Produces three DOCX files matching the layout option combinations:
#   1. allow_row_break = TRUE,  repeat_header = FALSE
#   2. allow_row_break = TRUE,  repeat_header = TRUE
#   3. allow_row_break = FALSE, repeat_header = TRUE
# ---------------------------------------------------------------------------

lorem <- paste(
  "here are many variations of passages of Lorem Ipsum available,",
  "but the majority have suffered alteration in some form, by injected humour, or",
  "randomised words which don't look even slightly believable.",
  "If you are going to use a passage of Lorem Ipsum, you need to be sure there isn't",
  "anything embarrassing hidden in the middle of text.",
  "All the Lorem Ipsum generators on the Internet tend to repeat predefined chunks as",
  "necessary, making this the first true generator on the Internet.",
  "It uses a dictionary of over 200 Latin words, combined with a handful of model",
  "sentence structures, to generate Lorem Ipsum which looks reasonable.",
  "The generated Lorem Ipsum is therefore always free from repetition,",
  "injected humour, or non-characteristic words etc.",
  "Ex nostrud labore sunt ipsum ex ea laboris officia officia sint excepteur enim nisi",
  "culpa amet minim velit Lorem dolor dolor anim enim pariatur do amet ex eiusmod et deserunt",
  "dolore incididunt occaecat magna id ad sit cillum commodo do ipsum adipisicing anim ullamco exercitation"
)

tbl_data <- tibble::tibble(
  col1 = c(lorem, lorem, lorem),
  col2 = c(lorem, lorem, lorem),
  col3 = c(lorem, lorem, lorem)
)

# --- helper: create a modified template & render one table -------------------
make_variant <- function(allow    = FALSE,
                         repeat_h = TRUE,
                         name) {
  # Read the Default template and patch the layout flags
  tmpl_path <- system.file("templates", "Default.json", package = "ksTFL")
  tmpl <- jsonlite::fromJSON(tmpl_path, simplifyVector = FALSE)
  tmpl$tableStyle$layout$allow_row_break_across_pages <- allow
  tmpl$tableStyle$layout$repeat_header_on_each_page   <- repeat_h

  # Write patched template to a temp file
 tmp_tmpl <- tempfile(fileext = ".json")
  jsonlite::write_json(tmpl, tmp_tmpl, auto_unbox = TRUE, pretty = TRUE, null = "null")

  subtitle <- sprintf(
    "allow_row_break_across_pages = %s | repeat_header_on_each_page = %s",
    tolower(as.character(allow)), tolower(as.character(repeat_h))
  )

  spec <- create_table(tbl_data) |>
    add_title("Table Layout Options", toclevel = 1) |>
    add_subtitle(subtitle) |>
    define_cols(col1, label = "\u0417\u0430\u0433\u043e\u043b\u043e\u0432\u043e\u043a") |>
    define_cols(col2, label = "\u0417\u0430\u0433\u043e\u043b\u043e\u0432\u043e\u043a 1") |>
    define_cols(col3, label = "\u0417\u0430\u0433\u043e\u043b\u043e\u0432\u043e\u043a 2")

  create_report(spec) |>
    write_doc(name, overrideTemplate = tmp_tmpl, metaPath = meta_dir)
}

# 1. allow row break + no repeat header
make_variant(allow = TRUE,  repeat_h = FALSE, name = "16a_rowbreak_no_repeat")

# 2. allow row break + repeat header
make_variant(allow = TRUE,  repeat_h = TRUE,  name = "16b_rowbreak_with_repeat")

# 3. no row break + repeat header
make_variant(allow = FALSE, repeat_h = TRUE,  name = "16c_no_rowbreak_with_repeat")

cat("Done. Check output files in:", out_dir, "\n")
