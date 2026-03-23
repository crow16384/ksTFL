// kstfl/logical_table.cpp — Build logical row stream from data + styleRows
//
// Implements spec §11–12: row stream construction, dedupe, styleRows expansion,
// grouping boundary detection.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "logical_table.h"
#include <algorithm>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <ranges>

namespace kstfl {

// ---------------------------------------------------------------------------
// Validate a printf-style format string for safe single-value numeric
// formatting. Allows optional literal prefix/suffix around exactly one
// conversion specifier of the form %[flags][width][.precision][diuoxXfFeEgG].
// Returns true if safe, false if the format should be rejected.
// Manual parser replacing std::regex for hot-path performance.
// ---------------------------------------------------------------------------
bool is_safe_numeric_format(const std::string &fmt) {
  const char *p = fmt.c_str();

  // Skip optional literal prefix (everything before '%')
  while (*p && *p != '%')
    ++p;
  if (*p != '%') return false; // no conversion specifier
  ++p;                         // skip '%'

  // Reject "%%" (literal percent — not a conversion)
  if (*p == '%') return false;

  // Flags: any of [-+ 0#]
  while (*p == '-' || *p == '+' || *p == ' ' || *p == '0' || *p == '#')
    ++p;

  // Width: optional digits
  while (*p >= '0' && *p <= '9')
    ++p;

  // Precision: optional . followed by digits
  if (*p == '.') {
    ++p;
    while (*p >= '0' && *p <= '9')
      ++p;
  }

  // Conversion specifier: exactly one of [diuoxXfFeEgG]
  static constexpr char specs[] = "diuoxXfFeEgG";
  bool found_spec = false;
  for (const char *s = specs; *s; ++s) {
    if (*p == *s) {
      found_spec = true;
      break;
    }
  }
  if (!found_spec) return false;
  ++p; // skip the specifier

  // Remainder must be literal suffix (no more '%' allowed)
  while (*p) {
    if (*p == '%') return false;
    ++p;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Helper: apply column format string to a cell value
// Format strings: "%s" (passthrough), "%.Nf" (N decimal places), "%d" (integer)
// If the value can't be parsed as a number, return it unchanged.
// ---------------------------------------------------------------------------
static std::string apply_column_format(const std::string &value, const ColumnFormat &fmt) {
  // No format specified or empty value — return as-is
  if (!fmt.format.has_value() || fmt.format->empty() || value.empty()) { return value; }

  const std::string &format_str = *fmt.format;

  // "%s" — passthrough for strings
  if (format_str == "%s") { return value; }

  if (!is_safe_numeric_format(format_str)) { return value; }

  // Numeric formats: try to parse value as double
  char *end = nullptr;
  errno = 0;
  double dval = std::strtod(value.c_str(), &end);
  if (end == value.c_str() || errno == ERANGE) { return value; }

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
  if (spec_char == 'd' || spec_char == 'i' || spec_char == 'u' || spec_char == 'o' || spec_char == 'x' ||
      spec_char == 'X') {
    n = std::snprintf(buf, sizeof(buf), format_str.c_str(), static_cast<int>(dval));
  } else {
    n = std::snprintf(buf, sizeof(buf), format_str.c_str(), dval);
  }
  if (n > 0 && n < static_cast<int>(sizeof(buf))) { return std::string(buf, static_cast<size_t>(n)); }

  return value;
}

// ---------------------------------------------------------------------------
// build_header_grid: construct multi-row header from stubColumns + column
// labels Spec §9: sort by stubOrder descending, build spanning header grid
// ---------------------------------------------------------------------------

HeaderGrid LogicalTableBuilder::build_header_grid(const TFLSpec &spec, const ColIdxMap &col_id_to_idx) {
  HeaderGrid grid;

  if (spec.columns.empty()) return grid;

  // Sort stub columns by stubOrder descending (higher = top)
  std::vector<StubColumn> stubs = spec.stub_columns;
  std::ranges::sort(stubs, [](const StubColumn &a, const StubColumn &b) { return a.stub_order > b.stub_order; });

  // Determine stub depth (number of header rows above the column-label row)
  size_t stub_depth = stubs.empty() ? 0 : 1;
  if (!stubs.empty()) {
    // Group stubs by stubOrder level
    std::vector<int> levels;
    for (const auto &s : stubs) {
      if (levels.empty() || levels.back() != s.stub_order) { levels.push_back(s.stub_order); }
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
  //   has_vmerge_restart[col] = true  → col has vMerge::Restart from a higher
  //   row covered_by_span[col]   = true  → col is inside a multi-column span
  //   from a higher row
  std::vector<bool> has_vmerge_restart(spec.columns.size(), false);
  std::vector<bool> covered_by_span(spec.columns.size(), false);

  if (stub_depth > 0) {
    // Get distinct levels
    std::vector<int> levels;
    for (const auto &s : stubs) {
      if (levels.empty() || levels.back() != s.stub_order) { levels.push_back(s.stub_order); }
    }

    for (int level : levels) {
      std::vector<HeaderGridCell> row;
      // Collect stubs at this level
      std::vector<const StubColumn *> level_stubs;
      for (const auto &s : stubs) {
        if (s.stub_order == level) { level_stubs.push_back(&s); }
      }

      // Track which column indices are covered by stubs at this level
      std::vector<bool> covered(spec.columns.size(), false);

      // Sort level_stubs by the minimum column index in their cols
      std::ranges::sort(level_stubs, [&](const StubColumn *a, const StubColumn *b) {
        size_t min_a = spec.columns.size(), min_b = spec.columns.size();
        for (const auto &c : a->cols) {
          auto it = col_id_to_idx.find(c);
          if (it != col_id_to_idx.end()) min_a = std::min(min_a, it->second);
        }
        for (const auto &c : b->cols) {
          auto it = col_id_to_idx.find(c);
          if (it != col_id_to_idx.end()) min_b = std::min(min_b, it->second);
        }
        return min_a < min_b;
      });

      // Fill the row: iterate visible columns left to right
      size_t col_idx = 0;
      while (col_idx < spec.columns.size()) {
        if (!spec.columns[col_idx].is_visible) {
          col_idx++;
          continue;
        }

        // Check if this column is the start of a stub span
        const StubColumn *matching_stub = nullptr;
        for (const auto *stub : level_stubs) {
          for (const auto &c : stub->cols) {
            auto ci = col_id_to_idx.find(c);
            if (ci != col_id_to_idx.end() && ci->second == col_idx) {
              matching_stub = stub;
              break;
            }
          }
          if (matching_stub) break;
        }

        if (matching_stub) {
          // Compute span across original indices; track min/max for range.
          Length total_width{0};
          size_t min_idx = spec.columns.size(), max_idx = 0;
          for (const auto &c : matching_stub->cols) {
            auto it = col_id_to_idx.find(c);
            if (it != col_id_to_idx.end() && spec.columns[it->second].is_visible) {
              covered[it->second] = true;
              covered_by_span[it->second] = true;
              // Do NOT reset has_vmerge_restart here — a column that
              // started a vertical merge at a higher level must keep
              // its Restart lineage so that lower rows and the label
              // row emit Continue markers.
              total_width = total_width + spec.columns[it->second].resolved_width;
              min_idx = std::min(min_idx, it->second);
              max_idx = std::max(max_idx, it->second);
            }
          }
          // col_span in original index space so emitter can iterate the range
          int span_orig = (min_idx <= max_idx) ? static_cast<int>(max_idx - min_idx + 1) : 1;

          HeaderGridCell cell;
          cell.label = matching_stub->label;
          cell.col_span = span_orig;
          cell.row_span = 1;
          cell.width = total_width;
          cell.style_ref = matching_stub->label_style_ref;
          cell.source_col_index = min_idx;
          row.push_back(cell);

          // Advance col_idx past the spanned range
          col_idx = max_idx + 1;
          // Skip any trailing invisible columns
          while (col_idx < spec.columns.size() && !spec.columns[col_idx].is_visible) {
            col_idx++;
          }
        } else {
          // Column not covered by any stub at this level.
          HeaderGridCell cell;
          cell.col_span = 1;
          cell.row_span = 1;
          cell.width = spec.columns[col_idx].resolved_width;
          cell.source_col_index = col_idx;

          if (has_vmerge_restart[col_idx]) {
            // Column already has a Restart from a higher row —
            // emit an empty continuation cell.
            cell.label = "";
            cell.v_merge = VMergeState::Continue;
          } else if (covered_by_span[col_idx]) {
            // Column was part of a horizontal span at a higher
            // level but is uncovered at this level.  Emit an
            // empty placeholder; a post-pass will promote
            // lower-level stubs into these gaps.
            cell.label = "";
          } else {
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

  // -----------------------------------------------------------------------
  // Post-pass: promote lower-level stubs into gap cells.
  //
  // When a column is covered by a horizontal span at a higher level but
  // uncovered at an intermediate level, the intermediate row has an empty
  // placeholder cell.  If a stub at a lower level covers the same columns,
  // we promote it: place the stub content at the first gap row and mark
  // all rows below (up to and including the stub's original row) as
  // vMerge::Continue so that Word merges cells vertically.
  // -----------------------------------------------------------------------
  for (size_t ri = 0; ri + 1 < grid.rows.size(); ++ri) {
    for (size_t ci = 0; ci < grid.rows[ri].size(); ++ci) {
      auto &gap = grid.rows[ri][ci];
      // Only consider empty placeholder cells (no vMerge state).
      if (!gap.label.empty() || gap.v_merge != VMergeState::None || gap.col_span != 1) { continue; }
      size_t src = gap.source_col_index;

      // Look for a span cell at a lower row whose range covers src.
      for (size_t lri = ri + 1; lri < grid.rows.size(); ++lri) {
        for (size_t lci = 0; lci < grid.rows[lri].size(); ++lci) {
          auto &lower = grid.rows[lri][lci];
          if (lower.label.empty() || lower.col_span <= 1) continue;
          size_t lo = lower.source_col_index;
          size_t hi = lo + static_cast<size_t>(lower.col_span) - 1;
          if (src < lo || src > hi) continue;

          // Found a span [lo..hi] that covers src.
          // Verify every physical column of the span is a gap at
          // row ri (empty, no vMerge, col_span==1).
          bool all_gaps = true;
          std::vector<size_t> gap_indices; // cell indices in grid.rows[ri]
          for (size_t gi = 0; gi < grid.rows[ri].size(); ++gi) {
            auto &g = grid.rows[ri][gi];
            if (g.source_col_index >= lo && g.source_col_index <= hi) {
              if (!g.label.empty() || g.v_merge != VMergeState::None || g.col_span != 1) {
                all_gaps = false;
                break;
              }
              gap_indices.push_back(gi);
            }
          }
          if (!all_gaps) break;

          // Safety: verify gap count matches the span's
          // visible column count before erasing cells.
          {
            int visible_in_span = 0;
            for (size_t si = lo; si <= hi; ++si) {
              if (si < spec.columns.size() && spec.columns[si].is_visible) { visible_in_span++; }
            }
            if (static_cast<int>(gap_indices.size()) != visible_in_span) {
              break; // Mismatch — skip promotion
            }
          }

          // Promote: replace the first gap cell with the span
          // content and remove the remaining gap cells covered
          // by the span.
          size_t first_gi = gap_indices.front();
          auto &dest = grid.rows[ri][first_gi];
          dest.label = lower.label;
          dest.col_span = lower.col_span;
          dest.width = lower.width;
          dest.style_ref = lower.style_ref;
          dest.source_col_index = lower.source_col_index;
          // The promoted cell always needs vMerge::Restart
          // because the original position (and any intermediate
          // rows) will be marked as Continue below.
          dest.v_merge = VMergeState::Restart;

          // Remove extra gap cells that are now covered by the
          // promoted span (iterate in reverse to keep indices
          // stable).
          for (size_t k = gap_indices.size() - 1; k >= 1; --k) {
            grid.rows[ri].erase(grid.rows[ri].begin() + static_cast<std::ptrdiff_t>(gap_indices[k]));
          }

          // Mark the original span cell (and any intermediates
          // at the same column range) as Continue.
          for (size_t mri = ri + 1; mri <= lri; ++mri) {
            for (auto &mc : grid.rows[mri]) {
              if (mc.source_col_index >= lo && mc.source_col_index <= hi) {
                if (mc.source_col_index == lo && mc.col_span == lower.col_span) {
                  // The promoted span's original position
                  // — replace with individual Continue
                  // cells (one per visible column).
                  mc.label = "";
                  mc.v_merge = VMergeState::Continue;
                  mc.col_span = lower.col_span;
                } else if (mc.col_span == 1) {
                  mc.label = "";
                  mc.v_merge = VMergeState::Continue;
                }
              }
            }
          }

          // Update ci to skip past the promoted span.
          ci = first_gi; // outer loop will ++ci
          break;         // break out of lri loop; promotion done
        }
      }
    }
  }

  // -----------------------------------------------------------------------
  // Post-pass 2: fill remaining empty placeholder cells.
  //
  // After promotion, any empty placeholder cells (label.empty(),
  // v_merge==None, col_span==1) represent columns that sat inside a
  // parent span but were never covered by a child stub.  Place the
  // column label at the earliest such gap and mark cells below as
  // vMerge::Continue so the label merges down to the label row.
  // -----------------------------------------------------------------------
  for (size_t ri = 0; ri < grid.rows.size(); ++ri) {
    for (auto &cell : grid.rows[ri]) {
      if (!cell.label.empty() || cell.v_merge != VMergeState::None || cell.col_span != 1) { continue; }
      size_t ci_col = cell.source_col_index;
      if (ci_col >= spec.columns.size() || !spec.columns[ci_col].is_visible) { continue; }
      // Fill with column label at this (earliest) row.
      cell.label = spec.columns[ci_col].label;
      cell.style_ref = spec.columns[ci_col].label_style_ref;
      cell.v_merge = VMergeState::Restart;

      // Mark same-column cells in all lower stub rows as Continue.
      for (size_t lri = ri + 1; lri < grid.rows.size(); ++lri) {
        for (auto &lcell : grid.rows[lri]) {
          if (lcell.source_col_index == ci_col && lcell.col_span == 1 && lcell.v_merge == VMergeState::None &&
              lcell.label.empty()) {
            lcell.v_merge = VMergeState::Continue;
          }
        }
      }
    }
  }

  // -----------------------------------------------------------------------
  // Post-pass 3: promote individual column cells upward through span
  // cells by "peeling" them off the span's left or right edge.
  //
  // After Post-pass 2 placed column labels at the earliest empty stub
  // row, those cells may sit below a parent span that covers the same
  // column.  We iteratively peel edge columns from the parent span:
  // shrink its col_span, insert the column cell at the parent's row,
  // and mark the original position as vMerge::Continue.
  //
  // Process from the bottom stub row upward so promotions cascade
  // through multiple nesting levels.
  // -----------------------------------------------------------------------
  for (int pp3_ri = static_cast<int>(grid.rows.size()) - 1; pp3_ri >= 1; --pp3_ri) {
    bool pp3_changed = true;
    while (pp3_changed) {
      pp3_changed = false;
      for (size_t ci = 0; ci < grid.rows[pp3_ri].size(); ++ci) {
        auto &cell = grid.rows[pp3_ri][ci];
        if (cell.v_merge != VMergeState::Restart || cell.col_span != 1) continue;
        size_t col_idx = cell.source_col_index;

        // Find a span cell in the row above that covers col_idx.
        for (size_t pi = 0; pi < grid.rows[pp3_ri - 1].size(); ++pi) {
          auto &parent = grid.rows[pp3_ri - 1][pi];
          if (parent.col_span <= 1) continue;
          size_t p_lo = parent.source_col_index;
          size_t p_hi = p_lo + static_cast<size_t>(parent.col_span) - 1;
          if (col_idx < p_lo || col_idx > p_hi) continue;

          // Parent span covers this column.
          // Never peel into a named (user-defined) stub span —
          // only anonymous (empty-label) wrapper spans may be shrunk.
          if (!parent.label.empty()) break;

          // Only peel from left or right boundary.
          if (col_idx == p_lo) {
            // --- Peel from left edge ---
            HeaderGridCell promoted;
            promoted.label = cell.label;
            promoted.col_span = 1;
            promoted.row_span = 1;
            promoted.width = cell.width;
            promoted.style_ref = cell.style_ref;
            promoted.source_col_index = col_idx;
            promoted.v_merge = VMergeState::Restart;
            promoted.text_orientation = cell.text_orientation;

            // Shrink parent from the left (modify before insert
            // invalidates the reference).
            parent.source_col_index = col_idx + 1;
            parent.col_span -= 1;
            {
              Length w{0};
              size_t s_lo = parent.source_col_index;
              size_t s_hi = s_lo + static_cast<size_t>(parent.col_span) - 1;
              for (size_t si = s_lo; si <= s_hi && si < spec.columns.size(); ++si) {
                if (spec.columns[si].is_visible) w = w + spec.columns[si].resolved_width;
              }
              parent.width = w;
            }

            grid.rows[pp3_ri - 1].insert(grid.rows[pp3_ri - 1].begin() + static_cast<std::ptrdiff_t>(pi), promoted);

            // Original cell becomes Continue.
            grid.rows[pp3_ri][ci].label = "";
            grid.rows[pp3_ri][ci].v_merge = VMergeState::Continue;
            pp3_changed = true;
            break;

          } else if (col_idx == p_hi) {
            // --- Peel from right edge ---
            HeaderGridCell promoted;
            promoted.label = cell.label;
            promoted.col_span = 1;
            promoted.row_span = 1;
            promoted.width = cell.width;
            promoted.style_ref = cell.style_ref;
            promoted.source_col_index = col_idx;
            promoted.v_merge = VMergeState::Restart;
            promoted.text_orientation = cell.text_orientation;

            // Shrink parent from the right.
            parent.col_span -= 1;
            {
              Length w{0};
              size_t s_lo = parent.source_col_index;
              size_t s_hi = s_lo + static_cast<size_t>(parent.col_span) - 1;
              for (size_t si = s_lo; si <= s_hi && si < spec.columns.size(); ++si) {
                if (spec.columns[si].is_visible) w = w + spec.columns[si].resolved_width;
              }
              parent.width = w;
            }

            grid.rows[pp3_ri - 1].insert(grid.rows[pp3_ri - 1].begin() + static_cast<std::ptrdiff_t>(pi + 1), promoted);

            grid.rows[pp3_ri][ci].label = "";
            grid.rows[pp3_ri][ci].v_merge = VMergeState::Continue;
            pp3_changed = true;
            break;
          }
          // Column is in the middle of the span — cannot peel.
          break;
        }
        if (pp3_changed) break; // restart row scan
      }
    }
  }

  // After promotion, update has_vmerge_restart for the label row.
  // A column needs Continue in the label row if ANY stub row above has
  // a Restart for it (individual column, not part of a span).
  for (size_t ci_col = 0; ci_col < spec.columns.size(); ++ci_col) {
    has_vmerge_restart[ci_col] = false;
  }
  for (const auto &hrow : grid.rows) {
    for (const auto &hcell : hrow) {
      if (hcell.v_merge == VMergeState::Restart && hcell.col_span == 1) {
        has_vmerge_restart[hcell.source_col_index] = true;
      }
    }
  }

  // Bottom row: individual column labels (visible columns only).
  // If a column is vertically merged from a stub row above (vMerge::Restart),
  // mark its label-row cell as vMerge::Continue (empty continuation cell).
  std::vector<HeaderGridCell> label_row;
  for (size_t ci = 0; ci < spec.columns.size(); ++ci) {
    if (!spec.columns[ci].is_visible) continue;

    HeaderGridCell cell;
    cell.col_span = 1;
    cell.row_span = 1;
    cell.width = spec.columns[ci].resolved_width;
    cell.source_col_index = ci;

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

std::vector<LogicalRow> LogicalTableBuilder::build_data_rows(const TFLSpec &spec, const DataTable &data) {
  std::vector<LogicalRow> rows;
  if (data.n_rows == 0) return rows;

  rows.reserve(data.n_rows);

  for (size_t row_idx = 0; row_idx < data.n_rows; ++row_idx) {
    LogicalRow lr;
    lr.type = LogicalRowType::DataRow;
    lr.source_index = row_idx;

    for (const auto &col : spec.columns) {
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

void LogicalTableBuilder::apply_dedupe(std::vector<LogicalRow> &rows, const std::vector<ColumnSpec> &columns) {
  if (rows.empty()) return;

  // Find columns with dedupe=true
  std::vector<size_t> dedupe_indices;
  for (size_t i = 0; i < columns.size(); ++i) {
    if (columns[i].dedupe) { dedupe_indices.push_back(i); }
  }

  if (dedupe_indices.empty()) return;

  // For each dedupe column, blank out consecutive duplicate values
  for (size_t col_idx : dedupe_indices) {
    std::string prev_value;
    for (size_t ri = 0; ri < rows.size(); ++ri) {
      if (rows[ri].type != LogicalRowType::DataRow) continue;
      if (col_idx >= rows[ri].cells.size()) continue;

      auto &cell = rows[ri].cells[col_idx];
      if (ri == 0) {
        prev_value = cell.text;
      } else {
        if (cell.text == prev_value) {
          cell.text = "";         // suppress duplicate
          cell.is_deduped = true; // mark so glue actions skip this cell
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

std::vector<LogicalRow> LogicalTableBuilder::apply_style_rows(std::vector<LogicalRow> &rows,
                                                              const std::vector<RowActionSet> &style_rows,
                                                              const std::vector<ColumnSpec> &columns,
                                                              const DataTable &data, const ColIdxMap &col_id_to_idx) {

  if (style_rows.empty()) return std::move(rows);

  // Use pre-computed col_id_to_idx (alias for local use)
  const auto &col_to_idx = col_id_to_idx;

  // Helper: get a value from the DataTable for a given column and row index.
  // This works for both visible and invisible columns.
  auto get_data_value = [&](const std::string &col_id, size_t row_index) -> std::string {
    auto it = data.columns.find(col_id);
    if (it != data.columns.end() && row_index < it->second.size()) { return it->second[row_index]; }
    return "";
  };

  // Helper: build a full-width merged synthetic row.
  // The first visible column becomes the merge leader spanning all visible
  // columns.
  auto build_addrow_synthetic = [&](size_t src_idx, const AddRowAction &ar) -> LogicalRow {
    LogicalRow synthetic;
    synthetic.type = LogicalRowType::SyntheticRow;
    synthetic.source_index = src_idx;
    synthetic.row_style_ref = ar.style_ref;

    std::string value_text = get_data_value(ar.value_from, src_idx);

    // Sum width and count of visible columns only
    Length total_width{0};
    int visible_count = 0;
    for (const auto &col : columns) {
      if (col.is_visible) {
        total_width = total_width + col.resolved_width;
        visible_count++;
      }
    }

    bool leader_placed = false;
    for (size_t ci = 0; ci < columns.size(); ++ci) {
      LogicalCell cell;
      cell.col_id = columns[ci].id;
      if (!columns[ci].is_visible) {
        // Invisible column — empty filler cell
        cell.is_merged = true;
      } else if (!leader_placed) {
        // First visible column is the merge leader
        cell.text = value_text;
        cell.is_merge_leader = true;
        cell.merge_span = visible_count;
        cell.merged_width = total_width;
        if (ar.style_ref.has_value()) { cell.style_refs.push_back(*ar.style_ref); }
        leader_placed = true;
      } else {
        cell.is_merged = true;
      }
      synthetic.cells.push_back(std::move(cell));
    }
    return synthetic;
  };

  std::vector<LogicalRow> result;
  result.reserve(rows.size() * 2); // conservative estimate

  for (size_t ri = 0; ri < rows.size(); ++ri) {
    auto &row = rows[ri];
    if (row.type != LogicalRowType::DataRow) {
      result.push_back(std::move(row));
      continue;
    }

    // Get the action set for this source row
    size_t src_idx = row.source_index;
    const RowActionSet *actions = nullptr;
    if (src_idx < style_rows.size()) { actions = &style_rows[src_idx]; }

    if (!actions || actions->empty()) {
      result.push_back(std::move(row));
      continue;
    }

    // --- page_break ---
    // Collect all page-break sources: explicit c_pageBreak() actions and
    // grouping-boundary breaks set by detect_grouping_boundaries().
    bool has_page_break = !actions->page_breaks.empty() || row.force_page_break;
    bool has_group_boundary = row.is_group_boundary;

    // --- add_row "above" insertions ---
    // When an "above" synthetic row is inserted, it becomes the first row
    // of the group.  Transfer force_page_break, is_group_boundary, and
    // group_values to the synthetic row so the paginator sees them at the
    // correct position for page-break decisions and #ByGroup resolution.
    for (const auto &ar : actions->add_rows) {
      if (ar.pos == AddRowAction::Position::Above) {
        LogicalRow synthetic = build_addrow_synthetic(src_idx, ar);
        if (has_page_break) {
          synthetic.force_page_break = true;
          has_page_break = false;
        }
        if (has_group_boundary) {
          synthetic.is_group_boundary = true;
          synthetic.group_values = row.group_values;
          has_group_boundary = false;
        }
        result.push_back(std::move(synthetic));
      }
    }

    if (has_page_break) {
      row.force_page_break = true;
    } else {
      row.force_page_break = false;
    }
    if (has_group_boundary) {
      // No "above" row consumed the boundary — keep it on the data row.
    } else {
      row.is_group_boundary = false;
    }

    // --- clear actions (before merge so cleared leader still participates) ---
    for (const auto &ca : actions->clears) {
      for (const auto &col_id : ca.cols) {
        auto it = col_to_idx.find(col_id);
        if (it != col_to_idx.end() && it->second < row.cells.size()) { row.cells[it->second].text = ""; }
      }
    }

    // --- style actions ---
    for (const auto &sa : actions->styles) {
      for (const auto &col_id : sa.cols) {
        auto it = col_to_idx.find(col_id);
        if (it != col_to_idx.end() && it->second < row.cells.size()) {
          row.cells[it->second].style_refs.push_back(sa.style_ref);
        }
      }
    }

    // --- merge actions ---
    for (const auto &ma : actions->merges) {
      if (ma.cols.empty()) continue;

      // Find the visible column indices for this merge.
      // Hidden (is_visible=false) columns are excluded from the merge
      // set — their values are transferred to the first visible column
      // below, but they don't participate in gridSpan computation.
      std::vector<size_t> merge_indices;
      for (const auto &col_id : ma.cols) {
        auto it = col_to_idx.find(col_id);
        if (it != col_to_idx.end() && columns[it->second].is_visible) { merge_indices.push_back(it->second); }
      }

      // Even with 1 visible column, we may need to apply value_from logic:
      // if the first column in the merge list is invisible, bring its value
      // to the first visible column.
      if (merge_indices.empty()) continue;

      // Sort indices
      std::ranges::sort(merge_indices);

      // Check if the first column in the merge list is invisible
      // (not visible). If so, bring its value to the first visible
      // column in the merge.
      const std::string &first_merge_col = ma.cols[0];
      bool first_is_invisible = false;
      {
        auto it = col_to_idx.find(first_merge_col);
        if (it == col_to_idx.end() || !columns[it->second].is_visible) { first_is_invisible = true; }
      }
      if (first_is_invisible) {
        // Get value from the invisible column via DataTable
        std::string invisible_val = get_data_value(first_merge_col, src_idx);
        size_t leader_idx = merge_indices[0];
        if (leader_idx < row.cells.size() && !invisible_val.empty()) { row.cells[leader_idx].text = invisible_val; }
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
            if (idx < columns.size()) { combined = combined + columns[idx].resolved_width; }
          }
          row.cells[leader_idx].merged_width = combined;

          if (ma.style_ref.has_value()) { row.cells[leader_idx].style_refs.push_back(*ma.style_ref); }
        }

        // Mark remaining cells as merged (suppressed)
        for (size_t k = 1; k < merge_indices.size(); ++k) {
          size_t idx = merge_indices[k];
          if (idx < row.cells.size()) { row.cells[idx].is_merged = true; }
        }
      } else if (merge_indices.size() == 1) {
        // Only 1 visible column in merge — just apply style if provided
        size_t leader_idx = merge_indices[0];
        if (leader_idx < row.cells.size() && ma.style_ref.has_value()) {
          row.cells[leader_idx].style_refs.push_back(*ma.style_ref);
        }
      }
    }

    // --- glue actions (after merge so suppressed cells are already marked) ---
    for (const auto &ga : actions->glues) {
      // Determine the text to concatenate
      std::string glue_text;
      if (ga.glue_col.has_value()) {
        glue_text = get_data_value(*ga.glue_col, src_idx);
      } else if (ga.text.has_value()) {
        glue_text = *ga.text;
      }

      // Nothing to glue (empty source value)
      if (glue_text.empty()) continue;

      for (const auto &col_id : ga.cols) {
        auto it = col_to_idx.find(col_id);
        if (it == col_to_idx.end()) continue;

        size_t cell_idx = it->second;
        if (cell_idx >= row.cells.size()) continue;

        auto &cell = row.cells[cell_idx];

        // Skip cells suppressed by merge or by dedupe (preserve blank)
        if (cell.is_merged || cell.is_deduped) continue;

        // Concatenate — separator only inserted when both sides are non-empty
        if (ga.position == "before") {
          cell.text = cell.text.empty() ? glue_text : (glue_text + ga.separator + cell.text);
        } else { // "after"
          cell.text = cell.text.empty() ? glue_text : (cell.text + ga.separator + glue_text);
        }
      }
    }

    result.push_back(std::move(row));

    // --- add_row "below" insertions ---
    if (actions) {
      for (const auto &ar : actions->add_rows) {
        if (ar.pos == AddRowAction::Position::Below) { result.push_back(build_addrow_synthetic(src_idx, ar)); }
      }
    }
  }

  return result;
}

// ---------------------------------------------------------------------------
// detect_grouping_boundaries: mark rows where grouping column values change
// ---------------------------------------------------------------------------

void LogicalTableBuilder::detect_grouping_boundaries(std::vector<LogicalRow> &rows,
                                                     const std::vector<ColumnSpec> &columns) {

  // Find grouping/paging columns — both trigger page breaks on value change.
  std::vector<size_t> grouping_indices;
  for (size_t i = 0; i < columns.size(); ++i) {
    if (columns[i].is_grouping || columns[i].is_paging) { grouping_indices.push_back(i); }
  }

  if (grouping_indices.empty()) return;

  // Track previous grouping values
  std::unordered_map<std::string, std::string> prev_group_values;

  for (auto &row : rows) {
    if (row.type == LogicalRowType::SyntheticRow) continue;

    // Read current grouping column values
    std::unordered_map<std::string, std::string> current_values;
    for (size_t gi : grouping_indices) {
      if (gi < row.cells.size()) { current_values[columns[gi].id] = row.cells[gi].text; }
    }

    // Check for changes
    if (!prev_group_values.empty()) {
      bool changed = false;
      for (const auto &[col_id, val] : current_values) {
        auto it = prev_group_values.find(col_id);
        if (it == prev_group_values.end() || it->second != val) {
          changed = true;
          break;
        }
      }
      if (changed) {
        row.is_group_boundary = true;
        // Any grouping or paging column change forces a page break
        // so each group starts on a fresh page.
        row.force_page_break = true;
      }
    }

    row.group_values = current_values;
    prev_group_values = current_values;
  }
}

// ---------------------------------------------------------------------------
// build: main entry point
// ---------------------------------------------------------------------------

LogicalTableBuilder::Result LogicalTableBuilder::build(const TFLSpec &spec, const DataTable &data) {
  Result result;

  // 1. Build column id -> index map (used by header grid + style rows)
  ColIdxMap col_id_to_idx;
  for (size_t i = 0; i < spec.columns.size(); ++i) {
    col_id_to_idx[spec.columns[i].id] = i;
  }

  // 2. Build header grid
  result.header_grid = build_header_grid(spec, col_id_to_idx);

  // 3. Build initial data rows
  auto rows = build_data_rows(spec, data);

  // 4. Detect grouping boundaries (BEFORE dedupe, which blanks cell text)
  detect_grouping_boundaries(rows, spec.columns);

  // 5. Apply dedupe (blanks consecutive duplicate values)
  apply_dedupe(rows, spec.columns);

  // 6. Apply styleRows actions (expands row stream with synthetic rows)
  rows = apply_style_rows(rows, spec.style_rows, spec.columns, data, col_id_to_idx);

  // 7. Collect grouping column indices (isGrouping or isPaging)
  for (size_t i = 0; i < spec.columns.size(); ++i) {
    if (spec.columns[i].is_grouping || spec.columns[i].is_paging) { result.grouping_col_indices.push_back(i); }
  }

  result.rows = std::move(rows);
  return result;
}

} // namespace kstfl
