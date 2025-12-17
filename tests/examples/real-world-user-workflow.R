# ============================================================================
# REAL-WORLD END-USER WORKFLOW: Creating TFLs with Different Options
# ============================================================================
# This script demonstrates how an end-user would interact with the ksTFL package
# to create multiple TFL (Tables, Figures, Listings) specifications with 
# different options and combinations.
#
# Workflow:
# 1. Load the package
# 2. Set up company/project defaults
# 3. Create multiple specs with different configurations
# 4. Override defaults for specific use cases
# 5. Export final specs

#library(ksTFL)
devtools::load_all()
cat("\n" %+% strrep("=", 80) %+% "\n")
cat("REAL-WORLD END-USER WORKFLOW: Creating TFLs with Options\n")
cat(strrep("=", 80) %+% "\n\n")

# ============================================================================
# STEP 1: Initialize the package with company-wide defaults
# ============================================================================
cat("STEP 1: Setting Up Company Defaults\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

# Reset to clean state
tfl_reset_options()

# Set company branding defaults that will apply to all specs
cat("Setting company-wide options:\n")
tfl_set_options(
  # Company headers
  add_header(c("ACME Pharmaceuticals", "Clinical Data Report", "2024")),
  
  # Company footer with metadata
  add_footer(c("CONFIDENTIAL", "Report Page:", "")),
  
  # Default page format
  page = tfl_page(
    size = "A4",
    orientation = "landscape"
  ),
  
  # Default body text for missing data
  add_body_text("No data available for this analysis")
)

cat("  ✓ Company Header: ACME Pharmaceuticals | Clinical Data Report | 2024\n")
cat("  ✓ Company Footer: CONFIDENTIAL | Report Page: | \n")
cat("  ✓ Page Format: A4 Landscape\n")
cat("  ✓ Default Body Text: 'No data available for this analysis'\n\n")

# ============================================================================
# STEP 2: Create Table 1 - Safety Summary (using company defaults)
# ============================================================================
cat("STEP 2: Creating Table 1 - Safety Summary\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

# Initialize a new spec (this will automatically inherit company options)
table1_spec <- tfl_init()

cat("  ✓ Table 1 spec created with inherited company defaults\n")
cat("    - Includes company header, footer, page format\n")
cat("    - Ready for population with data\n\n")

# At this point, users would:
# - Define columns with define_cols()
# - Add data with add_data()
# - Apply cell-level styles with add_style()
# - Format data with c_format()
# (These are not implemented yet in this example phase)

# ============================================================================
# STEP 3: Create Table 2 - Efficacy Analysis (override footer)
# ============================================================================
cat("STEP 3: Creating Table 2 - Efficacy Analysis (Different Footer)\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

# Update footer for secondary analysis tables
tfl_set_options(
  add_footer(c("CONFIDENTIAL", "Efficacy Analysis", "Table 2"))
)

cat("  Footer updated to:\n")
cat("    - CONFIDENTIAL | Efficacy Analysis | Table 2\n")
cat("  ✓ Header remains: ACME Pharmaceuticals | Clinical Data Report | 2024\n")
cat("  ✓ Page format remains: A4 Landscape\n\n")

table2_spec <- tfl_init()

cat("  ✓ Table 2 spec created with updated footer\n")
cat("    - Uses company header and page format\n")
cat("    - Has new footer specific to efficacy data\n\n")

# ============================================================================
# STEP 4: Create Figure 1 - Safety Plot (different page orientation)
# ============================================================================
cat("STEP 4: Creating Figure 1 - Safety Plot (Portrait Orientation)\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

# Update page orientation for figures
tfl_set_options(
  page = tfl_page(
    size = "A4",
    orientation = "portrait"  # Changed from landscape
  ),
  add_header(c("ACME Pharmaceuticals", "Safety Plot", "2024")),
  add_footer(c("CONFIDENTIAL", "Safety Profile", "Figure 1"))
)

cat("  Page orientation changed to Portrait\n")
cat("  ✓ Header updated: ACME Pharmaceuticals | Safety Plot | 2024\n")
cat("  ✓ Footer updated: CONFIDENTIAL | Safety Profile | Figure 1\n\n")

figure1_spec <- tfl_init()

cat("  ✓ Figure 1 spec created with portrait orientation\n")
cat("    - Different page format than tables\n")
cat("    - Specialized header/footer for figures\n\n")

# ============================================================================
# STEP 5: Create Executive Summary (special formatting)
# ============================================================================
cat("STEP 5: Creating Executive Summary (Special Page Format)\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

# Executive summary with Letter size and custom margins
tfl_set_options(
  page = tfl_page(
    size = "Letter",
    orientation = "landscape",
    margins = list(
      top = "1.0in",
      bottom = "1.0in", 
      left = "0.75in",
      right = "0.75in"
    )
  ),
  add_header(c("EXECUTIVE SUMMARY", "", "Clinical Data - 2024")),
  add_footer(c("PROPRIETARY", "Executive Summary", "")),
  add_body_text("Summary data not yet compiled")
)

cat("  Page format changed to Letter with custom margins\n")
cat("  Margins: Top 1.0in | Bottom 1.0in | Left 0.75in | Right 0.75in\n")
cat("  ✓ Header: EXECUTIVE SUMMARY | | Clinical Data - 2024\n")
cat("  ✓ Footer: PROPRIETARY | Executive Summary | \n\n")

exec_summary_spec <- tfl_init()

cat("  ✓ Executive Summary spec created\n")
cat("    - Letter size instead of A4\n")
cat("    - Custom margins for special formatting\n")
cat("    - Executive-specific header/footer\n\n")

# ============================================================================
# STEP 6: Create Listing - Full Dataset Export (default body text changed)
# ============================================================================
cat("STEP 6: Creating Listing - Full Patient Dataset\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

# Reset to simpler format for detailed listings
tfl_set_options(
  page = tfl_page(
    size = "A4",
    orientation = "landscape"
  ),
  add_header(c("ACME Pharmaceuticals", "Patient Listing", "Dataset v1.0")),
  add_footer(c("CONFIDENTIAL", "Listing", "Appendix A")),
  add_body_text("Patient-level data follows")
)

cat("  Reset to standard A4 Landscape\n")
cat("  ✓ Header: ACME Pharmaceuticals | Patient Listing | Dataset v1.0\n")
cat("  ✓ Footer: CONFIDENTIAL | Listing | Appendix A\n")
cat("  ✓ Body text: 'Patient-level data follows'\n\n")

listing_spec <- tfl_init()

cat("  ✓ Listing spec created\n")
cat("    - Standard page format\n")
cat("    - Specialized header/footer for listings\n\n")

# ============================================================================
# STEP 7: View current options at any point
# ============================================================================
cat("STEP 7: Inspecting Current Options\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

current_options <- tfl_get_options()

cat("Current options in effect:\n")
cat("  Headers defined: ", length(current_options$headers), "\n")
cat("  Footers defined: ", length(current_options$footers), "\n")
cat("  Body texts defined: ", length(current_options$bodyText), "\n")
cat("  Page size: ", current_options$page$size, "\n")
cat("  Page orientation: ", current_options$page$orientation, "\n\n")

# Get specific option
page_size <- tfl_get_option("page")
cat("Retrieved specific option (page):\n")
cat("  Size: ", page_size$size, "\n")
cat("  Orientation: ", page_size$orientation, "\n\n")

# ============================================================================
# STEP 8: Reset options for new project
# ============================================================================
cat("STEP 8: Starting New Project (Reset Options)\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

tfl_reset_options()

cat("Options reset to package defaults\n\n")

# Set new defaults for different project
tfl_set_options(
  add_header(c("ABC Research Corp", "Preclinical Study", "2024")),
  add_footer(c("INTERNAL USE", "Study XYZ", "")),
  page = tfl_page(size = "Letter", orientation = "portrait")
)

cat("  ✓ New project defaults established\n")
cat("    - Header: ABC Research Corp | Preclinical Study | 2024\n")
cat("    - Footer: INTERNAL USE | Study XYZ | \n")
cat("    - Format: Letter Portrait\n\n")

study_spec <- tfl_init()

cat("  ✓ Study spec created with new project defaults\n\n")

# ============================================================================
# SUMMARY
# ============================================================================
cat("SUMMARY: END-USER WORKFLOW\n")
cat(strrep("=", 80) %+% "\n\n")

cat("Created 6 TFL specifications:\n")
cat("  1. table1_spec     - Safety Summary (company defaults)\n")
cat("  2. table2_spec     - Efficacy Analysis (custom footer)\n")
cat("  3. figure1_spec    - Safety Plot (portrait format)\n")
cat("  4. exec_summary_spec - Executive Summary (Letter + margins)\n")
cat("  5. listing_spec    - Patient Listing (reset & new format)\n")
cat("  6. study_spec      - New Project Spec (reset + new defaults)\n\n")

cat("Key features demonstrated:\n")
cat("  ✓ Company-wide option defaults\n")
cat("  ✓ Incremental option overrides\n")
cat("  ✓ Multiple specs with different settings\n")
cat("  ✓ Page format variations (landscape/portrait/margins)\n")
cat("  ✓ Header/footer customization per spec\n")
cat("  ✓ Option inspection via tfl_get_option()\n")
cat("  ✓ Option reset for new projects\n")
cat("  ✓ Automatic inheritance of defaults\n\n")

cat("Each spec object is now ready for:\n")
cat("  - Data population and formatting\n")
cat("  - Style application\n")
cat("  - Export to document formats\n\n")

cat(strrep("=", 80) %+% "\n")
cat("✅ END-USER WORKFLOW COMPLETE\n\n")
