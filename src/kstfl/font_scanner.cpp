// kstfl/font_scanner.cpp — System font discovery and registry implementation
//
// Scans platform-specific font directories with FreeType to discover installed
// fonts. Resolves target fonts (Arial, Courier New, Times New Roman, Georgia,
// Verdana, Trebuchet MS) against the full scan results: system/user fonts
// always win over bundled fallbacks.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "font_scanner.h"

#include <ft2build.h>
#include FT_FREETYPE_H

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <mutex>
#include <shared_mutex>
#include <string>

#ifdef _WIN32
#include <windows.h>
#include <shlobj.h>
#endif

namespace fs = std::filesystem;

namespace kstfl {

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static std::string to_lower(const std::string &s) {
  std::string out;
  out.reserve(s.size());
  for (unsigned char c : s)
    out.push_back(static_cast<char>(std::tolower(c)));
  return out;
}

// ---------------------------------------------------------------------------
// Target → fallback mapping
// ---------------------------------------------------------------------------

struct TargetFallback {
  std::string target;       // canonical family name (mixed case)
  std::string target_lower; // pre-lowered for fast comparison
  std::string fallback;     // fallback family name
};

static const std::vector<TargetFallback> &target_fallbacks() {
  static const std::vector<TargetFallback> map = {
      {"Arial", "arial", "Liberation Sans"},
      {"Times New Roman", "times new roman", "Liberation Serif"},
      {"Courier New", "courier new", "Liberation Mono"},
      {"Georgia", "georgia", "Liberation Serif"},
      {"Verdana", "verdana", "Liberation Sans"},
      {"Trebuchet MS", "trebuchet ms", "Liberation Sans"},
  };
  return map;
}

// ---------------------------------------------------------------------------
// Global state (populated by initialize_font_registry, read by FontCache).
// Protected by a reader/writer lock: accessors take a shared lock and return
// copies so that the registry may be safely re-initialized via
// `tfl_rescan_fonts()` while other threads read.
// ---------------------------------------------------------------------------

static std::shared_mutex g_mutex;
static FontPathMap g_font_path_map;
static std::vector<std::string> g_all_font_dirs;

FontPathMap get_font_path_map() {
  std::shared_lock<std::shared_mutex> lock(g_mutex);
  return g_font_path_map;
}
std::vector<std::string> get_all_font_dirs() {
  std::shared_lock<std::shared_mutex> lock(g_mutex);
  return g_all_font_dirs;
}

std::string get_fallback_family(const std::string &target_family) {
  std::string lower = to_lower(target_family);
  for (const auto &tf : target_fallbacks()) {
    if (tf.target_lower == lower) return tf.fallback;
  }
  return {};
}

// ---------------------------------------------------------------------------
// Platform-specific system font directories
// ---------------------------------------------------------------------------

std::vector<std::string> get_system_font_dirs() {
  std::vector<std::string> dirs;

#if defined(_WIN32)
  // Windows system fonts directory
  {
    char win_dir[MAX_PATH];
    if (GetWindowsDirectoryA(win_dir, MAX_PATH)) { dirs.push_back(std::string(win_dir) + "\\Fonts"); }
  }
  // Per-user fonts (Windows 10+)
  {
    char local_app[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathA(NULL, CSIDL_LOCAL_APPDATA, NULL, 0, local_app))) {
      dirs.push_back(std::string(local_app) + "\\Microsoft\\Windows\\Fonts");
    }
  }

#elif defined(__APPLE__)
  dirs.push_back("/System/Library/Fonts");
  dirs.push_back("/System/Library/Fonts/Supplemental");
  dirs.push_back("/Library/Fonts");
  // User fonts
  const char *home = std::getenv("HOME");
  if (home) { dirs.push_back(std::string(home) + "/Library/Fonts"); }

#else
  // Linux / other Unix
  dirs.push_back("/usr/share/fonts");
  dirs.push_back("/usr/local/share/fonts");
  const char *home = std::getenv("HOME");
  if (home) {
    dirs.push_back(std::string(home) + "/.local/share/fonts");
    dirs.push_back(std::string(home) + "/.fonts");
  }
  // XDG data dirs may contain fonts too
  const char *xdg = std::getenv("XDG_DATA_DIRS");
  if (xdg) {
    std::string xdg_str(xdg);
    size_t pos = 0;
    while (pos < xdg_str.size()) {
      size_t colon = xdg_str.find(':', pos);
      std::string dir = xdg_str.substr(pos, colon - pos);
      if (!dir.empty()) {
        std::string font_dir = dir + "/fonts";
        // Avoid duplicating /usr/share/fonts etc.
        if (std::find(dirs.begin(), dirs.end(), font_dir) == dirs.end()) { dirs.push_back(font_dir); }
      }
      if (colon == std::string::npos) break;
      pos = colon + 1;
    }
  }
#endif

  return dirs;
}

// ---------------------------------------------------------------------------
// FreeType-based font directory scanning
// ---------------------------------------------------------------------------

/// Scan a single directory recursively, add discovered fonts to `out`.
static void scan_one_dir(const std::string &dir, FT_Library ft_lib, FontPathMap &out) {
  if (!fs::exists(dir) || !fs::is_directory(dir)) return;

  try {
    for (const auto &entry : fs::recursive_directory_iterator(dir, fs::directory_options::skip_permission_denied)) {
      if (!entry.is_regular_file()) continue;

      std::string ext = to_lower(entry.path().extension().string());
      if (ext != ".ttf" && ext != ".otf" && ext != ".ttc") continue;

      std::string path = entry.path().string();
      FT_Face face = nullptr;
      FT_Error err = FT_New_Face(ft_lib, path.c_str(), 0, &face);
      if (err || !face) continue;

      long num_faces = face->num_faces;
      FT_Done_Face(face);

      for (long fi = 0; fi < num_faces; ++fi) {
        face = nullptr;
        err = FT_New_Face(ft_lib, path.c_str(), fi, &face);
        if (err || !face) continue;

        if (face->family_name) {
          std::string family = to_lower(face->family_name);
          // style index: 0=regular, 1=bold, 2=italic, 3=bold+italic
          int idx = 0;
          if (face->style_flags & FT_STYLE_FLAG_BOLD) idx |= 1;
          if (face->style_flags & FT_STYLE_FLAG_ITALIC) idx |= 2;

          auto &slots = out[family];
          // Record font — later entries overwrite earlier ones,
          // so scanning system dirs first then bundled means system wins.
          // But we actually want ANY match, so only fill empty slots.
          if (slots[idx].empty()) { slots[idx] = path; }
        }
        FT_Done_Face(face);
      }
    }
  } catch (const fs::filesystem_error &) {
    // Skip inaccessible directories silently
  }
}

// ---------------------------------------------------------------------------
// Public: initialize_font_registry
// ---------------------------------------------------------------------------

FontScanReport initialize_font_registry(const std::string &fallback_dir, const std::vector<std::string> &extra_dirs) {
  std::unique_lock<std::shared_mutex> lock(g_mutex);

  // Clear previous state
  g_font_path_map.clear();
  g_all_font_dirs.clear();

  // Collect all directories to scan:
  //   1. System font dirs
  //   2. User-provided extra dirs (from ksTFL.font_dirs option)
  //   3. Bundled fallback dir (inst/fonts/) — scanned last
  std::vector<std::string> all_dirs = get_system_font_dirs();
  for (const auto &d : extra_dirs) {
    if (!d.empty()) all_dirs.push_back(d);
  }
  if (!fallback_dir.empty()) { all_dirs.push_back(fallback_dir); }
  g_all_font_dirs = all_dirs;

  // Initialize FreeType for scanning
  FT_Library ft_lib = nullptr;
  FT_Error ft_err = FT_Init_FreeType(&ft_lib);
  if (ft_err) {
    // Can't scan — return empty report
    FontScanReport report;
    report.dirs_scanned = all_dirs;
    return report;
  }

  // Scan ALL directories — system dirs first, bundled last.
  // scan_one_dir fills empty slots only, so the first directory that
  // provides a family+style wins. Since system dirs come first, a
  // system-installed "Arial Regular" is always preferred over a bundled
  // fallback with the same family name.
  FontPathMap full_map;
  for (const auto &dir : all_dirs) {
    scan_one_dir(dir, ft_lib, full_map);
  }

  FT_Done_FreeType(ft_lib);
  g_font_path_map = full_map;

  // Resolve target fonts
  FontScanReport report;
  report.dirs_scanned = all_dirs;

  for (const auto &tf : target_fallbacks()) {
    FontResolution res;
    res.target = tf.target;
    std::string target_lower = to_lower(tf.target);

    auto it = full_map.find(target_lower);
    if (it != full_map.end() && !it->second[0].empty()) {
      // Target font found on the system (regular variant exists)
      res.resolved_family = tf.target;
      res.resolved_path = it->second[0];
      res.is_fallback = false;
    } else {
      // Target not found — try designated fallback
      std::string fb_lower = to_lower(tf.fallback);
      auto fb_it = full_map.find(fb_lower);
      if (fb_it != full_map.end() && !fb_it->second[0].empty()) {
        res.resolved_family = tf.fallback;
        res.resolved_path = fb_it->second[0];
        res.is_fallback = true;
      } else {
        // Last resort: Liberation Sans (always bundled)
        auto ls_it = full_map.find("liberation sans");
        if (ls_it != full_map.end() && !ls_it->second[0].empty()) {
          res.resolved_family = "Liberation Sans";
          res.resolved_path = ls_it->second[0];
          res.is_fallback = true;
        } else {
          res.resolved_family = "";
          res.resolved_path = "";
          res.is_fallback = true;
        }
      }
    }
    report.resolutions.push_back(std::move(res));
  }

  return report;
}

} // namespace kstfl
