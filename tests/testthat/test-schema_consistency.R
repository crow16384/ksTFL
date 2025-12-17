test_that("schema files exist and schema keys are consistent with constants", {
  # Check that declared schema files exist
  expect_true(nzchar(system.file("schemas", .const_spec_schema_file, package = "ksTFL")), info = "Spec schema missing")
  expect_true(nzchar(system.file("schemas", .const_style_schema_file, package = "ksTFL")), info = "Style schema missing")
  expect_true(nzchar(system.file("schemas", .const_row_style_schema_file, package = "ksTFL")), info = "Row style schema missing")

  # Load the main spec schema and collect property names under 'properties'
  schema_file <- system.file("schemas", .const_spec_schema_file, package = "ksTFL")
  schema <- jsonlite::read_json(schema_file, simplifyVector = FALSE)

  collect_props <- function(node) {
    props <- character(0)
    if (is.list(node) && "properties" %in% names(node)) {
      props <- c(props, names(node$properties))
      for (child in node$properties) props <- c(props, collect_props(child))
    } else if (is.list(node)) {
      for (child in node) props <- c(props, collect_props(child))
    }
    unique(props)
  }

  props <- collect_props(schema)

  missing_keys <- setdiff(names(.const_schema_properties), props)
  expect(length(missing_keys) == 0, paste("Missing keys in schema:", paste(missing_keys, collapse = ", ")))
})