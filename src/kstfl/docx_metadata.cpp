// kstfl/docx_metadata.cpp — DOCX package metadata parts
//
// Extracted from docx_emitter.cpp to keep emitter orchestration focused.

#include "docx_emitter.h"

namespace kstfl {

// Package-level namespace constants
static constexpr const char* CT_NS = "http://schemas.openxmlformats.org/package/2006/content-types";
static constexpr const char* RELS_NS = "http://schemas.openxmlformats.org/package/2006/relationships";

// Relationship/content types
static constexpr const char* RT_DOCUMENT = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument";
static constexpr const char* RT_STYLES = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles";
static constexpr const char* RT_SETTINGS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings";
static constexpr const char* RT_FONT_TABLE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable";
static constexpr const char* RT_IMAGE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image";
static constexpr const char* RT_HEADER = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header";
static constexpr const char* RT_FOOTER = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer";
static constexpr const char* CT_HEADER = "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml";
static constexpr const char* CT_FOOTER = "application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml";

// ---------------------------------------------------------------------------
// [Content_Types].xml
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_content_types(const TFLDocument& doc,
                                             const std::vector<HdrFtrPartInfo>& hdr_ftr_parts) const {
    XmlWriter w;
    w.write_declaration();
    w.start_element("Types");
    w.attribute("xmlns", CT_NS);

    w.start_element("Default");
    w.attribute("Extension", "rels");
    w.attribute("ContentType", "application/vnd.openxmlformats-package.relationships+xml");
    w.end_element();

    w.start_element("Default");
    w.attribute("Extension", "xml");
    w.attribute("ContentType", "application/xml");
    w.end_element();

    w.start_element("Override");
    w.attribute("PartName", "/word/document.xml");
    w.attribute("ContentType", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml");
    w.end_element();

    w.start_element("Override");
    w.attribute("PartName", "/word/styles.xml");
    w.attribute("ContentType", "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml");
    w.end_element();

    w.start_element("Override");
    w.attribute("PartName", "/word/settings.xml");
    w.attribute("ContentType", "application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml");
    w.end_element();

    w.start_element("Override");
    w.attribute("PartName", "/word/fontTable.xml");
    w.attribute("ContentType", "application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml");
    w.end_element();

    for (const auto& part : hdr_ftr_parts) {
        w.start_element("Override");
        w.attribute("PartName", "/" + part.part_path);
        w.attribute("ContentType", part.is_header ? CT_HEADER : CT_FOOTER);
        w.end_element();
    }

    bool has_png = false, has_jpg = false, has_svg = false;
    for (const auto& spec : doc.specs) {
        if (spec.document.doc_type == DocType::Figure) {
            const auto& p = spec.figure_path;
            if (p.find(".png") != std::string::npos) has_png = true;
            if (p.find(".jpg") != std::string::npos || p.find(".jpeg") != std::string::npos) has_jpg = true;
            if (p.find(".svg") != std::string::npos) has_svg = true;
        }
    }
    if (has_png) {
        w.start_element("Default");
        w.attribute("Extension", "png");
        w.attribute("ContentType", "image/png");
        w.end_element();
    }
    if (has_jpg) {
        w.start_element("Default");
        w.attribute("Extension", "jpeg");
        w.attribute("ContentType", "image/jpeg");
        w.end_element();
    }
    if (has_svg) {
        w.start_element("Default");
        w.attribute("Extension", "svg");
        w.attribute("ContentType", "image/svg+xml");
        w.end_element();
    }

    w.end_element();
    return w.str();
}

// ---------------------------------------------------------------------------
// _rels/.rels
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_rels() const {
    XmlWriter w;
    w.write_declaration();
    w.start_element("Relationships");
    w.attribute("xmlns", RELS_NS);

    w.start_element("Relationship");
    w.attribute("Id", "rId1");
    w.attribute("Type", RT_DOCUMENT);
    w.attribute("Target", "word/document.xml");
    w.end_element();

    w.end_element();
    return w.str();
}

// ---------------------------------------------------------------------------
// word/_rels/document.xml.rels
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_document_rels(const TFLDocument& doc,
                                             const std::vector<HdrFtrPartInfo>& hdr_ftr_parts) const {
    XmlWriter w;
    w.write_declaration();
    w.start_element("Relationships");
    w.attribute("xmlns", RELS_NS);

    w.start_element("Relationship");
    w.attribute("Id", "rId1");
    w.attribute("Type", RT_STYLES);
    w.attribute("Target", "styles.xml");
    w.end_element();

    w.start_element("Relationship");
    w.attribute("Id", "rId2");
    w.attribute("Type", RT_SETTINGS);
    w.attribute("Target", "settings.xml");
    w.end_element();

    w.start_element("Relationship");
    w.attribute("Id", "rId3");
    w.attribute("Type", RT_FONT_TABLE);
    w.attribute("Target", "fontTable.xml");
    w.end_element();

    int rid = 4;
    for (const auto& spec : doc.specs) {
        if (spec.document.doc_type == DocType::Figure) {
            w.start_element("Relationship");
            w.attribute("Id", "rId" + std::to_string(rid));
            w.attribute("Type", RT_IMAGE);
            std::string ext = "png";
            size_t dot = spec.figure_path.rfind('.');
            if (dot != std::string::npos) ext = spec.figure_path.substr(dot + 1);
            w.attribute("Target", "media/image" + std::to_string(rid) + "." + ext);
            w.end_element();
            rid++;
        }
    }

    for (const auto& part : hdr_ftr_parts) {
        w.start_element("Relationship");
        w.attribute("Id", part.rid);
        w.attribute("Type", part.is_header ? RT_HEADER : RT_FOOTER);
        std::string target = part.part_path;
        if (target.substr(0, 5) == "word/") target = target.substr(5);
        w.attribute("Target", target);
        w.end_element();
    }

    w.end_element();
    return w.str();
}

}  // namespace kstfl
