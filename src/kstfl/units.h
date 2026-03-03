// kstfl/units.h — Unit system: Length parsing, EMU/twips/pt/cm/in conversions
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_UNITS_H
#define KSTFL_UNITS_H

#include "types.h"
#include <string>

namespace kstfl {

// ---------------------------------------------------------------------------
// Unit constants
// ---------------------------------------------------------------------------

/// EMU per inch = 914400
constexpr int64_t EMU_PER_INCH = 914400;
/// EMU per cm = 360000
constexpr int64_t EMU_PER_CM = 360000;
/// EMU per point = 12700
constexpr int64_t EMU_PER_PT = 12700;
/// EMU per twip = 635 (1 twip = 1/20 pt)
constexpr int64_t EMU_PER_TWIP = 635;
/// Half-points per point (OOXML uses half-points for font sizes)
constexpr int HALF_POINTS_PER_PT = 2;
/// Twips per inch
constexpr int64_t TWIPS_PER_INCH = 1440;

// ---------------------------------------------------------------------------
// Page size dimensions (in EMU) — portrait dimensions (width × height)
// ---------------------------------------------------------------------------

/// A4: 210 × 297 mm
constexpr int64_t A4_WIDTH_EMU  = 210 * 360000 / 10;   // 7560000
constexpr int64_t A4_HEIGHT_EMU = 297 * 360000 / 10;   // 10692000

/// A3: 297 × 420 mm
constexpr int64_t A3_WIDTH_EMU  = 297 * 360000 / 10;   // 10692000
constexpr int64_t A3_HEIGHT_EMU = 420 * 360000 / 10;   // 15120000

/// US Letter: 8.5 × 11 in
constexpr int64_t LETTER_WIDTH_EMU  = static_cast<int64_t>(8.5 * 914400);   // 7772400
constexpr int64_t LETTER_HEIGHT_EMU = static_cast<int64_t>(11.0 * 914400);  // 10058400

/// US Legal: 8.5 × 14 in
constexpr int64_t LEGAL_WIDTH_EMU  = static_cast<int64_t>(8.5 * 914400);    // 7772400
constexpr int64_t LEGAL_HEIGHT_EMU = static_cast<int64_t>(14.0 * 914400);   // 12801600

/// Executive: 7.25 × 10.5 in
constexpr int64_t EXECUTIVE_WIDTH_EMU  = static_cast<int64_t>(7.25 * 914400);  // 6629400
constexpr int64_t EXECUTIVE_HEIGHT_EMU = static_cast<int64_t>(10.5 * 914400);  // 9601200

// ---------------------------------------------------------------------------
// Functions
// ---------------------------------------------------------------------------

/// Get portrait dimensions for a standard paper size.
/// Returns {width, height} in EMU.
std::pair<int64_t, int64_t> page_size_dimensions(PageSize size);

/// Parse a unit-bearing string like "2.54cm", "1in", "72pt", "50%".
/// For percent, `reference_emu` is the base.
/// Throws RenderError on invalid input.
Length parse_length(const std::string& s, int64_t reference_emu = 0);

/// Convert EMU to OOXML twips (dxa) for table widths, margins, etc.
int64_t emu_to_twips(int64_t emu);

/// Convert EMU to OOXML half-points (for font sizes; 1 pt = 2 half-points).
int emu_to_half_points(int64_t emu);

/// Convert pt to OOXML half-points.
int pt_to_half_points(double pt);

/// Convert pt to OOXML eighth-points (for border widths; 1 pt = 8 eighth-pts).
int pt_to_eighth_points(double pt);

}  // namespace kstfl

#endif  // KSTFL_UNITS_H
