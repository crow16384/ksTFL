// kstfl/logical_table.cpp — Build logical row stream from data + styleRows
//
// Implements spec §11–12: row stream construction, dedupe, styleRows expansion,
// grouping boundary detection.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include "logical_table.h"
#include <algorithm>
#include <numeric>
#include <unordered_set>
#include <cstdio>
#include <cstdlib>
#include <cerrno>
#include <regex>

namespace kstfl {

// ---------------------------------------------------------------------------
// Validate a printf-style format string for safe single-value numeric formatting.
// Allows optional literal prefix/suffix around exactly one conversion specifier
// of the form %[flags][width][.precision][diuoxXfFeEgG].
// Returns true if safe, false if the format should be rejected.
// ---------------------------------------------------------------------------
static bool is_safe_numeric_format(const std::string& fmt) {
    static const std::regex safe_re(
        R"(^[^%]*%[-+ 0#]*[0-9]*(?:\.[0-9]+)?[diuoxXfFeEgG][^%]*$)");
    return std::regex_match(fmt, safe_re);
}

// ---------------------------------------------------------------------------
// Helper: apply column format string to a cell value
// Format strings: "%s" (passthrough), "%.Nf" (N decimal places), "%d" (integer)
// If the value can't be parsed as a number, return it unchanged.
// ---------------------------------------------------------------------------
static std::string apply_column_format(const std::string& value,
                                        const ColumnFormat& fmt) {
    // No format specified or empty value — return as-is
    if (!fmt.format.has_value() || fmt.format->empty() || value.empty()) {
        return value;
    }

    const std::string& format_str = *fmt.format;

    // "%s" — passthrough for strings
    if (format_str == "%s") {
        return value;
    }

    if (!is_safe_numeric_format(format_str)) {
        return value;
    }

    // Numeric formats: try to parse value as double
    char* end = nullptr;
    errno = 0;
    double dval = std::strtod(value.c_str(), &end);
    if (end == value.c_str() || errno == ERANGE) {
        return value;
    }

    // Determine whether the specifier is integer or floating-point by
    // finding the actual conversion character (last char matched by the regex).
    char spec_char = 0;
    for (auto it = format_str.rbegin(); it != format_str.rend(); ++it) {
        if (std::string("diuoxXfFeEgG").find(*it) != std::string::npos) {
            spec_char = *it;
            break;
        }
    }

    char buf[128];
    int n;
    if (spec_char == 'd' || spec_char == 'i' || spec_char == 'u' ||
        spec_char == 'o' || spec_char == 'x' || spec_char == 'X') {
        n = std::snprintf(buf, sizeof(buf), format_str.c_str(),
                          static_cast<int>(dval));
    } else {
        n = std::snprintf(buf, sizeof(buf), format_str.c_str(), dval);
    }
    if (n > 0 && n < static_cast<int>(sizeof(buf))) {
        return std::string(buf, static_cast<size_t>(n));
    }

    return value;
}

// ---------------------------------------------------------------------------
// build_header_grid: construct multi-row header from stubColumns + column labels
// Spec §9: sort by stubOrder descending, build spanning header grid
// ---------------------------------------------------------------------------

HeaderGrid LogicalTableBuilder::build_header_grid(const TFLSpec& spec) {
    HeaderGrid grid;

    if (spec.columns.empty()) return grid;

    // Build column ID → index map
    std::unordered_map<std::string, size_t> col_id_to_idx;
    for (size_t i = 0; i < spec.columns.size(); ++i) {
        col_id_to_idx[spec.columns[i].id] = i;
    }

    // Sort stub columns by stubOrder descending (higher = top)
    std::vector<StubColumn> stubs = spec.stub_columns;
    std::sort(stubs.begin(), stubs.end(), [](const StubColumn& a, const StubColumn& b) {
        return a.stub_order > b.stub_order;
    });

    // Determine stub depth (number of header rows above the column-label row)
    size_t stub_depth = stubs.empty() ? 0 : 1;
    if (!stubs.empty()) {
        // Group stubs by stubOrder level
        std::vector<int> levels;
        for (const auto& s : stubs) {
            if (levels.empty() || levels.back() != s.stub_order) {
                levels.push_back(s.stub_order);
            }
        }
        stub_depth = levels.size();
    }

    // Build stub rows
    // Each stub row corresponds to a stubOrder level.
    // Track per-column vertical merge state across levels so that
    // non-spanned columns show their label only once (in the topmost row)
    // and emit vMerge::Continue for all rows below.
    //
    // Column state:
    //   has_vmerge_restart[col] = true  → col has vMerge::Restart from a higher row
    //   covered_by_span[col]   = true  → col is inside a multi-column span from a higher row
    std::vector<bool> has_vmerge_restart(spec.columns.size(), false);
    std::vector<bool> covered_by_span(spec.columns.size(), false);

    if (stub_depth > 0) {
        // Get distinct levels
        std::vector<int> levels;
        for (const auto& s : stubs) {
            if (levels.empty() || levels.back() != s.stub_order) {
                levels.push_back(s.stub_order);
            }
        }

        for (int level : levels) {
            std::vector<HeaderGridCell> row;
            // Collect stubs at this level
            std::vector<const StubColumn*> level_stubs;
            for (const auto& s : stubs) {
                if (s.stub_order == level) {
                    level_stubs.push_back(&s);
                }
            }

            // Track which column indices are covered by stubs at this level
            std::vector<bool> covered(spec.columns.size(), false);

            // Sort level_stubs by the minimum column index in their cols
            std::sort(level_stubs.begin(), level_stubs.end(),
                      [&](const StubColumn* a, const StubColumn* b) {
                size_t min_a = spec.columns.size(), min_b = spec.columns.size();
                for (const auto& c : a->cols) {
                    auto it = col_id_to_idx.find(c);
                    if (it != col_id_to_idx.end()) min_a = std::min(min_a, it->second);
                }
                for (const auto& c : b->cols) {
                    auto it = col_id_to_idx.find(c);
                    if (it != col_id_to_idx.end()) min_b = std::min(min_b, it->second);
                }
                return min_a < min_b;
            });

            // Fill the row: iterate columns left to right
            size_t col_idx = 0;
            while (col_idx < spec.columns.size()) {
                // Check if this column is the start of a stub span
                const StubColumn* matching_stub = nullptr;
                for (const auto* stub : level_stubs) {
                    for (const auto& c : stub->cols) {
                        if (col_id_to_idx.count(c) && col_id_to_idx[c] == col_idx) {
                            matching_stub = stub;
                            break;
                        }
                    }
                    if (matching_stub) break;
                }

                if (matching_stub) {
                    // Compute span
                    int span = 0;
                    Length total_width{0};
                    for (const auto& c : matching_stub->cols) {
                        auto it = col_id_to_idx.find(c);
                        if (it != col_id_to_idx.end()) {
                            covered[it->second] = true;
                            // Mark columns as covered by a horizontal span
                            // (so lower levels know they can't vMerge with them)
                            covered_by_span[it->second] = true;
                            // If this column previously had vMerge, the span overrides it
                            has_vmerge_restart[it->second] = false;
                            total_width = total_width + spec.columns[it->second].resolved_width;
                            span++;
                        }
                    }

                    HeaderGridCell cell;
                    cell.label = matching_stub->label;
                    cell.col_span = span;
                    cell.row_span = 1;
                    cell.width = total_width;
                    cell.style_ref = matching_stub->label_style_ref;
                    row.push_back(cell);

                    // Advance past spanned columns
                    col_idx += static_cast<size_t>(span);
                } else {
                    // Column not covered by any stub at this level.
                    HeaderGridCell cell;
                    cell.col_span = 1;
                    cell.row_span = 1;
                    cell.width = spec.columns[col_idx].resolved_width;

                    if (has_vmerge_restart[col_idx]) {
                        // Already has vMerge from a higher row → continue
                        cell.label = "";
                        cell.v_merge = VMergeState::Continue;
                    } else if (covered_by_span[col_idx]) {
                        // Part of a horizontal span above → empty filler cell
                        cell.label = "";
                    } else {
                        // First time seeing this column uncovered → start vMerge
                        cell.label = spec.columns[col_idx].label;
                        cell.style_ref = spec.columns[col_idx].label_style_ref;
                        cell.v_merge = VMergeState::Restart;
                        has_vmerge_restart[col_idx] = true;
                    }

                    row.push_back(cell);
                    col_idx++;
                }
            }
            grid.rows.push_back(std::move(row));
        }
    }

    // Bottom row: individual column labels
    // If a column is vertically merged from a stub row above (vMerge::Restart),
    // mark its label-row cell as vMerge::Continue (empty continuation cell).
    std::vector<HeaderGridCell> label_row;
    for (size_t ci = 0; ci < spec.columns.size(); ++ci) {
        HeaderGridCell cell;
        cell.col_span = 1;
        cell.row_span = 1;
        cell.width = spec.columns[ci].resolved_width;

        // Check if this column has vMerge::Restart in ANY stub row above
        if (has_vmerge_restart[ci]) {
            cell.label = "";
            cell.v_merge = VMergeState::Continue;
        } else {
            cell.label = spec.columns[ci].label;
            cell.style_ref = spec.columns[ci].label_style_ref;
        }

        label_row.push_back(cell);
    }
    grid.rows.push_back(std::move(label_row));

    return grid;
}

// ---------------------------------------------------------------------------
// build_data_rows: create initial LogicalRow stream from DataTable
// ---------------------------------------------------------------------------

std::vector<LogicalRow> LogicalTableBuilder::build_data_rows(const TFLSpec& spec,
                                                              const DataTable& data) {
    std::vector<LogicalRow> rows;
    if (data.n_rows == 0) return rows;

    rows.reserve(data.n_rows);

    for (size_t row_idx = 0; row_idx < data.n_rows; ++row_idx) {
        LogicalRow lr;
        lr.type = LogicalRowType::DataRow;
        lr.source_index = row_idx;

        for (const auto& col : spec.columns) {
            LogicalCell cell;
            cell.col_id = col.id;

            // Get value from data
            auto col_it = data.columns.find(col.id);
            if (col_it != data.columns.end() && row_idx < col_it->second.size()) {
                cell.text = col_it->second[row_idx];
            } else {
                cell.text = "";
            }

            // Apply missings replacement if needed
            if (cell.text.empty() || cell.text == "NA") {
                if (col.format.missings.has_value() && !col.format.missings->empty()) {
                    cell.text = col.format.missings.value();
                }
            } else {
                // Apply column format string (e.g., "%.1f" for numeric)
                cell.text = apply_column_format(cell.text, col.format);
            }

            lr.cells.push_back(std::move(cell));
        }

        rows.push_back(std::move(lr));
    }

    return rows;
}

// ---------------------------------------------------------------------------
// apply_dedupe: suppress consecutive duplicate values in deduped columns
// ---------------------------------------------------------------------------

void LogicalTableBuilder::apply_dedupe(std::vector<LogicalRow>& rows,
                                        const std::vector<ColumnSpec>& columns) {
    if (rows.empty()) return;

    // Find columns with dedupe=true
    std::vector<size_t> dedupe_indices;
    for (size_t i = 0; i < columns.size(); ++i) {
        if (columns[i].dedupe) {
            dedupe_indices.push_back(i);
        }
    }

    if (dedupe_indices.empty()) return;

    // For each dedupe column, blank out consecutive duplicate values
    for (size_t col_idx : dedupe_indices) {
        std::string prev_value;
        for (size_t ri = 0; ri < rows.size(); ++ri) {
            if (rows[ri].type != LogicalRowType::DataRow) continue;
            if (col_idx >= rows[ri].cells.size()) continue;

            auto& cell = rows[ri].cells[col_idx];
            if (ri == 0) {
                prev_value = cell.text;
            } else {
                if (cell.text == prev_value) {
                    cell.text = "";  // suppress duplicate
                } else {
                    prev_value = cell.text;
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// apply_style_rows: expand row stream with styleRows actions
// Spec §12: style, merge, add_row, page_break
// ---------------------------------------------------------------------------

std::vector<LogicalRow> LogicalTableBuilder::apply_style_rows(
    std::vector<LogicalRow>& rows,
    const std::vector<RowActionSet>& style_rows,
    const std::vector<ColumnSpec>& columns,
    const DataTable& data) {

    if (style_rows.empty()) return std::move(rows);

    // Build column id -> cell index map (visible columns only)
    std::unordered_map<std::string, size_t> col_to_idx;
    for (size_t i = 0; i < columns.size(); ++i) {
        col_to_idx[columns[i].id] = i;
    }

    // Helper: get a value from the DataTable for a given column and row index.
    // This works for both visible and invisible columns.
    auto get_data_value = [&](const std::string& col_id, size_t row_index) -> std::string {
        auto it = data.columns.find(col_id);
        if (it != data.columns.end() && row_index < it->second.size()) {
            return it->second[row_index];
        }
        return "";
    };

    // Helper: build a full-width merged synthetic row.
    // All columns are merged into one cell with the text from value_from column.
    auto build_addrow_synthetic = [&](size_t src_idx, const AddRowAction& ar) -> LogicalRow {
        LogicalRow synthetic;
        synthetic.type = LogicalRowType::SyntheticRow;
        synthetic.source_index = src_idx;
        synthetic.row_style_ref = ar.style_ref;

        // Get the value: try DataTable first (handles invisible columns),
        // then fall back to visible column cells
        std::string value_text = get_data_value(ar.value_from, src_idx);

        // Build cells: first cell is the merge leader spanning all visible columns
        Length total_width{0};
        for (const auto& col : columns) {
            total_width = total_width + col.resolved_width;
        }

        for (size_t ci = 0; ci < columns.size(); ++ci) {
            LogicalCell cell;
            cell.col_id = columns[ci].id;
            if (ci == 0) {
                // Leader cell: carries the value and spans all columns
                cell.text = value_text;
                cell.is_merge_leader = true;
                cell.merge_span = static_cast<int>(columns.size());
                cell.merged_width = total_width;
                if (ar.style_ref.has_value()) {
                    cell.style_ref = ar.style_ref;
                }
            } else {
                // Merged (suppressed) cells
                cell.is_merged = true;
            }
            synthetic.cells.push_back(std::move(cell));
        }
        return synthetic;
    };

    std::vector<LogicalRow> result;
    result.reserve(rows.size() * 2);  // conservative estimate

    for (size_t ri = 0; ri < rows.size(); ++ri) {
        auto& row = rows[ri];
        if (row.type != LogicalRowType::DataRow) {
            result.push_back(std::move(row));
            continue;
        }

        // Get the action set for this source row
        size_t src_idx = row.source_index;
        const RowActionSet* actions = nullptr;
        if (src_idx < style_rows.size()) {
            actions = &style_rows[src_idx];
        }

        if (!actions || actions->empty()) {
            result.push_back(std::move(row));
            continue;
        }

        // --- add_row "above" insertions ---
        for (const auto& ar : actions->add_rows) {
            if (ar.pos == AddRowAction::Position::Above) {
                result.push_back(build_addrow_synthetic(src_idx, ar));
            }
        }

        // --- page_break ---
        if (!actions->page_breaks.empty()) {
            row.force_page_break = true;
        }

        // --- style actions ---
        for (const auto& sa : actions->styles) {
            for (const auto& col_id : sa.cols) {
                auto it = col_to_idx.find(col_id);
                if (it != col_to_idx.end() && it->second < row.cells.size()) {
                    row.cells[it->second].style_ref = sa.style_ref;
                }
            }
        }

        // --- merge actions ---
        for (const auto& ma : actions->merges) {
            if (ma.cols.empty()) continue;

            // Find the visible column indices for this merge
            std::vector<size_t> merge_indices;
            for (const auto& col_id : ma.cols) {
                auto it = col_to_idx.find(col_id);
                if (it != col_to_idx.end()) {
                    merge_indices.push_back(it->second);
                }
            }

            // Even with 1 visible column, we may need to apply value_from logic:
            // if the first column in the merge list is invisible, bring its value
            // to the first visible column.
            if (merge_indices.empty()) continue;

            // Sort indices
            std::sort(merge_indices.begin(), merge_indices.end());

            // Check if the first column in the merge list is invisible
            // (i.e., not present in col_to_idx). If so, bring its value
            // to the first visible column in the merge.
            const std::string& first_merge_col = ma.cols[0];
            bool first_is_invisible = (col_to_idx.find(first_merge_col) == col_to_idx.end());
            if (first_is_invisible) {
                // Get value from the invisible column via DataTable
                std::string invisible_val = get_data_value(first_merge_col, src_idx);
                size_t leader_idx = merge_indices[0];
                if (leader_idx < row.cells.size() && !invisible_val.empty()) {
                    row.cells[leader_idx].text = invisible_val;
                }
            }

            // Apply merge if 2+ visible columns
            if (merge_indices.size() >= 2) {
                size_t leader_idx = merge_indices[0];
                if (leader_idx < row.cells.size()) {
                    row.cells[leader_idx].is_merge_leader = true;
                    row.cells[leader_idx].merge_span = static_cast<int>(merge_indices.size());

                    // Compute combined width
                    Length combined{0};
                    for (size_t idx : merge_indices) {
                        if (idx < columns.size()) {
                            combined = combined + columns[idx].resolved_width;
                        }
                    }
                    row.cells[leader_idx].merged_width = combined;

                    if (ma.style_ref.has_value()) {
                        row.cells[leader_idx].style_ref = ma.style_ref;
                    }
                }

                // Mark remaining cells as merged (suppressed)
                for (size_t k = 1; k < merge_indices.size(); ++k) {
                    size_t idx = merge_indices[k];
                    if (idx < row.cells.size()) {
                        row.cells[idx].is_merged = true;
                    }
                }
            } else if (merge_indices.size() == 1) {
                // Only 1 visible column in merge — just apply style if provided
                size_t leader_idx = merge_indices[0];
                if (leader_idx < row.cells.size() && ma.style_ref.has_value()) {
                    row.cells[leader_idx].style_ref = ma.style_ref;
                }
            }
        }

        result.push_back(std::move(row));

        // --- add_row "below" insertions ---
        if (actions) {
            for (const auto& ar : actions->add_rows) {
                if (ar.pos == AddRowAction::Position::Below) {
                    result.push_back(build_addrow_synthetic(src_idx, ar));
                }
            }
        }
    }

    return result;
}

// ---------------------------------------------------------------------------
// detect_grouping_boundaries: mark rows where grouping column values change
// ---------------------------------------------------------------------------

void LogicalTableBuilder::detect_grouping_boundaries(
    std::vector<LogicalRow>& rows,
    const std::vector<ColumnSpec>& columns) {

    // Find grouping columns (isGrouping=true) and paging columns (isPaging=true)
    std::vector<size_t> grouping_indices;
    std::vector<size_t> paging_indices;
    for (size_t i = 0; i < columns.size(); ++i) {
        if (columns[i].is_grouping || columns[i].is_paging) {
            grouping_indices.push_back(i);
        }
        if (columns[i].is_paging) {
            paging_indices.push_back(i);
        }
    }

    if (grouping_indices.empty()) return;

    // Track previous grouping values
    std::unordered_map<std::string, std::string> prev_group_values;

    for (auto& row : rows) {
        if (row.type == LogicalRowType::SyntheticRow) continue;

        // Read current grouping column values
        std::unordered_map<std::string, std::string> current_values;
        for (size_t gi : grouping_indices) {
            if (gi < row.cells.size()) {
                current_values[columns[gi].id] = row.cells[gi].text;
            }
        }

        // Check for changes
        if (!prev_group_values.empty()) {
            bool changed = false;
            for (const auto& [col_id, val] : current_values) {
                auto it = prev_group_values.find(col_id);
                if (it == prev_group_values.end() || it->second != val) {
                    changed = true;
                    break;
                }
            }
            if (changed) {
                row.is_group_boundary = true;

                // Check if change is in a paging column — force page break
                for (size_t pi : paging_indices) {
                    if (pi < row.cells.size()) {
                        const auto& col_id = columns[pi].id;
                        auto it_cur = current_values.find(col_id);
                        auto it_prev = prev_group_values.find(col_id);
                        if (it_cur != current_values.end() &&
                            (it_prev == prev_group_values.end() || it_prev->second != it_cur->second)) {
                            row.force_page_break = true;
                            break;
                        }
                    }
                }
            }
        }

        row.group_values = current_values;
        prev_group_values = current_values;
    }
}

// ---------------------------------------------------------------------------
// build: main entry point
// ---------------------------------------------------------------------------

LogicalTableBuilder::Result LogicalTableBuilder::build(const TFLSpec& spec,
                                                        const DataTable& data) {
    Result result;

    // 1. Build header grid
    result.header_grid = build_header_grid(spec);

    // 2. Build initial data rows
    auto rows = build_data_rows(spec, data);

    // 3. Detect grouping boundaries (BEFORE dedupe, which blanks cell text)
    detect_grouping_boundaries(rows, spec.columns);

    // 4. Apply dedupe (blanks consecutive duplicate values)
    apply_dedupe(rows, spec.columns);

    // 5. Apply styleRows actions (expands row stream with synthetic rows)
    rows = apply_style_rows(rows, spec.style_rows, spec.columns, data);

    // 6. Collect grouping column indices (isGrouping or isPaging)
    for (size_t i = 0; i < spec.columns.size(); ++i) {
        if (spec.columns[i].is_grouping || spec.columns[i].is_paging) {
            result.grouping_col_indices.push_back(i);
        }
    }

    result.rows = std::move(rows);
    return result;
}

}  // namespace kstfl
