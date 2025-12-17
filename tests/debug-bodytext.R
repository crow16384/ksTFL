#!/usr/bin/env R
# Debug script for bodyText routing

library(testthat)
source("./tests/testthat/setup.R")
devtools::load_all()

cat("\n=== DEBUG: Testing bodyText routing ===\n\n")

# Reset settings
tfl_reset_settings()
settings <- tfl_get_settings()
cat("Initial bodyText names:", paste(names(settings$bodyText), collapse = ", "), "\n\n")

# Create a body_obj
cat("Creating body_obj with add_body_text('Test message')...\n")
body_obj <- add_body_text("Test message")

cat("body_obj class:", paste(class(body_obj), collapse = ", "), "\n")
cat("body_obj structure:\n")
str(body_obj)
cat("\n")

# Check inheritance
cat("inherits(body_obj, 'tfl_bodytext_setting'):", inherits(body_obj, "tfl_bodytext_setting"), "\n\n")

# Now let's manually trace what tfl_set_options should do
cat("=== Manual trace of tfl_set_options ===\n\n")

# Simulate tfl_set_options routing
arg <- body_obj
arg_clean <- arg[!sapply(arg, is.null)]

cat("arg_clean after removing NULLs:\n")
str(arg_clean)
cat("\n")

# Now try the do.call
cat("Attempting do.call('add_body_text.TFL_options', ...):\n")
call_args <- c(list(spec = settings), arg_clean)
cat("call_args structure:\n")
str(call_args)
cat("\n")

# Try the actual call
cat("Executing call...\n")
result <- do.call("add_body_text.TFL_options", call_args)

cat("Result bodyText names:", paste(names(result$bodyText), collapse = ", "), "\n")
cat("Result bodyText structure:\n")
str(result$bodyText)
cat("\n")

# Now test with the real tfl_set_options
cat("=== Testing with real tfl_set_options ===\n\n")
tfl_reset_settings()

body_obj2 <- add_body_text("Real message")
tfl_set_options(body_obj2)

final_settings <- tfl_get_settings()
cat("Final bodyText names:", paste(names(final_settings$bodyText), collapse = ", "), "\n")
cat("Final bodyText structure:\n")
str(final_settings$bodyText)

cat("\n=== DEBUG COMPLETE ===\n")
