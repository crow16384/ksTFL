// kstfl/paginator.cpp — Deterministic vertical + horizontal pagination
//
// Implements spec §13: pagination algorithm, break precedence, dynamic
// subtitles.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "paginator.h"
#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <functional>
#include <ranges>
#include <unordered_map>
#include <unordered_set>

namespace kstfl {

// ---------------------------------------------------------------------------
// Build horizontal segments from isColBreak columns
// Spec §13.3: split columns into segments at isColBreak boundaries,
// with ID columns repeated in every segment.
// ---------------------------------------------------------------------------

std::vector<HorizontalSegment> Paginator::build_segments(const std::vector<ColumnSpec> &columns) {

  std::vector<HorizontalSegment> segments;

  // Identify ID column indices (repeat in every segment)
  std::vector<size_t> id_indices;
  // Identify break points
  std::vector<size_t> break_after;

  for (size_t i = 0; i < columns.size(); ++i) {
    if (!columns[i].is_visible) continue;
    if (columns[i].is_id) { id_indices.push_back(i); }
    if (columns[i].is_col_break && i > 0) {
      // isColBreak marks the start of a new segment
      break_after.push_back(i);
    }
  }

  if (break_after.empty()) {
    // Single segment: all visible columns
    HorizontalSegment seg;
    seg.segment_index = 0;
    for (size_t i = 0; i < columns.size(); ++i) {
      if (columns[i].is_visible) seg.column_indices.push_back(i);
    }
    segments.push_back(std::move(seg));
    return segments;
  }

  // Build segments between break points
  size_t seg_start = 0;
  for (size_t b = 0; b <= break_after.size(); ++b) {
    size_t seg_end = (b < break_after.size()) ? break_after[b] : columns.size();

    HorizontalSegment seg;
    seg.segment_index = b;

    // First, add ID columns that are before this segment range
    std::unordered_set<size_t> included;
    for (size_t id_idx : id_indices) {
      if (id_idx < seg_start || id_idx >= seg_end) {
        seg.column_indices.push_back(id_idx);
        included.insert(id_idx);
      }
    }

    // Add visible columns in this segment range
    for (size_t i = seg_start; i < seg_end; ++i) {
      if (columns[i].is_visible && included.find(i) == included.end()) { seg.column_indices.push_back(i); }
    }

    // Sort by original column order
    std::ranges::sort(seg.column_indices);

    if (!seg.column_indices.empty()) { segments.push_back(std::move(seg)); }

    seg_start = seg_end;
  }

  return segments;
}

// ---------------------------------------------------------------------------
// Shared row-height computation core.
// WidthFn: (size_t ci, const LogicalCell& cell, const ColumnSpec& col) ->
// Length FilterFn: (size_t ci) -> bool  (return true to include column)
// ---------------------------------------------------------------------------
template <typename WidthFn, typename FilterFn>
static std::vector<Length> compute_row_heights_impl(const std::vector<LogicalRow> &rows,
                                                    const std::vector<ColumnSpec> &columns,
                                                    const TextMeasurer &measurer, const StyleResolver &resolver,
                                                    WidthFn width_fn, FilterFn filter_fn) {

  std::vector<Length> heights(rows.size());

  for (size_t ri = 0; ri < rows.size(); ++ri) {
    const auto &row = rows[ri];
    Length max_height{0};

    for (size_t ci = 0; ci < row.cells.size() && ci < columns.size(); ++ci) {
      if (!filter_fn(ci)) continue;
      if (!columns[ci].is_visible) continue;
      const auto &cell = row.cells[ci];
      if (cell.is_merged && !cell.is_merge_leader) continue;

      // Determine cell width via callable
      Length cell_width = width_fn(ci, cell, columns[ci]);

      // Resolve effective style for this cell
      bool is_addrow = (row.type == LogicalRowType::SyntheticRow);
      StyleDef cell_style =
          resolver.resolve_body_cell_style(columns[ci], row.row_style_ref, std::nullopt, std::nullopt, is_addrow);

      // Override with cell-level styles if present
      for (const auto &ref : cell.style_refs) {
        const StyleDef *override_style = resolver.find_style(ref);
        if (override_style) { cell_style.merge_from(*override_style); }
      }

      // Measure cell text
      MeasuredText measured = measurer.measure_plain(cell.text, cell_style, cell_width);

      if (measured.height > max_height) { max_height = measured.height; }
    }

    // Check explicit row height override from row-level or cell-level style.
    Length explicit_row_height{0};

    // 1) Row-level style (row_style_ref)
    if (row.row_style_ref.has_value()) {
      const StyleDef *rs = resolver.find_style(*row.row_style_ref);
      if (rs && rs->table_style.has_value() && rs->table_style->row_height.has_value()) {
        explicit_row_height = *rs->table_style->row_height;
      }
    }

    // 2) Cell-level style overrides (first match wins)
    if (explicit_row_height.emu == 0) {
      for (const auto &cell : row.cells) {
        if (!cell.style_refs.empty()) {
          for (const auto &ref : cell.style_refs) {
            const StyleDef *cs = resolver.find_style(ref);
            if (cs && cs->table_style.has_value() && cs->table_style->row_height.has_value()) {
              explicit_row_height = *cs->table_style->row_height;
              break;
            }
          }
          if (explicit_row_height.emu > 0) break;
        }
      }
    }

    heights[ri] = (explicit_row_height.emu > 0) ? explicit_row_height : max_height;
  }

  return heights;
}

// ---------------------------------------------------------------------------
// Compute row heights for all rows using all visible columns (spec §28.3)
// Row heights are computed once across all columns and shared by segments.
// ---------------------------------------------------------------------------

std::vector<Length> Paginator::compute_row_heights(const std::vector<LogicalRow> &rows,
                                                   const std::vector<ColumnSpec> &columns, const TextMeasurer &measurer,
                                                   const StyleResolver &resolver) {

  return compute_row_heights_impl(
      rows, columns, measurer, resolver,
      // Width resolver: use original column widths
      [](size_t /*ci*/, const LogicalCell &cell, const ColumnSpec &col) -> Length {
        return cell.is_merge_leader ? cell.merged_width : col.resolved_width;
      },
      // Filter: include all columns
      [](size_t /*ci*/) { return true; });
}

// ---------------------------------------------------------------------------
// Compute scaled column widths for a horizontal segment.
// Matches the scaling logic in docx_table.cpp: ID columns keep their
// original width, non-ID columns are scaled to fill the full table width.
// ---------------------------------------------------------------------------

std::unordered_map<size_t, int64_t> Paginator::compute_segment_column_widths(const std::vector<ColumnSpec> &columns,
                                                                             const HorizontalSegment &segment) {

  // Compute full table width across all visible columns
  Length full_table_width{0};
  size_t visible_col_count = 0;
  for (const auto &col : columns) {
    if (!col.is_visible) continue;
    full_table_width = full_table_width + col.resolved_width;
    visible_col_count++;
  }

  bool is_subset = (segment.column_indices.size() < visible_col_count);

  std::unordered_map<size_t, int64_t> col_widths;
  if (is_subset) {
    int64_t id_raw = 0, non_id_raw = 0;
    for (size_t col_idx : segment.column_indices) {
      if (col_idx < columns.size()) {
        if (columns[col_idx].is_id) {
          id_raw += columns[col_idx].resolved_width.emu;
        } else {
          non_id_raw += columns[col_idx].resolved_width.emu;
        }
      }
    }
    double non_id_scale =
        (non_id_raw > 0) ? static_cast<double>(full_table_width.emu - id_raw) / static_cast<double>(non_id_raw) : 1.0;
    for (size_t col_idx : segment.column_indices) {
      if (col_idx < columns.size()) {
        if (columns[col_idx].is_id) {
          col_widths[col_idx] = columns[col_idx].resolved_width.emu;
        } else {
          col_widths[col_idx] = static_cast<int64_t>(columns[col_idx].resolved_width.emu * non_id_scale);
        }
      }
    }
  } else {
    for (size_t col_idx : segment.column_indices) {
      if (col_idx < columns.size()) { col_widths[col_idx] = columns[col_idx].resolved_width.emu; }
    }
  }

  return col_widths;
}

// ---------------------------------------------------------------------------
// Compute row heights for a specific segment using scaled column widths.
// When isColBreak splits a table, each segment displays fewer columns at
// wider widths.  Text wraps differently at these widths, so row heights
// must be recalculated per segment rather than shared across all segments.
// ---------------------------------------------------------------------------

std::vector<Length> Paginator::compute_segment_row_heights(const std::vector<LogicalRow> &rows,
                                                           const std::vector<ColumnSpec> &columns,
                                                           const HorizontalSegment &segment,
                                                           const std::unordered_map<size_t, int64_t> &scaled_widths,
                                                           const TextMeasurer &measurer,
                                                           const StyleResolver &resolver) {

  // Build set of columns in this segment for quick lookup
  std::unordered_set<size_t> seg_cols(segment.column_indices.begin(), segment.column_indices.end());

  return compute_row_heights_impl(
      rows, columns, measurer, resolver,
      // Width resolver: use segment-scaled widths
      [&scaled_widths, &columns](size_t ci, const LogicalCell &cell, const ColumnSpec &col) -> Length {
        if (cell.is_merge_leader) {
          // Sum scaled widths of merged columns in this segment
          int64_t merged_emu = 0;
          for (size_t mi = ci; mi < ci + static_cast<size_t>(cell.merge_span) && mi < columns.size(); ++mi) {
            auto wit = scaled_widths.find(mi);
            if (wit != scaled_widths.end()) { merged_emu += wit->second; }
          }
          return Length{merged_emu > 0 ? merged_emu : cell.merged_width.emu};
        }
        auto wit = scaled_widths.find(ci);
        return (wit != scaled_widths.end()) ? Length{wit->second} : col.resolved_width;
      },
      // Filter: only columns in this segment
      [&seg_cols](size_t ci) { return seg_cols.find(ci) != seg_cols.end(); });
}

// ---------------------------------------------------------------------------
// Compute available body height for a page
// Spec §5.2: subtract all non-body blocks from usable height
// ---------------------------------------------------------------------------

Length Paginator::compute_available_height(const PageConfig &page, Length header_section_height, Length titles_height,
                                           Length subtitles_height, Length table_header_height, Length footnotes_height,
                                           Length footer_section_height, Length spacer_height) {

  Length available = page.usable_height();

  // Conservative safety margin: reserve a small amount of vertical space
  // so that Word's internal layout never overflows onto an extra page.
  available = available - PAGE_SAFETY_MARGIN;

  // Doc headers/footers are rendered in Word header/footer XML parts
  // (w:hdr / w:ftr), which occupy the margin area between the page edge
  // and the body.  usable_height() already excludes top+bottom margins,
  // so we must NOT subtract their full heights — that would double-count.
  //
  // However, when footer (or header) content is taller than the space
  // between margin boundary and the w:footer/w:header distance line,
  // Word pushes the body content to make room.  We must account for
  // that overflow.
  //
  // Available space for header content: top_margin - header_distance
  // Available space for footer content: bottom_margin - footer_distance
  {
    Length hdr_space = page.margins.top - page.margins.header_distance;
    if (hdr_space.emu < 0) hdr_space.emu = 0;
    if (header_section_height > hdr_space) { available = available - (header_section_height - hdr_space); }

    Length ftr_space = page.margins.bottom - page.margins.footer_distance;
    if (ftr_space.emu < 0) ftr_space.emu = 0;
    if (footer_section_height > ftr_space) { available = available - (footer_section_height - ftr_space); }
  }

  // Titles: callers pass titles_height=0 for pages that don't show titles
  available = available - titles_height;

  // Subtitles: repeated on every page (can be dynamic)
  available = available - subtitles_height;

  // Table header: repeated on every page
  available = available - table_header_height;

  // Footnotes: always reserved so the last page never overflows.
  // On non-last pages the emitter does not emit footnotes, so there
  // is simply a small extra whitespace at the bottom — acceptable.
  available = available - footnotes_height;

  // Table spacer rows (topEmptyLine / bottomEmptyLine) emitted by the
  // table renderer on every page that has body rows.
  available = available - spacer_height;

  if (available.emu < 0) available.emu = 0;
  return available;
}

// ---------------------------------------------------------------------------
// paginate: main pagination algorithm
// Spec §13: deterministic vertical pagination
// ---------------------------------------------------------------------------

PaginationResult Paginator::paginate(const TFLSpec &spec, std::vector<LogicalRow> &rows, const HeaderGrid &header_grid,
                                     const PageConfig &page_config, Length table_width, const TextMeasurer &measurer,
                                     const StyleResolver &resolver) {

  PaginationResult result;

  if (rows.empty()) {
    result.total_pages = 0;
    return result;
  }

  // 1. Build horizontal segments
  auto segments = build_segments(spec.columns);

  // 2. Compute row heights
  // For single-segment tables (no colBreak), compute once across all columns.
  // For multi-segment tables, compute per-segment using scaled column widths
  // so that row heights reflect the actual column widths in each segment.
  auto row_heights = compute_row_heights(rows, spec.columns, measurer, resolver);
  for (size_t i = 0; i < rows.size() && i < row_heights.size(); ++i) {
    rows[i].measured_height = row_heights[i];
  }

  bool has_multiple_segments = (segments.size() > 1);
  if (has_multiple_segments) {
    for (auto &seg : segments) {
      auto scaled_widths = compute_segment_column_widths(spec.columns, seg);
      seg.row_heights = compute_segment_row_heights(rows, spec.columns, seg, scaled_widths, measurer, resolver);
    }
  } else if (!segments.empty()) {
    // Single segment — reuse global row_heights
    segments[0].row_heights = row_heights;
  }

  // 3. Compute static block heights

  // Header section height.
  // In OOXML, header/footer sections render left/center/right side-by-side
  // separated by tab stops.  Each section occupies roughly 1/3 of the page
  // width.  Measure each independently and take the tallest.
  Length header_section_height{0};
  for (const auto &hdr : spec.headers) {
    StyleDef style = resolver.resolve_doc_header_style();
    Length third_width{page_config.usable_width().emu / 3};
    Length max_section_height{0};
    for (const auto &section : {hdr.left, hdr.center, hdr.right}) {
      if (!section.empty()) {
        MeasuredText m = measurer.measure_plain(section, style, third_width);
        if (m.height > max_section_height) max_section_height = m.height;
      }
    }
    header_section_height = header_section_height + max_section_height;
  }

  // Footer section height — same approach as headers.
  Length footer_section_height{0};
  for (const auto &ftr : spec.footers) {
    StyleDef style = resolver.resolve_doc_footer_style();
    Length third_width{page_config.usable_width().emu / 3};
    Length max_section_height{0};
    for (const auto &section : {ftr.left, ftr.center, ftr.right}) {
      if (!section.empty()) {
        MeasuredText m = measurer.measure_plain(section, style, third_width);
        if (m.height > max_section_height) max_section_height = m.height;
      }
    }
    footer_section_height = footer_section_height + max_section_height;
  }

  // Titles height.
  // The emitter renders each add_title() group as a separate paragraph,
  // with lines within a group joined by <br> soft breaks.
  Length titles_height{0};
  {
    // Measure each title group as a separate paragraph
    for (size_t gi = 0; gi < spec.titles.size(); ++gi) {
      const auto &tg = spec.titles[gi];
      StyleDef style = resolver.resolve_title_style(tg.style_refs);
      std::string combined;
      for (const auto &line : tg.text) {
        if (!combined.empty()) combined += "<br>";
        combined += line;
      }
      if (!combined.empty()) {
        MeasuredText m = measurer.measure_plain(combined, style, page_config.usable_width());
        titles_height = titles_height + m.height;
      }
    }
  }

  // Subtitles base height (may be dynamic per page with #ByGroupX).
  // The emitter (emit_text_groups) creates one paragraph per text group,
  // joining lines within each group with <br> soft breaks.
  Length subtitles_height{0};
  for (const auto &tg : spec.subtitles) {
    StyleDef style = resolver.resolve_subtitle_style(tg.style_refs);
    std::string combined;
    for (size_t i = 0; i < tg.text.size(); ++i) {
      if (i > 0) combined += "<br>";
      combined += tg.text[i];
    }
    if (!combined.empty()) {
      MeasuredText m = measurer.measure_plain(combined, style, page_config.usable_width());
      subtitles_height = subtitles_height + m.height;
    }
  }

  // Table header height
  Length table_header_height = header_grid.total_height;
  if (table_header_height.emu == 0 && !header_grid.rows.empty()) {
    // Estimate if not pre-measured
    StyleDef hdr_style = resolver.resolve_header_cell_style(spec.columns.empty() ? ColumnSpec{} : spec.columns[0]);
    Length line_h = measurer.line_height(hdr_style.font.value_or(FontProps{}));
    table_header_height = line_h * static_cast<double>(header_grid.rows.size());
  }

  // Footnotes height — same pattern as subtitles (one paragraph per group).
  Length footnotes_height{0};
  for (const auto &tg : spec.footnotes) {
    StyleDef style = resolver.resolve_footnote_style(tg.style_refs);
    std::string combined;
    for (size_t i = 0; i < tg.text.size(); ++i) {
      if (i > 0) combined += "<br>";
      combined += tg.text[i];
    }
    if (!combined.empty()) {
      MeasuredText m = measurer.measure_plain(combined, style, page_config.usable_width());
      footnotes_height = footnotes_height + m.height;
    }
  }

  FootnotePlace fn_place = spec.document.footnote_place;

  // When footnotes go into the Word footer part, add their height to the
  // footer section so pagination reserves the correct total footer space.
  if (fn_place == FootnotePlace::DocFooter) { footer_section_height = footer_section_height + footnotes_height; }

  // Resolve table spacer heights (topEmptyLine / bottomEmptyLine).
  // Per-spec override wins over template default (same logic as emitter).
  Length spacer_height{0};
  {
    const auto &tmpl_ts = resolver.template_styles().table_style;
    std::optional<Length> top_el =
        spec.document.top_empty_line.has_value() ? spec.document.top_empty_line : tmpl_ts.top_empty_line;
    std::optional<Length> bot_el =
        spec.document.bottom_empty_line.has_value() ? spec.document.bottom_empty_line : tmpl_ts.bottom_empty_line;
    if (top_el.has_value() && top_el->emu > 0) spacer_height = spacer_height + *top_el;
    if (bot_el.has_value() && bot_el->emu > 0) spacer_height = spacer_height + *bot_el;
  }

  bool is_continues = spec.document.is_continues;

  // When is_continues=false (default), titles repeat on every page.
  // When is_continues=true, titles appear only on the first page.
  bool repeat_titles = !is_continues;

  // Table header repetition: controlled by template layout flag.
  bool repeat_header = resolver.template_styles().table_style.repeat_header_on_each_page;
  bool allow_row_break = resolver.template_styles().table_style.allow_row_break_across_pages;

  // 4. Paginate
  // When multiple segments exist (isColBreak), compute unified row heights
  // (max across all segments per row) so that every segment uses the same
  // page breaks.  Each segment keeps its own row_heights for rendering,
  // but pagination decisions use the unified (tallest-per-row) heights.
  std::vector<Length> pagination_heights;
  if (has_multiple_segments) {
    pagination_heights.resize(rows.size());
    for (size_t ri = 0; ri < rows.size(); ++ri) {
      Length max_h{0};
      for (const auto &seg : segments) {
        if (ri < seg.row_heights.size() && seg.row_heights[ri] > max_h) max_h = seg.row_heights[ri];
      }
      pagination_heights[ri] = max_h;
    }
  } else if (!segments.empty()) {
    pagination_heights = segments[0].row_heights;
  }

  // Paginate once using unified heights, then replicate page breaks
  // across all segments.
  {
    struct PageBreakInfo {
      size_t first_row;
      size_t last_row;
      bool is_first_page;
      bool is_last_page;
      Length body_height;
      std::vector<std::string> dynamic_subtitle_values;
    };
    std::vector<PageBreakInfo> page_breaks;

    size_t page_num = 1;
    size_t row_idx = 0;
    bool is_first = true;

    while (row_idx < rows.size()) {
      Length page_subtitle_h = subtitles_height;
      bool show_titles = is_first || repeat_titles;

      Length fn_reserve = (fn_place == FootnotePlace::Repeated) ? footnotes_height : Length{0};
      Length hdr_reserve = (is_first || repeat_header) ? table_header_height : Length{0};
      Length available =
          compute_available_height(page_config, header_section_height, show_titles ? titles_height : Length{0},
                                   page_subtitle_h, hdr_reserve, fn_reserve, footer_section_height, spacer_height);

      Length used_height{0};
      size_t first_row = row_idx;
      size_t last_row = row_idx;
      std::vector<std::string> dyn_sub_vals;

      while (row_idx < rows.size()) {
        if (row_idx > last_row || row_idx > first_row) {
          if (rows[row_idx].force_page_break) break;
        }

        Length rh = pagination_heights[row_idx];

        // When row breaks are allowed, skip height-based page breaks:
        // all rows go into a single virtual page and Word handles
        // natural pagination.  force_page_break is still respected above.
        if (!allow_row_break) {
          if (used_height.emu > 0 && (used_height + rh) > available) { break; }

          if (used_height.emu == 0 && rh > (available + PAGE_SAFETY_MARGIN)) {
            Rcpp::Rcerr << "[ksTFL] WARNING: Row " << row_idx << " height (" << rh.to_pt() << "pt) exceeds available"
                        << " page body height (" << (available + PAGE_SAFETY_MARGIN).to_pt() << "pt)."
                        << " The row will be clipped to fit the page.\n";
            rows[row_idx].is_oversized = true;
            rows[row_idx].capped_height = available;
          }
        } // !allow_row_break

        used_height = used_height + rh;
        last_row = row_idx;

        // Capture grouping values for dynamic subtitles (first row of page)
        if (row_idx == first_row && dyn_sub_vals.empty()) {
          const auto *gv = &rows[row_idx].group_values;
          if (gv->empty()) {
            for (size_t scan = row_idx + 1; scan < rows.size(); ++scan) {
              if (!rows[scan].group_values.empty()) {
                gv = &rows[scan].group_values;
                break;
              }
            }
          }
          if (!gv->empty()) {
            for (const auto &col : spec.columns) {
              if (col.is_grouping || col.is_paging) {
                auto it = gv->find(col.id);
                if (it != gv->end()) { dyn_sub_vals.push_back(it->second); }
              }
            }
          }
        }

        row_idx++;
      }

      PageBreakInfo pb;
      pb.first_row = first_row;
      pb.last_row = (row_idx > first_row) ? row_idx - 1 : first_row;
      pb.is_first_page = is_first;
      pb.is_last_page = (row_idx >= rows.size());
      pb.body_height = used_height;
      pb.dynamic_subtitle_values = std::move(dyn_sub_vals);
      page_breaks.push_back(std::move(pb));

      is_first = false;
      page_num++;
    }

    // Apply the same page breaks to every segment
    for (auto &segment : segments) {
      segment.pages.clear();
      for (size_t pi = 0; pi < page_breaks.size(); ++pi) {
        const auto &pb = page_breaks[pi];
        PageSlice page;
        page.page_number = static_cast<size_t>(pi + 1);
        page.is_first_page = pb.is_first_page;
        page.first_row = pb.first_row;
        page.last_row = pb.last_row;
        page.is_last_page = pb.is_last_page;
        page.has_titles = pb.is_first_page || repeat_titles;
        page.has_subtitles = true;
        page.dynamic_subtitle_values = pb.dynamic_subtitle_values;

        bool show_titles = page.has_titles;
        page.header_section_height = header_section_height;
        page.titles_height = show_titles ? titles_height : Length{0};
        page.subtitles_height = subtitles_height;
        page.table_header_height = (pb.is_first_page || repeat_header) ? table_header_height : Length{0};
        page.footer_section_height = footer_section_height;

        // Recompute body_height using this segment's own row heights
        Length seg_body{0};
        for (size_t ri = pb.first_row; ri <= pb.last_row && ri < segment.row_heights.size(); ++ri) {
          seg_body = seg_body + segment.row_heights[ri];
        }
        page.body_height = seg_body;

        switch (fn_place) {
          using enum FootnotePlace;
        case Repeated:
          page.has_footnotes = true;
          page.footnotes_height = footnotes_height;
          break;
        case LastPage:
          page.has_footnotes = pb.is_last_page;
          page.footnotes_height = pb.is_last_page ? footnotes_height : Length{0};
          break;
        case DocFooter:
          page.has_footnotes = false;
          page.footnotes_height = Length{0};
          break;
        }

        segment.pages.push_back(std::move(page));
      }
    }

    // Post-pass for last_page footnotes (LastPage placement strategy).
    // Run per-segment since body heights differ, but initial breaks are
    // unified.
    if (fn_place == FootnotePlace::LastPage && footnotes_height.emu > 0) {
      for (auto &segment : segments) {
        if (segment.pages.empty()) continue;

        size_t last_idx = segment.pages.size() - 1;
        bool show_titles_last = segment.pages[last_idx].is_first_page || repeat_titles;
        Length last_hdr_h = (segment.pages[last_idx].is_first_page || repeat_header) ? table_header_height : Length{0};

        Length avail_with_fn = compute_available_height(
            page_config, header_section_height, show_titles_last ? titles_height : Length{0}, subtitles_height,
            last_hdr_h, footnotes_height, footer_section_height, spacer_height);

        while (segment.pages[last_idx].body_height > avail_with_fn &&
               segment.pages[last_idx].last_row > segment.pages[last_idx].first_row) {

          Length removed_h = segment.row_heights[segment.pages[last_idx].last_row];
          segment.pages[last_idx].body_height = segment.pages[last_idx].body_height - removed_h;
          segment.pages[last_idx].last_row--;

          PageSlice extra;
          extra.page_number = segment.pages.size() + 1;
          extra.is_first_page = false;
          extra.first_row = segment.pages[last_idx].last_row + 1;
          extra.last_row = extra.first_row;
          extra.is_last_page = false;
          extra.has_titles = repeat_titles;
          extra.has_subtitles = true;
          extra.header_section_height = header_section_height;
          extra.titles_height = repeat_titles ? titles_height : Length{0};
          extra.subtitles_height = subtitles_height;
          extra.table_header_height = repeat_header ? table_header_height : Length{0};
          extra.footnotes_height = footnotes_height;
          extra.footer_section_height = footer_section_height;
          extra.body_height = removed_h;
          extra.has_footnotes = false;

          segment.pages[last_idx].is_last_page = false;
          segment.pages[last_idx].has_footnotes = false;

          segment.pages.push_back(std::move(extra));
          last_idx = segment.pages.size() - 1;

          show_titles_last = segment.pages[last_idx].is_first_page || repeat_titles;
          last_hdr_h = (segment.pages[last_idx].is_first_page || repeat_header) ? table_header_height : Length{0};
          avail_with_fn = compute_available_height(page_config, header_section_height,
                                                   show_titles_last ? titles_height : Length{0}, subtitles_height,
                                                   last_hdr_h, footnotes_height, footer_section_height, spacer_height);
        }

        auto &final_page = segment.pages.back();
        size_t fill_start = final_page.last_row + 1;
        Length fill_avail = compute_available_height(
            page_config, header_section_height, (final_page.is_first_page || repeat_titles) ? titles_height : Length{0},
            subtitles_height, (final_page.is_first_page || repeat_header) ? table_header_height : Length{0},
            footnotes_height, footer_section_height, spacer_height);

        while (fill_start < rows.size() && !rows[fill_start].force_page_break &&
               (final_page.body_height + segment.row_heights[fill_start]) <= fill_avail) {
          final_page.body_height = final_page.body_height + segment.row_heights[fill_start];
          final_page.last_row = fill_start;
          fill_start++;
        }

        final_page.is_last_page = (fill_start >= rows.size());
        final_page.has_footnotes = final_page.is_last_page;

        while (fill_start < rows.size()) {
          PageSlice overflow;
          overflow.page_number = segment.pages.size() + 1;
          overflow.is_first_page = false;
          overflow.first_row = fill_start;
          overflow.has_titles = repeat_titles;
          overflow.has_subtitles = true;
          overflow.header_section_height = header_section_height;
          overflow.titles_height = repeat_titles ? titles_height : Length{0};
          overflow.subtitles_height = subtitles_height;
          overflow.table_header_height = repeat_header ? table_header_height : Length{0};
          overflow.footnotes_height = footnotes_height;
          overflow.footer_section_height = footer_section_height;

          Length ov_avail = compute_available_height(
              page_config, header_section_height, repeat_titles ? titles_height : Length{0}, subtitles_height,
              repeat_header ? table_header_height : Length{0}, footnotes_height, footer_section_height, spacer_height);

          while (
              fill_start < rows.size() && !rows[fill_start].force_page_break &&
              (overflow.body_height.emu == 0 || (overflow.body_height + segment.row_heights[fill_start]) <= ov_avail)) {
            overflow.body_height = overflow.body_height + segment.row_heights[fill_start];
            overflow.last_row = fill_start;
            fill_start++;
          }

          overflow.is_last_page = (fill_start >= rows.size());
          overflow.has_footnotes = overflow.is_last_page;
          segment.pages.push_back(std::move(overflow));
        }
      }
    }
  }

  // Count total pages across all segments
  result.total_pages = 0;
  for (const auto &seg : segments) {
    result.total_pages += seg.pages.size();
  }
  result.segments = std::move(segments);

  return result;
}

} // namespace kstfl
