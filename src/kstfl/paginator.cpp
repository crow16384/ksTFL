// kstfl/paginator.cpp — Deterministic vertical + horizontal pagination
//
// Implements spec §13: pagination algorithm, break precedence, dynamic subtitles.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include "paginator.h"
#include "inline_parser.h"
#include <algorithm>
#include <cmath>
#include <unordered_set>

namespace kstfl {

// ---------------------------------------------------------------------------
// Build horizontal segments from isColBreak columns
// Spec §13.3: split columns into segments at isColBreak boundaries,
// with ID columns repeated in every segment.
// ---------------------------------------------------------------------------

std::vector<HorizontalSegment> Paginator::build_segments(
    const std::vector<ColumnSpec>& columns) {

    std::vector<HorizontalSegment> segments;

    // Identify ID column indices (repeat in every segment)
    std::vector<size_t> id_indices;
    // Identify break points
    std::vector<size_t> break_after;

    for (size_t i = 0; i < columns.size(); ++i) {
        if (columns[i].is_id) {
            id_indices.push_back(i);
        }
        if (columns[i].is_col_break && i > 0) {
            // isColBreak marks the start of a new segment
            break_after.push_back(i);
        }
    }

    if (break_after.empty()) {
        // Single segment: all columns
        HorizontalSegment seg;
        seg.segment_index = 0;
        for (size_t i = 0; i < columns.size(); ++i) {
            seg.column_indices.push_back(i);
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
                // ID column outside this segment range — repeat it
                seg.column_indices.push_back(id_idx);
                included.insert(id_idx);
            }
        }

        // Add columns in this segment range
        for (size_t i = seg_start; i < seg_end; ++i) {
            if (included.find(i) == included.end()) {
                seg.column_indices.push_back(i);
            }
        }

        // Sort by original column order
        std::sort(seg.column_indices.begin(), seg.column_indices.end());

        if (!seg.column_indices.empty()) {
            segments.push_back(std::move(seg));
        }

        seg_start = seg_end;
    }

    return segments;
}

// ---------------------------------------------------------------------------
// Compute row heights for all rows using all visible columns (spec §28.3)
// Row heights are computed once across all columns and shared by segments.
// ---------------------------------------------------------------------------

std::vector<Length> Paginator::compute_row_heights(
    const std::vector<LogicalRow>& rows,
    const std::vector<ColumnSpec>& columns,
    const TextMeasurer& measurer,
    const StyleResolver& resolver) {

    std::vector<Length> heights(rows.size());

    for (size_t ri = 0; ri < rows.size(); ++ri) {
        const auto& row = rows[ri];
        Length max_height{0};

        for (size_t ci = 0; ci < row.cells.size() && ci < columns.size(); ++ci) {
            const auto& cell = row.cells[ci];
            if (cell.is_merged && !cell.is_merge_leader) continue;

            // Determine cell width
            Length cell_width = cell.is_merge_leader
                ? cell.merged_width
                : columns[ci].resolved_width;

            // Resolve effective style for this cell
            StyleDef cell_style = resolver.resolve_body_cell_style(
                columns[ci],
                row.row_style_ref,
                std::nullopt,
                std::nullopt
            );

            // Override with cell-level style if present
            if (cell.style_ref.has_value()) {
                const StyleDef* override_style = resolver.find_style(cell.style_ref.value());
                if (override_style) {
                    cell_style = cell_style.merged_with(*override_style);
                }
            }

            // Measure cell text
            MeasuredText measured = measurer.measure_plain(cell.text, cell_style, cell_width);

            if (measured.height > max_height) {
                max_height = measured.height;
            }
        }

        // Check explicit row height override
        // (from table_style.row_height if set)
        heights[ri] = max_height;
    }

    return heights;
}

// ---------------------------------------------------------------------------
// Compute available body height for a page
// Spec §5.2: subtract all non-body blocks from usable height
// ---------------------------------------------------------------------------

Length Paginator::compute_available_height(
    const PageConfig& page,
    Length header_section_height,
    Length titles_height,
    Length subtitles_height,
    Length table_header_height,
    Length footnotes_height,
    Length footer_section_height) {

    Length available = page.usable_height();

    // Conservative safety margin: reserve a small amount of vertical space
    // so that Word's internal layout never overflows onto an extra page.
    available = available - PAGE_SAFETY_MARGIN;

    // Header/footer sections
    available = available - header_section_height - footer_section_height;

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

    if (available.emu < 0) available.emu = 0;
    return available;
}

// ---------------------------------------------------------------------------
// paginate: main pagination algorithm
// Spec §13: deterministic vertical pagination
// ---------------------------------------------------------------------------

PaginationResult Paginator::paginate(
    const TFLSpec& spec,
    const std::vector<LogicalRow>& rows,
    const HeaderGrid& header_grid,
    const PageConfig& page_config,
    Length table_width,
    const TextMeasurer& measurer,
    const StyleResolver& resolver) {

    PaginationResult result;

    if (rows.empty()) {
        result.total_pages = 0;
        return result;
    }

    // 1. Build horizontal segments
    auto segments = build_segments(spec.columns);

    // 2. Compute row heights once (across all columns)
    auto row_heights = compute_row_heights(rows, spec.columns, measurer, resolver);

    // 3. Compute static block heights

    // Header section height (doc headers)
    Length header_section_height{0};
    for (const auto& hdr : spec.headers) {
        StyleDef style = resolver.resolve_doc_header_style();
        MeasuredText m = measurer.measure_plain(hdr.left + hdr.center + hdr.right,
                                                 style, page_config.usable_width());
        header_section_height = header_section_height + m.height;
    }

    // Footer section height
    Length footer_section_height{0};
    for (const auto& ftr : spec.footers) {
        StyleDef style = resolver.resolve_doc_footer_style();
        MeasuredText m = measurer.measure_plain(ftr.left + ftr.center + ftr.right,
                                                 style, page_config.usable_width());
        footer_section_height = footer_section_height + m.height;
    }

    // Titles height.
    // The emitter renders each add_title() group as a separate paragraph,
    // with lines within a group joined by <br> soft breaks.
    Length titles_height{0};
    {
        // If doc_prefix is not glued, it's a separate paragraph
        if (!spec.document.doc_prefix.empty() && !spec.document.glue_prefix) {
            StyleDef style = resolver.resolve_title_style();
            MeasuredText m = measurer.measure_plain(spec.document.doc_prefix, style,
                                                     page_config.usable_width());
            titles_height = titles_height + m.height;
        }

        // Measure each title group as a separate paragraph
        for (size_t gi = 0; gi < spec.titles.size(); ++gi) {
            const auto& tg = spec.titles[gi];
            StyleDef style = resolver.resolve_title_style(tg.style_ref);
            std::string combined;
            // Prepend glued prefix to first group
            if (gi == 0 && !spec.document.doc_prefix.empty() && spec.document.glue_prefix) {
                combined = spec.document.doc_prefix;
            }
            for (const auto& line : tg.text) {
                if (!combined.empty()) combined += "<br>";
                combined += line;
            }
            if (!combined.empty()) {
                MeasuredText m = measurer.measure_plain(combined, style,
                                                         page_config.usable_width());
                titles_height = titles_height + m.height;
            }
        }
    }

    // Subtitles base height (may be dynamic per page with #ByGroupX).
    // The emitter (emit_text_groups) creates one paragraph per text group,
    // joining lines within each group with <br> soft breaks.
    Length subtitles_height{0};
    for (const auto& tg : spec.subtitles) {
        StyleDef style = resolver.resolve_subtitle_style(tg.style_ref);
        std::string combined;
        for (size_t i = 0; i < tg.text.size(); ++i) {
            if (i > 0) combined += "<br>";
            combined += tg.text[i];
        }
        if (!combined.empty()) {
            MeasuredText m = measurer.measure_plain(combined, style,
                                                     page_config.usable_width());
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
    for (const auto& tg : spec.footnotes) {
        StyleDef style = resolver.resolve_footnote_style(tg.style_ref);
        std::string combined;
        for (size_t i = 0; i < tg.text.size(); ++i) {
            if (i > 0) combined += "<br>";
            combined += tg.text[i];
        }
        if (!combined.empty()) {
            MeasuredText m = measurer.measure_plain(combined, style,
                                                     page_config.usable_width());
            footnotes_height = footnotes_height + m.height;
        }
    }

    bool body_footnotes = spec.document.body_footnotes;
    bool is_continues = spec.document.is_continues;

    // When is_continues=false (default), titles repeat on every page.
    // When is_continues=true, titles appear only on the first page.
    bool repeat_titles = !is_continues;

    // 4. Paginate each segment
    for (auto& segment : segments) {
        size_t page_num = 1;
        size_t row_idx = 0;
        bool is_first = true;

        while (row_idx < rows.size()) {
            PageSlice page;
            page.page_number = page_num;
            page.is_first_page = is_first;
            page.first_row = row_idx;
            page.has_titles = is_first || repeat_titles;
            page.has_subtitles = true;

            // Determine subtitle height for this page
            // (may be dynamic if #ByGroupX placeholders are used)
            Length page_subtitle_h = subtitles_height;

            // Store page heights
            // When titles repeat, reserve height on all pages; otherwise only first.
            bool show_titles = is_first || repeat_titles;
            page.header_section_height = header_section_height;
            page.titles_height = show_titles ? titles_height : Length{0};
            page.subtitles_height = page_subtitle_h;
            page.table_header_height = table_header_height;
            page.footnotes_height = footnotes_height;
            page.footer_section_height = footer_section_height;

            // Always reserve footnotes space so the last page never
            // overflows its footnote onto a new (empty) page.
            Length available = compute_available_height(
                page_config,
                header_section_height,
                show_titles ? titles_height : Length{0},
                page_subtitle_h,
                table_header_height,
                body_footnotes ? footnotes_height : Length{0},
                footer_section_height);


            // Fill rows into this page
            Length used_height{0};
            size_t last_row = row_idx;

            while (row_idx < rows.size()) {
                // Check break triggers (spec §13.5 precedence)
                if (row_idx > last_row || row_idx > page.first_row) {
                    // Explicit page_break (from c_pageBreak() or isPaging column change)
                    if (rows[row_idx].force_page_break) break;
                }

                Length rh = row_heights[row_idx];

                // Check if row fits
                if (used_height.emu > 0 && (used_height + rh) > available) {
                    break;
                }

                used_height = used_height + rh;
                last_row = row_idx;

                // Capture grouping values for dynamic subtitles (first row only).
                // Iterate spec.columns in definition order to ensure deterministic
                // mapping: #ByGroup1 = first grouping/paging column, etc.
                if (row_idx == page.first_row && !rows[row_idx].group_values.empty()) {
                    for (const auto& col : spec.columns) {
                        if (col.is_grouping || col.is_paging) {
                            auto it = rows[row_idx].group_values.find(col.id);
                            if (it != rows[row_idx].group_values.end()) {
                                page.dynamic_subtitle_values.push_back(it->second);
                            }
                        }
                    }
                }

                row_idx++;
            }

            page.last_row = (row_idx > page.first_row) ? row_idx - 1 : page.first_row;
            page.body_height = used_height;

            // Determine if this is the last page
            page.is_last_page = (row_idx >= rows.size());


            segment.pages.push_back(std::move(page));
            is_first = false;
            page_num++;
        }
    }

    // Count total pages across all segments
    result.total_pages = 0;
    for (const auto& seg : segments) {
        result.total_pages += seg.pages.size();
    }
    result.segments = std::move(segments);

    return result;
}

}  // namespace kstfl
