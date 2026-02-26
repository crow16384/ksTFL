source("inst/examples/init.R")


# ============================================================================
# Build a multi-page laboratory results dataset
# ============================================================================
# Each analyte has a name (with chemical notation), units (with super/subscripts),
# reference range, and multi-visit results.

set.seed(42)

analytes <- list(
  # ── Hematology ──
  list(group = "Hematology", name = "Hemoglobin",
       unit = "g/dL", lo = 12.0, hi = 17.5),
  list(group = "Hematology", name = "Hematocrit",
       unit = "%", lo = 36, hi = 50),
  list(group = "Hematology", name = "WBC",
       unit = "10<sup>3</sup>/\u00b5L", lo = 4.5, hi = 11.0),
  list(group = "Hematology", name = "RBC",
       unit = "10<sup>6</sup>/\u00b5L", lo = 4.0, hi = 5.5),
  list(group = "Hematology", name = "Platelets",
       unit = "10<sup>3</sup>/\u00b5L", lo = 150, hi = 400),
  list(group = "Hematology", name = "MCV",
       unit = "fL", lo = 80, hi = 100),
  list(group = "Hematology", name = "MCH",
       unit = "pg", lo = 27, hi = 33),
  list(group = "Hematology", name = "MCHC",
       unit = "g/dL", lo = 32, hi = 36),
  
  # ── Chemistry ──
  list(group = "Chemistry", name = "Glucose",
       unit = "mg/dL", lo = 70, hi = 100),
  list(group = "Chemistry", name = "BUN",
       unit = "mg/dL", lo = 7, hi = 20),
  list(group = "Chemistry", name = "Creatinine",
       unit = "mg/dL", lo = 0.6, hi = 1.2),
  list(group = "Chemistry", name = "Na<sup>+</sup>",
       unit = "mEq/L", lo = 136, hi = 145),
  list(group = "Chemistry", name = "K<sup>+</sup>",
       unit = "mEq/L", lo = 3.5, hi = 5.0),
  list(group = "Chemistry", name = "Cl<sup>\u2212</sup>",
       unit = "mEq/L", lo = 98, hi = 106),
  list(group = "Chemistry", name = "CO<sub>2</sub>",
       unit = "mEq/L", lo = 23, hi = 29),
  list(group = "Chemistry", name = "Ca<sup>2+</sup>",
       unit = "mg/dL", lo = 8.5, hi = 10.5),
  
  # ── Liver Function ──
  list(group = "Liver Function", name = "ALT",
       unit = "U/L", lo = 7, hi = 56),
  list(group = "Liver Function", name = "AST",
       unit = "U/L", lo = 10, hi = 40),
  list(group = "Liver Function", name = "ALP",
       unit = "U/L", lo = 44, hi = 147),
  list(group = "Liver Function", name = "Total Bilirubin",
       unit = "mg/dL", lo = 0.1, hi = 1.2),
  list(group = "Liver Function", name = "Direct Bilirubin",
       unit = "mg/dL", lo = 0.0, hi = 0.3),
  list(group = "Liver Function", name = "Albumin",
       unit = "g/dL", lo = 3.5, hi = 5.5),
  list(group = "Liver Function", name = "Total Protein",
       unit = "g/dL", lo = 6.0, hi = 8.3),
  list(group = "Liver Function", name = "GGT",
       unit = "U/L", lo = 9, hi = 48),
  
  # ── Lipid Panel ──
  list(group = "Lipid Panel", name = "Total Cholesterol",
       unit = "mg/dL", lo = 0, hi = 200),
  list(group = "Lipid Panel", name = "LDL-C",
       unit = "mg/dL", lo = 0, hi = 100),
  list(group = "Lipid Panel", name = "HDL-C",
       unit = "mg/dL", lo = 40, hi = 999),
  list(group = "Lipid Panel", name = "Triglycerides",
       unit = "mg/dL", lo = 0, hi = 150),
  
  # ── Thyroid ──
  list(group = "Thyroid", name = "TSH",
       unit = "\u00b5IU/mL", lo = 0.27, hi = 4.2),
  list(group = "Thyroid", name = "Free T<sub>4</sub>",
       unit = "ng/dL", lo = 0.93, hi = 1.7),
  list(group = "Thyroid", name = "Free T<sub>3</sub>",
       unit = "pg/mL", lo = 2.0, hi = 4.4),
  
  # ── Urinalysis ──
  list(group = "Urinalysis", name = "pH",
       unit = "", lo = 4.6, hi = 8.0),
  list(group = "Urinalysis", name = "Specific Gravity",
       unit = "", lo = 1.005, hi = 1.030),
  list(group = "Urinalysis", name = "Protein",
       unit = "mg/dL", lo = 0, hi = 14),
  list(group = "Urinalysis", name = "Glucose (urine)",
       unit = "mg/dL", lo = 0, hi = 15),
  
  # ── Coagulation ──
  list(group = "Coagulation", name = "PT",
       unit = "sec", lo = 11.0, hi = 13.5),
  list(group = "Coagulation", name = "INR",
       unit = "", lo = 0.8, hi = 1.1),
  list(group = "Coagulation", name = "aPTT",
       unit = "sec", lo = 25, hi = 35),
  list(group = "Coagulation", name = "Fibrinogen",
       unit = "mg/dL", lo = 200, hi = 400)
)

# Generate 3 visits of data; some values are deliberately out of range.
visits <- c("Baseline", "Week 4", "Week 12")
rows <- list()

for (a in analytes) {
  mid <- (a$lo + a$hi) / 2
  span <- a$hi - a$lo
  
  vals <- numeric(length(visits))
  for (v_idx in seq_along(visits)) {
    # ~80% normal, ~20% out-of-range
    if (runif(1) < 0.2) {
      # out-of-range: either below lo or above hi
      if (runif(1) < 0.5) {
        vals[v_idx] <- a$lo - runif(1) * span * 0.3
      } else {
        vals[v_idx] <- a$hi + runif(1) * span * 0.3
      }
    } else {
      vals[v_idx] <- a$lo + runif(1) * span
    }
    vals[v_idx] <- round(vals[v_idx], 2)
  }
  
  # Format reference range with multi-line: value range + units on next line
  if (nchar(a$unit) > 0) {
    ref_range <- paste0(a$lo, " \u2013 ", a$hi, "\n", a$unit)
  } else {
    ref_range <- paste0(a$lo, " \u2013 ", a$hi)
  }
  
  # Mark out-of-range values with bold + flag character
  format_val <- function(val, lo, hi) {
    if (val < lo) {
      paste0("<b>", sprintf("%.2f", val), "</b> <i>\u2193</i>")
    } else if (val > hi) {
      paste0("<b>", sprintf("%.2f", val), "</b> <i>\u2191</i>")
    } else {
      sprintf("%.2f", val)
    }
  }
  
  rows[[length(rows) + 1]] <- data.frame(
    Group = a$group,
    Analyte = a$name,
    Units = if (nchar(a$unit) > 0) a$unit else "\u2014",
    Reference = ref_range,
    Baseline = format_val(vals[1], a$lo, a$hi),
    Week4 = format_val(vals[2], a$lo, a$hi),
    Week12 = format_val(vals[3], a$lo, a$hi),
    # hidden columns for conditional styling
    v1 = vals[1], v2 = vals[2], v3 = vals[3],
    lo = a$lo, hi = a$hi,
    stringsAsFactors = FALSE
  )
}

df_lab <- do.call(rbind, rows)
rownames(df_lab) <- NULL

df_lab <- tibble(df_lab)

cat("Lab dataset:", nrow(df_lab), "analytes across",
    length(unique(df_lab$Group)), "groups,",
    length(visits), "visits\n\n")
