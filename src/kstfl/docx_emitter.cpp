// kstfl/docx_emitter.cpp — orchestration entry point for DOCX emission
//
// High-level flow: build header/footer parts, emit document.xml,
// then assemble all package parts into final .docx.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "docx_emitter.h"
#include <algorithm>
#include <ranges>
#include <string>

namespace kstfl {

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

DocxEmitter::DocxEmitter(const StylesTemplate &tmpl,
                         const std::unordered_map<std::string, StylesTemplate> *per_spec_templates,
                         const RendererConfig &config)
    : tmpl_(tmpl), per_spec_templates_(per_spec_templates), config_(config) {}

const StylesTemplate &DocxEmitter::template_for_spec(const std::string &spec_key) const {
  if (per_spec_templates_) {
    auto it = per_spec_templates_->find(spec_key);
    if (it != per_spec_templates_->end()) { return it->second; }
  }
  return tmpl_;
}

// ---------------------------------------------------------------------------
// Build TOC-heading styles for body titles/subtitles (outline-level styles)
// ---------------------------------------------------------------------------

std::vector<TocHeadingEntry> DocxEmitter::build_toc_heading_styles(const TFLDocument &doc) const {
  std::vector<TocHeadingEntry> result;
  int level_index[10] = {0}; // 1-9 used for toclevel

  for (const auto &spec : doc.specs) {
    const StylesTemplate &t = template_for_spec(spec.key);
    StyleResolver resolver(t, spec.spec_styles);

    for (const auto &group : spec.titles) {
      if (group.toc_level < 1 || group.toc_level > 9) continue;
      StyleDef style = resolver.resolve_title_style(group.style_refs);
      stamp_exact_line_height(style);
      bool found = std::ranges::any_of(
          result, [&](const TocHeadingEntry &e) { return e.toc_level == group.toc_level && e.style == style; });
      if (!found) {
        TocHeadingEntry entry;
        entry.style = style;
        entry.toc_level = group.toc_level;
        entry.style_id =
            "TOCHead_" + std::to_string(group.toc_level) + "_" + std::to_string(level_index[group.toc_level]++);
        result.push_back(entry);
      }
    }

    for (const auto &group : spec.subtitles) {
      if (group.toc_level < 1 || group.toc_level > 9) continue;
      StyleDef style = resolver.resolve_subtitle_style(group.style_refs);
      stamp_exact_line_height(style);
      bool found = std::ranges::any_of(
          result, [&](const TocHeadingEntry &e) { return e.toc_level == group.toc_level && e.style == style; });
      if (!found) {
        TocHeadingEntry entry;
        entry.style = style;
        entry.toc_level = group.toc_level;
        entry.style_id =
            "TOCHead_" + std::to_string(group.toc_level) + "_" + std::to_string(level_index[group.toc_level]++);
        result.push_back(entry);
      }
    }
  }
  return result;
}

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

void DocxEmitter::emit(const TFLDocument &doc, const std::unordered_map<std::string, DataTable> &data_tables,
                       const std::string &output_path,
                       const std::unordered_map<std::string, PaginationResult> &resolved_pages,
                       const std::unordered_map<std::string, std::vector<LogicalRow>> &resolved_rows,
                       const std::unordered_map<std::string, HeaderGrid> &resolved_headers, TextMeasurer *measurer) {

  (void)data_tables; // reserved for API compatibility; not needed at emit stage

  measurer_ = measurer; // store for use in emit_page / emit_text_groups

  // RAII guard: reset measurer_ on scope exit (normal or exception)
  struct MeasurerReset {
    TextMeasurer *&ref;
    ~MeasurerReset() { ref = nullptr; }
  } measurer_guard{measurer_};

  // ======================================================================
  // Phase 1: Pre-compute header/footer XML parts and relationship IDs
  // ======================================================================

  std::vector<HdrFtrPartInfo> all_hdr_ftr_parts;
  std::vector<SpecHdrFtrRefs> spec_hdr_ftr_refs(doc.specs.size());
  build_hdr_ftr_parts(doc, all_hdr_ftr_parts, spec_hdr_ftr_refs);

  // ======================================================================
  // Phase 1b: Build TOC-heading styles (distinct title/subtitle style +
  // toclevel)
  // ======================================================================

  std::vector<TocHeadingEntry> toc_headings = build_toc_heading_styles(doc);

  // ======================================================================
  // Phase 2: Generate document.xml
  // ======================================================================
  std::string document_xml =
      emit_document_xml(doc, resolved_pages, resolved_rows, resolved_headers, spec_hdr_ftr_refs, toc_headings);

  // Package all emitted XML parts and media into final DOCX archive.
  emit_package(doc, output_path, document_xml, all_hdr_ftr_parts, toc_headings);
}

} // namespace kstfl
