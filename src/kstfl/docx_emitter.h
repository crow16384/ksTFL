// kstfl/docx_emitter.h — OOXML emission for DOCX documents
//
// Streaming emission: generates document.xml, styles.xml, etc.
// and packages into .docx via ZipWriter.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#ifndef KSTFL_DOCX_EMITTER_H
#define KSTFL_DOCX_EMITTER_H

#include "types.h"
#include "xml_writer.h"
#include "style_resolver.h"
#include "zip_writer.h"
#include <string>
#include <vector>

namespace kstfl {

/// Header/footer part info for DOCX package assembly.
struct HdrFtrPartInfo {
    std::string part_path;  ///< e.g., "word/header1.xml"
    std::string rid;        ///< e.g., "rId4"
    std::string xml;        ///< the XML content
    bool is_header;         ///< true = header, false = footer
};

/// Emits OOXML for a complete TFL document.
class DocxEmitter {
public:
    DocxEmitter(const StylesTemplate& tmpl,
                const RendererConfig& config);

    /// Emit a complete .docx file for a TFLDocument.
    /// @param doc  The parsed TFL document (all specs).
    /// @param data_tables  Map from data_ref -> DataTable.
    /// @param output_path  Path for the output .docx file.
    /// @param resolved_pages  Map from spec key -> PaginationResult.
    /// @param resolved_rows   Map from spec key -> logical rows.
    /// @param resolved_headers Map from spec key -> header grid.
    void emit(const TFLDocument& doc,
              const std::unordered_map<std::string, DataTable>& data_tables,
              const std::string& output_path,
              const std::unordered_map<std::string, PaginationResult>& resolved_pages,
              const std::unordered_map<std::string, std::vector<LogicalRow>>& resolved_rows,
              const std::unordered_map<std::string, HeaderGrid>& resolved_headers);

private:
    // ---- Static package files ----
    std::string emit_content_types(const TFLDocument& doc,
                                    const std::vector<HdrFtrPartInfo>& hdr_ftr_parts) const;
    std::string emit_rels() const;
    std::string emit_document_rels(const TFLDocument& doc,
                                    const std::vector<HdrFtrPartInfo>& hdr_ftr_parts) const;
    std::string emit_styles() const;
    std::string emit_settings() const;
    std::string emit_font_table() const;

    // ---- Per-spec emission ----
    /// Emit document.xml content for a single spec's page.
    void emit_page(XmlWriter& w,
                   const TFLSpec& spec,
                   const PageSlice& page,
                   const HorizontalSegment& segment,
                   const std::vector<LogicalRow>& rows,
                   const HeaderGrid& header_grid,
                   const StyleResolver& resolver) const;

    /// Emit a table element.
    void emit_table(XmlWriter& w,
                    const TFLSpec& spec,
                    const PageSlice& page,
                    const HorizontalSegment& segment,
                    const std::vector<LogicalRow>& rows,
                    const HeaderGrid& header_grid,
                    const StyleResolver& resolver) const;

    /// Emit table header rows.
    void emit_table_header(XmlWriter& w,
                           const HeaderGrid& header_grid,
                           const HorizontalSegment& segment,
                           const StyleResolver& resolver) const;

    /// Emit a single table body row.
    void emit_table_row(XmlWriter& w,
                        const LogicalRow& row,
                        const HorizontalSegment& segment,
                        const TFLSpec& spec,
                        const StyleResolver& resolver,
                        bool is_last_row = false) const;

    /// Emit a paragraph with styled content.
    void emit_paragraph(XmlWriter& w,
                        const std::string& text,
                        const StyleDef& style) const;

    /// Emit a paragraph with parsed inline markup.
    void emit_parsed_paragraph(XmlWriter& w,
                               const ParsedParagraph& para,
                               const StyleDef& base_style) const;

    /// Emit run properties (<w:rPr>).
    void emit_run_props(XmlWriter& w,
                        const FontProps& font,
                        const InlineRunStyle& run_style = {}) const;

    /// Emit paragraph properties (<w:pPr>).
    void emit_para_props(XmlWriter& w, const ParagraphProps& pp) const;

    /// Emit table cell properties (<w:tcPr>).
    void emit_cell_props(XmlWriter& w,
                         const TableCellProps& tcp,
                         Length cell_width,
                         int grid_span = 1,
                         VMergeState v_merge = VMergeState::None) const;

    /// Emit titles/subtitles block.
    void emit_text_groups(XmlWriter& w,
                          const std::vector<TextGroup>& groups,
                          const StyleDef& base_style,
                          const StyleResolver& resolver) const;

    /// Emit all text groups concatenated in a single paragraph with soft breaks.
    /// Each group retains its own font style; paragraph props come from base_style.
    /// Optional prefix is prepended before first group.
    void emit_text_groups_combined(XmlWriter& w,
                                   const std::vector<TextGroup>& groups,
                                   const StyleDef& base_style,
                                   const StyleResolver& resolver,
                                   const std::string& prefix = "") const;

    /// Emit header/footer section.
    void emit_header_footer_section(XmlWriter& w,
                                    const std::vector<HeaderFooterRow>& rows,
                                    const StyleDef& style,
                                    Length usable_width,
                                    size_t page_num,
                                    size_t total_pages,
                                    bool use_fields) const;

    /// Emit a page break paragraph.
    void emit_page_break(XmlWriter& w) const;

    /// Emit section properties.
    void emit_section_props(XmlWriter& w, const PageConfig& page,
                            const std::string& header_rid = "",
                            const std::string& footer_rid = "",
                            bool continuous = false) const;

    // ---- Fields ----
    /// Emit PAGE field code.
    void emit_page_field(XmlWriter& w) const;
    /// Emit NUMPAGES field code.
    void emit_numpages_field(XmlWriter& w) const;

    /// Generate a standalone header or footer XML part.
    /// @param rows    The header/footer row content.
    /// @param style   Resolved style for the content.
    /// @param usable_w Usable page width for tab stops.
    /// @param root_element "w:hdr" or "w:ftr"
    /// @return Complete XML string for the part.
    std::string emit_hdr_ftr_xml_part(const std::vector<HeaderFooterRow>& rows,
                                       const StyleDef& style,
                                       Length usable_w,
                                       const char* root_element) const;

    const StylesTemplate& tmpl_;
    const RendererConfig& config_;
};

}  // namespace kstfl

#endif  // KSTFL_DOCX_EMITTER_H
