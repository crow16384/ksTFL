## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)

## ----initial-widths-----------------------------------------------------------
# library(ksTFL)
# 
# # Create sample data
# data <- data.frame(
#   id = 1:100,
#   patient_id = sprintf("PAT-%04d", 1:100),
#   age = round(rnorm(100, 45, 10)),
#   weight_kg = round(rnorm(100, 70, 15), 1),
#   treatment_group = sample(c("Placebo", "Treatment A", "Treatment B"), 100, replace = TRUE)
# )
# 
# # Initial spec with auto-detected widths
# spec <- create_table(data)
# print(spec)  # Shows auto-calculated widths for all columns

## ----autocol-option-----------------------------------------------------------
# # Check current setting
# tfl_get_option("autoColWidth")  # TRUE by default
# 
# # Disable for manual width management
# tfl_set_options(autoColWidth = FALSE)
# 
# # Re-enable (restore default behavior)
# tfl_set_options(autoColWidth = TRUE)

## ----basic-locking------------------------------------------------------------
# # Lock the 'id' column at 15%
# spec <- create_table(data) |>
#   define_cols(id, colWidth = "15%")
# 
# # Result:
# # - id: 15% (LOCKED)
# # - Other visible columns: auto-recalculated to fill remaining 85%

## ----multiple-locks-----------------------------------------------------------
# spec <- create_table(data) |>
#   define_cols(id, colWidth = "10%") |>           # Lock at 10%
#   define_cols(patient_id, colWidth = "20%") |>   # Lock at 20%
#   define_cols(treatment_group, colWidth = "25%") # Lock at 25%
# 
# # Result:
# # - id: 10% (LOCKED)
# # - patient_id: 20% (LOCKED)
# # - treatment_group: 25% (LOCKED)
# # - age, weight_kg: share remaining 45% proportionally

## ----mixed-units--------------------------------------------------------------
# spec <- create_table(data) |>
#   define_cols(id, colWidth = "2.5cm") |>      # Fixed width (doesn't reduce % space)
#   define_cols(patient_id, colWidth = "20%")   # Takes 20% of available
# 
# # Result:
# # - id: 2.5cm (LOCKED, absolute)
# # - patient_id: 20% (LOCKED, relative)
# # - Other columns: share remaining 80% proportionally

## ----recalc-example-----------------------------------------------------------
# # Initial auto-distribution (example values):
# # id: 15%, patient_id: 25%, age: 20%, weight_kg: 20%, treatment_group: 20%
# 
# spec <- create_table(data) |>
#   define_cols(id, colWidth = "10%")
# 
# # After locking id at 10%:
# # - Available space: 100% - 10% = 90%
# # - Unlocked weights: patient_id=25, age=20, weight_kg=20, treatment_group=20 (sum=85)
# # - Normalized: patient_id=26.5%, age=21.2%, weight_kg=21.2%, treatment_group=21.2%
# # - Result sums to 100.1% (rounding), drift corrected to largest column

## ----invisible-basic----------------------------------------------------------
# spec <- create_table(data) |>
#   define_cols(id, isVisible = FALSE)
# 
# # Result:
# # - id: hidden, width = "0.0cm" (automatic)
# # - Other columns: recalculated to fill 100%

## ----invisible-error, error=TRUE----------------------------------------------
try({
# # This will error:
# spec <- create_table(data) |>
#   define_cols(id, isVisible = FALSE, colWidth = "15%")
# 
# # Error message:
# # "Cannot set colWidth for invisible column 'id'"
})

## ----invisible-logic----------------------------------------------------------
# spec <- create_table(data) |>
#   # Hide the flag column but keep data available
#   define_cols(patient_id, isVisible = FALSE) |>
#   # Use it in compute_cols() for conditional styling
#   compute_cols(
#     startsWith(patient_id, "PAT-001"),
#     c_style(age, styleRef = "highlight_yellow")
#   )

## ----manual-widths------------------------------------------------------------
# # Disable auto-recalculation
# tfl_set_options(autoColWidth = FALSE)
# 
# # Set exact widths - no automatic adjustment
# spec <- create_table(data) |>
#   define_cols(
#     c(id, patient_id, age, weight_kg, treatment_group),
#     colWidth = c("10%", "25%", "20%", "20%", "25%")
#   )
# 
# # Widths stay exactly as specified (sum = 100%)
# 
# # Re-enable for other tables
# tfl_set_options(autoColWidth = TRUE)

## ----min-width-error, error=TRUE----------------------------------------------
try({
# # This will error:
# spec <- create_table(data) |>
#   define_cols(id, colWidth = "0.1%")  # Below 0.5% minimum
# 
# # Error: "Column width '0.1%' is below minimum allowed"
})

## ----space-constraint-error, error=TRUE---------------------------------------
try({
# # 5 columns with minColWidth = 0.5% (default)
# # Minimum space needed for 4 unlocked columns: 4 × 0.5% = 2%
# 
# # This will error:
# spec <- create_table(data) |>
#   define_cols(id, colWidth = "99%")  # Leaves only 1% for 4 columns
# 
# # Error: "Cannot set column 'id' to '99%'"
# # "This would leave insufficient space for the remaining 4 unlocked columns"
# # "Maximum allowed relative width for id: 98.0%"
})

## ----custom-min---------------------------------------------------------------
# # Allow tighter columns (use with caution)
# tfl_set_options(minColWidth = 0.3)
# 
# # Now you can use narrower relative widths
# spec <- create_table(data) |>
#   define_cols(id, colWidth = "95%")  # More space for this column
# 
# # Reset to default
# tfl_set_options(minColWidth = 0.5)

## ----pattern-id---------------------------------------------------------------
# spec <- create_table(data) |>
#   define_cols(id, colWidth = "8%", isID = TRUE) |>
#   define_cols(patient_id, colWidth = "15%")
# 
# # Result: ID columns fixed, others auto-distribute

## ----pattern-fixed-flex-------------------------------------------------------
# spec <- create_table(data) |>
#   define_cols(
#     c(id, patient_id, treatment_group),
#     colWidth = c("8%", "20%", "22%")
#   )
#   # age and weight_kg auto-fill remaining 50%

## ----pattern-all-manual-------------------------------------------------------
# tfl_set_options(autoColWidth = FALSE)
# 
# spec <- create_table(data) |>
#   define_cols(
#     c(id, patient_id, age, weight_kg, treatment_group),
#     colWidth = c("8%", "22%", "15%", "18%", "37%")
#   )  # Sum = 100% exactly
# 
# tfl_set_options(autoColWidth = TRUE)

## ----pattern-progressive------------------------------------------------------
# # Lock columns one at a time, observing effects
# spec <- create_table(data)
# print(spec)  # See initial distribution
# 
# spec <- spec |>
#   define_cols(id, colWidth = "10%")
# print(spec)  # See after first lock
# 
# spec <- spec |>
#   define_cols(patient_id, colWidth = "20%")
# print(spec)  # See after second lock

## ----width-metadata-----------------------------------------------------------
# spec <- create_table(data) |>
#   define_cols(id, colWidth = "15%")
# 
# # Inspect metadata
# str(spec$.metadata$colWidths)
# 
# # Structure for each column:
# # $id
# #   $unit: "%" or "cm" or "in" etc.
# #   $value: numeric value
# #   $locked: TRUE/FALSE
# #   $auto_weight: initial proportion for recalculation

