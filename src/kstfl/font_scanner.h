// kstfl/font_scanner.h — System font discovery and registry
//
// Scans OS-specific font directories + user-provided directories at package
// load time. Builds a runtime font path map that replaces the old hardcoded
// font_map. Target fonts (Arial, Courier New, Times New Roman, Calibri) are
// resolved from system/user fonts first; only if not found anywhere do we
// fall back to bundled license-free alternatives (Liberation family, Carlito).
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_FONT_SCANNER_H
#define KSTFL_FONT_SCANNER_H

#include <array>
#include <string>
#include <unordered_map>
#include <vector>

namespace kstfl {

/// Full-path map: lowercase family name → [regular, bold, italic, bolditalic].
/// Empty string means that particular style variant was not found.
using FontPathMap = std::unordered_map<std::string, std::array<std::string, 4>>;

/// One entry in the scan report describing a target font resolution.
struct FontResolution {
  std::string target;          // e.g. "Arial"
  std::string resolved_family; // e.g. "Arial" or "Liberation Sans"
  std::string resolved_path;   // path to the regular variant
  bool is_fallback = false;    // true if using a substitute
};

/// Complete scan report returned to R.
struct FontScanReport {
  std::vector<FontResolution> resolutions; // one per target font
  std::vector<std::string> dirs_scanned;   // all directories that were scanned
};

// ---------------------------------------------------------------------------
// Public API (called from Rcpp bindings)
// ---------------------------------------------------------------------------

/// Return platform-specific system font directories.
std::vector<std::string> get_system_font_dirs();

/// Scan all directories, build global font path map, resolve target fonts.
/// @param fallback_dir  Path to bundled inst/fonts/ (always included last).
/// @param extra_dirs    User-provided directories (from ksTFL.font_dirs option).
/// @return FontScanReport with resolution details.
FontScanReport initialize_font_registry(const std::string &fallback_dir, const std::vector<std::string> &extra_dirs);

// ---------------------------------------------------------------------------
// Accessors for the global registry (used by FontCache at render time)
// ---------------------------------------------------------------------------

/// Get the global font path map (populated by initialize_font_registry).
const FontPathMap &get_font_path_map();

/// Get all font directories from the last scan.
const std::vector<std::string> &get_all_font_dirs();

/// Get the fallback family for a target family, or empty if no mapping.
/// Lookups are case-insensitive (input is lowercased internally).
std::string get_fallback_family(const std::string &target_family);

} // namespace kstfl

#endif // KSTFL_FONT_SCANNER_H
