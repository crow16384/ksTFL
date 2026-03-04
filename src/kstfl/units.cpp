// kstfl/units.cpp — Unit system: parsing, conversion, page geometry
//
// Style merge methods and OOXML enum converters live in style_types.cpp.
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

}  // namespace kstfl
