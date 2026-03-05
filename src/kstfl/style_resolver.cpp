// kstfl/style_resolver.cpp — Style merging and resolution implementation
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "style_resolver.h"

namespace kstfl {

StyleResolver::StyleResolver(const StylesTemplate& tmpl, const StyleMap& spec_styles)
    : tmpl_(tmpl), spec_styles_(spec_styles) {}

// ---------------------------------------------------------------------------
// Page config resolution
// ---------------------------------------------------------------------------

PageConfig StyleResolver::resolve_page_config(const TFLSpec& spec) const {
    PageConfig result = tmpl_.page;  // Start with template defaults
    if (spec.has_page_override) {
        const auto& ovr = spec.page_override;
        result.size = ovr.size;
        result.orientation = ovr.orientation;
        // Merge margins — apply only explicitly specified fields (including zero)
        const auto& mo = spec.margin_overrides;
        if (mo.top.has_value())              result.margins.top = *mo.top;
        if (mo.bottom.has_value())           result.margins.bottom = *mo.bottom;
        if (mo.left.has_value())             result.margins.left = *mo.left;
        if (mo.right.has_value())            result.margins.right = *mo.right;
        if (mo.header_distance.has_value())  result.margins.header_distance = *mo.header_distance;
        if (mo.footer_distance.has_value())  result.margins.footer_distance = *mo.footer_distance;
    }
    return result;
}

// ---------------------------------------------------------------------------
// Table width resolution
// ---------------------------------------------------------------------------

Length StyleResolver::resolve_table_width(const TFLSpec& spec, Length usable_width) const {
    if (spec.document.content_width_raw.has_value()) {
        return Length::parse(*spec.document.content_width_raw, usable_width.emu);
    }
    // Default: full usable width
    return usable_width;
}

// ---------------------------------------------------------------------------
// Column width resolution
// ---------------------------------------------------------------------------

void StyleResolver::resolve_column_widths(std::vector<ColumnSpec>& columns,
                                           Length table_width) const {
    if (columns.empty()) return;

    // Invisible columns get zero width; skip them in distribution.
    for (auto& col : columns) {
        if (!col.is_visible) {
            col.resolved_width = Length{0};
        }
    }

    // Pass 1: resolve fixed-unit columns (cm, in, mm, pt) first so we know
    // how much space they consume before applying percentage columns.
    int64_t fixed_total = 0;
    for (auto& col : columns) {
        if (!col.is_visible) continue;
        if (!col.format.col_width_raw.has_value()) continue;
        const std::string& raw = *col.format.col_width_raw;
        // Detect percentage strings: they end with '%'
        bool is_percent = (!raw.empty() && raw.back() == '%');
        if (!is_percent) {
            col.resolved_width = Length::parse(raw, table_width.emu);
            fixed_total += col.resolved_width.emu;
        }
    }

    // The reference width for percentage columns is the space remaining after
    // fixed-unit columns are placed.  Clamp to zero to avoid negative refs.
    int64_t pct_reference = table_width.emu - fixed_total;
    if (pct_reference < 0) pct_reference = 0;

    // Pass 2: resolve percentage columns against the remaining space.
    int64_t pct_total = 0;
    size_t unspecified_count = 0;
    for (auto& col : columns) {
        if (!col.is_visible) continue;
        if (!col.format.col_width_raw.has_value()) {
            unspecified_count++;
            continue;
        }
        const std::string& raw = *col.format.col_width_raw;
        bool is_percent = (!raw.empty() && raw.back() == '%');
        if (is_percent) {
            col.resolved_width = Length::parse(raw, pct_reference);
            pct_total += col.resolved_width.emu;
        }
    }

    // Distribute any remaining width among visible columns with no explicit width.
    int64_t remaining = table_width.emu - fixed_total - pct_total;
    if (remaining < 0) remaining = 0;

    if (unspecified_count > 0) {
        int64_t per_col = remaining / static_cast<int64_t>(unspecified_count);
        int64_t leftover = remaining - per_col * static_cast<int64_t>(unspecified_count);
        bool first = true;
        for (auto& col : columns) {
            if (!col.is_visible) continue;
            if (!col.format.col_width_raw.has_value()) {
                col.resolved_width = Length{per_col + (first ? leftover : 0)};
                first = false;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Style lookup
// ---------------------------------------------------------------------------

const StyleDef* StyleResolver::find_style(const std::string& id) const {
    // Spec styles are the only source of named/user-defined styles.
    // Template styles (default, tableHeader, etc.) are accessed as struct
    // fields by the resolve_*() methods, not via string lookup.
    auto it = spec_styles_.find(id);
    if (it != spec_styles_.end()) return &it->second;
    return nullptr;
}

StyleDef StyleResolver::apply_style_ref(const StyleDef& base, const std::string& ref) const {
    const StyleDef* found = find_style(ref);
    if (found) {
        StyleDef result = base;
        result.merge_from(*found);
        return result;
    }
    return base;
}

// ---------------------------------------------------------------------------
// Header cell style (cascade per spec §6.5)
// ---------------------------------------------------------------------------

StyleDef StyleResolver::resolve_header_cell_style(const ColumnSpec& col,
                                                   const StubColumn* stub) const {
    // 1. Template default text style
    StyleDef result = tmpl_.text_styles.default_style;

    // 2. Region style: tableHeader
    result.merge_from(tmpl_.text_styles.table_header);

    // 3. Template header row defaults
    if (tmpl_.table_style.header_row.has_value()) {
        result.merge_from(*tmpl_.table_style.header_row);
    }

    // 4. Structural: allHeaders (non-overridable in template, but here applied early)
    if (tmpl_.table_style.structural.all_headers.has_value()) {
        result.merge_from(*tmpl_.table_style.structural.all_headers);
    }

    // 5. Column labelStyleRef
    if (col.label_style_ref.has_value()) {
        result = apply_style_ref(result, *col.label_style_ref);
    }

    // 6. Stub labelStyleRef
    if (stub && stub->label_style_ref.has_value()) {
        result = apply_style_ref(result, *stub->label_style_ref);
    }

    return result;
}

// ---------------------------------------------------------------------------
// Body cell style (cascade per spec §6.4 + §6.5)
// ---------------------------------------------------------------------------

StyleDef StyleResolver::resolve_body_cell_style(
    const ColumnSpec& col,
    const std::optional<std::string>& row_style_ref,
    const std::optional<std::string>& merge_style_ref,
    const std::optional<std::string>& addrow_style_ref,
    bool is_addrow) const
{
    // 1. Template default
    StyleDef result = tmpl_.text_styles.default_style;

    // 2. Region style: tableBody
    result.merge_from(tmpl_.text_styles.table_body);

    // 3. Template body row defaults
    if (tmpl_.table_style.body_row.has_value()) {
        result.merge_from(*tmpl_.table_style.body_row);
    }

    // 4. Structural: tableBody
    if (tmpl_.table_style.structural.table_body.has_value()) {
        result.merge_from(*tmpl_.table_style.structural.table_body);
    }

    // 5. Column valueStyleRef — skip for synthetic (addrow) rows:
    //    addrow cells carry their own styleRef and should not inherit
    //    column-specific formatting like indent_2.
    if (!is_addrow && col.format.value_style_ref.has_value()) {
        result = apply_style_ref(result, *col.format.value_style_ref);
    }

    // 6. Row style action (from styleRows)
    if (row_style_ref.has_value()) {
        result = apply_style_ref(result, *row_style_ref);
    }

    // 7. Merge styleRef
    if (merge_style_ref.has_value()) {
        result = apply_style_ref(result, *merge_style_ref);
    }

    // 8. Add-row styleRef
    if (addrow_style_ref.has_value()) {
        result = apply_style_ref(result, *addrow_style_ref);
    }

    return result;
}

// ---------------------------------------------------------------------------
// Base header style (template cascade only — no column/stub refs)
// ---------------------------------------------------------------------------

StyleDef StyleResolver::resolve_base_header_style() const {
    // 1. Template default text style
    StyleDef result = tmpl_.text_styles.default_style;

    // 2. Region style: tableHeader
    result.merge_from(tmpl_.text_styles.table_header);

    // 3. Template header row defaults
    if (tmpl_.table_style.header_row.has_value()) {
        result.merge_from(*tmpl_.table_style.header_row);
    }

    // 4. Structural: allHeaders
    if (tmpl_.table_style.structural.all_headers.has_value()) {
        result.merge_from(*tmpl_.table_style.structural.all_headers);
    }

    return result;
}

// ---------------------------------------------------------------------------
// Content style resolvers
// ---------------------------------------------------------------------------

StyleDef StyleResolver::resolve_title_style(const std::vector<std::string>& style_refs) const {
    StyleDef result = tmpl_.text_styles.default_style;
    result.merge_from(tmpl_.text_styles.titles);
    for (const auto& ref : style_refs) {
        result = apply_style_ref(result, ref);
    }
    return result;
}

StyleDef StyleResolver::resolve_subtitle_style(const std::vector<std::string>& style_refs) const {
    StyleDef result = tmpl_.text_styles.default_style;
    result.merge_from(tmpl_.text_styles.subtitles);
    for (const auto& ref : style_refs) {
        result = apply_style_ref(result, ref);
    }
    return result;
}

StyleDef StyleResolver::resolve_footnote_style(const std::vector<std::string>& style_refs) const {
    StyleDef result = tmpl_.text_styles.default_style;
    result.merge_from(tmpl_.text_styles.footnotes);
    for (const auto& ref : style_refs) {
        result = apply_style_ref(result, ref);
    }
    return result;
}

StyleDef StyleResolver::resolve_doc_header_style() const {
    StyleDef result = tmpl_.text_styles.default_style;
    result.merge_from(tmpl_.text_styles.doc_header);
    return result;
}

StyleDef StyleResolver::resolve_doc_footer_style() const {
    StyleDef result = tmpl_.text_styles.default_style;
    result.merge_from(tmpl_.text_styles.doc_footer);
    return result;
}

StyleDef StyleResolver::resolve_body_text_style(const std::optional<std::string>& custom_ref) const {
    StyleDef result = tmpl_.text_styles.default_style;
    if (custom_ref.has_value()) {
        result = apply_style_ref(result, *custom_ref);
    }
    return result;
}

StyleDef StyleResolver::resolve_toc_title_style() const {
    StyleDef result = tmpl_.text_styles.default_style;
    result.merge_from(tmpl_.text_styles.toc_title);
    return result;
}

StyleDef StyleResolver::resolve_toc_entry_style() const {
    StyleDef result = tmpl_.text_styles.default_style;
    result.merge_from(tmpl_.text_styles.toc_entry);
    return result;
}

StyleDef StyleResolver::resolve_figure_caption_style(const std::vector<std::string>& style_refs) const {
    StyleDef result = tmpl_.text_styles.default_style;

    const StyleDef* base = find_template_text_style(tmpl_.figure_style.caption_text_style_ref);
    if (base) {
        result.merge_from(*base);
    } else {
        result.merge_from(tmpl_.text_styles.figure_caption);
    }

    for (const auto& ref : style_refs) {
        result = apply_style_ref(result, ref);
    }
    return result;
}

const StyleDef* StyleResolver::find_template_text_style(const std::string& key) const {
    if (key == "default") return &tmpl_.text_styles.default_style;
    if (key == "docHeader") return &tmpl_.text_styles.doc_header;
    if (key == "docFooter") return &tmpl_.text_styles.doc_footer;
    if (key == "titles") return &tmpl_.text_styles.titles;
    if (key == "subtitles") return &tmpl_.text_styles.subtitles;
    if (key == "footnotes") return &tmpl_.text_styles.footnotes;
    if (key == "tableHeader") return &tmpl_.text_styles.table_header;
    if (key == "tableBody") return &tmpl_.text_styles.table_body;
    if (key == "tocTitle") return &tmpl_.text_styles.toc_title;
    if (key == "tocEntry") return &tmpl_.text_styles.toc_entry;
    if (key == "figureCaption") return &tmpl_.text_styles.figure_caption;
    return nullptr;
}

}  // namespace kstfl
