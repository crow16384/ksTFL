# Extracted from test-25-docx-semantic.R:148

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "ksTFL", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
dirs <- local_docx_dirs()
spec <- create_table(data.frame(a = 1:2)) |>
    set_document(footnotePlace = "doc_footer") |>
    add_footnote("DF-NOTE-ABC") |>
    add_footer(c("Conf", ""))
p <- write_doc(create_report(spec), "sem_docfooter", outDir = dirs$out,
                 metaPath = dirs$meta, verbose = FALSE)
fparts <- grep("^word/footer", docx_parts(p), value = TRUE)
expect_true(any(vapply(fparts, function(q)
    grepl("DF-NOTE-ABC", docx_part_text(p, q), fixed = TRUE), logical(1))),
    label = "note lands in a footer part")
dirs2 <- local_docx_dirs()
spec2 <- create_table(data.frame(a = 1:2)) |>
    set_document(footnotePlace = "doc_footer") |>
    add_footnote("DF-NOTE-DROPPED")
p2 <- write_doc(create_report(spec2), "sem_docfooter2", outDir = dirs2$out,
                  metaPath = dirs2$meta, verbose = FALSE)
anywhere <- any(vapply(docx_parts(p2), function(q)
    grepl("DF-NOTE-DROPPED", docx_part_text(p2, q), fixed = TRUE), logical(1)))
expect_false(anywhere, label = "doc_footer without add_footer drops the note (known)")
