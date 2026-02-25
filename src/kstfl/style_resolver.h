// kstfl/style_resolver.h — Style merging and resolution
//
// Implements the full cascade: template defaults -> region styles -> structural ->
// column refs -> styleRows -> merge refs -> add_row refs -> inline markup.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#ifndef KSTFL_STYLE_RESOLVER_H
#define KSTFL_STYLE_RESOLVER_H

#include "types.h"

namespace kstfl {

/// Resolves and merges styles for the rendering pipeline.
class StyleResolver {
public:
    /// Initialize with the styles template and per-spec styles.
    StyleResolver(const StylesTemplate& tmpl, const StyleMap& spec_styles);

    /// Resolve the effective page config (template + spec override).
    PageConfig resolve_page_config(const TFLSpec& spec) const;

    /// Resolve table width (from contentWidth + usable_width).
    Length resolve_table_width(const TFLSpec& spec, Length usable_width) const;

    /// Resolve column widths: absolute, percent, and distribute remaining.
    /// Modifies columns in-place setting `resolved_width`.
    void resolve_column_widths(std::vector<ColumnSpec>& columns, Length table_width) const;

    /// Resolve the effective style for a **table header** cell.
    /// Cascade: default -> tableHeader textStyle -> structural.allHeaders ->
    ///          header_row -> column labelStyleRef -> stub labelStyleRef.
    StyleDef resolve_header_cell_style(const ColumnSpec& col,
                                       const StubColumn* stub = nullptr) const;

    /// Resolve the effective style for a **table body** cell.
    /// Cascade: default -> tableBody textStyle -> body_row ->
    ///          structural.tableBody -> column valueStyleRef ->
    ///          row styleAction -> merge styleRef -> add_row styleRef.
    StyleDef resolve_body_cell_style(const ColumnSpec& col,
                                     const std::optional<std::string>& row_style_ref = std::nullopt,
                                     const std::optional<std::string>& merge_style_ref = std::nullopt,
                                     const std::optional<std::string>& addrow_style_ref = std::nullopt) const;

    /// Resolve a style for titles.
    StyleDef resolve_title_style(const std::optional<std::string>& custom_ref = std::nullopt) const;

    /// Resolve a style for subtitles.
    StyleDef resolve_subtitle_style(const std::optional<std::string>& custom_ref = std::nullopt) const;

    /// Resolve a style for footnotes.
    StyleDef resolve_footnote_style(const std::optional<std::string>& custom_ref = std::nullopt) const;

    /// Resolve a style for doc headers.
    StyleDef resolve_doc_header_style() const;

    /// Resolve a style for doc footers.
    StyleDef resolve_doc_footer_style() const;

    /// Resolve a style for body text (hasData=false).
    StyleDef resolve_body_text_style(const std::optional<std::string>& custom_ref = std::nullopt) const;

    /// Lookup a style by ID (checks spec styles first, then template-derived).
    const StyleDef* find_style(const std::string& id) const;

private:
    const StylesTemplate& tmpl_;
    const StyleMap& spec_styles_;

    /// Apply a named style ref on top of base.
    StyleDef apply_style_ref(const StyleDef& base, const std::string& ref) const;
};

}  // namespace kstfl

#endif  // KSTFL_STYLE_RESOLVER_H
