// kstfl/logical_table.h — Build logical row stream from data + styleRows
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_LOGICAL_TABLE_H
#define KSTFL_LOGICAL_TABLE_H

#include "types.h"
#include <vector>

namespace kstfl {

/// Builds the logical table model from a TFLSpec + DataTable.
class LogicalTableBuilder {
public:
    /// Build the complete logical table.
    /// @param spec  The parsed TFL specification.
    /// @param data  The parsed data table.
    /// @return Logical row stream + header grid.
    struct Result {
        HeaderGrid header_grid;
        std::vector<LogicalRow> rows;
        std::vector<size_t> grouping_col_indices;  // columns with isGrouping=true
    };

    static Result build(const TFLSpec& spec, const DataTable& data);

private:
    /// Build header grid from stubColumns + column labels.
    static HeaderGrid build_header_grid(const TFLSpec& spec);

    /// Build initial row list from data.
    static std::vector<LogicalRow> build_data_rows(const TFLSpec& spec, const DataTable& data);

    /// Apply dedupe to rows.
    static void apply_dedupe(std::vector<LogicalRow>& rows, const std::vector<ColumnSpec>& columns);

    /// Apply styleRows actions (style, merge, add_row, page_break).
    /// Expands the row stream with synthetic rows.
    /// @param data  The full data table (needed for value_from on invisible columns).
    static std::vector<LogicalRow> apply_style_rows(
        std::vector<LogicalRow>& rows,
        const std::vector<RowActionSet>& style_rows,
        const std::vector<ColumnSpec>& columns,
        const DataTable& data);

    /// Detect grouping boundaries.
    static void detect_grouping_boundaries(
        std::vector<LogicalRow>& rows,
        const std::vector<ColumnSpec>& columns);
};

}  // namespace kstfl

#endif  // KSTFL_LOGICAL_TABLE_H
