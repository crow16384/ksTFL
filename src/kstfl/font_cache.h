// kstfl/font_cache.h — FreeType face loading + HarfBuzz font creation + caching
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#ifndef KSTFL_FONT_CACHE_H
#define KSTFL_FONT_CACHE_H

#include "types.h"
#include <string>
#include <unordered_map>
#include <memory>
#include <vector>
#include <tuple>

// Forward-declare external types to avoid header pollution
typedef struct FT_LibraryRec_* FT_Library;
typedef struct FT_FaceRec_* FT_Face;
typedef struct hb_font_t hb_font_t;

namespace kstfl {

/// Key for face cache: (font_name, bold, italic).
struct FaceKey {
    std::string name;
    bool bold = false;
    bool italic = false;

    bool operator==(const FaceKey& other) const {
        return name == other.name && bold == other.bold && italic == other.italic;
    }
};

/// Hash for FaceKey.
struct FaceKeyHash {
    size_t operator()(const FaceKey& k) const {
        size_t h = std::hash<std::string>()(k.name);
        h ^= std::hash<bool>()(k.bold) << 1;
        h ^= std::hash<bool>()(k.italic) << 2;
        return h;
    }
};

/// Cached face entry.
struct CachedFace {
    FT_Face ft_face = nullptr;
    hb_font_t* hb_font = nullptr;
    std::string file_path;
};

/// Font metrics for a specific face at a specific size.
struct FontMetrics {
    double ascent = 0.0;    // in pt
    double descent = 0.0;   // in pt (positive)
    double line_height = 0.0; // ascent + descent
    double units_per_em = 0.0;
};

/// Key for metrics cache: face key + size.
struct MetricsKey {
    FaceKey face_key;
    double size_pt = 0.0;

    bool operator==(const MetricsKey& other) const {
        return face_key == other.face_key && size_pt == other.size_pt;
    }
};

struct MetricsKeyHash {
    size_t operator()(const MetricsKey& k) const {
        size_t h = FaceKeyHash()(k.face_key);
        h ^= std::hash<double>()(k.size_pt) << 3;
        return h;
    }
};

/// Font cache: manages FreeType faces and HarfBuzz fonts.
class FontCache {
public:
    FontCache();
    ~FontCache();

    // Non-copyable
    FontCache(const FontCache&) = delete;
    FontCache& operator=(const FontCache&) = delete;

    /// Add a directory to search for font files.
    void add_font_dir(const std::string& dir);

    /// Get or create a FreeType face + HarfBuzz font for the given key.
    /// Searches font directories and falls back to LiberationSans if not found.
    const CachedFace& get_face(const FaceKey& key);

    /// Get font metrics for a face at a given size.
    /// Uses OS/2 table (usWinAscent/usWinDescent) to match Word's metrics.
    FontMetrics get_metrics(const FaceKey& key, double size_pt);

    /// Get HarfBuzz font for shaping at a given size.
    hb_font_t* get_hb_font(const FaceKey& key, double size_pt);

private:
    /// Try to find a font file matching the key.
    std::string find_font_file(const FaceKey& key) const;

    /// Load a font from file.
    CachedFace load_face(const std::string& path) const;

    FT_Library ft_library_ = nullptr;
    std::vector<std::string> font_dirs_;
    std::unordered_map<FaceKey, CachedFace, FaceKeyHash> face_cache_;
    std::unordered_map<MetricsKey, FontMetrics, MetricsKeyHash> metrics_cache_;
};

}  // namespace kstfl

#endif  // KSTFL_FONT_CACHE_H
