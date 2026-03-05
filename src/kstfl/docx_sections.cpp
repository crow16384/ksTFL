// kstfl/docx_sections.cpp — section/header/footer preparation for DocxEmitter

#include "docx_emitter.h"

namespace kstfl {

void DocxEmitter::build_hdr_ftr_parts(
        const TFLDocument& doc,
        std::vector<HdrFtrPartInfo>& all_hdr_ftr_parts,
        std::vector<SpecHdrFtrRefs>& spec_hdr_ftr_refs) const {
    // Start relationship IDs after the base ones (rId1=styles, rId2=settings,
    // rId3=fontTable, rId4+ for images). Count images first.
    int next_rid = 4;
    for (const auto& spec : doc.specs) {
        if (spec.document.doc_type == DocType::Figure) next_rid++;
    }

    int hdr_ftr_idx = 1;
    for (size_t spec_idx = 0; spec_idx < doc.specs.size(); ++spec_idx) {
        const auto& spec = doc.specs[spec_idx];
        const auto& spec_tmpl = template_for_spec(spec.key);
        StyleResolver resolver(spec_tmpl, spec.spec_styles);
        PageConfig page_config = resolver.resolve_page_config(spec);
        Length usable_width = page_config.usable_width();

        if (!spec.headers.empty()) {
            std::string rid = "rId" + std::to_string(next_rid++);
            std::string part_path = "word/header" + std::to_string(hdr_ftr_idx) + ".xml";
            StyleDef header_style = resolver.resolve_doc_header_style();
            std::string xml = emit_hdr_ftr_xml_part(spec.headers, header_style,
                                                    usable_width, "w:hdr");
            all_hdr_ftr_parts.push_back({part_path, rid, xml, true});
            spec_hdr_ftr_refs[spec_idx].header_rid = rid;
            hdr_ftr_idx++;
        }

        if (!spec.footers.empty()) {
            std::string rid = "rId" + std::to_string(next_rid++);
            std::string part_path = "word/footer" + std::to_string(hdr_ftr_idx) + ".xml";
            StyleDef footer_style = resolver.resolve_doc_footer_style();
            const std::vector<TextGroup>* footnotes =
                (spec.document.footnote_place == FootnotePlace::DocFooter && !spec.footnotes.empty())
                    ? &spec.footnotes : nullptr;
            std::string xml = emit_hdr_ftr_xml_part(spec.footers, footer_style,
                                                    usable_width, "w:ftr",
                                                    footnotes, &resolver);
            all_hdr_ftr_parts.push_back({part_path, rid, xml, false});
            spec_hdr_ftr_refs[spec_idx].footer_rid = rid;
            hdr_ftr_idx++;
        }
    }
}

}  // namespace kstfl
