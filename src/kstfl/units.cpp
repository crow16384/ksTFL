// kstfl/units.cpp — Unit system implementation
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "units.h"
#include <algorithm>
#include <cctype>
#include <cmath>
#include <string_view>

namespace kstfl {

// ---------------------------------------------------------------------------
// Page size dimensions lookup
// ---------------------------------------------------------------------------

std::pair<int64_t, int64_t> page_size_dimensions(PageSize size) {
    switch (size) {
        case PageSize::A4:        return {A4_WIDTH_EMU, A4_HEIGHT_EMU};
        case PageSize::A3:        return {A3_WIDTH_EMU, A3_HEIGHT_EMU};
        case PageSize::Letter:    return {LETTER_WIDTH_EMU, LETTER_HEIGHT_EMU};
        case PageSize::Legal:     return {LEGAL_WIDTH_EMU, LEGAL_HEIGHT_EMU};
        case PageSize::Executive: return {EXECUTIVE_WIDTH_EMU, EXECUTIVE_HEIGHT_EMU};
    }
    // Should never reach here
    throw RenderError("Unknown page size");
}

// ---------------------------------------------------------------------------
// Length parsing
// ---------------------------------------------------------------------------

/// Trim leading/trailing whitespace from a string_view.
static std::string_view trim(std::string_view sv) {
    while (!sv.empty() && std::isspace(static_cast<unsigned char>(sv.front())))
        sv.remove_prefix(1);
    while (!sv.empty() && std::isspace(static_cast<unsigned char>(sv.back())))
        sv.remove_suffix(1);
    return sv;
}

/// Extract numeric value from the beginning of the string.
/// Returns the number and advances `pos` past it.
static double extract_number(std::string_view sv, size_t& pos) {
    pos = 0;
    // Allow optional leading sign
    if (pos < sv.size() && (sv[pos] == '+' || sv[pos] == '-')) ++pos;
    // Integer part
    while (pos < sv.size() && std::isdigit(static_cast<unsigned char>(sv[pos]))) ++pos;
    // Decimal part
    if (pos < sv.size() && sv[pos] == '.') {
        ++pos;
        while (pos < sv.size() && std::isdigit(static_cast<unsigned char>(sv[pos]))) ++pos;
    }
    if (pos == 0) {
        throw RenderError("Invalid length value: no number found in '" + std::string(sv) + "'");
    }
    // Parse the number
    std::string num_str(sv.substr(0, pos));
    return std::stod(num_str);
}

Length parse_length(const std::string& s, int64_t reference_emu) {
    auto sv = trim(std::string_view(s));
    if (sv.empty()) {
        throw RenderError("Empty length string");
    }

    size_t num_end = 0;
    double value = extract_number(sv, num_end);
    
    // Get the unit suffix (lowercased)
    std::string unit;
    for (size_t i = num_end; i < sv.size(); ++i) {
        char c = static_cast<char>(std::tolower(static_cast<unsigned char>(sv[i])));
        if (!std::isspace(static_cast<unsigned char>(c))) {
            unit += c;
        }
    }

    if (unit.empty() || unit == "emu") {
        return Length::from_emu(static_cast<int64_t>(value));
    } else if (unit == "cm") {
        return Length::from_cm(value);
    } else if (unit == "mm") {
        return Length{static_cast<int64_t>(value * 36000.0)};
    } else if (unit == "in") {
        return Length::from_in(value);
    } else if (unit == "pt") {
        return Length::from_pt(value);
    } else if (unit == "twip" || unit == "twips") {
        return Length::from_twips(static_cast<int64_t>(value));
    } else if (unit == "%") {
        if (reference_emu == 0) {
            throw RenderError("Percent length requires a reference value, got '" + s + "'");
        }
        return Length{static_cast<int64_t>(reference_emu * value / 100.0)};
    } else {
        throw RenderError("Unknown unit '" + unit + "' in length string '" + s + "'");
    }
}

// ---------------------------------------------------------------------------
// Length::parse static method (delegates to parse_length)
// ---------------------------------------------------------------------------

Length Length::parse(const std::string& s, int64_t reference_emu) {
    return parse_length(s, reference_emu);
}

// ---------------------------------------------------------------------------
// Color parsing
// ---------------------------------------------------------------------------

Color Color::parse(const std::string& s) {
    if (s.empty()) return Color{};
    std::string h = s;
    // Strip leading '#'
    if (!h.empty() && h[0] == '#') {
        h = h.substr(1);
    }
    // Validate hex
    if (h.size() != 6) {
        throw RenderError("Invalid color hex string: '" + s + "' (expected 6 hex digits)");
    }
    for (char c : h) {
        if (!std::isxdigit(static_cast<unsigned char>(c))) {
            throw RenderError("Invalid hex character in color: '" + s + "'");
        }
    }
    // Uppercase for consistency
    std::transform(h.begin(), h.end(), h.begin(),
                   [](unsigned char c) { return static_cast<char>(std::toupper(c)); });
    return Color{h};
}

// ---------------------------------------------------------------------------
// Conversion helpers
// ---------------------------------------------------------------------------

int64_t emu_to_twips(int64_t emu) {
    return emu / EMU_PER_TWIP;
}

int emu_to_half_points(int64_t emu) {
    double pt = static_cast<double>(emu) / EMU_PER_PT;
    return static_cast<int>(std::round(pt * HALF_POINTS_PER_PT));
}

int pt_to_half_points(double pt) {
    return static_cast<int>(std::round(pt * HALF_POINTS_PER_PT));
}

int pt_to_eighth_points(double pt) {
    return static_cast<int>(std::round(pt * 8.0));
}

// ---------------------------------------------------------------------------
// PageConfig methods
// ---------------------------------------------------------------------------

Length PageConfig::page_width() const {
    auto [w, h] = page_size_dimensions(size);
    if (orientation == Orientation::Landscape) {
        return Length::from_emu(h);  // swap for landscape
    }
    return Length::from_emu(w);
}

Length PageConfig::page_height() const {
    auto [w, h] = page_size_dimensions(size);
    if (orientation == Orientation::Landscape) {
        return Length::from_emu(w);  // swap for landscape
    }
    return Length::from_emu(h);
}

Length PageConfig::usable_width() const {
    return page_width() - margins.left - margins.right;
}

Length PageConfig::usable_height() const {
    return page_height() - margins.top - margins.bottom;
}

// ---------------------------------------------------------------------------
// Border line style to OOXML
// ---------------------------------------------------------------------------

const char* border_line_style_to_ooxml(BorderLineStyle s) {
    switch (s) {
        case BorderLineStyle::None:              return "nil";
        case BorderLineStyle::Single:            return "single";
        case BorderLineStyle::Double:            return "double";
        case BorderLineStyle::Dashed:            return "dashed";
        case BorderLineStyle::Dotted:            return "dotted";
        case BorderLineStyle::Thick:             return "thick";
        case BorderLineStyle::DashSmallGap:      return "dashSmallGap";
        case BorderLineStyle::DotDash:           return "dotDash";
        case BorderLineStyle::DotDotDash:        return "dotDotDash";
        case BorderLineStyle::Triple:            return "triple";
        case BorderLineStyle::ThinThickSmallGap: return "thinThickSmallGap";
        case BorderLineStyle::ThickThinSmallGap: return "thickThinSmallGap";
        case BorderLineStyle::Wave:              return "wave";
    }
    return "single";
}

/// Convert Alignment to OOXML w:jc value string.
const char* alignment_to_ooxml(Alignment a) {
    switch (a) {
        case Alignment::Left:    return "left";
        case Alignment::Center:  return "center";
        case Alignment::Right:   return "right";
        case Alignment::Justify: return "both";
    }
    return "left";
}

// ---------------------------------------------------------------------------
// Style merge implementations
// ---------------------------------------------------------------------------

/// Helper: merge optional<T> — later wins if present.
template <typename T>
static std::optional<T> merge_opt(const std::optional<T>& base, const std::optional<T>& over) {
    return over.has_value() ? over : base;
}

Border Border::merged_with(const Border& other) const {
    Border result;
    result.color = merge_opt(color, other.color);
    result.width = merge_opt(width, other.width);
    result.line_style = merge_opt(line_style, other.line_style);
    return result;
}

Borders Borders::merged_with(const Borders& other) const {
    Borders result;
    if (other.top.has_value()) {
        result.top = top.has_value() ? top->merged_with(*other.top) : other.top;
    } else {
        result.top = top;
    }
    if (other.bottom.has_value()) {
        result.bottom = bottom.has_value() ? bottom->merged_with(*other.bottom) : other.bottom;
    } else {
        result.bottom = bottom;
    }
    if (other.left.has_value()) {
        result.left = left.has_value() ? left->merged_with(*other.left) : other.left;
    } else {
        result.left = left;
    }
    if (other.right.has_value()) {
        result.right = right.has_value() ? right->merged_with(*other.right) : other.right;
    } else {
        result.right = right;
    }
    return result;
}

FontProps FontProps::merged_with(const FontProps& other) const {
    FontProps result;
    result.font_name = merge_opt(font_name, other.font_name);
    result.font_size = merge_opt(font_size, other.font_size);
    result.bold      = merge_opt(bold, other.bold);
    result.italic    = merge_opt(italic, other.italic);
    result.underline = merge_opt(underline, other.underline);
    result.color     = merge_opt(color, other.color);
    result.highlight = merge_opt(highlight, other.highlight);
    return result;
}

SpacingProps SpacingProps::merged_with(const SpacingProps& other) const {
    SpacingProps result;
    result.before = merge_opt(before, other.before);
    result.after  = merge_opt(after, other.after);
    result.line_spacing_multiplier = merge_opt(line_spacing_multiplier, other.line_spacing_multiplier);
    result.exact_line_height = merge_opt(exact_line_height, other.exact_line_height);
    return result;
}

IndentProps IndentProps::merged_with(const IndentProps& other) const {
    IndentProps result;
    result.left       = merge_opt(left, other.left);
    result.right      = merge_opt(right, other.right);
    result.first_line = merge_opt(first_line, other.first_line);
    result.hanging    = merge_opt(hanging, other.hanging);
    return result;
}

ParagraphProps ParagraphProps::merged_with(const ParagraphProps& other) const {
    ParagraphProps result;
    result.alignment = merge_opt(alignment, other.alignment);
    result.widow_control = merge_opt(widow_control, other.widow_control);
    result.keep_next = merge_opt(keep_next, other.keep_next);
    result.keep_lines = merge_opt(keep_lines, other.keep_lines);
    if (other.spacing.has_value()) {
        result.spacing = spacing.has_value()
            ? spacing->merged_with(*other.spacing)
            : other.spacing;
    } else {
        result.spacing = spacing;
    }
    if (other.indents.has_value()) {
        result.indents = indents.has_value()
            ? indents->merged_with(*other.indents)
            : other.indents;
    } else {
        result.indents = indents;
    }
    return result;
}

TableCellProps TableCellProps::merged_with(const TableCellProps& other) const {
    TableCellProps result;
    result.background_color   = merge_opt(background_color, other.background_color);
    result.vertical_alignment = merge_opt(vertical_alignment, other.vertical_alignment);
    result.text_orientation   = merge_opt(text_orientation, other.text_orientation);
    result.row_height         = merge_opt(row_height, other.row_height);
    result.cell_margin_top    = merge_opt(cell_margin_top, other.cell_margin_top);
    result.cell_margin_bottom = merge_opt(cell_margin_bottom, other.cell_margin_bottom);
    result.cell_margin_left   = merge_opt(cell_margin_left, other.cell_margin_left);
    result.cell_margin_right  = merge_opt(cell_margin_right, other.cell_margin_right);
    if (other.borders.has_value()) {
        result.borders = borders.has_value()
            ? borders->merged_with(*other.borders)
            : other.borders;
    } else {
        result.borders = borders;
    }
    return result;
}

StyleDef StyleDef::merged_with(const StyleDef& other) const {
    StyleDef result;
    result.id = other.id.empty() ? id : other.id;
    if (other.font.has_value()) {
        result.font = font.has_value()
            ? font->merged_with(*other.font)
            : other.font;
    } else {
        result.font = font;
    }
    if (other.paragraph.has_value()) {
        result.paragraph = paragraph.has_value()
            ? paragraph->merged_with(*other.paragraph)
            : other.paragraph;
    } else {
        result.paragraph = paragraph;
    }
    if (other.table_style.has_value()) {
        result.table_style = table_style.has_value()
            ? table_style->merged_with(*other.table_style)
            : other.table_style;
    } else {
        result.table_style = table_style;
    }
    return result;
}

// ---------------------------------------------------------------------------
// DataTable helpers
// ---------------------------------------------------------------------------

const std::vector<std::string>& DataTable::col(const std::string& name) const {
    auto it = columns.find(name);
    if (it == columns.end()) {
        throw RenderError("Column '" + name + "' not found in data table");
    }
    return it->second;
}

}  // namespace kstfl
