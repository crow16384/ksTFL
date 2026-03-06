// kstfl/font_cache.cpp — FreeType + HarfBuzz font loading and caching
//
// Font loading uses ONLY fonts from inst/fonts/ (bundled with the package).
// No system fonts are used. If a requested font is not found, LiberationSans
// is used as fallback. Metrics are computed from the OS/2 table
// (usWinAscent / usWinDescent) to match Microsoft Word's line height
// calculation.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "font_cache.h"
#include "types.h"

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_TRUETYPE_TABLES_H
#include <hb.h>
#include <hb-ft.h>

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <Rcpp.h>

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
    if (err) {
        throw RenderError("Failed to initialize FreeType library (error " +
                          std::to_string(err) + ")");
    }
}

FontCache::~FontCache() {
    // Destroy HarfBuzz fonts and FreeType faces
    for (auto& [key, face] : face_cache_) {
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

void FontCache::add_font_dir(const std::string& dir) {
    if (fs::exists(dir) && fs::is_directory(dir)) {
        font_dirs_.push_back(dir);
    }
}

// ---------------------------------------------------------------------------
// Font file finding (recursive directory search)
// ---------------------------------------------------------------------------

/// Map common font names to typical filenames (case-insensitive).
static std::string font_name_to_filename_hint(const std::string& name, bool bold, bool italic) {
    std::string lower;
    for (char c : name)
        lower += static_cast<char>(std::tolower(static_cast<unsigned char>(c)));

    // Build expected filename patterns
    std::string suffix;
    if (bold && italic) suffix = "bi";
    else if (bold) suffix = "bd";
    else if (italic) suffix = "i";

    // Common mappings (filenames match inst/fonts/ bundled files)
    if (lower == "courier new") return bold && italic ? "courbi" : bold ? "courb" : italic ? "couri" : "cour";
    if (lower == "arial") return bold && italic ? "arialbi" : bold ? "arialb" : italic ? "ariali" : "arial";
    if (lower == "times new roman") return bold && italic ? "timesbi" : bold ? "timesbd" : italic ? "timesi" : "times";
    if (lower == "calibri") return bold && italic ? "calibriz" : bold ? "calibrib" : italic ? "calibrii" : "calibri";
    if (lower == "liberation sans") return bold && italic ? "LiberationSans-BoldItalic" : bold ? "LiberationSans-Bold" : italic ? "LiberationSans-Italic" : "LiberationSans-Regular";
    if (lower == "dejavu sans") return bold && italic ? "DejaVuSans-BoldOblique" : bold ? "DejaVuSans-Bold" : italic ? "DejaVuSans-Oblique" : "DejaVuSans";

    return lower + suffix;
}

std::string FontCache::find_font_file(const FaceKey& key) const {
    std::string hint = font_name_to_filename_hint(key.name, key.bold, key.italic);
    std::string hint_lower = hint;
    std::transform(hint_lower.begin(), hint_lower.end(), hint_lower.begin(),
                   [](unsigned char c) { return std::tolower(c); });

    // Search all font directories recursively
    for (const auto& dir : font_dirs_) {
        try {
            for (const auto& entry : fs::recursive_directory_iterator(dir,
                 fs::directory_options::skip_permission_denied)) {
                if (!entry.is_regular_file()) continue;
                std::string ext = entry.path().extension().string();
                std::transform(ext.begin(), ext.end(), ext.begin(),
                               [](unsigned char c) { return std::tolower(c); });
                if (ext != ".ttf" && ext != ".otf" && ext != ".ttc") continue;

                std::string stem = entry.path().stem().string();
                std::string stem_lower = stem;
                std::transform(stem_lower.begin(), stem_lower.end(), stem_lower.begin(),
                               [](unsigned char c) { return std::tolower(c); });

                if (stem_lower == hint_lower) {
                    return entry.path().string();
                }
            }
        } catch (const fs::filesystem_error&) {
            // Skip inaccessible directories
        }
    }

    return "";  // not found
}

// ---------------------------------------------------------------------------
// Face loading
// ---------------------------------------------------------------------------

CachedFace FontCache::load_face(const std::string& path) const {
    CachedFace face;
    face.file_path = path;

    FT_Error err = FT_New_Face(ft_library_, path.c_str(), 0, &face.ft_face);
    if (err) {
        throw RenderError("Failed to load font face from '" + path + "' (FreeType error " +
                          std::to_string(err) + ")");
    }

    // Create HarfBuzz font from FreeType face
    face.hb_font = hb_ft_font_create_referenced(face.ft_face);
    if (!face.hb_font) {
        FT_Done_Face(face.ft_face);
        throw RenderError("Failed to create HarfBuzz font from '" + path + "'");
    }

    return face;
}

// ---------------------------------------------------------------------------
// Public: get_face
// ---------------------------------------------------------------------------

const CachedFace& FontCache::get_face(const FaceKey& key) {
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
        // Fallback to LiberationSans with matching style
        Rcpp::Rcerr << "[ksTFL] WARNING: Font '" << key.name
                  << "' not found in inst/fonts/. Falling back to "
                  << FALLBACK_FONT_NAME << ".\n";
        FaceKey fallback_key{FALLBACK_FONT_NAME, key.bold, key.italic};
        path = find_font_file(fallback_key);

        if (path.empty() && (key.bold || key.italic)) {
            // Try plain LiberationSans
            FaceKey fallback_plain{FALLBACK_FONT_NAME, false, false};
            path = find_font_file(fallback_plain);
        }
    }

    if (path.empty()) {
        throw RenderError("Font not found: '" + key.name + "' (bold=" +
                          (key.bold ? "true" : "false") + ", italic=" +
                          (key.italic ? "true" : "false") + "). "
                          "No matching font in inst/fonts/ and LiberationSans fallback also not found.");
    }

    CachedFace face = load_face(path);
    auto [ins_it, inserted] = face_cache_.emplace(key, std::move(face));
    return ins_it->second;
}

// ---------------------------------------------------------------------------
// Public: get_metrics
// ---------------------------------------------------------------------------

FontMetrics FontCache::get_metrics(const FaceKey& key, double size_pt) {
    MetricsKey mk{key, size_pt};
    auto it = metrics_cache_.find(mk);
    if (it != metrics_cache_.end()) return it->second;

    const CachedFace& face = get_face(key);

    // Set FreeType char size (size in 1/64 points)
    FT_Error ft_err = FT_Set_Char_Size(face.ft_face, 0,
                     static_cast<FT_F26Dot6>(size_pt * 64.0),
                     72, 72);  // 72 DPI
    if (ft_err) {
        throw RenderError("FT_Set_Char_Size failed for font '" + key.name +
                          "' at size " + std::to_string(size_pt) + "pt");
    }

    FontMetrics m;
    m.units_per_em = static_cast<double>(face.ft_face->units_per_EM);
    double scale = size_pt / m.units_per_em;

    // Use OS/2 table metrics (usWinAscent / usWinDescent) to match
    // Microsoft Word's line height calculation. Word uses these values
    // for single-spaced text layout, not the hhea table metrics that
    // FreeType's face->ascender / face->descender provide.
    TT_OS2* os2 = static_cast<TT_OS2*>(
        FT_Get_Sfnt_Table(face.ft_face, FT_SFNT_OS2));
    if (os2) {
        m.ascent  = static_cast<double>(os2->usWinAscent)  * scale;
        m.descent = static_cast<double>(os2->usWinDescent) * scale;
    } else {
        // Fallback to hhea metrics if OS/2 table not available
        m.ascent  =  static_cast<double>(face.ft_face->ascender)  * scale;
        m.descent = -static_cast<double>(face.ft_face->descender) * scale;
    }
    m.line_height = m.ascent + m.descent;

    metrics_cache_[mk] = m;
    return m;
}

// ---------------------------------------------------------------------------
// Public: get_hb_font (at specific size)
// ---------------------------------------------------------------------------

hb_font_t* FontCache::get_hb_font(const FaceKey& key, double size_pt) {
    const CachedFace& face = get_face(key);
    // Set size for proper shaping
    FT_Error ft_err = FT_Set_Char_Size(face.ft_face, 0,
                     static_cast<FT_F26Dot6>(size_pt * 64.0),
                     72, 72);
    if (ft_err) {
        throw RenderError("FT_Set_Char_Size failed for font '" + key.name +
                          "' at size " + std::to_string(size_pt) + "pt");
    }
    hb_ft_font_changed(face.hb_font);
    return face.hb_font;
}

}  // namespace kstfl
