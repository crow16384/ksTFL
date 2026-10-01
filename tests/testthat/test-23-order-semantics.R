# ============================================================================
# Test: execution ORDER semantics (task §5)
#
# ksTFL has deliberately order-DEPENDENT behavior (action seq, f_combine
# last-arg-wins, add_title append) and order-INDEPENDENT behavior (column
# vector recycling semantics, same-result requirement for equivalent configs).
# Each test below states which category it pins.
# ============================================================================

# ---- order-DEPENDENT: action sequence number = arrival order ------------------

test_that("action seq follows ARG order inside one compute_cols block (order-dependent by design)", {
  df <- data.frame(a = c("x", "y"), b = c("1", "2"), stringsAsFactors = FALSE)
  base <- create_table(df) |> define_cols(b, isVisible = FALSE)

  p_order1 <- create_report(
    compute_cols(base, a == "x",
                 c_clear(a), c_glue(a, "after", text = "G")))
  p_order2 <- create_report(
    compute_cols(base, a == "x",
                 c_glue(a, "after", text = "G"), c_clear(a)))

  acts1 <- jsonlite::fromJSON(p_order1[[1]]$styleRows[1], simplifyVector = FALSE)
  acts2 <- jsonlite::fromJSON(p_order2[[1]]$styleRows[1], simplifyVector = FALSE)

  expect_equal(acts1$clear[[1]]$seq, 0L)
  expect_equal(acts1$glue[[1]]$seq, 1L)
  expect_equal(acts2$glue[[1]]$seq, 0L)
  expect_equal(acts2$clear[[1]]$seq, 1L)
})

test_that("f_combine() argument order is semantic: last argument wins per property", {
  df <- data.frame(z = "cell")
  mk2 <- function(first, second, nm, .env = parent.frame()) {
    dirs <- local_docx_dirs(.env = .env)
    spec <- create_table(df) |>
      add_style("b", s_font(bold = TRUE)) |>
      add_style("p", s_font(bold = FALSE)) |>
      compute_cols(TRUE, c_style(z, f_combine(first, second)))
    write_doc(create_report(spec), nm, outDir = dirs$out,
              metaPath = dirs$meta, verbose = FALSE)
  }

  p1 <- mk2("b", "p", "fc_bp")   # last wins -> NOT bold
  p2 <- mk2("p", "b", "fc_pb")   # last wins -> bold

  run_of <- function(path) {
    rx_all(docx_part_text(path),
           "(?s)<w:r>(?:(?!</w:r>).)*<w:t(?: [^>]*)?>cell</w:t>(?:(?!</w:r>).)*</w:r>")
  }
  r1 <- run_of(p1); r2 <- run_of(p2)
  expect_gte(length(r1), 1L); expect_gte(length(r2), 1L)
  expect_false(any(grepl("<w:b/>|<w:b ", r1)),
               label = "f_combine(b, plain): plain last -> not bold")
  expect_true(any(grepl("<w:b/>|<w:b ", r2)),
              label = "f_combine(plain, b): bold last -> bold")
})

# ---- order-DEPENDENT: titles/footnotes append in call order -------------------

test_that("repeated add_title() calls append in call order (documented stacking)", {
  spec <- create_text() |> add_title("one") |> add_title("two")
  expect_equal(unname(vapply(spec$titles, function(t) t$text, character(1))),
               c("one", "two"))
  # a single vector call expresses the same stacking:
  spec2 <- create_text() |> add_title(c("one", "two"))
  texts2 <- unlist(lapply(spec2$titles, function(t) t$text))
  expect_setequal(texts2, c("one", "two"))
})

test_that("add_footnote() accumulates in order while add_header() REPLACES (asymmetric semantics)", {
  spec <- create_table(test_df) |>
    add_footnote("f1") |> add_footnote("f2")
  expect_equal(length(spec$footnotes), 2L)
  expect_equal(spec$footnotes[[1]]$text, "f1")
  expect_equal(spec$footnotes[[2]]$text, "f2")

  # add_header() accumulates by default; same level REPLACES (asymmetric with
  # footnotes' plain accumulation) — true semantics, verified live.
  hdr <- create_text() |> add_header("h1") |> add_header("h2")
  expect_equal(length(hdr$headers), 2L, label = "no level -> accumulate")
  hdr2 <- create_text() |> add_header("h1", level = 1) |> add_header("h2", level = 1)
  expect_equal(hdr2$headers[[1]], "h2", label = "same level -> replace")
})

# ---- order-DEPENDENT: define_cols last-call-wins per property ------------------

test_that("two define_cols calls on one column: later call wins per property, earlier kept otherwise", {
  spec <- create_table(test_df) |>
    define_cols(id, label = "First", colWidth = "2cm") |>
    define_cols(id, label = "Second")
  expect_equal(spec$columns$id$label, "Second")
  expect_equal(spec$columns$id$format$colWidth, "2cm",
               label = "property not restated survives from first call")
})

# ---- order-INDEPENDENT: equivalent configurations -----------------------------

test_that("column vector form vs repeated scalar calls produce IDENTICAL specs (order-independent)", {
  df <- data.frame(a = 1:2, b = c("x", "y"), stringsAsFactors = FALSE)

  s1 <- create_table(df) |>
    define_cols(c(a, b), label = c("LA", "LB"), isVisible = c(TRUE, FALSE))
  s2 <- create_table(df) |>
    define_cols(a, label = "LA") |>
    define_cols(b, label = "LB", isVisible = FALSE)

  # serialization must be byte-identical apart from transient bookkeeping
  # (report keys embed the object name by design -> normalize them)
  j1 <- serialize_spec(create_report(s1))$fixed
  j2 <- serialize_spec(create_report(s2))$fixed
  drop_meta <- function(x) {
    l <- if (!is.list(x)) list(x) else x
    for (i in seq_along(l)) {
      l[[i]]$.metadata <- NULL
      if (!is.null(l[[i]]$specKey)) l[[i]]$specKey <- "K"
      names(l)[i] <- "K"
    }
    names(l) <- NULL
    l
  }
  expect_identical(jsonlite::toJSON(drop_meta(j1), auto_unbox = TRUE),
                   jsonlite::toJSON(drop_meta(j2), auto_unbox = TRUE))
})

test_that("tidyselect reordering of define_cols targets does not change resulting spec", {
  s1 <- create_table(test_df) |>
    define_cols(c(id, value), label = c("I", "V"))
  s2 <- create_table(test_df) |>
    define_cols(starts_with("i"), label = "I") |>
    define_cols(starts_with("va"), label = "V")
  expect_equal(s1$columns$id$label, "I"); expect_equal(s2$columns$id$label, "I")
  expect_equal(s1$columns$value$label, "V"); expect_equal(s2$columns$value$label, "V")
})

test_that("create_report() renumbers docOrder by argument position; swapping inputs swaps order", {
  t1 <- create_table(test_df) |> add_title("T1")
  t2 <- create_table(test_df) |> add_title("T2")
  rA <- create_report(t1, t2)
  rB <- create_report(t2, t1)
  ordA <- vapply(rA, function(s) s$document$docOrder, numeric(1))
  ordB <- vapply(rB, function(s) s$document$docOrder, numeric(1))
  expect_equal(unname(ordA), c(1L, 2L))
  expect_equal(unname(ordB), c(1L, 2L))
  expect_equal(names(rA)[1], names(rB)[2],
               label = "same specs, opposite assembly order")
})

test_that("span header stubOrder grouping is insertion-order independent for disjoint bands", {
  b1 <- create_table(test_df) |>
    add_span_header(c(id, group), label = "X", stubOrder = 1) |>
    add_span_header(c(value, ratio), label = "Y", stubOrder = 1)
  b2 <- create_table(test_df) |>
    add_span_header(c(value, ratio), label = "Y", stubOrder = 1) |>
    add_span_header(c(id, group), label = "X", stubOrder = 1)
  s1 <- sort(unname(vapply(b1$stubColumns, function(x) x$label, character(1))))
  s2 <- sort(unname(vapply(b2$stubColumns, function(x) x$label, character(1))))
  expect_identical(s1, s2)
})
