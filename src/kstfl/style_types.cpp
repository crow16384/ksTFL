// kstfl/style_types.cpp — Style type method implementations
//
// Style merge/convert methods separated from units.cpp for SRP compliance.
// Declarations live in types.h (no additional header needed).
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "types.h"
#include <array>
#include <optional>
#include <utility>

namespace kstfl {

// ---------------------------------------------------------------------------
// Border line style to OOXML
// ---------------------------------------------------------------------------

const char *border_line_style_to_ooxml(BorderLineStyle s) {
  using enum BorderLineStyle;
  static constexpr std::array<std::pair<BorderLineStyle, const char *>, 13> table{
      {{None, "nil"},
       {Single, "single"},
       {Double, "double"},
       {Dashed, "dashed"},
       {Dotted, "dotted"},
       {Thick, "thick"},
       {DashSmallGap, "dashSmallGap"},
       {DotDash, "dotDash"},
       {DotDotDash, "dotDotDash"},
       {Triple, "triple"},
       {ThinThickSmallGap, "thinThickSmallGap"},
       {ThickThinSmallGap, "thickThinSmallGap"},
       {Wave, "wave"}}};
  for (const auto &[key, val] : table) {
    if (key == s) return val;
  }
  return "single";
}

/// Convert Alignment to OOXML w:jc value string.
const char *alignment_to_ooxml(Alignment a) {
  using enum Alignment;
  static constexpr std::array<std::pair<Alignment, const char *>, 4> table{
      {{Left, "left"}, {Center, "center"}, {Right, "right"}, {Justify, "both"}}};
  for (const auto &[key, val] : table) {
    if (key == a) return val;
  }
  return "left";
}

// ---------------------------------------------------------------------------
// Style merge helpers
// ---------------------------------------------------------------------------

/// Helper: in-place merge — overwrite target only if source has value.
template <typename T> static void merge_opt_into(std::optional<T> &target, const std::optional<T> &source) {
  if (source.has_value()) target = source;
}

/// Merge an optional field whose value type itself has a merge_from() method.
/// If source has a value: merge into existing target, or assign if target is
/// empty.
template <Mergeable T> static void merge_nested_opt(std::optional<T> &target, const std::optional<T> &source) {
  if (source.has_value()) {
    if (target.has_value())
      target->merge_from(*source);
    else
      target = source;
  }
}

// -- Border -----------------------------------------------------------------

void Border::merge_from(const Border &other) {
  merge_opt_into(color, other.color);
  merge_opt_into(width, other.width);
  merge_opt_into(line_style, other.line_style);
}

Border Border::merged_with(const Border &other) const {
  Border result = *this;
  result.merge_from(other);
  return result;
}

// -- Borders ----------------------------------------------------------------

void Borders::merge_from(const Borders &other) {
  static constexpr std::array<std::optional<Border> Borders::*, 6> sides = {
      &Borders::top, &Borders::bottom, &Borders::left, &Borders::right, &Borders::insideH, &Borders::insideV};
  for (auto member : sides) {
    merge_nested_opt(this->*member, other.*member);
  }
}

Borders Borders::merged_with(const Borders &other) const {
  Borders result = *this;
  result.merge_from(other);
  return result;
}

// -- Optional equality helper -----------------------------------------------

template <typename T> static bool opt_eq(const std::optional<T> &a, const std::optional<T> &b) {
  if (a.has_value() != b.has_value()) return false;
  return !a.has_value() || *a == *b;
}

// -- Border / Borders equality (uses opt_eq) --------------------------------

bool Border::operator==(const Border &other) const {
  return opt_eq(color, other.color) && opt_eq(width, other.width) && opt_eq(line_style, other.line_style);
}

bool Borders::operator==(const Borders &other) const {
  return opt_eq(top, other.top) && opt_eq(bottom, other.bottom) && opt_eq(left, other.left) &&
         opt_eq(right, other.right) && opt_eq(insideH, other.insideH) && opt_eq(insideV, other.insideV);
}

// -- FontProps --------------------------------------------------------------

bool FontProps::operator==(const FontProps &other) const {
  return opt_eq(font_name, other.font_name) && opt_eq(font_size, other.font_size) && opt_eq(bold, other.bold) &&
         opt_eq(italic, other.italic) && opt_eq(underline, other.underline) &&
         opt_eq(strikethrough, other.strikethrough) && opt_eq(color, other.color) && opt_eq(highlight, other.highlight);
}

void FontProps::merge_from(const FontProps &other) {
  merge_opt_into(font_name, other.font_name);
  merge_opt_into(font_size, other.font_size);
  merge_opt_into(bold, other.bold);
  merge_opt_into(italic, other.italic);
  merge_opt_into(underline, other.underline);
  merge_opt_into(strikethrough, other.strikethrough);
  merge_opt_into(color, other.color);
  merge_opt_into(highlight, other.highlight);
}

FontProps FontProps::merged_with(const FontProps &other) const {
  FontProps result = *this;
  result.merge_from(other);
  return result;
}

// -- SpacingProps ------------------------------------------------------------

bool SpacingProps::operator==(const SpacingProps &other) const {
  return opt_eq(before, other.before) && opt_eq(after, other.after) &&
         opt_eq(line_spacing_multiplier, other.line_spacing_multiplier) &&
         opt_eq(exact_line_height, other.exact_line_height);
}

void SpacingProps::merge_from(const SpacingProps &other) {
  merge_opt_into(before, other.before);
  merge_opt_into(after, other.after);
  merge_opt_into(line_spacing_multiplier, other.line_spacing_multiplier);
  merge_opt_into(exact_line_height, other.exact_line_height);
}

SpacingProps SpacingProps::merged_with(const SpacingProps &other) const {
  SpacingProps result = *this;
  result.merge_from(other);
  return result;
}

// -- IndentProps -------------------------------------------------------------

bool IndentProps::operator==(const IndentProps &other) const {
  return opt_eq(left, other.left) && opt_eq(right, other.right) && opt_eq(first_line, other.first_line) &&
         opt_eq(hanging, other.hanging);
}

void IndentProps::merge_from(const IndentProps &other) {
  merge_opt_into(left, other.left);
  merge_opt_into(right, other.right);
  merge_opt_into(first_line, other.first_line);
  merge_opt_into(hanging, other.hanging);
}

IndentProps IndentProps::merged_with(const IndentProps &other) const {
  IndentProps result = *this;
  result.merge_from(other);
  return result;
}

// -- ParagraphProps ----------------------------------------------------------

bool ParagraphProps::operator==(const ParagraphProps &other) const {
  return opt_eq(alignment, other.alignment) && opt_eq(spacing, other.spacing) && opt_eq(indents, other.indents) &&
         opt_eq(widow_control, other.widow_control) && opt_eq(keep_next, other.keep_next) &&
         opt_eq(keep_lines, other.keep_lines) && opt_eq(outline_level, other.outline_level) &&
         opt_eq(borders, other.borders);
}

void ParagraphProps::merge_from(const ParagraphProps &other) {
  merge_opt_into(alignment, other.alignment);
  merge_opt_into(widow_control, other.widow_control);
  merge_opt_into(keep_next, other.keep_next);
  merge_opt_into(keep_lines, other.keep_lines);
  merge_opt_into(outline_level, other.outline_level);
  merge_nested_opt(spacing, other.spacing);
  merge_nested_opt(indents, other.indents);
  merge_nested_opt(borders, other.borders);
}

ParagraphProps ParagraphProps::merged_with(const ParagraphProps &other) const {
  ParagraphProps result = *this;
  result.merge_from(other);
  return result;
}

// -- TableCellProps ----------------------------------------------------------

void TableCellProps::merge_from(const TableCellProps &other) {
  merge_opt_into(background_color, other.background_color);
  merge_opt_into(vertical_alignment, other.vertical_alignment);
  merge_opt_into(text_orientation, other.text_orientation);
  merge_opt_into(row_height, other.row_height);
  merge_opt_into(cell_margin_top, other.cell_margin_top);
  merge_opt_into(cell_margin_bottom, other.cell_margin_bottom);
  merge_opt_into(cell_margin_left, other.cell_margin_left);
  merge_opt_into(cell_margin_right, other.cell_margin_right);
  merge_nested_opt(borders, other.borders);
}

TableCellProps TableCellProps::merged_with(const TableCellProps &other) const {
  TableCellProps result = *this;
  result.merge_from(other);
  return result;
}

// -- StyleDef ---------------------------------------------------------------

bool StyleDef::operator==(const StyleDef &other) const {
  return opt_eq(font, other.font) && opt_eq(paragraph, other.paragraph);
}

void StyleDef::merge_from(const StyleDef &other) {
  if (!other.id.empty()) id = other.id;
  merge_nested_opt(font, other.font);
  merge_nested_opt(paragraph, other.paragraph);
  merge_nested_opt(table_style, other.table_style);
}

StyleDef StyleDef::merged_with(const StyleDef &other) const {
  StyleDef result = *this;
  result.merge_from(other);
  return result;
}

// ---------------------------------------------------------------------------
// DataTable helpers
// ---------------------------------------------------------------------------

const std::vector<std::string> &DataTable::col(const std::string &name) const {
  auto it = columns.find(name);
  if (it == columns.end()) { throw RenderError("Column '" + name + "' not found in data table"); }
  return it->second;
}

} // namespace kstfl
