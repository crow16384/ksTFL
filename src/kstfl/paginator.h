// kstfl/paginator.h — Deterministic vertical + horizontal pagination
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#ifndef KSTFL_PAGINATOR_H
#define KSTFL_PAGINATOR_H

#include "types.h"
#include "text_measurer.h"
#include "style_resolver.h"
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
        const std::vector<LogicalRow>& rows,
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
    static Length compute_available_height(
        const PageConfig& page,
        Length header_section_height,
        Length titles_height,
        Length subtitles_height,
        Length table_header_height,
        Length footnotes_height,
        Length footer_section_height,
        bool is_first_page,
        bool is_last_page,
        bool body_footnotes);

    /// Compute row heights for the full logical row set (all columns).
    /// Row heights are shared across horizontal segments.
    static std::vector<Length> compute_row_heights(
        const std::vector<LogicalRow>& rows,
        const std::vector<ColumnSpec>& columns,
        const TextMeasurer& measurer,
        const StyleResolver& resolver);
};

}  // namespace kstfl

#endif  // KSTFL_PAGINATOR_H
