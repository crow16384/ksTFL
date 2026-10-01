# Standard testthat runner. Without this file R CMD check and covr::package_coverage()
# silently execute ZERO tests (see test-suite review 2026-09-29).
library(testthat)
library(ksTFL)

test_check("ksTFL")
