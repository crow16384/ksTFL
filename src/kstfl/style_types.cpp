// kstfl/style_types.cpp — Style type method implementations
//
// Style merge/convert methods separated from units.cpp for SRP compliance.
// Declarations live in types.h (no additional header needed).
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "types.h"
#include <optional>

namespace kstfl {

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
// Style merge helpers
// ---------------------------------------------------------------------------

/// Helper: in-place merge — overwrite target only if source has value.
template <typename T>
static void merge_opt_into(std::optional<T>& target, const std::optional<T>& source) {
    if (source.has_value()) target = source;
}

// -- Border -----------------------------------------------------------------

void Border::merge_from(const Border& other) {
    merge_opt_into(color, other.color);
    merge_opt_into(width, other.width);
    merge_opt_into(line_style, other.line_style);
}

Border Border::merged_with(const Border& other) const {
    Border result = *this;
    result.merge_from(other);
    return result;
}

// -- Borders ----------------------------------------------------------------

void Borders::merge_from(const Borders& other) {
    if (other.top.has_value()) {
        if (top.has_value()) top->merge_from(*other.top);
        else top = other.top;
    }
    if (other.bottom.has_value()) {
        if (bottom.has_value()) bottom->merge_from(*other.bottom);
        else bottom = other.bottom;
    }
    if (other.left.has_value()) {
        if (left.has_value()) left->merge_from(*other.left);
        else left = other.left;
    }
    if (other.right.has_value()) {
        if (right.has_value()) right->merge_from(*other.right);
        else right = other.right;
    }
}

Borders Borders::merged_with(const Borders& other) const {
    Borders result = *this;
    result.merge_from(other);
    return result;
}

// -- FontProps --------------------------------------------------------------

void FontProps::merge_from(const FontProps& other) {
    merge_opt_into(font_name, other.font_name);
    merge_opt_into(font_size, other.font_size);
    merge_opt_into(bold, other.bold);
    merge_opt_into(italic, other.italic);
    merge_opt_into(underline, other.underline);
    merge_opt_into(color, other.color);
    merge_opt_into(highlight, other.highlight);
}

FontProps FontProps::merged_with(const FontProps& other) const {
    FontProps result = *this;
    result.merge_from(other);
    return result;
}

// -- SpacingProps ------------------------------------------------------------

void SpacingProps::merge_from(const SpacingProps& other) {
    merge_opt_into(before, other.before);
    merge_opt_into(after, other.after);
    merge_opt_into(line_spacing_multiplier, other.line_spacing_multiplier);
    merge_opt_into(exact_line_height, other.exact_line_height);
}

SpacingProps SpacingProps::merged_with(const SpacingProps& other) const {
    SpacingProps result = *this;
    result.merge_from(other);
    return result;
}

// -- IndentProps -------------------------------------------------------------

void IndentProps::merge_from(const IndentProps& other) {
    merge_opt_into(left, other.left);
    merge_opt_into(right, other.right);
    merge_opt_into(first_line, other.first_line);
    merge_opt_into(hanging, other.hanging);
}

IndentProps IndentProps::merged_with(const IndentProps& other) const {
    IndentProps result = *this;
    result.merge_from(other);
    return result;
}

// -- ParagraphProps ----------------------------------------------------------

void ParagraphProps::merge_from(const ParagraphProps& other) {
    merge_opt_into(alignment, other.alignment);
    merge_opt_into(widow_control, other.widow_control);
    merge_opt_into(keep_next, other.keep_next);
    merge_opt_into(keep_lines, other.keep_lines);
    if (other.spacing.has_value()) {
        if (spacing.has_value()) spacing->merge_from(*other.spacing);
        else spacing = other.spacing;
    }
    if (other.indents.has_value()) {
        if (indents.has_value()) indents->merge_from(*other.indents);
        else indents = other.indents;
    }
}

ParagraphProps ParagraphProps::merged_with(const ParagraphProps& other) const {
    ParagraphProps result = *this;
    result.merge_from(other);
    return result;
}

// -- TableCellProps ----------------------------------------------------------

void TableCellProps::merge_from(const TableCellProps& other) {
    merge_opt_into(background_color, other.background_color);
    merge_opt_into(vertical_alignment, other.vertical_alignment);
    merge_opt_into(text_orientation, other.text_orientation);
    merge_opt_into(row_height, other.row_height);
    merge_opt_into(cell_margin_top, other.cell_margin_top);
    merge_opt_into(cell_margin_bottom, other.cell_margin_bottom);
    merge_opt_into(cell_margin_left, other.cell_margin_left);
    merge_opt_into(cell_margin_right, other.cell_margin_right);
    if (other.borders.has_value()) {
        if (borders.has_value()) borders->merge_from(*other.borders);
        else borders = other.borders;
    }
}

TableCellProps TableCellProps::merged_with(const TableCellProps& other) const {
    TableCellProps result = *this;
    result.merge_from(other);
    return result;
}

// -- StyleDef ---------------------------------------------------------------

void StyleDef::merge_from(const StyleDef& other) {
    if (!other.id.empty()) id = other.id;
    if (other.font.has_value()) {
        if (font.has_value()) font->merge_from(*other.font);
        else font = other.font;
    }
    if (other.paragraph.has_value()) {
        if (paragraph.has_value()) paragraph->merge_from(*other.paragraph);
        else paragraph = other.paragraph;
    }
    if (other.table_style.has_value()) {
        if (table_style.has_value()) table_style->merge_from(*other.table_style);
        else table_style = other.table_style;
    }
}

StyleDef StyleDef::merged_with(const StyleDef& other) const {
    StyleDef result = *this;
    result.merge_from(other);
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
