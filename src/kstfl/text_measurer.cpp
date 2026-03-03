// kstfl/text_measurer.cpp — HarfBuzz-based text measurement + wrapping
//
// Implements spec §16: text measurement, line wrapping, paragraph spacing.
// Deterministic measurement: same input + same fonts = same result.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "text_measurer.h"
#include "font_cache.h"
#include "inline_parser.h"

#include <hb.h>
#include <cmath>

namespace kstfl {

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

TextMeasurer::TextMeasurer(FontCache& cache)
    : cache_(cache), hb_buf_(hb_buffer_create()) {}

TextMeasurer::~TextMeasurer() {
    if (hb_buf_) {
        hb_buffer_destroy(hb_buf_);
    }
}

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

    hb_buffer_reset(hb_buf_);
    hb_buffer_add_utf8(hb_buf_, text.c_str(), static_cast<int>(text.size()), 0,
                        static_cast<int>(text.size()));
    hb_buffer_set_direction(hb_buf_, HB_DIRECTION_LTR);
    hb_buffer_set_script(hb_buf_, HB_SCRIPT_LATIN);
    hb_buffer_set_language(hb_buf_, hb_language_from_string("en", -1));

    hb_shape(hb_font, hb_buf_, nullptr, 0);

    unsigned int glyph_count = 0;
    hb_glyph_position_t* glyph_pos = hb_buffer_get_glyph_positions(hb_buf_, &glyph_count);

    double total_advance = 0.0;
    for (unsigned int i = 0; i < glyph_count; ++i) {
        total_advance += glyph_pos[i].x_advance;
    }

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

    // -----------------------------------------------------------------------
    // Rotated text (vertical_90 / vertical_270)
    // -----------------------------------------------------------------------
    // When a cell is rotated 90° or 270°, Word renders the text vertically.
    // The column width becomes the visual cell HEIGHT, and the text's natural
    // (horizontal) width becomes the visual cell HEIGHT contribution.
    // Word does NOT word-wrap inside rotated cells — the full label runs as a
    // single unwrapped line.
    //
    // Measurement strategy:
    //   • Measure the text as one unwrapped horizontal line → natural_width.
    //   • The cell's HEIGHT contribution = natural_width + top/bottom cell margins.
    //   • The cell's WIDTH contribution = one line height (the font height).
    //     (This is what the column width must accommodate, but column widths are
    //     already fixed at this point, so we only return the height contribution.)
    //
    // Returned MeasuredText: { width = line_height, height = natural_text_width
    //                          + cell_margin_top + cell_margin_bottom }
    if (base_tcp.text_orientation.has_value() &&
        base_tcp.text_orientation.value() != TextOrientation::Horizontal) {

        double line_spacing_mult = 1.0;
        if (base_pp.spacing.has_value() &&
            base_pp.spacing->line_spacing_multiplier.has_value()) {
            line_spacing_mult = base_pp.spacing->line_spacing_multiplier.value();
        }
        Length lh = line_height(base_font, line_spacing_mult);

        // Measure the full text as one unwrapped line
        Length natural_width{0};
        for (const auto& para : parsed.paragraphs) {
            Length para_width{0};
            for (const auto& run : para.runs) {
                if (run.text.empty() || run.text == "\n") continue;
                FontProps run_font = base_font;
                if (run.style.bold_override)   run_font.bold   = true;
                if (run.style.italic_override) run_font.italic = true;
                FontProps measure_font = run_font;
                if (run.style.superscript || run.style.subscript) {
                    measure_font.font_size = effective_font_size(base_font, run.style);
                }
                para_width = para_width + measure_run_width(run.text, measure_font, {});
            }
            if (para_width > natural_width) natural_width = para_width;
        }

        // In a btLr/tbRl cell the row height becomes the text-flow "width".
        // Word subtracts paragraph indents from this width before wrapping,
        // and adds paragraph spacing (before/after) between paragraphs.
        // We must include all of these so the row is tall enough.
        Length indent_left  = base_pp.indents.has_value() && base_pp.indents->left.has_value()
                                  ? *base_pp.indents->left : Length{0};
        Length indent_right = base_pp.indents.has_value() && base_pp.indents->right.has_value()
                                  ? *base_pp.indents->right : Length{0};

        Length spacing_before = (base_pp.spacing.has_value() && base_pp.spacing->before.has_value())
                                    ? *base_pp.spacing->before : Length{0};
        Length spacing_after  = (base_pp.spacing.has_value() && base_pp.spacing->after.has_value())
                                    ? *base_pp.spacing->after : Length{0};

        size_t n_paras = parsed.paragraphs.size();
        Length total_para_spacing{0};
        if (n_paras > 0) {
            total_para_spacing = (spacing_before + spacing_after) * static_cast<double>(n_paras);
        }

        Length cell_margin_top    = base_tcp.cell_margin_top.value_or(Length{0});
        Length cell_margin_bottom = base_tcp.cell_margin_bottom.value_or(Length{0});
        Length required_height = natural_width + indent_left + indent_right
                               + total_para_spacing
                               + cell_margin_top + cell_margin_bottom;

        // Width contribution = one line height (font height after rotation)
        Length cell_margin_left  = base_tcp.cell_margin_left.value_or(Length{0});
        Length cell_margin_right = base_tcp.cell_margin_right.value_or(Length{0});
        Length reported_width = lh + cell_margin_left + cell_margin_right;

        return MeasuredText{reported_width, required_height, 1};
    }

    double line_spacing_mult = 1.0;
    if (base_pp.spacing.has_value() && base_pp.spacing->line_spacing_multiplier.has_value()) {
        line_spacing_mult = base_pp.spacing->line_spacing_multiplier.value();
    }

    // Cell margins reduce available width
    Length cell_margin_left = base_tcp.cell_margin_left.value_or(Length{0});
    Length cell_margin_right = base_tcp.cell_margin_right.value_or(Length{0});
    Length inner_width = max_width - cell_margin_left - cell_margin_right;

    // Paragraph indents further reduce the available text width.
    // left indent + right indent both consume horizontal space.
    if (base_pp.indents.has_value()) {
        Length para_indent_left  = base_pp.indents->left.value_or(Length{0});
        Length para_indent_right = base_pp.indents->right.value_or(Length{0});
        inner_width = inner_width - para_indent_left - para_indent_right;
    }

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

        // OOXML: paragraph spacing is additive (not collapsed like CSS).
        // Every paragraph gets its full space_before and space_after.
        total_height = total_height + space_before;

        // Build a single-pass word-wrap across all runs in this paragraph.
        // We need to iterate through runs, measuring word by word, wrapping
        // when we exceed inner_width.
        Length current_line_width{0};
        int para_lines = 0;

        // Get base line height for this paragraph
        Length base_lh = line_height(base_font, line_spacing_mult);

        for (const auto& run : para.runs) {
            if (run.text.empty()) continue;

            // Handle line break runs (from <br> inline markup)
            if (run.text == "\n") {
                if (current_line_width > max_line_width) {
                    max_line_width = current_line_width;
                }
                total_height = total_height + base_lh;
                para_lines++;
                current_line_width = Length{0};
                continue;
            }

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

                // Handle single word wider than the available cell width
                // (character-level wrapping: Word breaks within the word).
                // Estimate the number of lines needed by dividing word width
                // by inner_width, then carry the remainder forward.
                if (inner_width.emu > 0 && word_width > inner_width) {
                    int64_t full_lines = word_width.emu / inner_width.emu;
                    int64_t remainder = word_width.emu % inner_width.emu;
                    // full_lines complete lines consumed by this word
                    for (int64_t fl = 0; fl < full_lines; ++fl) {
                        if (max_line_width < inner_width) max_line_width = inner_width;
                        total_height = total_height + base_lh;
                        para_lines++;
                    }
                    // Carry the remainder to the current line
                    current_line_width = Length{remainder};
                } else {
                    current_line_width = current_line_width + word_width;
                }
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

        // OOXML: space_after on every paragraph (additive, not collapsed)
        total_height = total_height + space_after;
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
    ParsedCell parsed = parse_inline_markup(text);
    return measure_cell(parsed, style, max_width);
}

}  // namespace kstfl
