// kstfl/docx_emitter.cpp — orchestration entry point for DOCX emission
//
// High-level flow: build header/footer parts, emit document.xml,
// then assemble all package parts into final .docx.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "docx_emitter.h"


namespace kstfl {

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

DocxEmitter::DocxEmitter(const StylesTemplate& tmpl, const RendererConfig& config)
    : tmpl_(tmpl), config_(config) {}

// ---------------------------------------------------------------------------
// [Content_Types].xml, _rels/.rels, and word/_rels/document.xml.rels
// are implemented in docx_metadata.cpp.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// word/styles.xml, word/settings.xml, and word/fontTable.xml
// are implemented in docx_styles.cpp.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Content/style/text helper emission is implemented in docx_content.cpp.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// TOC/field emission helpers are implemented in docx_toc.cpp.
// Header/footer and section layout helpers are implemented in docx_layout.cpp.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Table emission helpers are implemented in docx_table.cpp.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Per-page content emission is implemented in docx_page.cpp.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// emit: main entry — assemble complete .docx
// ---------------------------------------------------------------------------

void DocxEmitter::emit(
    const TFLDocument& doc,
    const std::unordered_map<std::string, DataTable>& data_tables,
    const std::string& output_path,
    const std::unordered_map<std::string, PaginationResult>& resolved_pages,
    const std::unordered_map<std::string, std::vector<LogicalRow>>& resolved_rows,
    const std::unordered_map<std::string, HeaderGrid>& resolved_headers,
    TextMeasurer* measurer) {

    (void)data_tables;  // reserved for API compatibility; not needed at emit stage

    measurer_ = measurer;  // store for use in emit_page / emit_text_groups
    toc_bookmark_counter_ = 0;  // reset per document so IDs are deterministic

    // ======================================================================
    // Phase 1: Pre-compute header/footer XML parts and relationship IDs
    // ======================================================================

    std::vector<HdrFtrPartInfo> all_hdr_ftr_parts;
    std::vector<SpecHdrFtrRefs> spec_hdr_ftr_refs(doc.specs.size());
    build_hdr_ftr_parts(doc, all_hdr_ftr_parts, spec_hdr_ftr_refs);

    // ======================================================================
    // Phase 2: Generate document.xml
    // ======================================================================
    std::string document_xml = emit_document_xml(
        doc,
        resolved_pages,
        resolved_rows,
        resolved_headers,
        spec_hdr_ftr_refs);

    // Package all emitted XML parts and media into final DOCX archive.
    emit_package(doc, output_path, document_xml, all_hdr_ftr_parts);
    measurer_ = nullptr;  // clear after emit
}

}  // namespace kstfl
