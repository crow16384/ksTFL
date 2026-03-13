source(file.path(getwd(), "inst", "examples", "showcase", "init_showcase.R"))

# Demonstrates both multi-spec template behaviors:
# 1) Per-spec templates resolved from each spec's docTemplate
# 2) Global override using one template_json for all specs

labs_small <- tibble::tibble(
  subject_id = sprintf("S%03d", 1:8),
  ALT = c(24, 31, 28, 37, 22, 30, 34, 26),
  AST = c(21, 29, 25, 35, 20, 27, 31, 24)
)

spec_table <- create_table(labs_small, cols = c(subject_id, ALT, AST)) %>%
  add_title("Table T9.1") %>%
  add_subtitle("Per-Spec Template Demo") %>%
  set_page_style(docTemplate = "Navy_Pro")

spec_text <- create_text() %>%
  add_title("Narrative Section") %>%
  add_body_text("This section uses a different docTemplate unless globally overridden.") %>%
  set_page_style(docTemplate = "Carbon_Dark")

report <- create_report(spec_table, spec_text)

# A) Default behavior: each spec keeps its own docTemplate.
write_doc(
  report = report,
  name = "showcase_09_multi_spec_per_spec_templates",
  toc = TRUE,
  metaPath = meta_dir
)

# B) Global override behavior: one template is forced for all specs.
write_doc(
  report = report,
  name = "showcase_09_multi_spec_global_override",
  toc = TRUE,
  metaPath = meta_dir,
  overrideTemplate = "Navy_Pro"
)
