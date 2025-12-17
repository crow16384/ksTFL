# ============================================================================
# END-USER WORKFLOW: Real-World TFL Document Creation
# ============================================================================
# 
# This script demonstrates a practical workflow from the end-user perspective:
# - Setting company/project defaults once
# - Creating multiple TFL specs with different combinations
# - Overriding settings for specific document types
# - Showing actual data with tables
#
# No test framework - just practical usage!

#library(ksTFL)
devtools::load_all()

cat("\n" %+% strrep("=", 80) %+% "\n")
cat("REAL-WORLD END-USER WORKFLOW: TFL Document Creation\n")
cat(strrep("=", 80) %+% "\n\n")

# ============================================================================
# PART 1: COMPANY-LEVEL SETUP (Done Once at Project Start)
# ============================================================================

cat("PART 1: PROJECT SETUP - Company Defaults\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

cat("Setting up company-wide defaults...\n")
cat("These settings will apply to ALL documents created in this project session\n\n")

tfl_set_options(
  add_header(c(
    "ACME Financial Services",
    "Quarterly Business Report",
    "2024"
  )),
  
  add_footer(c(
    "CONFIDENTIAL",
    "Page [1]",
    format(Sys.Date(), "%B %d, %Y")
  )),
  
  # Default page size for all reports
  page = tfl_page(
    size = "Letter",
    orientation = "landscape"
  )
)

cat("✓ Company defaults set:\n")
cat("  - Header: ACME Financial Services | Quarterly Business Report | 2024\n")
cat("  - Footer: CONFIDENTIAL | Page [1] | [Current Date]\n")
cat("  - Page: Letter Landscape\n\n")

# ============================================================================
# PART 2: CREATE DOCUMENT 1 - Sales Analysis Report
# ============================================================================

cat("PART 2: DOCUMENT 1 - Sales Analysis Report\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

# Sample data
sales_data <- data.frame(
  Quarter = c("Q1", "Q2", "Q3", "Q4"),
  Revenue = c(1500000, 1750000, 1950000, 2100000),
  Growth = c(0.00, 0.167, 0.114, 0.077),
  Region = c("North America", "North America", "EMEA", "APAC"),
  Status = c("On Track", "On Track", "Exceeding", "Exceeding")
)

cat("Creating Sales Analysis spec...\n")
sales_spec <- list()
sales_spec <- .fill_spec_defaults(sales_spec)

cat("✓ Sales spec created with company defaults\n")
cat("  - Includes: Company header, footer, and page settings\n\n")

# ============================================================================
# PART 3: CREATE DOCUMENT 2 - Executive Summary (OVERRIDE FORMAT)
# ============================================================================

cat("PART 3: DOCUMENT 2 - Executive Summary (Different Format)\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

cat("For Executive Summary, we need:\n")
cat("  - Different header (Exec Brief title)\n")
cat("  - Portrait orientation (easier reading)\n")
cat("  - Custom margins\n\n")

tfl_set_options(
  add_header(c(
    "EXECUTIVE BRIEF",
    "Key Performance Indicators",
    ""
  )),
  
  page = tfl_page(
    size = "Letter",
    orientation = "portrait",
    margins = list(
      top = "1.0in",
      bottom = "1.0in",
      left = "0.75in",
      right = "0.75in"
    )
  )
)

cat("Creating Executive Summary spec...\n")
exec_spec <- list()
exec_spec <- .fill_spec_defaults(exec_spec)

cat("✓ Executive Summary spec created\n")
cat("  - Header: EXECUTIVE BRIEF | Key Performance Indicators |\n")
cat("  - Page: Letter Portrait with custom margins (1.0\" top/bottom, 0.75\" sides)\n\n")

# ============================================================================
# PART 4: CREATE DOCUMENT 3 - Technical Deep Dive (ANOTHER OVERRIDE)
# ============================================================================

cat("PART 4: DOCUMENT 3 - Technical Deep Dive Report\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

cat("Technical report needs:\n")
cat("  - Detailed data tables (wider pages needed)\n")
cat("  - A4 size for international distribution\n")
cat("  - Alternative header with technical focus\n\n")

tfl_set_options(
  add_header(c(
    "ACME Technical Analysis",
    "System Performance & Architecture Review",
    "Q4 2024"
  )),
  
  page = tfl_page(
    size = "A4",
    orientation = "landscape",
    margins = list(
      top = "20mm",
      bottom = "20mm",
      left = "15mm",
      right = "15mm"
    )
  )
)

cat("Creating Technical Deep Dive spec...\n")
tech_spec <- list()
tech_spec <- .fill_spec_defaults(tech_spec)

cat("✓ Technical Report spec created\n")
cat("  - Header: ACME Technical Analysis | System Performance & Architecture Review | Q4 2024\n")
cat("  - Page: A4 Landscape with tight margins (20mm top/bottom, 15mm sides)\n\n")

# ============================================================================
# PART 5: CREATE DOCUMENT 4 - Financial Report (BACK TO DEFAULTS)
# ============================================================================

cat("PART 5: DOCUMENT 4 - Financial Report (Back to Defaults)\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

cat("For Financial Report, we can use company defaults without changes\n\n")

# Reset to company defaults by creating new spec
tfl_set_options(
  add_header(c(
    "ACME Financial Services",
    "Quarterly Business Report",
    "2024"
  )),
  
  page = tfl_page(
    size = "Letter",
    orientation = "landscape"
  )
)

cat("Creating Financial Report spec...\n")
financial_spec <- list()
financial_spec <- .fill_spec_defaults(financial_spec)

cat("✓ Financial Report spec created\n")
cat("  - Uses company defaults (Letter Landscape)\n\n")

# ============================================================================
# PART 6: CREATE DOCUMENT 5 - Board Meeting Presentation (MINIMAL FORMAT)
# ============================================================================

cat("PART 6: DOCUMENT 5 - Board Meeting Presentation\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

cat("Board meeting format:\n")
cat("  - Very clean header (just logo reference)\n")
cat("  - Legal size (standard for presentations)\n")
cat("  - Extra-wide margins for handwritten notes\n\n")

tfl_set_options(
  add_header(c(
    "ACME",
    "",
    ""
  )),
  
  add_footer(c(
    "",
    "",
    "© 2024 ACME Financial Services"
  )),
  
  page = tfl_page(
    size = "Legal",
    orientation = "landscape",
    margins = list(
      top = "1.5in",
      bottom = "1.5in",
      left = "1.25in",
      right = "1.25in"
    )
  )
)

cat("Creating Board Presentation spec...\n")
board_spec <- list()
board_spec <- .fill_spec_defaults(board_spec)

cat("✓ Board Presentation spec created\n")
cat("  - Header: ACME | | (minimal)\n")
cat("  - Footer: (company copyright)\n")
cat("  - Page: Legal Landscape with wide margins for notes\n\n")

# ============================================================================
# PART 7: DEMONSTRATE SETTINGS STATE
# ============================================================================

cat("PART 7: CURRENT SETTINGS STATE\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

current_settings <- tfl_get_options()

cat("Current Active Settings:\n")
cat("├─ Headers: ", length(current_settings$headers), "\n")
if (length(current_settings$headers) > 0) {
  for (i in seq_along(current_settings$headers)) {
    cat("|  └─ Header ", i, ": ", 
        paste(current_settings$headers[[i]], collapse=" | "), "\n", sep="")
  }
}

cat("├─ Footers: ", length(current_settings$footers), "\n")
if (length(current_settings$footers) > 0) {
  for (i in seq_along(current_settings$footers)) {
    cat("|  └─ Footer ", i, ": ", 
        paste(current_settings$footers[[i]], collapse=" | "), "\n", sep="")
  }
}

cat("├─ Page:\n")
cat("|  ├─ Size: ", current_settings$page$size, "\n")
cat("|  ├─ Orientation: ", current_settings$page$orientation, "\n")
if (!is.null(current_settings$page$margins)) {
  cat("|  └─ Margins:\n")
  cat("|     ├─ Top: ", current_settings$page$margins$top, "\n")
  cat("|     ├─ Bottom: ", current_settings$page$margins$bottom, "\n")
  cat("|     ├─ Left: ", current_settings$page$margins$left, "\n")
  cat("|     └─ Right: ", current_settings$page$margins$right, "\n")
}
cat("\n")

# ============================================================================
# PART 8: RESET AND VERIFY FRESH START
# ============================================================================

cat("PART 8: RESET FOR NEW PROJECT\n")
cat("-" %+% strrep("-", 78) %+% "\n\n")

cat("Resetting to clean state...\n")
tfl_reset_options()

cat("✓ Settings reset to defaults\n")
cat("  - Ready to start new project with clean settings\n\n")

# ============================================================================
# SUMMARY
# ============================================================================

cat("SUMMARY: END-USER WORKFLOW\n")
cat(strrep("=", 80) %+% "\n\n")

cat("Documents created with different settings combinations:\n\n")

cat("1. SALES ANALYSIS REPORT\n")
cat("   └─ Used company defaults\n")
cat("      └─ Letter Landscape | Company header/footer\n\n")

cat("2. EXECUTIVE SUMMARY\n")
cat("   └─ Custom format\n")
cat("      └─ Letter Portrait | Custom header | Custom margins\n\n")

cat("3. TECHNICAL DEEP DIVE\n")
cat("   └─ International format\n")
cat("      └─ A4 Landscape | Technical header | Tight margins (metric)\n\n")

cat("4. FINANCIAL REPORT\n")
cat("   └─ Back to defaults\n")
cat("      └─ Letter Landscape | Company header/footer\n\n")

cat("5. BOARD PRESENTATION\n")
cat("   └─ Presentation format\n")
cat("      └─ Legal Landscape | Minimal header | Wide margins for notes\n\n")

cat("KEY OBSERVATIONS:\n")
cat("✓ Settings persist across multiple spec creations\n")
cat("✓ Calling tfl_set_options() REPLACES previous settings\n")
cat("✓ Each document can have its own customized format\n")
cat("✓ Easy to switch between formats mid-session\n")
cat("✓ Reset functionality provides clean slate\n\n")

cat(strrep("=", 80) %+% "\n")
cat("\n✅ END-USER WORKFLOW DEMONSTRATION COMPLETE\n\n")

cat("INTERACTIVE EXPLORATION:\n")
cat("Try these commands to explore:\n\n")
cat("  # View current settings\n")
cat("  tfl_get_options()\n\n")

cat("  # Change a specific setting\n")
cat("  tfl_set_options(add_header(c('New Header', '', '')))\n\n")

cat("  # Create a spec with custom page\n")
cat("  my_spec <- list()\n")
cat("  my_spec <- .fill_spec_defaults(my_spec)\n\n")

cat("  # Reset to defaults\n")
cat("  tfl_reset_options()\n\n")
