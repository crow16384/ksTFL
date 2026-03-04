// kstfl/text_measurer.h — HarfBuzz-based text measurement + wrapping
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_TEXT_MEASURER_H
#define KSTFL_TEXT_MEASURER_H

#include "types.h"
#include "font_cache.h"
#include <string_view>

struct hb_buffer_t;

namespace kstfl {

/// Result of measuring a text block.
struct MeasuredText {
    Length width;           // Maximum line width used
    Length height;          // Total height including spacing
    int line_count = 0;    // Number of wrapped lines
};

/// Measures text for layout using HarfBuzz shaping.
class TextMeasurer {
public:
    explicit TextMeasurer(FontCache& cache);
    ~TextMeasurer();

    TextMeasurer(const TextMeasurer&) = delete;
    TextMeasurer& operator=(const TextMeasurer&) = delete;

    /// Measure a single cell's text content within a given available width.
    /// Applies word wrapping, paragraph spacing, and line spacing.
    /// @param parsed  Parsed cell content (paragraphs + runs).
    /// @param style   Effective style for the cell.
    /// @param max_width  Available cell width (column width minus cell margins).
    MeasuredText measure_cell(const ParsedCell& parsed,
                              const StyleDef& style,
                              Length max_width) const;

    /// Measure a plain text string (no inline markup).
    MeasuredText measure_plain(const std::string& text,
                               const StyleDef& style,
                               Length max_width) const;

    /// Measure the width of a single text run (no wrapping).
    Length measure_run_width(std::string_view text,
                            const FontProps& font,
                            const InlineRunStyle& run_style = {}) const;

    /// Get the line height for a given font + size.
    Length line_height(const FontProps& font, double line_spacing_mult = 1.0) const;

private:
    FontCache& cache_;
    mutable hb_buffer_t* hb_buf_;

    /// Get effective font size (handling superscript/subscript scaling).
    double effective_font_size(const FontProps& font, const InlineRunStyle& run_style) const;
};

}  // namespace kstfl

#endif  // KSTFL_TEXT_MEASURER_H
