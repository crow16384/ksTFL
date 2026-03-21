// kstfl/docx_emitter.h — OOXML emission for DOCX documents
//
// Streaming emission: generates document.xml, styles.xml, etc.
// and packages into .docx via ZipWriter.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_DOCX_EMITTER_H
#define KSTFL_DOCX_EMITTER_H

#include "types.h"
#include "xml_writer.h"
#include "style_resolver.h"
#include "text_measurer.h"
#include "zip_writer.h"
#include <optional>
#include <string>
#include <vector>
#include <unordered_map>
#include <unordered_set>

namespace kstfl {

/// Header/footer part info for DOCX package assembly.
struct HdrFtrPartInfo {
  std::string part_path; ///< e.g., "word/header1.xml"
  std::string rid;       ///< e.g., "rId4"
  std::string xml;       ///< the XML content
  bool is_header;        ///< true = header, false = footer
};

/// TOC-heading style entry: body title/subtitle style + outline level, for styles.xml and document body.
struct TocHeadingEntry {
  StyleDef style;       ///< resolved title or subtitle style (appearance)
  int toc_level = 0;    ///< 1-9
  std::string style_id; ///< e.g. "TOCHead_1_0"
};

/// Look up TOC-heading style_id from (style, toc_level). Used when emitting title/subtitle paragraphs.
inline std::optional<std::string> find_toc_heading_style_id(const std::vector<TocHeadingEntry> &toc_headings,
                                                            const StyleDef &style, int toc_level) {
  for (const auto &e : toc_headings) {
    if (e.toc_level == toc_level && e.style == style) return e.style_id;
  }
  return std::nullopt;
}

/// Emits OOXML for a complete TFL document.
class DocxEmitter {
public:
  DocxEmitter(const StylesTemplate &tmpl, const std::unordered_map<std::string, StylesTemplate> *per_spec_templates,
              const RendererConfig &config);

  /// Emit a complete .docx file for a TFLDocument.
  /// @param doc  The parsed TFL document (all specs).
  /// @param data_tables  Map from data_ref -> DataTable.
  /// @param output_path  Path for the output .docx file.
  /// @param resolved_pages  Map from spec key -> PaginationResult.
  /// @param resolved_rows   Map from spec key -> logical rows.
  /// @param resolved_headers Map from spec key -> header grid.
  void emit(const TFLDocument &doc, const std::unordered_map<std::string, DataTable> &data_tables,
            const std::string &output_path, const std::unordered_map<std::string, PaginationResult> &resolved_pages,
            const std::unordered_map<std::string, std::vector<LogicalRow>> &resolved_rows,
            const std::unordered_map<std::string, HeaderGrid> &resolved_headers, TextMeasurer *measurer = nullptr);

private:
  struct SpecHdrFtrRefs {
    std::string header_rid;
    std::string footer_rid;
  };

  void build_hdr_ftr_parts(const TFLDocument &doc, std::vector<HdrFtrPartInfo> &all_hdr_ftr_parts,
                           std::vector<SpecHdrFtrRefs> &spec_hdr_ftr_refs) const;

  // ---- Static package files ----
  std::string emit_content_types(const TFLDocument &doc, const std::vector<HdrFtrPartInfo> &hdr_ftr_parts) const;
  std::string emit_rels() const;
  std::string emit_document_rels(const TFLDocument &doc, const std::vector<HdrFtrPartInfo> &hdr_ftr_parts) const;
  /// @param toc_tab_pos_twips When set, TOC 1–9 styles use this as the right-aligned
  ///   tab position (content width) so the TOC spans the full width of the first section's page.
  ///   When nullopt, a default (15840 twips) is used.
  /// @param toc_headings Precomputed TOC-heading styles (body title/subtitle + outline level) for styles.xml.
  std::string emit_styles(std::optional<int> toc_tab_pos_twips, const std::vector<TocHeadingEntry> &toc_headings) const;
  std::string emit_settings() const;
  std::string emit_font_table() const;
  void emit_package(const TFLDocument &doc, const std::string &output_path, const std::string &document_xml,
                    const std::vector<HdrFtrPartInfo> &all_hdr_ftr_parts,
                    const std::vector<TocHeadingEntry> &toc_headings) const;
  /// Build TOC-heading list from doc (all specs): distinct (resolved title/subtitle style, toclevel) with style_id.
  std::vector<TocHeadingEntry> build_toc_heading_styles(const TFLDocument &doc) const;
  std::string emit_document_xml(const TFLDocument &doc,
                                const std::unordered_map<std::string, PaginationResult> &resolved_pages,
                                const std::unordered_map<std::string, std::vector<LogicalRow>> &resolved_rows,
                                const std::unordered_map<std::string, HeaderGrid> &resolved_headers,
                                const std::vector<SpecHdrFtrRefs> &spec_hdr_ftr_refs,
                                const std::vector<TocHeadingEntry> &toc_headings) const;

  /// Returns template for a spec key, falling back to default template.
  const StylesTemplate &template_for_spec(const std::string &spec_key) const;

  // ---- Per-spec emission ----
  /// Emit document.xml content for a single spec's page.
  void emit_page(XmlWriter &w, const TFLSpec &spec, const PageSlice &page, const HorizontalSegment &segment,
                 const std::vector<LogicalRow> &rows, const HeaderGrid &header_grid, const StyleResolver &resolver,
                 const std::vector<ParsedCell> &parsed_titles, const std::vector<TocHeadingEntry> &toc_headings) const;

  /// Emit a table element.
  void emit_table(XmlWriter &w, const TFLSpec &spec, const PageSlice &page, const HorizontalSegment &segment,
                  const std::vector<LogicalRow> &rows, const HeaderGrid &header_grid,
                  const StyleResolver &resolver) const;

  /// Emit table header rows.
  /// @param col_widths  Per-column scaled widths (column index -> EMU).
  /// @param seg_cols    Pre-built set of column indices in this segment.
  void emit_table_header(XmlWriter &w, const HeaderGrid &header_grid, const HorizontalSegment &segment,
                         const StyleResolver &resolver, const std::unordered_map<size_t, int64_t> &col_widths,
                         const std::unordered_set<size_t> &seg_cols) const;

  /// Emit a single table body row.
  /// @param row_height  Segment-specific row height for trHeight.
  /// @param col_widths  Per-column scaled widths (column index -> EMU).
  /// @param seg_cols    Pre-built set of column indices in this segment.
  void emit_table_row(XmlWriter &w, const LogicalRow &row, Length row_height, const HorizontalSegment &segment,
                      const TFLSpec &spec, const StyleResolver &resolver, bool is_last_row,
                      const std::unordered_map<size_t, int64_t> &col_widths,
                      const std::unordered_set<size_t> &seg_cols) const;

  /// Emit a paragraph with styled content.
  void emit_paragraph(XmlWriter &w, const std::string &text, const StyleDef &style) const;

  /// Emit a paragraph with parsed inline markup.
  void emit_parsed_paragraph(XmlWriter &w, const ParsedParagraph &para, const StyleDef &base_style) const;

  /// Emit only the runs of a parsed paragraph (no w:p). Used for TC+title in one paragraph.
  void emit_parsed_paragraph_runs(XmlWriter &w, const ParsedParagraph &para, const StyleDef &base_style) const;

  /// Emit run properties (<w:rPr>).
  void emit_run_props(XmlWriter &w, const FontProps &font, const InlineRunStyle &run_style = {}) const;

  /// Emit paragraph properties (<w:pPr>).
  void emit_para_props(XmlWriter &w, const ParagraphProps &pp) const;

  /// Emit table cell properties (<w:tcPr>).
  void emit_cell_props(XmlWriter &w, const TableCellProps &tcp, Length cell_width, int grid_span = 1,
                       VMergeState v_merge = VMergeState::None) const;

  /// Emit titles/subtitles block. When group.toc_level > 0, uses TOC-heading style from toc_headings if found.
  void emit_text_groups(XmlWriter &w, const std::vector<TextGroup> &groups, const StyleDef &base_style,
                        const StyleResolver &resolver, const std::vector<TocHeadingEntry> &toc_headings) const;

  /// Emit all text groups concatenated in a single paragraph with soft breaks.
  /// Each group retains its own font style; paragraph props come from base_style.
  /// Optional prefix is prepended before first group.
  void emit_text_groups_combined(XmlWriter &w, const std::vector<TextGroup> &groups, const StyleDef &base_style,
                                 const StyleResolver &resolver, const std::string &prefix = "") const;

  /// Emit header/footer section.
  void emit_header_footer_section(XmlWriter &w, const std::vector<HeaderFooterRow> &rows, const StyleDef &style,
                                  Length usable_width, size_t page_num, size_t total_pages, bool use_fields) const;

  /// Emit a page break paragraph.
  void emit_page_break(XmlWriter &w) const;

  /// Emit an inline drawing paragraph for a figure image relationship.
  void emit_figure_drawing(XmlWriter &w, const std::string &r_id, int64_t cx_emu, int64_t cy_emu, int img_id,
                           const std::optional<ParagraphProps> &paragraph_props = std::nullopt) const;

  /// Emit section properties.
  /// @param is_body_level  True for the body-level sectPr (last child of
  ///   w:body).  In that position w:type must be omitted to prevent an
  ///   extra blank page at the end of the document.
  void emit_section_props(XmlWriter &w, const PageConfig &page, const std::string &header_rid = "",
                          const std::string &footer_rid = "", bool continuous = false,
                          bool is_body_level = false) const;

  // ---- Fields ----
  /// Emit PAGE field code.
  void emit_page_field(XmlWriter &w) const;
  /// Emit NUMPAGES field code.
  void emit_numpages_field(XmlWriter &w) const;
  /// Emit a complete TOC page as a separate Word section (nextPage break after it).
  /// @param w         XmlWriter for document.xml (w:body must already be open).
  /// @param toc_title Heading text above the TOC field; empty string omits the heading.
  /// @param page      Page config to use for the TOC section (taken from first spec).
  /// @param header_rid Relationship ID for the header part (may be empty).
  /// @param footer_rid Relationship ID for the footer part (may be empty).
  void emit_toc_page(XmlWriter &w, const std::string &toc_title, const PageConfig &page, const std::string &header_rid,
                     const std::string &footer_rid) const;

  /// Generate a standalone header or footer XML part.
  /// @param rows    The header/footer row content.
  /// @param style   Resolved style for the content.
  /// @param usable_w Usable page width for tab stops.
  /// @param root_element "w:hdr" or "w:ftr"
  /// @param footnotes  Optional footnotes to append after footer rows
  ///                   (used when footnotePlace="doc_footer").
  /// @param resolver   Required when footnotes is non-null.
  /// @return Complete XML string for the part.
  std::string emit_hdr_ftr_xml_part(const std::vector<HeaderFooterRow> &rows, const StyleDef &style, Length usable_w,
                                    const char *root_element, const std::vector<TextGroup> *footnotes = nullptr,
                                    const StyleResolver *resolver = nullptr) const;

  /// Stamp exact line height on a style's spacing props so the emitter
  /// can use w:lineRule="exact" for deterministic pagination.
  void stamp_exact_line_height(StyleDef &style) const;

  const StylesTemplate &tmpl_;
  const std::unordered_map<std::string, StylesTemplate> *per_spec_templates_;
  const RendererConfig &config_;
  TextMeasurer *measurer_ = nullptr; ///< set during emit(), cleared after
};

} // namespace kstfl

#endif // KSTFL_DOCX_EMITTER_H
