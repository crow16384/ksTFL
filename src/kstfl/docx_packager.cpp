// kstfl/docx_packager.cpp — DOCX package assembly for DocxEmitter
//
// Builds the final .docx ZIP archive from emitted OOXML parts and media.

#include "docx_emitter.h"

namespace kstfl {

void DocxEmitter::emit_package(const TFLDocument &doc, const std::string &output_path, const std::string &document_xml,
                               const std::vector<HdrFtrPartInfo> &all_hdr_ftr_parts,
                               const std::vector<TocHeadingEntry> &toc_headings) const {
  // TOC 1–9 tab position: use first section's content width so TOC spans full width
  // for whatever page size and orientation the document uses.
  std::optional<int> toc_tab_twips;
  if (!doc.specs.empty()) {
    const auto &first_tmpl = template_for_spec(doc.specs[0].key);
    StyleResolver first_resolver(first_tmpl, doc.specs[0].spec_styles);
    PageConfig first_page = first_resolver.resolve_page_config(doc.specs[0]);
    toc_tab_twips = static_cast<int>(first_page.usable_width().to_twips());
  }

  ZipWriter zip(output_path);

  zip.add_entry("[Content_Types].xml", emit_content_types(doc, all_hdr_ftr_parts));
  zip.add_entry("_rels/.rels", emit_rels());
  zip.add_entry("word/_rels/document.xml.rels", emit_document_rels(doc, all_hdr_ftr_parts));
  zip.add_entry("word/document.xml", document_xml);
  zip.add_entry("word/styles.xml", emit_styles(toc_tab_twips, toc_headings));
  zip.add_entry("word/settings.xml", emit_settings());
  zip.add_entry("word/fontTable.xml", emit_font_table());

  // Add header/footer parts
  for (const auto &part : all_hdr_ftr_parts) {
    zip.add_entry(part.part_path, part.xml);
  }

  // Embed figures
  int img_idx = 4;
  for (const auto &spec : doc.specs) {
    if (spec.document.doc_type == DocType::Figure && !spec.figure_path.empty()) {
      std::string ext = "png";
      size_t dot = spec.figure_path.rfind('.');
      if (dot != std::string::npos) ext = spec.figure_path.substr(dot + 1);
      zip.add_file("word/media/image" + std::to_string(img_idx) + "." + ext, spec.figure_path);
      img_idx++;
    }
  }

  zip.close();
}

} // namespace kstfl
