// kstfl/docx_table.cpp — table emission helpers for DocxEmitter

#include "docx_emitter.h"
#include <unordered_map>
#include <unordered_set>

namespace kstfl {

// ---------------------------------------------------------------------------
// emit_table_header: table header rows with tblHeader flag
// ---------------------------------------------------------------------------

void DocxEmitter::emit_table_header(XmlWriter &w, const HeaderGrid &header_grid, const HorizontalSegment &segment,
                                    const StyleResolver &resolver,
                                    const std::unordered_map<size_t, int64_t> &col_widths,
                                    const std::unordered_set<size_t> &seg_cols) const {
  const auto &tmpl = resolver.template_styles();
  // Base header style: template cascade without column/stub refs
  StyleDef base_hdr = resolver.resolve_base_header_style();

  size_t total_header_rows = header_grid.rows.size();

  for (size_t row_idx = 0; row_idx < total_header_rows; ++row_idx) {
    const auto &header_row = header_grid.rows[row_idx];
    bool is_first_header_row = (row_idx == 0);
    bool is_last_header_row = (row_idx == total_header_rows - 1);

    w.start_element("w:tr");

    // Row properties: header repetition + cantSplit + exact height
    w.start_element("w:trPr");
    if (tmpl.table_style.repeat_header_on_each_page) w.self_closing_element("w:tblHeader");
    w.self_closing_element("w:cantSplit");
    // Set exact row height to match paginator's calculation
    if (row_idx < header_grid.row_heights.size() && header_grid.row_heights[row_idx].emu > 0) {
      w.start_element("w:trHeight");
      w.attribute("w:val", std::to_string(header_grid.row_heights[row_idx].to_twips()));
      w.attribute("w:hRule", "exact");
      w.end_element();
    }
    w.end_element();

    // Emit only cells whose columns belong to this segment.
    // Each cell carries source_col_index (its position in spec.columns)
    // to correctly map to segment column indices when invisible columns
    // create gaps in the index space.
    for (const auto &cell : header_row) {
      size_t col_start = cell.source_col_index;
      size_t col_end = col_start + static_cast<size_t>(cell.col_span);

      // Count how many of this cell's columns are in the segment
      int visible_span = 0;
      for (size_t ci = col_start; ci < col_end; ++ci) {
        if (seg_cols.count(ci)) { visible_span++; }
      }

      // Skip cells entirely outside this segment
      if (visible_span > 0) {
        // Compute visible width by summing per-column scaled widths
        int64_t visible_emu = 0;
        for (size_t ci = col_start; ci < col_end; ++ci) {
          auto it = col_widths.find(ci);
          if (it != col_widths.end()) { visible_emu += it->second; }
        }
        Length visible_width{visible_emu};

        w.start_element("w:tc");

        // Resolve per-cell style: base cascade + cell.style_ref override
        StyleDef cell_style = base_hdr;
        if (cell.style_ref.has_value()) {
          const StyleDef *ref_style = resolver.find_style(*cell.style_ref);
          if (ref_style) { cell_style.merge_from(*ref_style); }
        }

        // Cell properties from resolved table_style
        TableCellProps tcp = cell_style.table_style.value_or(TableCellProps{});

        // Override with structural borders (highest priority)
        if (is_first_header_row && tmpl.table_style.structural.header_top_border.has_value()) {
          if (!tcp.borders.has_value()) { tcp.borders = Borders{}; }
          tcp.borders->top = tmpl.table_style.structural.header_top_border;
        }
        if (is_last_header_row && tmpl.table_style.structural.header_bottom_border.has_value()) {
          if (!tcp.borders.has_value()) { tcp.borders = Borders{}; }
          tcp.borders->bottom = tmpl.table_style.structural.header_bottom_border;
        }

        emit_cell_props(w, tcp, visible_width, visible_span, cell.v_merge);

        // Cell content (empty for vMerge continuation cells)
        emit_paragraph(w, cell.label, cell_style);

        w.end_element(); // w:tc
      }
    }

    w.end_element(); // w:tr
  }
}

// ---------------------------------------------------------------------------
// emit_table_row: a single body row
// ---------------------------------------------------------------------------

void DocxEmitter::emit_table_row(XmlWriter &w, const LogicalRow &row, Length row_height,
                                 const HorizontalSegment &segment, const TFLSpec &spec, const StyleResolver &resolver,
                                 bool is_last_row, const std::unordered_map<size_t, int64_t> &col_widths,
                                 const std::unordered_set<size_t> &seg_cols) const {
  const auto &tmpl = resolver.template_styles();
  w.start_element("w:tr");

  // Row properties
  w.start_element("w:trPr");
  if (!tmpl.table_style.allow_row_break_across_pages) w.self_closing_element("w:cantSplit");
  if (row_height.emu > 0 && !tmpl.table_style.allow_row_break_across_pages) {
    // Use exact height for all rows so Word never expands them beyond
    // what the paginator calculated.  Expansion ("atLeast") can cause
    // cumulative overflow that pushes footnote paragraphs to the next
    // physical page, creating empty pages.
    // For oversized rows the height is capped to the available page body
    // space so they do not overflow; content is clipped at the bottom.
    Length effective_height = (row.is_oversized && row.capped_height.emu > 0) ? row.capped_height : row_height;
    w.start_element("w:trHeight");
    w.attribute("w:val", std::to_string(effective_height.to_twips()));
    w.attribute("w:hRule", "exact");
    w.end_element();
  }
  w.end_element();

  // Build fast lookup for segment columns (once per table, not per row)

  // Emit cells for this segment
  for (size_t col_idx : segment.column_indices) {
    if (col_idx >= row.cells.size()) continue;
    const auto &cell = row.cells[col_idx];

    // Skip merged (non-leader) cells
    if (cell.is_merged && !cell.is_merge_leader) continue;

    w.start_element("w:tc");

    // Resolve cell style
    StyleDef cell_style;
    if (col_idx < spec.columns.size()) {
      bool is_addrow = (row.type == LogicalRowType::SyntheticRow);
      cell_style = resolver.resolve_body_cell_style(spec.columns[col_idx], row.row_style_ref, std::nullopt,
                                                    std::nullopt, is_addrow);
      if (cell.style_ref.has_value()) {
        const StyleDef *override_style = resolver.find_style(cell.style_ref.value());
        if (override_style) { cell_style.merge_from(*override_style); }
      }
    }

    // Cell properties — clamp merge span to columns present in this
    // segment, mirroring the header logic.  Without this, synthetic
    // rows (c_addrow) that merge ALL visible columns would emit a
    // gridSpan exceeding the segment's grid, creating artifacts.
    int effective_span = 0;
    int64_t width_emu = 0;
    if (cell.is_merge_leader && cell.merge_span > 1) {
      size_t span_end = col_idx + static_cast<size_t>(cell.merge_span);
      for (size_t ci = col_idx; ci < span_end; ++ci) {
        if (seg_cols.count(ci)) {
          effective_span++;
          auto it = col_widths.find(ci);
          if (it != col_widths.end()) { width_emu += it->second; }
        }
      }
      if (effective_span == 0) effective_span = 1;
    } else {
      effective_span = 1;
      auto it = col_widths.find(col_idx);
      if (it != col_widths.end()) { width_emu = it->second; }
    }
    Length cell_width{width_emu};

    TableCellProps tcp = cell_style.table_style.value_or(TableCellProps{});

    // Override bottom border on last row with structural table_bottom_border
    if (is_last_row && tmpl.table_style.structural.table_bottom_border.has_value()) {
      if (!tcp.borders.has_value()) { tcp.borders = Borders{}; }
      tcp.borders->bottom = tmpl.table_style.structural.table_bottom_border;
    }

    emit_cell_props(w, tcp, cell_width, effective_span);

    // Cell content
    emit_paragraph(w, cell.text, cell_style);

    w.end_element(); // w:tc
  }

  w.end_element(); // w:tr
}

// ---------------------------------------------------------------------------
// emit_table: a complete table element
// ---------------------------------------------------------------------------

void DocxEmitter::emit_table(XmlWriter &w, const TFLSpec &spec, const PageSlice &page, const HorizontalSegment &segment,
                             const std::vector<LogicalRow> &rows, const HeaderGrid &header_grid,
                             const StyleResolver &resolver) const {
  const auto &tmpl = resolver.template_styles();
  w.start_element("w:tbl");

  // Table properties
  w.start_element("w:tblPr");

  // Fixed layout (spec §19.3)
  w.start_element("w:tblLayout");
  w.attribute("w:type", "fixed");
  w.end_element();

  // ---- Horizontal-segment width scaling ----
  // When isColBreak splits columns into segments, each segment only
  // displays a subset of all columns.  We scale non-ID columns so the
  // segment fills the full table width, while ID columns keep their
  // original width so they align across interleaved segments.
  Length full_table_width{0};
  size_t visible_col_count = 0;
  for (const auto &col : spec.columns) {
    if (!col.is_visible) continue;
    full_table_width = full_table_width + col.resolved_width;
    visible_col_count++;
  }

  bool is_subset = (segment.column_indices.size() < visible_col_count);

  // Build per-column scaled width map
  std::unordered_map<size_t, int64_t> col_widths;
  if (is_subset) {
    // Sum raw widths of ID and non-ID columns in this segment
    int64_t id_raw = 0, non_id_raw = 0;
    for (size_t col_idx : segment.column_indices) {
      if (col_idx < spec.columns.size()) {
        if (spec.columns[col_idx].is_id) {
          id_raw += spec.columns[col_idx].resolved_width.emu;
        } else {
          non_id_raw += spec.columns[col_idx].resolved_width.emu;
        }
      }
    }
    // Non-ID columns share the remaining width after ID columns
    double non_id_scale =
        (non_id_raw > 0) ? static_cast<double>(full_table_width.emu - id_raw) / static_cast<double>(non_id_raw) : 1.0;
    for (size_t col_idx : segment.column_indices) {
      if (col_idx < spec.columns.size()) {
        if (spec.columns[col_idx].is_id) {
          col_widths[col_idx] = spec.columns[col_idx].resolved_width.emu;
        } else {
          col_widths[col_idx] = static_cast<int64_t>(spec.columns[col_idx].resolved_width.emu * non_id_scale);
        }
      }
    }
  } else {
    for (size_t col_idx : segment.column_indices) {
      if (col_idx < spec.columns.size()) { col_widths[col_idx] = spec.columns[col_idx].resolved_width.emu; }
    }
  }

  Length table_width = full_table_width;
  w.start_element("w:tblW");
  w.attribute("w:w", std::to_string(table_width.to_twips()));
  w.attribute("w:type", "dxa");
  w.end_element();

  // Table alignment on page (spec: tableStyle.layout.table_alignment)
  if (tmpl.table_style.table_alignment.has_value()) {
    w.element_with_attr("w:jc", "w:val", alignment_to_ooxml(*tmpl.table_style.table_alignment));
  }

  // Table borders from template
  if (tmpl.table_style.table_borders.has_value()) {
    w.start_element("w:tblBorders");
    auto emit_border = [&](const char *name, const std::optional<Border> &b) {
      if (!b.has_value()) return;
      w.start_element(name);
      w.attribute("w:val", b->line_style.has_value() ? border_line_style_to_ooxml(b->line_style.value()) : "single");
      if (b->width.has_value()) {
        int eighth_pt = static_cast<int>(b->width->to_pt() * 8.0);
        w.attribute("w:sz", std::to_string(eighth_pt));
      }
      w.attribute("w:space", "0");
      if (b->color.has_value()) {
        w.attribute("w:color", b->color->hex);
      } else {
        w.attribute("w:color", "auto");
      }
      w.end_element();
    };
    const auto &borders = tmpl.table_style.table_borders.value();
    emit_border("w:top", borders.top);
    emit_border("w:left", borders.left);
    emit_border("w:bottom", borders.bottom);
    emit_border("w:right", borders.right);
    emit_border("w:insideH", borders.insideH);
    emit_border("w:insideV", borders.insideV);
    w.end_element();
  }

  // Default cell margins from template.
  // IMPORTANT: Word adds tblCellMar top/bottom OUTSIDE trHeight even when
  // hRule="exact", causing rows to be taller than specified.  Our paginator
  // already includes cell_margin_top/bottom in the computed trHeight, so we
  // must emit top=0 bottom=0 here to avoid double-counting.  Left/right
  // margins are horizontal and don't affect row height.
  {
    w.start_element("w:tblCellMar");
    auto emit_margin = [&](const char *name, const std::optional<Length> &m) {
      if (!m.has_value()) return;
      w.start_element(name);
      w.attribute("w:w", std::to_string(m->to_twips()));
      w.attribute("w:type", "dxa");
      w.end_element();
    };
    // Force top/bottom to zero — vertical padding is baked into trHeight
    w.start_element("w:top");
    w.attribute("w:w", "0");
    w.attribute("w:type", "dxa");
    w.end_element();
    w.start_element("w:bottom");
    w.attribute("w:w", "0");
    w.attribute("w:type", "dxa");
    w.end_element();
    emit_margin("w:left", tmpl.table_style.default_cell_margin_left);
    emit_margin("w:right", tmpl.table_style.default_cell_margin_right);
    w.end_element();
  }

  w.end_element(); // w:tblPr

  // Grid definition (spec §19.3: gridCol widths in twips, scaled per segment)
  w.start_element("w:tblGrid");
  for (size_t col_idx : segment.column_indices) {
    auto it = col_widths.find(col_idx);
    if (it != col_widths.end()) {
      w.start_element("w:gridCol");
      w.attribute("w:w", std::to_string(Length{it->second}.to_twips()));
      w.end_element();
    }
  }
  w.end_element();

  // Header rows
  // Build segment column set once, shared by header and all body rows
  std::unordered_set<size_t> seg_cols(segment.column_indices.begin(), segment.column_indices.end());

  // Effective spacer rows: per-table spec override wins over template default.
  std::optional<Length> top_empty_line =
      spec.document.top_empty_line.has_value() ? spec.document.top_empty_line : tmpl.table_style.top_empty_line;
  std::optional<Length> bottom_empty_line = spec.document.bottom_empty_line.has_value()
                                                ? spec.document.bottom_empty_line
                                                : tmpl.table_style.bottom_empty_line;

  auto emit_empty_spacer_row = [&](const Length &spacer_height, bool apply_table_bottom_border) {
    if (spacer_height.emu <= 0) return;

    w.start_element("w:tr");

    w.start_element("w:trPr");
    w.self_closing_element("w:cantSplit");
    w.start_element("w:trHeight");
    w.attribute("w:val", std::to_string(spacer_height.to_twips()));
    w.attribute("w:hRule", "exact");
    w.end_element();
    w.end_element();

    // Emit a single merged cell spanning all segment columns, styled
    // with the table body cascade so the spacer inherits the template's
    // body formatting (font, background, alignment) and does not leave
    // visible column-separator artifacts.
    int grid_span = static_cast<int>(segment.column_indices.size());
    int64_t total_width_emu = 0;
    for (size_t col_idx : segment.column_indices) {
      auto it = col_widths.find(col_idx);
      if (it != col_widths.end()) { total_width_emu += it->second; }
    }
    Length total_width{total_width_emu};

    // Resolve table body style (is_addrow=true to skip column-specific
    // formatting such as indents).
    size_t first_col = segment.column_indices.empty() ? 0 : segment.column_indices.front();
    StyleDef cell_style;
    if (first_col < spec.columns.size()) {
      cell_style =
          resolver.resolve_body_cell_style(spec.columns[first_col], std::nullopt, std::nullopt, std::nullopt, true);
    }

    TableCellProps tcp = cell_style.table_style.value_or(TableCellProps{});

    // Preserve left/right borders from the resolved body style so that
    // vertical border lines remain continuous through the spacer row.
    // Only suppress top/bottom borders (the spacer provides visual space,
    // not a visible horizontal rule).
    Border none_border;
    none_border.line_style = BorderLineStyle::None;
    Borders spacer_borders = tcp.borders.value_or(Borders{});
    spacer_borders.top = none_border;
    spacer_borders.bottom = none_border;

    // When this is the bottom spacer, the structural bottom border must
    // appear AFTER the spacer (table border semantics requested by user).
    if (apply_table_bottom_border && tmpl.table_style.structural.table_bottom_border.has_value()) {
      spacer_borders.bottom = tmpl.table_style.structural.table_bottom_border;
    }
    tcp.borders = spacer_borders;

    w.start_element("w:tc");
    emit_cell_props(w, tcp, total_width, grid_span);
    emit_paragraph(w, "", cell_style);
    w.end_element(); // w:tc

    w.end_element(); // w:tr
  };

  if (page.is_first_page || tmpl.table_style.repeat_header_on_each_page)
    emit_table_header(w, header_grid, segment, resolver, col_widths, seg_cols);

  // Body rows for this page slice
  // Find effective last data row and whether this slice contains body rows.
  size_t effective_last_row = page.first_row;
  bool has_body_rows = false;
  for (size_t ri = page.first_row; ri <= page.last_row && ri < rows.size(); ++ri) {
    if (rows[ri].type == LogicalRowType::GroupBreak) continue;
    effective_last_row = ri;
    has_body_rows = true;
  }

  if (has_body_rows && top_empty_line.has_value() && top_empty_line->emu > 0) {
    emit_empty_spacer_row(*top_empty_line, false);
  }

  bool use_bottom_spacer = has_body_rows && bottom_empty_line.has_value() && bottom_empty_line->emu > 0;

  for (size_t ri = page.first_row; ri <= page.last_row && ri < rows.size(); ++ri) {
    if (rows[ri].type == LogicalRowType::GroupBreak) continue;
    bool is_last = (ri == effective_last_row) && !use_bottom_spacer;
    Length rh = (ri < segment.row_heights.size()) ? segment.row_heights[ri] : rows[ri].measured_height;
    emit_table_row(w, rows[ri], rh, segment, spec, resolver, is_last, col_widths, seg_cols);
  }

  if (use_bottom_spacer) { emit_empty_spacer_row(*bottom_empty_line, true); }

  w.end_element(); // w:tbl
}

} // namespace kstfl
