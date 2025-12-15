# Test setup file for ksTFL package tests
# Runs before all tests to ensure clean state

# Reset package settings to defaults before each test
setup_package <- function() {
  library(testthat)
  library(ksTFL)
  library(cli)
  
  # Ensure clean state
  if (exists("tfl_reset_settings", mode = "function")) {
    tfl_reset_settings()
  }
}

# Reset settings after each test file
teardown_package <- function() {
  if (exists("tfl_reset_settings", mode = "function")) {
    tfl_reset_settings()
  }
}
