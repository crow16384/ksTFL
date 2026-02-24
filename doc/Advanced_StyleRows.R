## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)

## ----c-style-basic------------------------------------------------------------
# library(ksTFL)
# 
# data <- data.frame(
#   patient = sprintf("PAT-%03d", 1:20),
#   age = c(23, 45, 67, 34, 89, 56, 42, 71, 38, 29,
#           55, 66, 44, 52, 60, 48, 35, 70, 41, 58),
#   response = sample(c("CR", "PR", "SD", "PD"), 20, replace = TRUE)
# )
# 
# # Define styles first
# spec <- create_table(data) |>
#   add_style("highlight_green", s_font(color = "#006400", bold = TRUE)) |>
#   add_style("highlight_red", s_font(color = "#8B0000", bold = TRUE))
# 
# # Apply conditional styling
# spec <- spec |>
#   compute_cols(
#     response == "CR",
#     c_style(response, styleRef = "highlight_green")
#   ) |>
#   compute_cols(
#     response == "PD",
#     c_style(response, styleRef = "highlight_red")
#   )

## ----c-merge-basic------------------------------------------------------------
# data_groups <- data.frame(
#   group = c("Treatment A", "Treatment A", "Treatment A",
#             "Placebo", "Placebo"),
#   visit = c("Week 0", "Week 4", "Week 8", "Week 0", "Week 4"),
#   value = c(5.2, 6.1, 7.3, 4.8, 5.5)
# )
# 
# spec <- create_table(data_groups) |>
#   compute_cols(
#     !firstOf(group),  # Not the first occurrence of this group value
#     c_merge(c(group, visit), display_col = "group")
#   )

## ----c-addrow-basic-----------------------------------------------------------
# spec <- create_table(data_groups) |>
#   compute_cols(
#     firstOf(group),  # First row of each group
#     c_addrow(
#       position = "before",
#       values = list(
#         group = paste0("=== ", group, " ==="),
#         visit = "",
#         value = NA
#       )
#     )
#   )

## ----data-env-example---------------------------------------------------------
# # You can reference any column directly in conditions
# spec <- create_table(data) |>
#   compute_cols(
#     age > 60 & response %in% c("CR", "PR"),  # Multi-column condition
#     c_style(c(age, response), styleRef = "elderly_responder")
#   )

## ----helpers-example----------------------------------------------------------
# # Highlight first and last rows using helper functions
# spec <- create_table(data) |>
#   compute_cols(
#     firstRow() | lastRow(),
#     c_style(everything(), styleRef = "border_emphasis")
#   )
# 
# # Use firstOf/lastOf for value-based boundaries
# spec <- create_table(data_groups) |>
#   add_style("group_boundary", s_font(bold = TRUE)) |>
#   compute_cols(
#     firstOf(group) | lastOf(group),
#     c_style(group, styleRef = "group_boundary")
#   )
# 
# # Use every_nth for alternating patterns
# spec <- create_table(data) |>
#   add_style("gray_bg", s_table_style(background_color = "#F5F5F5")) |>
#   compute_cols(
#     every_nth(2),  # Every 2nd row starting from row 1
#     c_style(everything(), styleRef = "gray_bg")
#   )

## ----c-style-multi------------------------------------------------------------
# data_lab <- data.frame(
#   patient = sprintf("PAT-%03d", 1:10),
#   hemoglobin = rnorm(10, 13.5, 1.5),
#   glucose = rnorm(10, 95, 15),
#   cholesterol = rnorm(10, 200, 30)
# )
# 
# spec <- create_table(data_lab) |>
#   add_style("out_of_range", s_font(color = "#FF4500", bold = TRUE)) |>
#   compute_cols(
#     hemoglobin < 12 | hemoglobin > 16,
#     c_style(hemoglobin, styleRef = "out_of_range")
#   ) |>
#   compute_cols(
#     glucose < 70 | glucose > 140,
#     c_style(glucose, styleRef = "out_of_range")
#   ) |>
#   compute_cols(
#     cholesterol > 240,
#     c_style(cholesterol, styleRef = "out_of_range")
#   )

## ----c-style-complex----------------------------------------------------------
# spec <- create_table(data) |>
#   add_style("critical_senior",
#             s_font(color = "#8B0000", bold = TRUE),
#             s_table_style(background_color = "#FFEBCD")) |>
#   compute_cols(
#     age >= 70 & response == "PD",
#     c_style(c(patient, age, response), styleRef = "critical_senior")
#   )

## ----c-style-row--------------------------------------------------------------
# spec <- create_table(data) |>
#   add_style("alternate_row",
#             s_table_style(background_color = "#F0F0F0")) |>
#   compute_cols(
#     row_number() %% 2 == 0,  # Even rows
#     c_style(everything(), styleRef = "alternate_row")
#   )

## ----c-merge-multi------------------------------------------------------------
# data_nested <- data.frame(
#   study = rep(c("Study A", "Study B"), each = 6),
#   phase = rep(c("Phase I", "Phase II", "Phase III"), 4),
#   site = rep(c("Site 1", "Site 2", "Site 1", "Site 2"), 3),
#   enrollment = sample(10:50, 12)
# )
# 
# spec <- create_table(data_nested) |>
#   # Merge study column for consecutive same-study rows
#   compute_cols(
#     !firstOf(study),
#     c_merge(study, display_col = "study")
#   ) |>
#   # Merge phase column within same study
#   compute_cols(
#     !firstOf(study, phase),
#     c_merge(phase, display_col = "phase")
#   )

## ----c-merge-custom-----------------------------------------------------------
# spec <- create_table(data_groups) |>
#   compute_cols(
#     !firstOf(group),
#     c_merge(
#       c(group, visit),
#       display_col = "group"
#     )
#   )

## ----c-merge-style------------------------------------------------------------
# spec <- create_table(data_nested) |>
#   add_style("merged_header",
#             s_font(bold = TRUE),
#             s_table_style(background_color = "#E0E0E0")) |>
#   compute_cols(
#     !firstOf(study),
#     c_merge(study, display_col = "study")
#   ) |>
#   compute_cols(
#     firstOf(study),  # First row of group
#     c_style(study, styleRef = "merged_header")
#   )

## ----c-addrow-summary---------------------------------------------------------
# data_sales <- data.frame(
#   region = c("North", "North", "South", "South", "West", "West"),
#   product = rep(c("A", "B"), 3),
#   revenue = c(100, 150, 200, 120, 180, 160)
# )
# 
# spec <- create_table(data_sales) |>
#   add_style("summary_row",
#             s_font(bold = TRUE),
#             s_table_style(background_color = "#D3D3D3")) |>
#   compute_cols(
#     lastOf(region),  # Last row of each region
#     c_addrow(
#       position = "after",
#       values = list(
#         region = paste0(region, " Total"),
#         product = "",
#         revenue = NA  # Could be calculated if needed
#       ),
#       styleRef = "summary_row"
#     )
#   )

## ----c-addrow-header----------------------------------------------------------
# spec <- create_table(data_sales) |>
#   add_style("section_header",
#             s_font(bold = TRUE, font_size = 12),
#             s_table_style(background_color = "#4682B4")) |>
#   compute_cols(
#     firstOf(region),  # First row of each new region
#     c_addrow(
#       position = "before",
#       values = list(
#         region = toupper(region),
#         product = "REGION HEADER",
#         revenue = NA
#       ),
#       styleRef = "section_header"
#     )
#   )

## ----c-addrow-conditional-----------------------------------------------------
# spec <- create_table(data_sales) |>
#   compute_cols(
#     revenue > 150 & product == "A",  # Only for high-revenue product A
#     c_addrow(
#       position = "after",
#       values = list(
#         region = paste0("⚠ ", region, " - High Performance"),
#         product = "",
#         revenue = revenue * 1.1  # Projected next period
#       )
#     )
#   )

## ----combine-sequential-------------------------------------------------------
# spec <- create_table(data_sales) |>
#   # Step 1: Add summary rows
#   compute_cols(
#     lastOf(region),
#     c_addrow(position = "after",
#              values = list(region = paste(region, "Total"),
#                           product = "",
#                           revenue = NA))
#   ) |>
#   # Step 2: Style summary rows
#   add_style("bold_summary", s_font(bold = TRUE)) |>
#   compute_cols(
#     grepl("Total$", region),
#     c_style(region, styleRef = "bold_summary")
#   ) |>
#   # Step 3: Merge region cells (exclude summary rows)
#   compute_cols(
#     !firstOf(region) & !grepl("Total$", region),
#     c_merge(region, display_col = "region")
#   )

## ----combine-same-condition---------------------------------------------------
# spec <- create_table(data) |>
#   # Action 1: Style cells
#   compute_cols(
#     age > 65,
#     c_style(age, styleRef = "elderly")
#   ) |>
#   # Action 2: Add row marker for elderly patients
#   compute_cols(
#     age > 65 & firstOf(patient),
#     c_style(patient, styleRef = "elderly_marker")
#   )

## ----perf-minimize------------------------------------------------------------
# # ❌ Less efficient:
# spec <- create_table(data) |>
#   compute_cols(age < 30, c_style(age, styleRef = "young")) |>
#   compute_cols(age >= 30 & age < 60, c_style(age, styleRef = "middle")) |>
#   compute_cols(age >= 60, c_style(age, styleRef = "senior"))
# 
# # ✅ More efficient (single pass with case_when logic):
# spec <- create_table(data) |>
#   add_style("young", s_font(color = "#008000")) |>
#   add_style("middle", s_font(color = "#0000FF")) |>
#   add_style("senior", s_font(color = "#FF0000")) |>
#   compute_cols(
#     age < 30,
#     c_style(age, styleRef = "young")
#   ) |>
#   compute_cols(
#     age >= 30 & age < 60,
#     c_style(age, styleRef = "middle")
#   ) |>
#   compute_cols(
#     age >= 60,
#     c_style(age, styleRef = "senior")
#   )
# 
# # Note: Consider refactoring to reduce compute_cols() calls if performance is critical

## ----perf-vectorized----------------------------------------------------------
# # ❌ Slower (scalar logic):
# spec <- create_table(data) |>
#   compute_cols(
#     sapply(response, function(x) x %in% c("CR", "PR")),  # Row-by-row
#     c_style(response, styleRef = "responder")
#   )
# 
# # ✅ Faster (vectorized):
# spec <- create_table(data) |>
#   compute_cols(
#     response %in% c("CR", "PR"),  # Vectorized
#     c_style(response, styleRef = "responder")
#   )

## ----perf-prefilter-----------------------------------------------------------
# # If only 5% of rows need special formatting:
# # Consider creating separate tables and combining in report
# 
# data_outliers <- subset(data, age > 80)
# data_normal <- subset(data, age <= 80)
# 
# spec_outliers <- create_table(data_outliers) |>
#   add_style("outlier", s_font(color = "#FF0000", bold = TRUE)) |>
#   compute_cols(TRUE, c_style(everything(), styleRef = "outlier"))
# 
# spec_normal <- create_table(data_normal)
# 
# # Combine in report
# report <- create_report(spec_normal, spec_outliers)

## ----perf-consolidation-------------------------------------------------------
# # ✅ Define once, use many times:
# spec <- create_table(data) |>
#   add_style("critical", s_font(color = "#FF0000", bold = TRUE)) |>
#   compute_cols(age > 80, c_style(age, styleRef = "critical")) |>
#   compute_cols(response == "PD", c_style(response, styleRef = "critical"))
# 
# # ❌ Avoid duplicate style definitions:
# # (This creates two identical but separate styles)
# spec <- create_table(data) |>
#   add_style("critical_age", s_font(color = "#FF0000", bold = TRUE)) |>
#   add_style("critical_response", s_font(color = "#FF0000", bold = TRUE))

## ----debug-inspect------------------------------------------------------------
# spec <- create_table(data) |>
#   compute_cols(
#     age > 60,
#     c_style(age, styleRef = "elderly")
#   )
# 
# # Examine metadata
# str(spec$.metadata$styleRows)
# # Shows captured quosures and action types

## ----debug-test---------------------------------------------------------------
# # Get data from spec
# data_test <- spec$.metadata$data_env$`__data__`
# 
# # Test your condition
# test_condition <- with(data_test, age > 60)
# sum(test_condition)  # How many rows match?
# 
# # Verify subset
# data_test[test_condition, ]

## ----debug-incremental--------------------------------------------------------
# spec <- create_table(data)
# 
# # Add first action
# spec <- spec |>
#   compute_cols(age > 60, c_style(age, styleRef = "elderly"))
# print(spec)  # Check structure
# 
# # Add second action
# spec <- spec |>
#   compute_cols(response == "CR", c_style(response, styleRef = "success"))
# print(spec)  # Check again

## ----pattern-alternate--------------------------------------------------------
# spec <- create_table(data) |>
#   add_style("gray_bg", s_table_style(background_color = "#F5F5F5")) |>
#   compute_cols(
#     row_number() %% 2 == 0,
#     c_style(everything(), styleRef = "gray_bg")
#   )

## ----pattern-grouped----------------------------------------------------------
# spec <- create_table(data_groups) |>
#   add_style("group_header",
#             s_font(bold = TRUE, font_size = 11),
#             s_table_style(background_color = "#D0D0D0")) |>
#   # Insert header row before each new group
#   compute_cols(
#     firstOf(group),
#     c_addrow(
#       position = "before",
#       values = list(group = paste("===", group, "==="), visit = "", value = NA),
#       styleRef = "group_header"
#     )
#   ) |>
#   # Merge consecutive same-group cells
#   compute_cols(
#     !firstOf(group),
#     c_merge(group, display_col = "group")
#   )

## ----pattern-thresholds-------------------------------------------------------
# spec <- create_table(data_lab) |>
#   add_style("low", s_font(color = "#0000FF")) |>
#   add_style("normal", s_font(color = "#008000")) |>
#   add_style("high", s_font(color = "#FF0000")) |>
#   compute_cols(
#     hemoglobin < 12,
#     c_style(hemoglobin, styleRef = "low")
#   ) |>
#   compute_cols(
#     hemoglobin >= 12 & hemoglobin <= 16,
#     c_style(hemoglobin, styleRef = "normal")
#   ) |>
#   compute_cols(
#     hemoglobin > 16,
#     c_style(hemoglobin, styleRef = "high")
#   )

## ----pattern-totals-----------------------------------------------------------
# spec <- create_table(data_sales) |>
#   add_style("total_row",
#             s_font(bold = TRUE),
#             s_table_style(background_color = "#FFD700")) |>
#   compute_cols(
#     lastOf(region),  # Last row of each region
#     c_addrow(
#       position = "after",
#       values = list(
#         region = "SUBTOTAL",
#         product = "",
#         revenue = NA
#       ),
#       styleRef = "total_row"
#     )
#   )

## ----limit-aggregates, error=TRUE---------------------------------------------
try({
# # ❌ This won't work as expected:
# spec <- create_table(data) |>
#   compute_cols(
#     age > mean(age),  # Evaluates mean() at condition capture, not evaluation
#     c_style(age, styleRef = "above_average")
#   )
})

## ----workaround-aggregates----------------------------------------------------
# data$age_above_avg <- data$age > mean(data$age)
# 
# spec <- create_table(data) |>
#   compute_cols(
#     age_above_avg,
#     c_style(age, styleRef = "above_average")
#   )

## ----limit-nested, error=TRUE-------------------------------------------------
try({
# # ❌ This is invalid:
# spec <- create_table(data) |>
#   compute_cols(
#     age > 60,
#     c_style(age, styleRef = c_merge(patient, age))  # Not allowed
#   )
})

## ----workaround-nested--------------------------------------------------------
# spec <- create_table(data) |>
#   compute_cols(age > 60, c_style(age, styleRef = "elderly")) |>
#   compute_cols(age > 60, c_merge(c(patient, age), display_col = "patient"))

## ----limit-styleref, error=TRUE-----------------------------------------------
try({
# # ❌ This will error at evaluation time:
# spec <- create_table(data) |>
#   compute_cols(age > 60, c_style(age, styleRef = "undefined_style"))
})

## ----workaround-styleref------------------------------------------------------
# spec <- create_table(data) |>
#   add_style("elderly", s_font(bold = TRUE)) |>  # Define first
#   compute_cols(age > 60, c_style(age, styleRef = "elderly"))

## ----integrate-define---------------------------------------------------------
# spec <- create_table(data) |>
#   define_cols(age, type = "numeric", format = "0.0", colWidth = "15%") |>
#   compute_cols(
#     age > 65,
#     c_style(age, styleRef = "elderly")
#   )

## ----integrate-invisible------------------------------------------------------
# data$flag <- sample(c(TRUE, FALSE), nrow(data), replace = TRUE)
# 
# spec <- create_table(data) |>
#   define_cols(flag, isVisible = FALSE) |>  # Hide column
#   compute_cols(
#     flag == TRUE,  # But use it in condition
#     c_style(response, styleRef = "flagged")
#   )

## ----integrate-report---------------------------------------------------------
# spec1 <- create_table(data[1:10, ]) |>
#   compute_cols(age > 60, c_style(age, styleRef = "elderly"))
# 
# spec2 <- create_table(data[11:20, ]) |>
#   compute_cols(response == "CR", c_style(response, styleRef = "success"))
# 
# report <- create_report(spec1, spec2)

