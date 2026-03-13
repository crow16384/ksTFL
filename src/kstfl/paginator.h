// kstfl/paginator.h — Deterministic vertical + horizontal pagination
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_PAGINATOR_H
#define KSTFL_PAGINATOR_H

#include "types.h"
#include "text_measurer.h"
#include "style_resolver.h"
#include <unordered_map>
#include <vector>

namespace kstfl {

/// Deterministic table paginator.
class Paginator {
public:
    /// Paginate a logical table.
    /// @param spec  The TFL specification.
    /// @param rows  Logical row stream (from LogicalTableBuilder).
    /// @param header_grid  The table header grid.
    /// @param page_config  Resolved page configuration.
    /// @param table_width  Resolved table width.
    /// @param measurer  Text measurer for dynamic subtitle heights.
    /// @param resolver  Style resolver.
    /// @return Pagination result with horizontal segments and page slices.
    static PaginationResult paginate(
        const TFLSpec& spec,
        std::vector<LogicalRow>& rows,
        const HeaderGrid& header_grid,
        const PageConfig& page_config,
        Length table_width,
        const TextMeasurer& measurer,
        const StyleResolver& resolver);

private:
    /// Build horizontal segments from isColBreak columns.
    static std::vector<HorizontalSegment> build_segments(
        const std::vector<ColumnSpec>& columns);

    /// Compute available body height for a page.
    /// Footnotes height is always subtracted when passed (caller decides
    /// whether to pass footnotes_height or Length{0}).
    static Length compute_available_height(
        const PageConfig& page,
        Length header_section_height,
        Length titles_height,
        Length subtitles_height,
        Length table_header_height,
        Length footnotes_height,
        Length footer_section_height);

    /// Compute row heights for the full logical row set (all columns).
    /// Row heights are shared across horizontal segments.
    static std::vector<Length> compute_row_heights(
        const std::vector<LogicalRow>& rows,
        const std::vector<ColumnSpec>& columns,
        const TextMeasurer& measurer,
        const StyleResolver& resolver);

    /// Compute scaled column widths for a horizontal segment.
    /// ID columns keep their original width; non-ID columns are scaled
    /// to fill the full table width.
    static std::unordered_map<size_t, int64_t> compute_segment_column_widths(
        const std::vector<ColumnSpec>& columns,
        const HorizontalSegment& segment);

    /// Compute row heights for a specific segment using scaled column widths.
    /// When isColBreak splits a table, each segment has wider columns, so
    /// text wraps differently and row heights must be recalculated.
    static std::vector<Length> compute_segment_row_heights(
        const std::vector<LogicalRow>& rows,
        const std::vector<ColumnSpec>& columns,
        const HorizontalSegment& segment,
        const std::unordered_map<size_t, int64_t>& scaled_widths,
        const TextMeasurer& measurer,
        const StyleResolver& resolver);
};

}  // namespace kstfl

#endif  // KSTFL_PAGINATOR_H
