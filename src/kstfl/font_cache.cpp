// kstfl/font_cache.cpp — FreeType + HarfBuzz font loading and caching
//
// Font loading uses fonts discovered by the font scanner at package load time.
// System-installed fonts are preferred; if a requested font is not found,
// the scanner's fallback assignment is used (e.g., Calibri → Carlito).
// Last-resort fallback is always Liberation Sans (bundled in inst/fonts/).
// Metrics are computed from the OS/2 table (usWinAscent / usWinDescent)
// to match Microsoft Word's line height calculation.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "font_cache.h"
#include "font_scanner.h"
#include "types.h"

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_TRUETYPE_TABLES_H
#include <hb-ft.h>
#include <hb.h>

#include <Rcpp.h>
#include <algorithm>
#include <array>
#include <cctype>
#include <filesystem>
#include <format>
#include <ranges>
#include <string>
#include <unordered_map>

namespace fs = std::filesystem;

namespace kstfl {

// ---------------------------------------------------------------------------
// Fallback font name (LiberationSans — always bundled in inst/fonts/)
// ---------------------------------------------------------------------------

static const std::string FALLBACK_FONT_NAME = "Liberation Sans";

// ---------------------------------------------------------------------------
// Ctor / Dtor
// ---------------------------------------------------------------------------

FontCache::FontCache() {
  FT_Error err = FT_Init_FreeType(&ft_library_);
  if (err) { throw RenderError(std::format("Failed to initialize FreeType library (error {})", err)); }
}

FontCache::~FontCache() {
  // Destroy HarfBuzz fonts and FreeType faces
  for (auto &[key, face] : face_cache_) {
    if (face.hb_font) hb_font_destroy(face.hb_font);
    if (face.ft_face) FT_Done_Face(face.ft_face);
  }
  face_cache_.clear();
  if (ft_library_) {
    FT_Done_FreeType(ft_library_);
    ft_library_ = nullptr;
  }
}

// ---------------------------------------------------------------------------
// Font directory management
// ---------------------------------------------------------------------------

void FontCache::add_font_dir(const std::string &dir) {
  if (fs::exists(dir) && fs::is_directory(dir)) {
    font_dirs_.push_back(dir);
    // Build index: lowercase stem → full path
    try {
      for (const auto &entry : fs::recursive_directory_iterator(dir, fs::directory_options::skip_permission_denied)) {
        if (!entry.is_regular_file()) continue;
        std::string ext = entry.path().extension().string();
        std::ranges::transform(ext, ext.begin(), [](unsigned char c) { return std::tolower(c); });
        if (ext != ".ttf" && ext != ".otf" && ext != ".ttc") continue;
        std::string stem = entry.path().stem().string();
        std::string stem_lower;
        stem_lower.reserve(stem.size());
        for (unsigned char c : stem)
          stem_lower.push_back(static_cast<char>(std::tolower(c)));
        font_index_.try_emplace(std::move(stem_lower), entry.path().string());
      }
    } catch (const fs::filesystem_error &) {
      // Skip inaccessible directories
    }
  }
}

// ---------------------------------------------------------------------------
// Font file finding (recursive directory search)
// ---------------------------------------------------------------------------

/// Look up a font path from the global font path map (populated by font scanner).
/// Returns the full path for the requested family+style, or empty string.
static std::string lookup_in_path_map(const std::string &name, bool bold, bool italic) {
  std::string lower;
  lower.reserve(name.size());
  for (unsigned char c : name)
    lower.push_back(static_cast<char>(std::tolower(c)));

  const auto &path_map = get_font_path_map();
  auto it = path_map.find(lower);
  if (it == path_map.end()) return "";

  int idx = (bold ? 1 : 0) | (italic ? 2 : 0);
  return it->second[idx];
}

/// Stem-based fallback hint for the font_index_ built by add_font_dir().
static std::string font_name_to_stem_hint(const std::string &name, bool bold, bool italic) {
  std::string lower;
  lower.reserve(name.size());
  for (unsigned char c : name)
    lower.push_back(static_cast<char>(std::tolower(c)));

  static constexpr std::array<const char *, 4> suffixes = {"", "bd", "i", "bi"};
  int idx = (bold ? 1 : 0) | (italic ? 2 : 0);
  return lower + suffixes[idx];
}

std::string FontCache::find_font_file(const FaceKey &key) const {
  // 1. Check global font path map (populated at package load by font scanner)
  std::string path = lookup_in_path_map(key.name, key.bold, key.italic);
  if (!path.empty()) return path;

  // 2. Fall back to stem-based lookup in per-render font_index_
  // font_name_to_stem_hint() already returns a lowercase string,
  // so no additional lowering is needed.
  std::string hint = font_name_to_stem_hint(key.name, key.bold, key.italic);

  auto it = font_index_.find(hint);
  if (it != font_index_.end()) return it->second;

  return ""; // not found
}

// ---------------------------------------------------------------------------
// Face loading
// ---------------------------------------------------------------------------

CachedFace FontCache::load_face(const std::string &path) const {
  CachedFace face;
  face.file_path = path;

  FT_Error err = FT_New_Face(ft_library_, path.c_str(), 0, &face.ft_face);
  if (err) { throw RenderError(std::format("Failed to load font face from '{}' (FreeType error {})", path, err)); }

  // Create HarfBuzz font from FreeType face.
  // Guard with try/catch to ensure FT_Done_Face() on any exception,
  // not just the null-return case.
  try {
    face.hb_font = hb_ft_font_create_referenced(face.ft_face);
  } catch (...) {
    FT_Done_Face(face.ft_face);
    throw;
  }
  if (!face.hb_font) {
    FT_Done_Face(face.ft_face);
    throw RenderError(std::format("Failed to create HarfBuzz font from '{}'", path));
  }

  return face;
}

// ---------------------------------------------------------------------------
// Public: get_face
// ---------------------------------------------------------------------------

const CachedFace &FontCache::get_face(const FaceKey &key) {
  // Check cache
  auto it = face_cache_.find(key);
  if (it != face_cache_.end()) return it->second;

  // Try to find the exact font
  std::string path = find_font_file(key);

  if (path.empty() && (key.bold || key.italic)) {
    // Try without bold/italic as a secondary attempt for the same font
    FaceKey plain_key{key.name, false, false};
    path = find_font_file(plain_key);
  }

  if (path.empty() && key.name != FALLBACK_FONT_NAME) {
    // Try the designated fallback for this font (e.g., Calibri → Carlito)
    std::string fb_family = get_fallback_family(key.name);
    if (!fb_family.empty()) {
      FaceKey fb_key{fb_family, key.bold, key.italic};
      path = find_font_file(fb_key);
      if (path.empty() && (key.bold || key.italic)) {
        FaceKey fb_plain{fb_family, false, false};
        path = find_font_file(fb_plain);
      }
      if (!path.empty()) {
        Rcpp::Rcerr << "[ksTFL] INFO: Font '" << key.name << "' not found. Using " << fb_family << " (fallback).\n";
      }
    }
  }

  if (path.empty() && key.name != FALLBACK_FONT_NAME) {
    // Last resort: Liberation Sans
    Rcpp::Rcerr << "[ksTFL] WARNING: Font '" << key.name << "' not found. Falling back to " << FALLBACK_FONT_NAME
                << ".\n";
    FaceKey fallback_key{FALLBACK_FONT_NAME, key.bold, key.italic};
    path = find_font_file(fallback_key);

    if (path.empty() && (key.bold || key.italic)) {
      FaceKey fallback_plain{FALLBACK_FONT_NAME, false, false};
      path = find_font_file(fallback_plain);
    }
  }

  if (path.empty()) {
    throw RenderError(std::format("Font not found: '{}' (bold={}, italic={}). "
                                  "No matching font found and LiberationSans "
                                  "fallback also not found.",
                                  key.name, key.bold, key.italic));
  }

  CachedFace face = load_face(path);
  auto [ins_it, inserted] = face_cache_.emplace(key, std::move(face));
  return ins_it->second;
}

// ---------------------------------------------------------------------------
// Public: get_metrics
// ---------------------------------------------------------------------------

FontMetrics FontCache::get_metrics(const FaceKey &key, double size_pt) {
  MetricsKey mk{key, size_pt};
  auto it = metrics_cache_.find(mk);
  if (it != metrics_cache_.end()) return it->second;

  const CachedFace &face = get_face(key);

  // Set FreeType char size (size in 1/64 points)
  FT_Error ft_err = FT_Set_Char_Size(face.ft_face, 0, static_cast<FT_F26Dot6>(size_pt * 64.0), 72, 72); // 72 DPI
  if (ft_err) {
    throw RenderError(std::format("FT_Set_Char_Size failed for font '{}' at size {}pt", key.name, size_pt));
  }

  FontMetrics m;
  m.units_per_em = static_cast<double>(face.ft_face->units_per_EM);
  double scale = size_pt / m.units_per_em;

  // Use OS/2 table metrics (usWinAscent / usWinDescent) to match
  // Microsoft Word's line height calculation. Word uses these values
  // for single-spaced text layout, not the hhea table metrics that
  // FreeType's face->ascender / face->descender provide.
  TT_OS2 *os2 = static_cast<TT_OS2 *>(FT_Get_Sfnt_Table(face.ft_face, FT_SFNT_OS2));
  if (os2) {
    m.ascent = static_cast<double>(os2->usWinAscent) * scale;
    m.descent = static_cast<double>(os2->usWinDescent) * scale;
  } else {
    // Fallback to hhea metrics if OS/2 table not available
    m.ascent = static_cast<double>(face.ft_face->ascender) * scale;
    m.descent = -static_cast<double>(face.ft_face->descender) * scale;
  }
  m.line_height = m.ascent + m.descent;

  metrics_cache_[mk] = m;
  return m;
}

// ---------------------------------------------------------------------------
// Public: get_hb_font (at specific size)
// ---------------------------------------------------------------------------

hb_font_t *FontCache::get_hb_font(const FaceKey &key, double size_pt) {
  const CachedFace &face = get_face(key);
  // Set size for proper shaping
  FT_Error ft_err = FT_Set_Char_Size(face.ft_face, 0, static_cast<FT_F26Dot6>(size_pt * 64.0), 72, 72);
  if (ft_err) {
    throw RenderError(std::format("FT_Set_Char_Size failed for font '{}' at size {}pt", key.name, size_pt));
  }
  hb_ft_font_changed(face.hb_font);
  return face.hb_font;
}

} // namespace kstfl
