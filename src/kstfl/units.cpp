// kstfl/units.cpp — Unit system: parsing, conversion, page geometry
//
// Style merge methods and OOXML enum converters live in style_types.cpp.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "units.h"
#include <algorithm>
#include <cctype>
#include <cmath>
#include <ranges>
#include <string_view>
#include <unordered_map>

namespace kstfl {

// ---------------------------------------------------------------------------
// Page size dimensions lookup
// ---------------------------------------------------------------------------

std::pair<int64_t, int64_t> page_size_dimensions(PageSize size) {
  static const std::unordered_map<PageSize, std::pair<int64_t, int64_t>> map{
      {PageSize::A4, {A4_WIDTH_EMU, A4_HEIGHT_EMU}},
      {PageSize::A3, {A3_WIDTH_EMU, A3_HEIGHT_EMU}},
      {PageSize::Letter, {LETTER_WIDTH_EMU, LETTER_HEIGHT_EMU}},
      {PageSize::Legal, {LEGAL_WIDTH_EMU, LEGAL_HEIGHT_EMU}},
      {PageSize::Executive, {EXECUTIVE_WIDTH_EMU, EXECUTIVE_HEIGHT_EMU}}};
  auto it = map.find(size);
  if (it != map.end())
    return it->second;
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
static double extract_number(std::string_view sv, size_t &pos) {
  pos = 0;
  // Allow optional leading sign
  if (pos < sv.size() && (sv[pos] == '+' || sv[pos] == '-'))
    ++pos;
  // Integer part
  while (pos < sv.size() && std::isdigit(static_cast<unsigned char>(sv[pos])))
    ++pos;
  // Decimal part
  if (pos < sv.size() && sv[pos] == '.') {
    ++pos;
    while (pos < sv.size() && std::isdigit(static_cast<unsigned char>(sv[pos])))
      ++pos;
  }
  if (pos == 0) {
    throw RenderError("Invalid length value: no number found in '" +
                      std::string(sv) + "'");
  }
  // Parse the number
  std::string num_str(sv.substr(0, pos));
  return std::stod(num_str);
}

Length parse_length(const std::string &s, int64_t reference_emu) {
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

  // Percent needs reference_emu — handle separately
  if (unit == "%") {
    if (reference_emu == 0) {
      throw RenderError("Percent length requires a reference value, got '" + s +
                        "'");
    }
    return Length{static_cast<int64_t>(reference_emu * value / 100.0)};
  }

  using UnitFn = Length (*)(double);
  static const std::unordered_map<std::string_view, UnitFn> unit_map{
      {"", +[](double v) { return Length::from_emu(static_cast<int64_t>(v)); }},
      {"emu",
       +[](double v) { return Length::from_emu(static_cast<int64_t>(v)); }},
      {"cm", +[](double v) { return Length::from_cm(v); }},
      {"mm",
       +[](double v) { return Length{static_cast<int64_t>(v * 36000.0)}; }},
      {"in", +[](double v) { return Length::from_in(v); }},
      {"pt", +[](double v) { return Length::from_pt(v); }},
      {"twip",
       +[](double v) { return Length::from_twips(static_cast<int64_t>(v)); }},
      {"twips",
       +[](double v) { return Length::from_twips(static_cast<int64_t>(v)); }}};

  auto it = unit_map.find(std::string_view{unit});
  if (it != unit_map.end())
    return it->second(value);
  throw RenderError("Unknown unit '" + unit + "' in length string '" + s + "'");
}

// ---------------------------------------------------------------------------
// Length::parse static method (delegates to parse_length)
// ---------------------------------------------------------------------------

Length Length::parse(const std::string &s, int64_t reference_emu) {
  return parse_length(s, reference_emu);
}

// ---------------------------------------------------------------------------
// Color parsing
// ---------------------------------------------------------------------------

Color Color::parse(const std::string &s) {
  if (s.empty())
    return Color{};
  std::string h = s;
  // Strip leading '#'
  if (!h.empty() && h[0] == '#') {
    h = h.substr(1);
  }
  // Validate hex
  if (h.size() != 6) {
    throw RenderError("Invalid color hex string: '" + s +
                      "' (expected 6 hex digits)");
  }
  for (char c : h) {
    if (!std::isxdigit(static_cast<unsigned char>(c))) {
      throw RenderError("Invalid hex character in color: '" + s + "'");
    }
  }
  // Uppercase for consistency
  std::ranges::transform(h, h.begin(), [](unsigned char c) {
    return static_cast<char>(std::toupper(c));
  });
  return Color{h};
}

// ---------------------------------------------------------------------------
// Conversion helpers
// ---------------------------------------------------------------------------

int64_t emu_to_twips(int64_t emu) { return emu / EMU_PER_TWIP; }

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
    return Length::from_emu(h); // swap for landscape
  }
  return Length::from_emu(w);
}

Length PageConfig::page_height() const {
  auto [w, h] = page_size_dimensions(size);
  if (orientation == Orientation::Landscape) {
    return Length::from_emu(w); // swap for landscape
  }
  return Length::from_emu(h);
}

Length PageConfig::usable_width() const {
  return page_width() - margins.left - margins.right;
}

Length PageConfig::usable_height() const {
  return page_height() - margins.top - margins.bottom;
}

} // namespace kstfl
