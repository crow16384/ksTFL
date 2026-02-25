// kstfl/text_measurer.cpp — HarfBuzz-based text measurement + wrapping
//
// Implements spec §16: text measurement, line wrapping, paragraph spacing.
// Deterministic measurement: same input + same fonts = same result.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include "text_measurer.h"
#include "font_cache.h"
#include "inline_parser.h"

#include <hb.h>
#include <algorithm>
#include <cmath>
#include <sstream>

namespace kstfl {

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

TextMeasurer::TextMeasurer(FontCache& cache) : cache_(cache) {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

double TextMeasurer::effective_font_size(const FontProps& font,
                                          const InlineRunStyle& run_style) const {
    double base_size = font.font_size.value_or(10.0);
    // Superscript/subscript rendered at 65% of base size (spec §16.4)
    if (run_style.superscript || run_style.subscript) {
        return base_size * 0.65;
    }
    return base_size;
}

// ---------------------------------------------------------------------------
// Measure width of a single text run (no wrapping)
// ---------------------------------------------------------------------------

Length TextMeasurer::measure_run_width(const std::string& text,
                                       const FontProps& font,
                                       const InlineRunStyle& run_style) const {
    if (text.empty()) return Length{0};

    std::string font_name = font.font_name.value_or("Courier New");
    bool bold = font.bold.value_or(false) || run_style.bold_override;
    bool italic = font.italic.value_or(false) || run_style.italic_override;
    double size_pt = effective_font_size(font, run_style);

    FaceKey key{font_name, bold, italic};
    hb_font_t* hb_font = cache_.get_hb_font(key, size_pt);
    if (!hb_font) return Length{0};

    // Create HarfBuzz buffer and shape
    hb_buffer_t* buf = hb_buffer_create();
    hb_buffer_add_utf8(buf, text.c_str(), static_cast<int>(text.size()), 0,
                        static_cast<int>(text.size()));
    hb_buffer_set_direction(buf, HB_DIRECTION_LTR);
    hb_buffer_set_script(buf, HB_SCRIPT_LATIN);
    hb_buffer_set_language(buf, hb_language_from_string("en", -1));

    hb_shape(hb_font, buf, nullptr, 0);

    // Sum glyph advances
    unsigned int glyph_count = 0;
    hb_glyph_position_t* glyph_pos = hb_buffer_get_glyph_positions(buf, &glyph_count);

    double total_advance = 0.0;
    for (unsigned int i = 0; i < glyph_count; ++i) {
        total_advance += glyph_pos[i].x_advance;
    }

    hb_buffer_destroy(buf);

    // HarfBuzz positions are in font units. Convert: advance is in 1/64 of a point
    // when FreeType char size is set with (size * 64). HarfBuzz inherits FreeType's
    // scale. FT_Set_Char_Size(face, 0, size_pt * 64, 72, 72) means coordinates
    // are in 1/64 points. So total_advance / 64.0 = points.
    double width_pt = total_advance / 64.0;
    return Length::from_pt(width_pt);
}

// ---------------------------------------------------------------------------
// Get line height for a font
// ---------------------------------------------------------------------------

Length TextMeasurer::line_height(const FontProps& font, double line_spacing_mult) const {
    std::string font_name = font.font_name.value_or("Courier New");
    bool bold = font.bold.value_or(false);
    bool italic = font.italic.value_or(false);
    double size_pt = font.font_size.value_or(10.0);

    FaceKey key{font_name, bold, italic};
    FontMetrics metrics = cache_.get_metrics(key, size_pt);

    double lh = metrics.line_height * line_spacing_mult;
    return Length::from_pt(lh);
}

// ---------------------------------------------------------------------------
// Word-wrap: break text into lines that fit within max_width
// ---------------------------------------------------------------------------

namespace {

/// Split text into word tokens (preserving spaces as part of word).
std::vector<std::string> split_words(const std::string& text) {
    std::vector<std::string> words;
    std::string current;
    for (size_t i = 0; i < text.size(); ++i) {
        current += text[i];
        if (text[i] == ' ' || text[i] == '\t' || i == text.size() - 1) {
            words.push_back(current);
            current.clear();
        }
    }
    if (!current.empty()) {
        words.push_back(current);
    }
    return words;
}

}  // namespace

// ---------------------------------------------------------------------------
// Measure a parsed cell
// ---------------------------------------------------------------------------

MeasuredText TextMeasurer::measure_cell(const ParsedCell& parsed,
                                         const StyleDef& style,
                                         Length max_width) const {
    if (parsed.paragraphs.empty()) {
        return MeasuredText{Length{0}, Length{0}, 0};
    }

    FontProps base_font = style.font.value_or(FontProps{});
    ParagraphProps base_pp = style.paragraph.value_or(ParagraphProps{});
    TableCellProps base_tcp = style.table_style.value_or(TableCellProps{});

    double line_spacing_mult = 1.0;
    if (base_pp.spacing.has_value() && base_pp.spacing->line_spacing_multiplier.has_value()) {
        line_spacing_mult = base_pp.spacing->line_spacing_multiplier.value();
    }

    // Cell margins reduce available width
    Length cell_margin_left = base_tcp.cell_margin_left.value_or(Length{0});
    Length cell_margin_right = base_tcp.cell_margin_right.value_or(Length{0});
    Length inner_width = max_width - cell_margin_left - cell_margin_right;
    if (inner_width.emu < 0) inner_width.emu = 0;

    Length total_height{0};
    Length max_line_width{0};
    int total_lines = 0;

    for (size_t pi = 0; pi < parsed.paragraphs.size(); ++pi) {
        const auto& para = parsed.paragraphs[pi];

        // Paragraph spacing
        Length space_before{0};
        Length space_after{0};
        if (base_pp.spacing.has_value()) {
            space_before = base_pp.spacing->before.value_or(Length{0});
            space_after = base_pp.spacing->after.value_or(Length{0});
        }

        // Don't add spacing_before on very first paragraph
        if (pi > 0) {
            total_height = total_height + space_before;
        }

        // Build a single-pass word-wrap across all runs in this paragraph.
        // We need to iterate through runs, measuring word by word, wrapping
        // when we exceed inner_width.
        Length current_line_width{0};
        int para_lines = 0;

        // Get base line height for this paragraph
        Length base_lh = line_height(base_font, line_spacing_mult);

        for (const auto& run : para.runs) {
            if (run.text.empty()) continue;

            double eff_size = effective_font_size(base_font, run.style);
            FontProps run_font = base_font;
            if (run.style.bold_override) run_font.bold = true;
            if (run.style.italic_override) run_font.italic = true;

            // For superscript/subscript, use reduced size
            FontProps measure_font = run_font;
            if (run.style.superscript || run.style.subscript) {
                measure_font.font_size = eff_size;
            }

            auto words = split_words(run.text);
            for (const auto& word : words) {
                Length word_width = measure_run_width(word, measure_font, {});
                
                // Check if word fits on current line
                if (current_line_width.emu > 0 &&
                    (current_line_width + word_width) > inner_width) {
                    // Wrap: finalize this line
                    if (current_line_width > max_line_width) {
                        max_line_width = current_line_width;
                    }
                    total_height = total_height + base_lh;
                    para_lines++;
                    current_line_width = Length{0};
                }
                current_line_width = current_line_width + word_width;
            }
        }

        // Finalize last line in paragraph
        if (current_line_width.emu > 0 || para.runs.empty()) {
            if (current_line_width > max_line_width) {
                max_line_width = current_line_width;
            }
            total_height = total_height + base_lh;
            para_lines++;
        }

        total_lines += para_lines;

        // Spacing after paragraph (not on last paragraph)
        if (pi < parsed.paragraphs.size() - 1) {
            total_height = total_height + space_after;
        }
    }

    // Add cell margins top/bottom
    Length cell_margin_top = base_tcp.cell_margin_top.value_or(Length{0});
    Length cell_margin_bottom = base_tcp.cell_margin_bottom.value_or(Length{0});
    total_height = total_height + cell_margin_top + cell_margin_bottom;

    return MeasuredText{max_line_width, total_height, total_lines};
}

// ---------------------------------------------------------------------------
// Measure a plain text string
// ---------------------------------------------------------------------------

MeasuredText TextMeasurer::measure_plain(const std::string& text,
                                          const StyleDef& style,
                                          Length max_width) const {
    if (text.empty()) {
        // Even empty cell has at least 1 line height
        FontProps font = style.font.value_or(FontProps{});
        Length lh = line_height(font);
        TableCellProps tcp = style.table_style.value_or(TableCellProps{});
        Length mt = tcp.cell_margin_top.value_or(Length{0});
        Length mb = tcp.cell_margin_bottom.value_or(Length{0});
        return MeasuredText{Length{0}, lh + mt + mb, 1};
    }

    // Quick path: parse inline, then measure
    InlineParser parser;
    ParsedCell parsed = parser.parse(text);
    return measure_cell(parsed, style, max_width);
}

}  // namespace kstfl
