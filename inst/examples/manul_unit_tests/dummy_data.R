### Dummy data for tests

set.seed(2025)
demography_tbl_01 <- tibble(
  param = c(
    "Age", "Age", "Age",
    "Sex", "Sex", "Sex",
    "Race", "Race", "Race", "Race", "Race",
    "Ethnicity", "Ethnicity", "Ethnicity"
  ),
  value = c(
    NA, NA, NA,
    NA, "Male", "Female",
    NA, "White", "Black or African American", "Asian", "Other",
    NA, "Hispanic or Latino", "Not Hispanic or Latino"
  ),
  stat = c(
    "n", "Mean (SD)", "Min - Max",
    "n", "n (%)", "n (%)",
    "n", "n (%)", "n (%)", "n (%)", "n (%)",
    "n", "n (%)", "n (%)"
  ),
  trt_a = c(
    "100", "45.2 (12.1)", "18 - 75", 
    "100", "52 (52%)", "48 (48%)",
    "100", "70 (70%)", "20 (20%)", "5 (5%)", "5 (5%)",
    "100", "15 (15%)", "85 (85%)"
  ),
  trt_b = c(
    "98", "47.8 (11.5)", "21 - 73", 
    "98", "50 (51%)", "48 (49%)",
    "98", "65 (66%)", "22 (22%)", "6 (6%)", "5 (5%)",
    "98", "12 (12%)", "86 (88%)"
  ),
  trt_c = c(
    "102", "44.1 (13.0)", "19 - 78", 
    "102", "55 (54%)", "47 (46%)",
    "102", "72 (71%)", "18 (18%)", "7 (7%)", "5 (5%)",
    "102", "18 (18%)", "84 (82%)"
  )
)
