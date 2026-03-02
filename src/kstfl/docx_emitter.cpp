// kstfl/docx_emitter.cpp — OOXML emission for DOCX documents
//
// Implements spec §19: streaming OOXML emission, fixed-layout tables,
// header repetition, page/section breaks, field codes.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include "docx_emitter.h"
#include "inline_parser.h"
#include <algorithm>
#include <Rcpp.h>
#include <sstream>
#include <cmath>
#include <cstring>
#include <iomanip>
#include <unordered_set>

namespace kstfl {

// OOXML namespace constants
static constexpr const char* W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
static constexpr const char* R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
static constexpr const char* MC_NS = "http://schemas.openxmlformats.org/markup-compatibility/2006";
static constexpr const char* WP_NS = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing";
static constexpr const char* A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main";
static constexpr const char* PIC_NS = "http://schemas.openxmlformats.org/drawingml/2006/picture";
static constexpr const char* CT_NS = "http://schemas.openxmlformats.org/package/2006/content-types";
static constexpr const char* RELS_NS = "http://schemas.openxmlformats.org/package/2006/relationships";

// Relationship types
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
// Constructor
// ---------------------------------------------------------------------------

DocxEmitter::DocxEmitter(const StylesTemplate& tmpl, const RendererConfig& config)
    : tmpl_(tmpl), config_(config) {}

// ---------------------------------------------------------------------------
// [Content_Types].xml
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_content_types(const TFLDocument& doc,
                                             const std::vector<HdrFtrPartInfo>& hdr_ftr_parts) const {
    XmlWriter w;
    w.write_declaration();
    w.start_element("Types");
    w.attribute("xmlns", CT_NS);

    // Default content types
    w.start_element("Default");
    w.attribute("Extension", "rels");
    w.attribute("ContentType", "application/vnd.openxmlformats-package.relationships+xml");
    w.end_element();

    w.start_element("Default");
    w.attribute("Extension", "xml");
    w.attribute("ContentType", "application/xml");
    w.end_element();

    // Part overrides
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

    // Header/footer part overrides
    for (const auto& part : hdr_ftr_parts) {
        w.start_element("Override");
        w.attribute("PartName", "/" + part.part_path);
        w.attribute("ContentType", part.is_header ? CT_HEADER : CT_FOOTER);
        w.end_element();
    }

    // Add image content types for figure specs
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

    w.end_element();  // Types
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

    // Add image relationships for figure specs
    int rid = 4;
    for (const auto& spec : doc.specs) {
        if (spec.document.doc_type == DocType::Figure) {
            w.start_element("Relationship");
            w.attribute("Id", "rId" + std::to_string(rid));
            w.attribute("Type", RT_IMAGE);
            // Image will be at word/media/imageN.ext
            std::string ext = "png";
            size_t dot = spec.figure_path.rfind('.');
            if (dot != std::string::npos) ext = spec.figure_path.substr(dot + 1);
            w.attribute("Target", "media/image" + std::to_string(rid) + "." + ext);
            w.end_element();
            rid++;
        }
    }
// Add header/footer relationships
    for (const auto& part : hdr_ftr_parts) {
        w.start_element("Relationship");
        w.attribute("Id", part.rid);
        w.attribute("Type", part.is_header ? RT_HEADER : RT_FOOTER);
        // Target is relative to word/ directory
        // part_path is "word/header1.xml" -> target is "header1.xml"
        std::string target = part.part_path;
        if (target.substr(0, 5) == "word/") target = target.substr(5);
        w.attribute("Target", target);
        w.end_element();
    }

    
    w.end_element();
    return w.str();
}

// ---------------------------------------------------------------------------
// word/styles.xml
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_styles(std::optional<int> toc_tab_pos_twips) const {
    XmlWriter w;
    w.write_declaration();
    w.start_element("w:styles");
    w.namespace_decl("w", W_NS);
    w.namespace_decl("r", R_NS);

    // Default document styles
    w.start_element("w:docDefaults");

    // Run defaults
    w.start_element("w:rPrDefault");
    w.start_element("w:rPr");
    const auto& df = tmpl_.text_styles.default_style.font.value_or(FontProps{});
    if (df.font_name.has_value()) {
        w.start_element("w:rFonts");
        w.attribute("w:ascii", df.font_name.value());
        w.attribute("w:hAnsi", df.font_name.value());
        w.attribute("w:cs", df.font_name.value());
        w.end_element();
    }
    if (df.font_size.has_value()) {
        // OOXML font size in half-points
        int half_pt = static_cast<int>(df.font_size.value() * 2.0);
        w.element_with_attr("w:sz", "w:val", std::to_string(half_pt));
        w.element_with_attr("w:szCs", "w:val", std::to_string(half_pt));
    }
    w.end_element();  // w:rPr
    w.end_element();  // w:rPrDefault

    // Paragraph defaults
    w.start_element("w:pPrDefault");
    w.start_element("w:pPr");
    const auto& dp = tmpl_.text_styles.default_style.paragraph.value_or(ParagraphProps{});
    if (dp.spacing.has_value()) {
        w.start_element("w:spacing");
        if (dp.spacing->before.has_value()) {
            w.attribute("w:before", std::to_string(dp.spacing->before->to_twips()));
        }
        if (dp.spacing->after.has_value()) {
            w.attribute("w:after", std::to_string(dp.spacing->after->to_twips()));
        }
        if (dp.spacing->line_spacing_multiplier.has_value()) {
            // OOXML line spacing in 240ths of a line: 240 = single, 360 = 1.5, 480 = double
            int line_val = static_cast<int>(dp.spacing->line_spacing_multiplier.value() * 240.0);
            w.attribute("w:line", std::to_string(line_val));
            w.attribute("w:lineRule", "auto");
        }
        w.end_element();  // w:spacing
    }
    w.end_element();  // w:pPr
    w.end_element();  // w:pPrDefault

    w.end_element();  // w:docDefaults

    // Normal style (base)
    w.start_element("w:style");
    w.attribute("w:type", "paragraph");
    w.attribute("w:default", "1");
    w.attribute("w:styleId", "Normal");
    w.element_with_attr("w:name", "w:val", "Normal");
    w.end_element();

    // TOC 1–9 styles: required for Word to render TC-field-based TOC entries.
    // Without these styles Word may report "No table of contents entries found"
    // even when TC fields are present and correctly formed.
    // Tab position for right-aligned page numbers: use first section's content width
    // when available so TOC spans full width for any page size/orientation; else 15840 twips.
    const int toc_tab_twips = toc_tab_pos_twips.value_or(15840);
    for (int level = 1; level <= 9; ++level) {
        std::string style_id = "TOC" + std::to_string(level);
        std::string style_name = "toc " + std::to_string(level);
        int indent_twips = (level - 1) * 360;  // 0.25in per level
        w.start_element("w:style");
        w.attribute("w:type", "paragraph");
        w.attribute("w:styleId", style_id);
        w.element_with_attr("w:name", "w:val", style_name);
        w.element_with_attr("w:basedOn", "w:val", "Normal");
        w.start_element("w:pPr");
        if (indent_twips > 0) {
            w.start_element("w:ind");
            w.attribute("w:left", std::to_string(indent_twips));
            w.end_element();
        }
        w.start_element("w:tabs");
        w.start_element("w:tab");
        w.attribute("w:val", "right");
        w.attribute("w:leader", "dot");
        w.attribute("w:pos", std::to_string(toc_tab_twips));
        w.end_element();
        w.end_element();  // w:tabs
        w.end_element();  // w:pPr
        w.end_element();  // w:style
    }

    w.end_element();  // w:styles
    return w.str();
}

// ---------------------------------------------------------------------------
// word/settings.xml
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_settings() const {
    XmlWriter w;
    w.write_declaration();
    w.start_element("w:settings");
    w.namespace_decl("w", W_NS);

    // Compatibility settings for deterministic layout
    w.start_element("w:compat");
    // Use Word 2013+ compatibility
    w.start_element("w:compatSetting");
    w.attribute("w:name", "compatibilityMode");
    w.attribute("w:uri", "http://schemas.microsoft.com/office/word");
    w.attribute("w:val", "15");
    w.end_element();
    w.end_element();

    // Do not update fields when the document is opened (avoids the "fields that may
    // refer to other files" prompt for TOC and other fields).
    w.start_element("w:updateFields");
    w.attribute("w:val", "false");
    w.end_element();

    // Widow/orphan control
    if (tmpl_.widow_control.value_or(true)) {
        w.self_closing_element("w:widowControl");
    }

    w.end_element();  // w:settings
    return w.str();
}

// ---------------------------------------------------------------------------
// word/fontTable.xml
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_font_table() const {
    XmlWriter w;
    w.write_declaration();
    w.start_element("w:fonts");
    w.namespace_decl("w", W_NS);

    // At minimum, declare the default font family
    auto default_font = tmpl_.text_styles.default_style.font;
    std::string font_name = default_font.has_value()
        ? default_font->font_name.value_or("Courier New")
        : "Courier New";

    w.start_element("w:font");
    w.attribute("w:name", font_name);
    w.element_with_attr("w:charset", "w:val", "00");
    w.element_with_attr("w:family", "w:val", "modern");
    w.element_with_attr("w:pitch", "w:val", "fixed");
    w.end_element();

    // Also declare Times New Roman (Word requires it)
    w.start_element("w:font");
    w.attribute("w:name", "Times New Roman");
    w.element_with_attr("w:charset", "w:val", "00");
    w.element_with_attr("w:family", "w:val", "roman");
    w.element_with_attr("w:pitch", "w:val", "variable");
    w.end_element();

    w.end_element();  // w:fonts
    return w.str();
}

// ---------------------------------------------------------------------------
// Exact line height stamping
// ---------------------------------------------------------------------------

void DocxEmitter::stamp_exact_line_height(StyleDef& style) const {
    if (!measurer_) return;           // no measurer available, skip
    if (!style.font) return;          // no font info, skip

    const auto& fp = *style.font;
    double mult = 1.0;
    if (style.paragraph && style.paragraph->spacing &&
        style.paragraph->spacing->line_spacing_multiplier) {
        mult = *style.paragraph->spacing->line_spacing_multiplier;
    }

    Length lh = measurer_->line_height(fp, mult);

    // Ensure paragraph.spacing exists
    if (!style.paragraph) style.paragraph = ParagraphProps{};
    if (!style.paragraph->spacing) style.paragraph->spacing = SpacingProps{};
    style.paragraph->spacing->exact_line_height = lh;
}

// ---------------------------------------------------------------------------
// Run properties (<w:rPr>)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_run_props(XmlWriter& w,
                                  const FontProps& font,
                                  const InlineRunStyle& run_style) const {
    w.start_element("w:rPr");

    if (font.font_name.has_value()) {
        w.start_element("w:rFonts");
        w.attribute("w:ascii", font.font_name.value());
        w.attribute("w:hAnsi", font.font_name.value());
        w.attribute("w:cs", font.font_name.value());
        w.end_element();
    }

    bool bold = font.bold.value_or(false) || run_style.bold_override;
    if (bold) {
        w.self_closing_element("w:b");
        w.self_closing_element("w:bCs");
    }

    bool italic = font.italic.value_or(false) || run_style.italic_override;
    if (italic) {
        w.self_closing_element("w:i");
        w.self_closing_element("w:iCs");
    }

    bool underline = font.underline.value_or(false) || run_style.underline_override;
    if (underline) {
        w.element_with_attr("w:u", "w:val", "single");
    }

    if (font.font_size.has_value()) {
        double size = font.font_size.value();
        // Note: do NOT reduce font size for superscript/subscript here.
        // Word handles the visual sizing via w:vertAlign; manual reduction
        // would double-apply the size change.
        int half_pt = static_cast<int>(size * 2.0);
        w.element_with_attr("w:sz", "w:val", std::to_string(half_pt));
        w.element_with_attr("w:szCs", "w:val", std::to_string(half_pt));
    }

    if (font.color.has_value() && !font.color->empty()) {
        w.element_with_attr("w:color", "w:val", font.color->hex);
    }

    if (font.highlight.has_value() && !font.highlight->empty()) {
        w.start_element("w:shd");
        w.attribute("w:val", "clear");
        w.attribute("w:color", "auto");
        w.attribute("w:fill", font.highlight->hex);
        w.end_element();
    }

    // Superscript/subscript
    if (run_style.superscript) {
        w.element_with_attr("w:vertAlign", "w:val", "superscript");
    } else if (run_style.subscript) {
        w.element_with_attr("w:vertAlign", "w:val", "subscript");
    }

    w.end_element();  // w:rPr
}

// ---------------------------------------------------------------------------
// Paragraph properties (<w:pPr>)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_para_props(XmlWriter& w, const ParagraphProps& pp) const {
    w.start_element("w:pPr");

    if (pp.alignment.has_value()) {
        w.element_with_attr("w:jc", "w:val", alignment_to_ooxml(pp.alignment.value()));
    }

    if (pp.spacing.has_value()) {
        w.start_element("w:spacing");
        if (pp.spacing->before.has_value()) {
            w.attribute("w:before", std::to_string(pp.spacing->before->to_twips()));
        }
        if (pp.spacing->after.has_value()) {
            w.attribute("w:after", std::to_string(pp.spacing->after->to_twips()));
        }
        if (pp.spacing->exact_line_height.has_value()) {
            // Deterministic mode: emit exact twip value matching our paginator's
            // measurement, so Word uses precisely our calculated line height.
            int64_t lh_twips = pp.spacing->exact_line_height->to_twips();
            if (lh_twips < 1) lh_twips = 1;
            w.attribute("w:line", std::to_string(lh_twips));
            w.attribute("w:lineRule", "exact");
        } else if (pp.spacing->line_spacing_multiplier.has_value()) {
            int line_val = static_cast<int>(pp.spacing->line_spacing_multiplier.value() * 240.0);
            w.attribute("w:line", std::to_string(line_val));
            w.attribute("w:lineRule", "auto");
        }
        w.end_element();
    }

    if (pp.indents.has_value()) {
        w.start_element("w:ind");
        if (pp.indents->left.has_value()) {
            w.attribute("w:left", std::to_string(pp.indents->left->to_twips()));
        }
        if (pp.indents->right.has_value()) {
            w.attribute("w:right", std::to_string(pp.indents->right->to_twips()));
        }
        if (pp.indents->first_line.has_value()) {
            w.attribute("w:firstLine", std::to_string(pp.indents->first_line->to_twips()));
        }
        if (pp.indents->hanging.has_value()) {
            w.attribute("w:hanging", std::to_string(pp.indents->hanging->to_twips()));
        }
        w.end_element();
    }

    if (pp.keep_next.value_or(false)) {
        w.self_closing_element("w:keepNext");
    }
    if (pp.keep_lines.value_or(false)) {
        w.self_closing_element("w:keepLines");
    }
    if (pp.widow_control.value_or(false)) {
        w.self_closing_element("w:widowControl");
    }

    w.end_element();  // w:pPr
}

// ---------------------------------------------------------------------------
// Table cell properties (<w:tcPr>)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_cell_props(XmlWriter& w,
                                   const TableCellProps& tcp,
                                   Length cell_width,
                                   int grid_span,
                                   VMergeState v_merge) const {
    w.start_element("w:tcPr");

    // Cell width in twips
    w.start_element("w:tcW");
    w.attribute("w:w", std::to_string(cell_width.to_twips()));
    w.attribute("w:type", "dxa");
    w.end_element();

    // Grid span for merged cells
    if (grid_span > 1) {
        w.element_with_attr("w:gridSpan", "w:val", std::to_string(grid_span));
    }

    // Vertical merge
    if (v_merge == VMergeState::Restart) {
        w.element_with_attr("w:vMerge", "w:val", "restart");
    } else if (v_merge == VMergeState::Continue) {
        w.self_closing_element("w:vMerge");
    }

    // Vertical alignment
    if (tcp.vertical_alignment.has_value()) {
        const char* val = "top";
        switch (tcp.vertical_alignment.value()) {
            case VerticalAlignment::Top:     val = "top"; break;
            case VerticalAlignment::Center:  val = "center"; break;
            case VerticalAlignment::Bottom:  val = "bottom"; break;
        }
        w.element_with_attr("w:vAlign", "w:val", val);
    }

    // Background color / shading
    if (tcp.background_color.has_value() && !tcp.background_color->empty()) {
        w.start_element("w:shd");
        w.attribute("w:val", "clear");
        w.attribute("w:color", "auto");
        w.attribute("w:fill", tcp.background_color->hex);
        w.end_element();
    }

    // Text orientation
    if (tcp.text_orientation.has_value()) {
        switch (tcp.text_orientation.value()) {
            case TextOrientation::BottomToTop:
                w.element_with_attr("w:textDirection", "w:val", "btLr");
                break;
            case TextOrientation::TopToBottom:
                w.element_with_attr("w:textDirection", "w:val", "tbRl");
                break;
            default: break;
        }
    }

    // Cell borders
    if (tcp.borders.has_value()) {
        w.start_element("w:tcBorders");
        auto emit_border = [&](const char* name, const std::optional<Border>& b) {
            if (!b.has_value()) return;
            w.start_element(name);
            if (b->line_style.has_value()) {
                w.attribute("w:val", border_line_style_to_ooxml(b->line_style.value()));
            } else {
                w.attribute("w:val", "single");
            }
            if (b->width.has_value()) {
                // Border width in 1/8 points (OOXML quirk)
                int eighth_pt = static_cast<int>(b->width->to_pt() * 8.0);
                w.attribute("w:sz", std::to_string(eighth_pt));
            }
            if (b->color.has_value() && !b->color->empty()) {
                w.attribute("w:color", b->color->hex);
            } else {
                w.attribute("w:color", "auto");
            }
            w.attribute("w:space", "0");
            w.end_element();
        };
        emit_border("w:top", tcp.borders->top);
        emit_border("w:bottom", tcp.borders->bottom);
        emit_border("w:left", tcp.borders->left);
        emit_border("w:right", tcp.borders->right);
        w.end_element();  // w:tcBorders
    }

    // Cell margins
    bool has_margins = tcp.cell_margin_top.has_value() || tcp.cell_margin_bottom.has_value() ||
                       tcp.cell_margin_left.has_value() || tcp.cell_margin_right.has_value();
    if (has_margins) {
        w.start_element("w:tcMar");
        auto emit_margin = [&](const char* name, const std::optional<Length>& m) {
            if (!m.has_value()) return;
            w.start_element(name);
            w.attribute("w:w", std::to_string(m->to_twips()));
            w.attribute("w:type", "dxa");
            w.end_element();
        };
        emit_margin("w:top", tcp.cell_margin_top);
        emit_margin("w:bottom", tcp.cell_margin_bottom);
        emit_margin("w:left", tcp.cell_margin_left);
        emit_margin("w:right", tcp.cell_margin_right);
        w.end_element();  // w:tcMar
    }

    w.end_element();  // w:tcPr
}

// ---------------------------------------------------------------------------
// Emit a paragraph with plain text + style
// ---------------------------------------------------------------------------

void DocxEmitter::emit_paragraph(XmlWriter& w,
                                  const std::string& text,
                                  const StyleDef& style) const {
    // Parse inline markup first
    ParsedCell parsed = parse_inline_markup(text);

    if (parsed.paragraphs.empty()) {
        // Empty paragraph
        w.start_element("w:p");
        if (style.paragraph.has_value()) {
            emit_para_props(w, style.paragraph.value());
        }
        w.end_element();
        return;
    }

    for (const auto& para : parsed.paragraphs) {
        emit_parsed_paragraph(w, para, style);
    }
}

// ---------------------------------------------------------------------------
// Emit a parsed paragraph (with inline markup runs)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_parsed_paragraph(XmlWriter& w,
                                         const ParsedParagraph& para,
                                         const StyleDef& base_style) const {
    w.start_element("w:p");

    // Paragraph properties
    if (base_style.paragraph.has_value()) {
        emit_para_props(w, base_style.paragraph.value());
    }

    emit_parsed_paragraph_runs(w, para, base_style);
    w.end_element();  // w:p
}

void DocxEmitter::emit_parsed_paragraph_runs(XmlWriter& w,
                                               const ParsedParagraph& para,
                                               const StyleDef& base_style) const {
    FontProps base_font = base_style.font.value_or(FontProps{});

    for (const auto& run : para.runs) {
        w.start_element("w:r");
        emit_run_props(w, base_font, run.style);

        if (run.text == "\n") {
            w.self_closing_element("w:br");
        } else {
            w.element_with_text("w:t", run.text);
        }

        w.end_element();  // w:r
    }
}

// ---------------------------------------------------------------------------
// Emit text groups (titles, subtitles, footnotes)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_text_groups(XmlWriter& w,
                                    const std::vector<TextGroup>& groups,
                                    const StyleDef& base_style,
                                    const StyleResolver& resolver) const {
    for (const auto& group : groups) {
        StyleDef style = base_style;
        for (const auto& ref : group.style_refs) {
            const StyleDef* ref_style = resolver.find_style(ref);
            if (ref_style) {
                style = style.merged_with(*ref_style);
            }
        }

        // Stamp exact line height so Word uses same height as paginator
        stamp_exact_line_height(style);

        // Concatenate text lines with soft break (within one paragraph)
        std::string combined;
        for (size_t i = 0; i < group.text.size(); ++i) {
            if (i > 0) combined += "<br>";
            combined += group.text[i];
        }

        // When toclevel is set: put TC field in the same paragraph as the title so Word finds the entry
        if (group.toc_level > 0) {
            std::string toc_plain;
            for (size_t i = 0; i < group.text.size(); ++i) {
                if (i > 0) toc_plain += ' ';
                toc_plain += get_plain_text(group.text[i]);
            }
            w.start_element("w:p");
            if (style.paragraph.has_value()) {
                emit_para_props(w, style.paragraph.value());
            }
            emit_tc_field(w, toc_plain, group.toc_level);
            ParsedCell parsed = parse_inline_markup(combined);
            if (!parsed.paragraphs.empty()) {
                emit_parsed_paragraph_runs(w, parsed.paragraphs[0], style);
            }
            w.end_element();  // w:p
        } else {
            emit_paragraph(w, combined, style);
        }
    }
}

// ---------------------------------------------------------------------------
// Emit all text groups combined in one paragraph with soft breaks
// ---------------------------------------------------------------------------

void DocxEmitter::emit_text_groups_combined(XmlWriter& w,
                                             const std::vector<TextGroup>& groups,
                                             const StyleDef& base_style,
                                             const StyleResolver& resolver,
                                             const std::string& prefix) const {
    w.start_element("w:p");

    // Paragraph properties from base style
    if (base_style.paragraph.has_value()) {
        emit_para_props(w, base_style.paragraph.value());
    }

    bool first_run = true;

    // Helper: emit a soft break run with given font
    auto emit_break = [&](const FontProps& font) {
        w.start_element("w:r");
        emit_run_props(w, font);
        w.self_closing_element("w:br");
        w.end_element();
    };

    // Optionally emit prefix text
    if (!prefix.empty()) {
        FontProps base_font = base_style.font.value_or(FontProps{});
        w.start_element("w:r");
        emit_run_props(w, base_font);
        w.element_with_text("w:t", prefix);
        w.end_element();
        first_run = false;
    }

    // Emit each group's text lines as runs, with <br> between groups
    for (const auto& group : groups) {
        StyleDef style = base_style;
        for (const auto& ref : group.style_refs) {
            const StyleDef* ref_style = resolver.find_style(ref);
            if (ref_style) {
                style = style.merged_with(*ref_style);
            }
        }
        FontProps font = style.font.value_or(FontProps{});

        for (size_t i = 0; i < group.text.size(); ++i) {
            // Soft break before each line except the very first run
            if (!first_run) {
                emit_break(font);
            }

            w.start_element("w:r");
            emit_run_props(w, font);
            w.element_with_text("w:t", group.text[i]);
            w.end_element();
            first_run = false;
        }
    }

    w.end_element();  // w:p
}

// ---------------------------------------------------------------------------
// Emit header/footer section (3-column layout with tab stops)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_header_footer_section(XmlWriter& w,
                                              const std::vector<HeaderFooterRow>& rows,
                                              const StyleDef& style,
                                              Length usable_width,
                                              size_t page_num,
                                              size_t total_pages,
                                              bool use_fields) const {
    FontProps font = style.font.value_or(FontProps{});

    // Lambda: emit a text segment with page field code placeholders
    // AND inline markup support (<b>, <i>, <u>, <sup>, <sub>).
    // Supports both {PAGE}/{NUMPAGES} and #page/#pages patterns.
    auto emit_text_with_fields = [&](const std::string& text) {
        if (text.empty()) return;

        // Parse inline markup into runs with style overrides.
        // Note: headers/footers are single-line, so we only look at the
        // first paragraph (no <p> or <br> support needed here).
        ParsedCell parsed = parse_inline_markup(text);
        if (parsed.paragraphs.empty()) return;

        const auto& runs = parsed.paragraphs[0].runs;

        for (const auto& run : runs) {
            if (run.text.empty()) continue;

            if (!use_fields) {
                // No field substitution needed — emit the run with style
                w.start_element("w:r");
                emit_run_props(w, font, run.style);
                w.element_with_text("w:t", run.text);
                w.end_element();
                continue;
            }

            // Scan for field placeholders within this run
            size_t pos = 0;
            while (pos < run.text.size()) {
                struct Match { size_t pos; size_t len; bool is_numpages; };
                Match best{std::string::npos, 0, false};

                const char* patterns[] = {"{NUMPAGES}", "{PAGE}", "#pages", "#page"};
                bool is_numpages_map[] = {true, false, true, false};

                for (int pi = 0; pi < 4; ++pi) {
                    size_t found = run.text.find(patterns[pi], pos);
                    if (found != std::string::npos && found < best.pos) {
                        best.pos = found;
                        best.len = std::strlen(patterns[pi]);
                        best.is_numpages = is_numpages_map[pi];
                    }
                }

                if (best.pos == std::string::npos) {
                    // No more placeholders — emit rest as literal
                    w.start_element("w:r");
                    emit_run_props(w, font, run.style);
                    w.element_with_text("w:t", run.text.substr(pos));
                    w.end_element();
                    break;
                }

                // Emit literal text before the placeholder
                if (best.pos > pos) {
                    w.start_element("w:r");
                    emit_run_props(w, font, run.style);
                    w.element_with_text("w:t", run.text.substr(pos, best.pos - pos));
                    w.end_element();
                }

                // Emit field code
                if (best.is_numpages) {
                    emit_numpages_field(w);
                } else {
                    emit_page_field(w);
                }

                pos = best.pos + best.len;
            }
        }
    };

    for (const auto& row : rows) {
        w.start_element("w:p");

        // Paragraph properties with tab stops for center and right alignment
        w.start_element("w:pPr");
        if (style.paragraph.has_value()) {
            // Apply spacing from style
            if (style.paragraph->spacing.has_value()) {
                w.start_element("w:spacing");
                if (style.paragraph->spacing->before.has_value()) {
                    w.attribute("w:before",
                        std::to_string(style.paragraph->spacing->before->to_twips()));
                }
                if (style.paragraph->spacing->after.has_value()) {
                    w.attribute("w:after",
                        std::to_string(style.paragraph->spacing->after->to_twips()));
                }
                if (style.paragraph->spacing->line_spacing_multiplier.has_value()) {
                    int line_val = static_cast<int>(
                        style.paragraph->spacing->line_spacing_multiplier.value() * 240.0);
                    w.attribute("w:line", std::to_string(line_val));
                    w.attribute("w:lineRule", "auto");
                }
                w.end_element();
            }
        }
        w.start_element("w:tabs");
        // Center tab at usable_width / 2
        w.start_element("w:tab");
        w.attribute("w:val", "center");
        w.attribute("w:pos", std::to_string((usable_width / 2.0).to_twips()));
        w.end_element();
        // Right tab at usable_width
        w.start_element("w:tab");
        w.attribute("w:val", "right");
        w.attribute("w:pos", std::to_string(usable_width.to_twips()));
        w.end_element();
        w.end_element();  // w:tabs
        w.end_element();  // w:pPr

        // Left content
        emit_text_with_fields(row.left);

        // Tab to center
        w.start_element("w:r");
        w.self_closing_element("w:tab");
        w.end_element();

        // Center content
        emit_text_with_fields(row.center);

        // Tab to right
        w.start_element("w:r");
        w.self_closing_element("w:tab");
        w.end_element();

        // Right content
        emit_text_with_fields(row.right);

        w.end_element();  // w:p
    }
}

// ---------------------------------------------------------------------------
// Page field (PAGE)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_page_field(XmlWriter& w) const {
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "begin");
    w.end_element();
    w.end_element();

    w.start_element("w:r");
    w.start_element("w:instrText");
    w.attribute("xml:space", "preserve");
    w.text(" PAGE ");
    w.end_element();
    w.end_element();

    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "end");
    w.end_element();
    w.end_element();
}

// ---------------------------------------------------------------------------
// NUMPAGES field
// ---------------------------------------------------------------------------

void DocxEmitter::emit_numpages_field(XmlWriter& w) const {
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "begin");
    w.end_element();
    w.end_element();

    w.start_element("w:r");
    w.start_element("w:instrText");
    w.attribute("xml:space", "preserve");
    w.text(" NUMPAGES ");
    w.end_element();
    w.end_element();

    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "end");
    w.end_element();
    w.end_element();
}

// ---------------------------------------------------------------------------
// TC (Table of Contents Entry) field runs (no w:p wrapper — caller owns the paragraph).
//
// TC fields must NOT use w:vanish on their runs. Word hides TC fields via its own
// internal mechanism; adding w:vanish causes Word to skip them during TOC generation.
// Structure: bookmarkStart → begin → instrText → end → bookmarkEnd
//
// The w:bookmarkStart/End pair (name "_TocXXXXXX") is required for two reasons:
//   1. When the TOC field uses \h, Word generates internal hyperlinks that point to
//      these bookmarks — not external file paths — so PDF navigation works correctly.
//   2. Word's "Generate Bookmarks" option in PDF export becomes active when the
//      document contains named bookmarks, enabling clickable PDF bookmarks.
// ---------------------------------------------------------------------------

void DocxEmitter::emit_tc_field(XmlWriter& w, const std::string& entry_text, int level) const {
    // Allocate a unique bookmark ID and build the _Toc name.
    int bm_id = ++toc_bookmark_counter_;
    // Format as _Toc + zero-padded 9-digit number (matches Word's own naming).
    char bm_name[32];
    std::snprintf(bm_name, sizeof(bm_name), "_Toc%09d", bm_id);

    // Escape double-quotes for Word field code: " -> ""
    std::string escaped;
    escaped.reserve(entry_text.size() + 4);
    for (char c : entry_text) {
        if (c == '"') escaped += "\"\"";
        else escaped += c;
    }
    // Leading and trailing spaces required by OOXML field instruction syntax.
    // No \f type — untyped TC entries are collected by { TOC \f } (no letter).
    std::string instr = " TC \"" + escaped + "\" \\l " + std::to_string(level) + " ";

    // bookmarkStart — wraps the TC field so the TOC \h switch can target it
    w.start_element("w:bookmarkStart");
    w.attribute("w:id", std::to_string(bm_id));
    w.attribute("w:name", bm_name);
    w.end_element();

    // begin — no w:rPr, no w:vanish
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "begin");
    w.end_element();
    w.end_element();

    // instrText
    w.start_element("w:r");
    w.start_element("w:instrText");
    w.attribute("xml:space", "preserve");
    w.text(instr);
    w.end_element();
    w.end_element();

    // end
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "end");
    w.end_element();
    w.end_element();

    // bookmarkEnd
    w.start_element("w:bookmarkEnd");
    w.attribute("w:id", std::to_string(bm_id));
    w.end_element();
}

// ---------------------------------------------------------------------------
// TOC page — a separate Word section prepended before all specs.
//
// Structure emitted into w:body:
//   [optional] <w:p> title paragraph (e.g. "Table of Contents")
//   <w:p> containing the { TOC \f \h \z } complex field
//   <w:p> section-break paragraph (nextPage) that ends the TOC section
//
// The TOC field uses:
//   \f  — collect all untyped TC fields (no letter = all TC entries)
//   \h  — make entries hyperlinks; safe because each TC field paragraph carries a
//          w:bookmarkStart/End (_TocXXXXXX), so Word generates internal #anchor
//          links rather than external file:// paths — no security prompt, and PDF
//          navigation (Ctrl+Click in Word, clickable bookmarks in PDF) works correctly.
//   \z  — hide tab leader and page numbers in Web Layout view
// ---------------------------------------------------------------------------

void DocxEmitter::emit_toc_page(XmlWriter& w,
                                 const std::string& toc_title,
                                 const PageConfig& page,
                                 const std::string& header_rid,
                                 const std::string& footer_rid) const
{
    // Optional title paragraph
    if (!toc_title.empty()) {
        w.start_element("w:p");
        w.start_element("w:r");
        w.start_element("w:rPr");
        w.self_closing_element("w:b");
        w.end_element();  // w:rPr
        w.start_element("w:t");
        w.attribute("xml:space", "preserve");
        w.text(toc_title);
        w.end_element();  // w:t
        w.end_element();  // w:r
        w.end_element();  // w:p
    }

    // TOC field paragraph: { TOC \f \z }
    // \f  — collect all untyped TC fields
    // \z  — hide tab/page numbers in Web Layout view
    // No \h — omitting hyperlinks avoids the "fields that may refer to other files" prompt.
    // No fldLock — field must remain unlocked so the user can press F9 to update it.
    // Complex field: begin → instrText → separate → (result placeholder) → end
    w.start_element("w:p");

    // begin
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "begin");
    w.end_element();
    w.end_element();

    // instrText — \f \h \z: collect TC fields, make entries hyperlinks, hide in Web view.
    // \h is safe here because TC field paragraphs carry _Toc bookmarks, so Word
    // generates internal #anchor links (not file:// paths) — no security prompt.
    w.start_element("w:r");
    w.start_element("w:instrText");
    w.attribute("xml:space", "preserve");
    w.text(" TOC \\f \\h \\z ");
    w.end_element();
    w.end_element();

    // separate
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "separate");
    w.end_element();
    w.end_element();

    // placeholder result run (empty — Word fills this on F9 update)
    w.start_element("w:r");
    w.start_element("w:rPr");
    w.self_closing_element("w:noProof");
    w.end_element();
    w.end_element();

    // end
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "end");
    w.end_element();
    w.end_element();

    w.end_element();  // w:p (TOC field)

    // Section-break paragraph — ends the TOC section with a nextPage break.
    // This paragraph carries the sectPr for the TOC section (same page config as first spec).
    w.start_element("w:p");
    w.start_element("w:pPr");
    emit_section_props(w, page, header_rid, footer_rid, /*continuous=*/false, /*is_body_level=*/false);
    w.end_element();  // w:pPr
    w.end_element();  // w:p
}

// ---------------------------------------------------------------------------
// Generate a standalone header/footer XML part
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_hdr_ftr_xml_part(
    const std::vector<HeaderFooterRow>& rows,
    const StyleDef& style,
    Length usable_w,
    const char* root_element) const
{
    XmlWriter w;
    w.write_declaration();
    w.start_element(root_element);
    w.namespace_decl("w", W_NS);
    w.namespace_decl("r", R_NS);

    // Always use field codes in header/footer parts (Word resolves them)
    emit_header_footer_section(w, rows, style, usable_w, 0, 0, true);

    w.end_element();  // w:hdr or w:ftr
    return w.str();
}

// ---------------------------------------------------------------------------
// Page break paragraph
// ---------------------------------------------------------------------------

void DocxEmitter::emit_page_break(XmlWriter& w) const {
    w.start_element("w:p");
    // Minimize height: tiny font + zero spacing so page break paragraph
    // doesn't consume vertical space on the previous page.
    w.start_element("w:pPr");
    w.start_element("w:spacing");
    w.attribute("w:before", "0");
    w.attribute("w:after", "0");
    w.attribute("w:line", "0");
    w.attribute("w:lineRule", "exact");
    w.end_element();  // w:spacing
    w.start_element("w:rPr");
    w.start_element("w:sz");
    w.attribute("w:val", "2");  // 1pt
    w.end_element();
    w.end_element();  // w:rPr
    w.end_element();  // w:pPr
    w.start_element("w:r");
    w.start_element("w:rPr");
    w.start_element("w:sz");
    w.attribute("w:val", "2");
    w.end_element();
    w.end_element();  // w:rPr
    w.start_element("w:br");
    w.attribute("w:type", "page");
    w.end_element();
    w.end_element();
    w.end_element();
}

// ---------------------------------------------------------------------------
// Section properties
// ---------------------------------------------------------------------------

void DocxEmitter::emit_section_props(XmlWriter& w,
                                      const PageConfig& page,
                                      const std::string& header_rid,
                                      const std::string& footer_rid,
                                      bool continuous,
                                      bool is_body_level) const {
    w.start_element("w:sectPr");

    // The body-level sectPr (last child of w:body) must NOT carry
    // w:type="nextPage" — that would make Word create an extra blank page
    // at the end of the document.  Omitting w:type entirely is correct;
    // it defaults to "nextPage" semantics for intermediate breaks.
    if (!is_body_level) {
        if (continuous) {
            w.element_with_attr("w:type", "w:val", "continuous");
        } else {
            w.element_with_attr("w:type", "w:val", "nextPage");
        }
    }

    // Header reference
    if (!header_rid.empty()) {
        w.start_element("w:headerReference");
        w.attribute("w:type", "default");
        w.attribute("r:id", header_rid);
        w.end_element();
    }

    // Footer reference
    if (!footer_rid.empty()) {
        w.start_element("w:footerReference");
        w.attribute("w:type", "default");
        w.attribute("r:id", footer_rid);
        w.end_element();
    }

    // Page size
    w.start_element("w:pgSz");
    w.attribute("w:w", std::to_string(page.page_width().to_twips()));
    w.attribute("w:h", std::to_string(page.page_height().to_twips()));
    if (page.orientation == Orientation::Landscape) {
        w.attribute("w:orient", "landscape");
    }
    w.end_element();

    // Page margins
    w.start_element("w:pgMar");
    w.attribute("w:top", std::to_string(page.margins.top.to_twips()));
    w.attribute("w:bottom", std::to_string(page.margins.bottom.to_twips()));
    w.attribute("w:left", std::to_string(page.margins.left.to_twips()));
    w.attribute("w:right", std::to_string(page.margins.right.to_twips()));
    w.attribute("w:header", std::to_string(page.margins.header_distance.to_twips()));
    w.attribute("w:footer", std::to_string(page.margins.footer_distance.to_twips()));
    w.end_element();

    w.end_element();  // w:sectPr
}

// ---------------------------------------------------------------------------
// emit_table_header: table header rows with tblHeader flag
// ---------------------------------------------------------------------------

void DocxEmitter::emit_table_header(XmlWriter& w,
                                     const HeaderGrid& header_grid,
                                     const HorizontalSegment& segment,
                                     const StyleResolver& resolver,
                                     double width_scale) const {
    // Base header style: template cascade without column/stub refs
    StyleDef base_hdr = resolver.resolve_base_header_style();

    // Build set of segment column indices for fast lookup
    std::unordered_set<size_t> seg_cols(segment.column_indices.begin(),
                                         segment.column_indices.end());

    size_t total_header_rows = header_grid.rows.size();

    for (size_t row_idx = 0; row_idx < total_header_rows; ++row_idx) {
        const auto& header_row = header_grid.rows[row_idx];
        bool is_first_header_row = (row_idx == 0);
        bool is_last_header_row = (row_idx == total_header_rows - 1);

        w.start_element("w:tr");

        // Row properties: header repetition + cantSplit + exact height
        w.start_element("w:trPr");
        w.self_closing_element("w:tblHeader");
        w.self_closing_element("w:cantSplit");
        // Set exact row height to match paginator's calculation
        if (row_idx < header_grid.row_heights.size() &&
            header_grid.row_heights[row_idx].emu > 0) {
            w.start_element("w:trHeight");
            w.attribute("w:val", std::to_string(
                header_grid.row_heights[row_idx].to_twips()));
            w.attribute("w:hRule", "exact");
            w.end_element();
        }
        w.end_element();

        // Emit only cells whose columns belong to this segment.
        // Track running column index to map cells → column ranges.
        size_t running_col = 0;
        for (const auto& cell : header_row) {
            size_t col_start = running_col;
            size_t col_end = running_col + static_cast<size_t>(cell.col_span);

            // Count how many of this cell's columns are in the segment
            int visible_span = 0;
            for (size_t ci = col_start; ci < col_end; ++ci) {
                if (seg_cols.count(ci)) {
                    visible_span++;
                }
            }

            // Skip cells entirely outside this segment
            if (visible_span > 0) {
                // Scale the visible portion of the cell width
                int64_t unscaled_emu = cell.width.emu;
                if (cell.col_span > 0 && visible_span < cell.col_span) {
                    // Partial span: proportional fraction of the original width
                    unscaled_emu = cell.width.emu * visible_span / cell.col_span;
                }
                int64_t scaled_emu = static_cast<int64_t>(
                    static_cast<double>(unscaled_emu) * width_scale);
                Length visible_width{scaled_emu};

                w.start_element("w:tc");

                // Resolve per-cell style: base cascade + cell.style_ref override
                StyleDef cell_style = base_hdr;
                if (cell.style_ref.has_value()) {
                    const StyleDef* ref_style = resolver.find_style(*cell.style_ref);
                    if (ref_style) {
                        cell_style = cell_style.merged_with(*ref_style);
                    }
                }

                // Cell properties from resolved table_style
                TableCellProps tcp = cell_style.table_style.value_or(TableCellProps{});

                // Override with structural borders (highest priority)
                // First header row: apply header_top_border
                if (is_first_header_row && tmpl_.table_style.structural.header_top_border.has_value()) {
                    if (!tcp.borders.has_value()) {
                        tcp.borders = Borders{};
                    }
                    tcp.borders->top = tmpl_.table_style.structural.header_top_border;
                }
                // Last header row: apply header_bottom_border
                if (is_last_header_row && tmpl_.table_style.structural.header_bottom_border.has_value()) {
                    if (!tcp.borders.has_value()) {
                        tcp.borders = Borders{};
                    }
                    tcp.borders->bottom = tmpl_.table_style.structural.header_bottom_border;
                }

                emit_cell_props(w, tcp, visible_width, visible_span, cell.v_merge);

                // Cell content (empty for vMerge continuation cells)
                emit_paragraph(w, cell.label, cell_style);

                w.end_element();  // w:tc
            }

            running_col = col_end;
        }

        w.end_element();  // w:tr
    }
}

// ---------------------------------------------------------------------------
// emit_table_row: a single body row
// ---------------------------------------------------------------------------

void DocxEmitter::emit_table_row(XmlWriter& w,
                                  const LogicalRow& row,
                                  const HorizontalSegment& segment,
                                  const TFLSpec& spec,
                                  const StyleResolver& resolver,
                                  bool is_last_row,
                                  double width_scale) const {
    w.start_element("w:tr");

    // Row properties
    w.start_element("w:trPr");
    w.self_closing_element("w:cantSplit");
    if (row.measured_height.emu > 0) {
        w.start_element("w:trHeight");
        w.attribute("w:val", std::to_string(row.measured_height.to_twips()));
        // Use "exact" to force Word to render rows at exactly our calculated
        // height, ensuring deterministic pagination (no overflow).
        w.attribute("w:hRule", "exact");
        w.end_element();
    }
    w.end_element();

    // Emit cells for this segment
    for (size_t col_idx : segment.column_indices) {
        if (col_idx >= row.cells.size()) continue;
        const auto& cell = row.cells[col_idx];

        // Skip merged (non-leader) cells
        if (cell.is_merged && !cell.is_merge_leader) continue;

        w.start_element("w:tc");

        // Resolve cell style
        StyleDef cell_style;
        if (col_idx < spec.columns.size()) {
            bool is_addrow = (row.type == LogicalRowType::SyntheticRow);
            cell_style = resolver.resolve_body_cell_style(
                spec.columns[col_idx],
                row.row_style_ref,
                std::nullopt,
                std::nullopt,
                is_addrow
            );
            if (cell.style_ref.has_value()) {
                const StyleDef* override_style = resolver.find_style(cell.style_ref.value());
                if (override_style) {
                    cell_style = cell_style.merged_with(*override_style);
                }
            }
        }

        // Cell properties — scale width for horizontal segment
        Length cell_width = cell.is_merge_leader
            ? cell.merged_width
            : (col_idx < spec.columns.size() ? spec.columns[col_idx].resolved_width : Length{0});
        if (width_scale != 1.0) {
            cell_width = Length{static_cast<int64_t>(
                static_cast<double>(cell_width.emu) * width_scale)};
        }

        TableCellProps tcp = cell_style.table_style.value_or(TableCellProps{});

        // Override bottom border on last row with structural table_bottom_border
        if (is_last_row && tmpl_.table_style.structural.table_bottom_border.has_value()) {
            if (!tcp.borders.has_value()) {
                tcp.borders = Borders{};
            }
            tcp.borders->bottom = tmpl_.table_style.structural.table_bottom_border;
        }

        emit_cell_props(w, tcp, cell_width, cell.merge_span);

        // Cell content
        emit_paragraph(w, cell.text, cell_style);

        w.end_element();  // w:tc
    }

    w.end_element();  // w:tr
}

// ---------------------------------------------------------------------------
// emit_table: a complete table element
// ---------------------------------------------------------------------------

void DocxEmitter::emit_table(XmlWriter& w,
                              const TFLSpec& spec,
                              const PageSlice& page,
                              const HorizontalSegment& segment,
                              const std::vector<LogicalRow>& rows,
                              const HeaderGrid& header_grid,
                              const StyleResolver& resolver) const {
    w.start_element("w:tbl");

    // Table properties
    w.start_element("w:tblPr");

    // Fixed layout (spec §19.3)
    w.start_element("w:tblLayout");
    w.attribute("w:type", "fixed");
    w.end_element();

    // ---- Horizontal-segment width scaling ----
    // When isColBreak splits columns into segments, each segment only
    // displays a subset of all columns.  We must scale widths so that
    // each segment fills the full table width.
    Length full_table_width{0};
    for (const auto& col : spec.columns) {
        full_table_width = full_table_width + col.resolved_width;
    }

    Length raw_segment_width{0};
    for (size_t col_idx : segment.column_indices) {
        if (col_idx < spec.columns.size()) {
            raw_segment_width = raw_segment_width + spec.columns[col_idx].resolved_width;
        }
    }

    // Scale factor: only apply when the segment is a true subset
    double width_scale = 1.0;
    if (raw_segment_width.emu > 0 &&
        segment.column_indices.size() < spec.columns.size()) {
        width_scale = static_cast<double>(full_table_width.emu)
                    / static_cast<double>(raw_segment_width.emu);
    }

    // Table width = scaled segment width (== full_table_width when scaling)
    Length table_width = (width_scale != 1.0) ? full_table_width
                                              : raw_segment_width;
    w.start_element("w:tblW");
    w.attribute("w:w", std::to_string(table_width.to_twips()));
    w.attribute("w:type", "dxa");
    w.end_element();

    // Table alignment on page (spec: tableStyle.layout.table_alignment)
    if (tmpl_.table_style.table_alignment.has_value()) {
        w.element_with_attr("w:jc", "w:val",
            alignment_to_ooxml(*tmpl_.table_style.table_alignment));
    }

    // Table borders from template
    if (tmpl_.table_style.table_borders.has_value()) {
        w.start_element("w:tblBorders");
        auto emit_border = [&](const char* name, const std::optional<Border>& b) {
            if (!b.has_value()) return;
            w.start_element(name);
            w.attribute("w:val", b->line_style.has_value()
                ? border_line_style_to_ooxml(b->line_style.value()) : "single");
            if (b->width.has_value()) {
                int eighth_pt = static_cast<int>(b->width->to_pt() * 8.0);
                w.attribute("w:sz", std::to_string(eighth_pt));
            }
            w.attribute("w:space", "0");
            if (b->color.has_value()) {
                w.attribute("w:color", b->color->hex);
            } else {
                w.attribute("w:color", "auto");
            }
            w.end_element();
        };
        const auto& borders = tmpl_.table_style.table_borders.value();
        emit_border("w:top", borders.top);
        emit_border("w:left", borders.left);
        emit_border("w:bottom", borders.bottom);
        emit_border("w:right", borders.right);
        emit_border("w:insideH", borders.top);  // Use top border for insideH
        emit_border("w:insideV", borders.left);  // Use left border for insideV
        w.end_element();
    }

    // Default cell margins from template
    bool has_default_margins =
        tmpl_.table_style.default_cell_margin_top.has_value() ||
        tmpl_.table_style.default_cell_margin_bottom.has_value() ||
        tmpl_.table_style.default_cell_margin_left.has_value() ||
        tmpl_.table_style.default_cell_margin_right.has_value();
    if (has_default_margins) {
        w.start_element("w:tblCellMar");
        auto emit_margin = [&](const char* name, const std::optional<Length>& m) {
            if (!m.has_value()) return;
            w.start_element(name);
            w.attribute("w:w", std::to_string(m->to_twips()));
            w.attribute("w:type", "dxa");
            w.end_element();
        };
        emit_margin("w:top", tmpl_.table_style.default_cell_margin_top);
        emit_margin("w:bottom", tmpl_.table_style.default_cell_margin_bottom);
        emit_margin("w:left", tmpl_.table_style.default_cell_margin_left);
        emit_margin("w:right", tmpl_.table_style.default_cell_margin_right);
        w.end_element();
    }

    w.end_element();  // w:tblPr

    // Grid definition (spec §19.3: gridCol widths in twips, scaled per segment)
    w.start_element("w:tblGrid");
    for (size_t col_idx : segment.column_indices) {
        if (col_idx < spec.columns.size()) {
            int64_t scaled_emu = static_cast<int64_t>(
                spec.columns[col_idx].resolved_width.emu * width_scale);
            w.start_element("w:gridCol");
            w.attribute("w:w", std::to_string(Length{scaled_emu}.to_twips()));
            w.end_element();
        }
    }
    w.end_element();

    // Header rows
    emit_table_header(w, header_grid, segment, resolver, width_scale);

    // Body rows for this page slice
    // Find effective last data row (skip trailing GroupBreak rows)
    size_t effective_last_row = page.last_row;
    while (effective_last_row > page.first_row &&
           effective_last_row < rows.size() &&
           rows[effective_last_row].type == LogicalRowType::GroupBreak) {
        --effective_last_row;
    }

    for (size_t ri = page.first_row; ri <= page.last_row && ri < rows.size(); ++ri) {
        if (rows[ri].type == LogicalRowType::GroupBreak) continue;
        bool is_last = (ri == effective_last_row);
        emit_table_row(w, rows[ri], segment, spec, resolver, is_last, width_scale);
    }

    w.end_element();  // w:tbl
}

// ---------------------------------------------------------------------------
// emit_page: a single page's content for a spec
// ---------------------------------------------------------------------------

void DocxEmitter::emit_page(XmlWriter& w,
                             const TFLSpec& spec,
                             const PageSlice& page,
                             const HorizontalSegment& segment,
                             const std::vector<LogicalRow>& rows,
                             const HeaderGrid& header_grid,
                             const StyleResolver& resolver) const {

    // NOTE: Document headers/footers are no longer emitted in the page body.
    // They are placed in separate word/headerN.xml and word/footerN.xml parts
    // and referenced via <w:sectPr> section properties.

    if (config_.verbose) {
        Rcpp::Rcerr << "[ksTFL] emit_page: page_num=" << page.page_number
                  << " first_row=" << page.first_row
                  << " last_row=" << page.last_row
                  << " has_titles=" << page.has_titles
                  << " has_subtitles=" << page.has_subtitles
                  << " is_first=" << page.is_first_page
                  << " is_last=" << page.is_last_page
                  << "\n";
        if (page.first_row < rows.size() && !rows[page.first_row].cells.empty()) {
            Rcpp::Rcerr << "[ksTFL]   first_row cells:";
            for (size_t ci = 0; ci < rows[page.first_row].cells.size() && ci < 4; ++ci) {
                Rcpp::Rcerr << " [" << ci << "]='" << rows[page.first_row].cells[ci].text.substr(0, 20) << "'";
            }
            Rcpp::Rcerr << "\n";
        }
    }

    // 1. Titles (on first page, or repeated per spec §13.6)
    //    Each add_title() call is a separate TextGroup → separate paragraph.
    //    Within a group, text lines are concatenated with soft breaks (<br>).
    //    Per-group font styles are preserved via styleRef.
    if (page.has_titles && !spec.titles.empty()) {
        StyleDef title_style = resolver.resolve_title_style();

        // Emit each title group as a separate paragraph.
        for (size_t gi = 0; gi < spec.titles.size(); ++gi) {
            const auto& group = spec.titles[gi];
            StyleDef style = title_style;
            for (const auto& ref : group.style_refs) {
                const StyleDef* ref_style = resolver.find_style(ref);
                if (ref_style) {
                    style = style.merged_with(*ref_style);
                }
            }

            // Stamp exact line height so Word uses same height as paginator
            stamp_exact_line_height(style);

            // Concatenate text lines with soft break (within one paragraph)
            std::string combined;
            for (size_t i = 0; i < group.text.size(); ++i) {
                if (i > 0) combined += "<br>";
                combined += group.text[i];
            }

            // When toclevel is set, emit TC only on first page; put TC in same paragraph as title so Word finds it
            if (page.is_first_page && group.toc_level > 0) {
                std::string toc_plain;
                for (size_t i = 0; i < group.text.size(); ++i) {
                    if (i > 0) toc_plain += ' ';
                    toc_plain += get_plain_text(group.text[i]);
                }
                w.start_element("w:p");
                if (style.paragraph.has_value()) {
                    emit_para_props(w, style.paragraph.value());
                }
                emit_tc_field(w, toc_plain, group.toc_level);
                ParsedCell parsed = parse_inline_markup(combined);
                if (!parsed.paragraphs.empty()) {
                    emit_parsed_paragraph_runs(w, parsed.paragraphs[0], style);
                }
                w.end_element();  // w:p
            } else {
                emit_paragraph(w, combined, style);
            }
        }
    }

    // 2. Subtitles
    if (page.has_subtitles && !spec.subtitles.empty()) {
        StyleDef sub_style = resolver.resolve_subtitle_style();

        // Deep-copy subtitles and substitute #ByGroupX placeholders.
        std::vector<TextGroup> resolved_subtitles = spec.subtitles;
        for (auto& group : resolved_subtitles) {
            for (auto& line : group.text) {
                for (size_t gi = 0; gi < page.dynamic_subtitle_values.size(); ++gi) {
                    std::string placeholder = "#ByGroup" + std::to_string(gi + 1);
                    size_t pos;
                    while ((pos = line.find(placeholder)) != std::string::npos) {
                        line.replace(pos, placeholder.size(),
                                     page.dynamic_subtitle_values[gi]);
                    }
                }
            }
        }

        // Emit each resolved subtitle group.
        // For groups with toc_level > 0:
        //   - Static subtitles (no #ByGroupX in original): TC only on first page.
        //   - Dynamic subtitles (contain #ByGroupX in original): TC on every page
        //     so each distinct group value gets its own TOC entry.
        for (size_t gi = 0; gi < resolved_subtitles.size(); ++gi) {
            const auto& group = resolved_subtitles[gi];
            StyleDef style = sub_style;
            for (const auto& ref : group.style_refs) {
                const StyleDef* ref_style = resolver.find_style(ref);
                if (ref_style) style = style.merged_with(*ref_style);
            }
            stamp_exact_line_height(style);

            std::string combined;
            for (size_t li = 0; li < group.text.size(); ++li) {
                if (li > 0) combined += "<br>";
                combined += group.text[li];
            }

            if (group.toc_level > 0) {
                // Determine whether the original (pre-substitution) subtitle is dynamic.
                bool is_dynamic = false;
                for (const auto& orig_line : spec.subtitles[gi].text) {
                    if (orig_line.find("#ByGroup") != std::string::npos) {
                        is_dynamic = true;
                        break;
                    }
                }

                bool emit_tc = is_dynamic || page.is_first_page;
                if (emit_tc) {
                    // Build plain-text TC entry from the resolved (substituted) lines.
                    std::string toc_plain;
                    for (size_t li = 0; li < group.text.size(); ++li) {
                        if (li > 0) toc_plain += ' ';
                        toc_plain += get_plain_text(group.text[li]);
                    }
                    w.start_element("w:p");
                    if (style.paragraph.has_value()) {
                        emit_para_props(w, style.paragraph.value());
                    }
                    emit_tc_field(w, toc_plain, group.toc_level);
                    ParsedCell parsed = parse_inline_markup(combined);
                    if (!parsed.paragraphs.empty()) {
                        emit_parsed_paragraph_runs(w, parsed.paragraphs[0], style);
                    }
                    w.end_element();  // w:p
                } else {
                    emit_paragraph(w, combined, style);
                }
            } else {
                emit_paragraph(w, combined, style);
            }
        }
    }

    // 3. Table (for Table docType)
    if (spec.document.doc_type == DocType::Table && spec.document.has_data) {
        emit_table(w, spec, page, segment, rows, header_grid, resolver);
    }

    // 4. Footnotes (if body placement and last page)
    if (spec.document.body_footnotes && page.is_last_page && !spec.footnotes.empty()) {
        StyleDef fn_style = resolver.resolve_footnote_style();
        emit_text_groups(w, spec.footnotes, fn_style, resolver);
    }
}

// ---------------------------------------------------------------------------
// Helper: emit an inline <w:drawing> for a Figure spec
// ---------------------------------------------------------------------------
static void emit_figure_drawing(XmlWriter& w, const std::string& r_id,
                                 int64_t cx_emu, int64_t cy_emu, int img_id) {
    w.start_element("w:p");
    w.start_element("w:r");
    w.start_element("w:drawing");

    w.start_element("wp:inline");
    w.namespace_decl("wp", WP_NS);
    w.attribute("distT", (int64_t)0);
    w.attribute("distB", (int64_t)0);
    w.attribute("distL", (int64_t)0);
    w.attribute("distR", (int64_t)0);

        w.start_element("wp:extent");
        w.attribute("cx", cx_emu);
        w.attribute("cy", cy_emu);
        w.end_element();

        w.start_element("wp:effectExtent");
        w.attribute("l", (int64_t)0);
        w.attribute("t", (int64_t)0);
        w.attribute("r", (int64_t)0);
        w.attribute("b", (int64_t)0);
        w.end_element();

        w.start_element("wp:docPr");
        w.attribute("id", (int64_t)img_id);
        w.attribute("name", "Image " + std::to_string(img_id));
        w.end_element();

        w.start_element("wp:cNvGraphicFramePr");
            w.start_element("a:graphicFrameLocks");
            w.namespace_decl("a", A_NS);
            w.attribute("noChangeAspect", "1");
            w.end_element();
        w.end_element();  // wp:cNvGraphicFramePr

        w.start_element("a:graphic");
        w.namespace_decl("a", A_NS);

            w.start_element("a:graphicData");
            w.attribute("uri", std::string(PIC_NS));

                w.start_element("pic:pic");
                w.namespace_decl("pic", PIC_NS);

                    w.start_element("pic:nvPicPr");
                        w.start_element("pic:cNvPr");
                        w.attribute("id", (int64_t)0);
                        w.attribute("name", "Figure");
                        w.end_element();
                        w.start_element("pic:cNvPicPr");
                        w.end_element();
                    w.end_element();  // pic:nvPicPr

                    w.start_element("pic:blipFill");
                        w.start_element("a:blip");
                        w.attribute("r:embed", r_id);
                        w.end_element();
                        w.start_element("a:stretch");
                            w.start_element("a:fillRect");
                            w.end_element();
                        w.end_element();
                    w.end_element();  // pic:blipFill

                    w.start_element("pic:spPr");
                        w.start_element("a:xfrm");
                            w.start_element("a:off");
                            w.attribute("x", (int64_t)0);
                            w.attribute("y", (int64_t)0);
                            w.end_element();
                            w.start_element("a:ext");
                            w.attribute("cx", cx_emu);
                            w.attribute("cy", cy_emu);
                            w.end_element();
                        w.end_element();  // a:xfrm
                        w.start_element("a:prstGeom");
                        w.attribute("prst", "rect");
                            w.start_element("a:avLst");
                            w.end_element();
                        w.end_element();  // a:prstGeom
                    w.end_element();  // pic:spPr

                w.end_element();  // pic:pic
            w.end_element();  // a:graphicData
        w.end_element();  // a:graphic

    w.end_element();  // wp:inline
    w.end_element();  // w:drawing
    w.end_element();  // w:r
    w.end_element();  // w:p
}

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

    measurer_ = measurer;  // store for use in emit_page / emit_text_groups
    toc_bookmark_counter_ = 0;  // reset per document so IDs are deterministic

    // ======================================================================
    // Phase 1: Pre-compute header/footer XML parts and relationship IDs
    // ======================================================================

    std::vector<HdrFtrPartInfo> all_hdr_ftr_parts;
    // Per-spec header/footer rIds for section properties
    struct SpecHdrFtrRefs {
        std::string header_rid;
        std::string footer_rid;
    };
    std::vector<SpecHdrFtrRefs> spec_hdr_ftr_refs(doc.specs.size());

    // Start relationship IDs after the base ones (rId1=styles, rId2=settings,
    // rId3=fontTable, rId4+ for images). Count images first.
    int next_rid = 4;
    for (const auto& spec : doc.specs) {
        if (spec.document.doc_type == DocType::Figure) next_rid++;
    }

    int hdr_ftr_idx = 1;
    for (size_t spec_idx = 0; spec_idx < doc.specs.size(); ++spec_idx) {
        const auto& spec = doc.specs[spec_idx];
        StyleResolver resolver(tmpl_, spec.spec_styles);
        PageConfig pc = resolver.resolve_page_config(spec);
        Length usable_w = pc.usable_width();

        if (!spec.headers.empty()) {
            std::string rid = "rId" + std::to_string(next_rid++);
            std::string part_path = "word/header" + std::to_string(hdr_ftr_idx) + ".xml";
            StyleDef hdr_style = resolver.resolve_doc_header_style();
            std::string xml = emit_hdr_ftr_xml_part(spec.headers, hdr_style,
                                                     usable_w, "w:hdr");
            all_hdr_ftr_parts.push_back({part_path, rid, xml, true});
            spec_hdr_ftr_refs[spec_idx].header_rid = rid;
            hdr_ftr_idx++;
        }

        if (!spec.footers.empty()) {
            std::string rid = "rId" + std::to_string(next_rid++);
            std::string part_path = "word/footer" + std::to_string(hdr_ftr_idx) + ".xml";
            StyleDef ftr_style = resolver.resolve_doc_footer_style();
            std::string xml = emit_hdr_ftr_xml_part(spec.footers, ftr_style,
                                                     usable_w, "w:ftr");
            all_hdr_ftr_parts.push_back({part_path, rid, xml, false});
            spec_hdr_ftr_refs[spec_idx].footer_rid = rid;
            hdr_ftr_idx++;
        }
    }

    // ======================================================================
    // Phase 2: Generate document.xml
    // ======================================================================

    XmlWriter doc_w;
    doc_w.write_declaration();
    doc_w.start_element("w:document");
    doc_w.namespace_decl("w", W_NS);
    doc_w.namespace_decl("r", R_NS);
    doc_w.namespace_decl("mc", MC_NS);

    doc_w.start_element("w:body");

    // Emit TOC page as the first section when requested.
    // Uses the first spec's page config and header/footer refs so the TOC page
    // inherits the same page size, margins, and running headers/footers.
    if (doc.metadata.insert_toc && !doc.specs.empty()) {
        StyleResolver first_resolver(tmpl_, doc.specs[0].spec_styles);
        PageConfig toc_page = first_resolver.resolve_page_config(doc.specs[0]);
        const auto& first_refs = spec_hdr_ftr_refs[0];
        emit_toc_page(doc_w, doc.metadata.toc_title, toc_page,
                      first_refs.header_rid, first_refs.footer_rid);
    }

    // Pre-compute rId assignments for Figure specs (rId4, rId5, ... in spec order)
    std::unordered_map<std::string, std::string> figure_rids;
    {
        int fig_rid_num = 4;
        for (const auto& spec : doc.specs) {
            if (spec.document.doc_type == DocType::Figure) {
                figure_rids[spec.key] = "rId" + std::to_string(fig_rid_num++);
            }
        }
    }
    int figure_img_counter = 0;  // unique drawing id for wp:docPr

    for (size_t spec_idx = 0; spec_idx < doc.specs.size(); ++spec_idx) {
        const auto& spec = doc.specs[spec_idx];

        // Create style resolver for this spec
        StyleResolver resolver(tmpl_, spec.spec_styles);

        //const auto& refs = spec_hdr_ftr_refs[spec_idx];

        // ----- Emit section break for previous spec (not before first) -----
        if (spec_idx > 0) {
            // Section break paragraph with previous spec's section properties
            const auto& prev_spec = doc.specs[spec_idx - 1];
            StyleResolver prev_resolver(tmpl_, prev_spec.spec_styles);
            PageConfig prev_page = prev_resolver.resolve_page_config(prev_spec);
            const auto& prev_refs = spec_hdr_ftr_refs[spec_idx - 1];

            doc_w.start_element("w:p");
            doc_w.start_element("w:pPr");
            emit_section_props(doc_w, prev_page,
                               prev_refs.header_rid, prev_refs.footer_rid);
            doc_w.end_element();  // w:pPr
            doc_w.end_element();  // w:p
        }

        // Get pagination result for this spec
        auto pages_it = resolved_pages.find(spec.key);
        auto rows_it = resolved_rows.find(spec.key);
        auto headers_it = resolved_headers.find(spec.key);

        if (spec.document.doc_type == DocType::Text || !spec.document.has_data) {
            // Titles
            if (!spec.titles.empty()) {
                emit_text_groups(doc_w, spec.titles,
                                  resolver.resolve_title_style(), resolver);
            }

            if (spec.document.doc_type == DocType::Figure &&
                !spec.figure_path.empty()) {
                // Figure: emit inline image drawing
                auto rid_it = figure_rids.find(spec.key);
                if (rid_it != figure_rids.end()) {
                    ++figure_img_counter;
                    int64_t cx = static_cast<int64_t>(
                        spec.document.figure_width_in  * 914400.0);
                    int64_t cy = static_cast<int64_t>(
                        spec.document.figure_height_in * 914400.0);
                    emit_figure_drawing(doc_w, rid_it->second,
                                        cx, cy, figure_img_counter);
                }
            } else {
                // Text (or Figure with no resolved path): emit bodyText
                StyleDef body_style = resolver.resolve_body_text_style();
                emit_text_groups(doc_w, spec.body_text, body_style, resolver);
            }

            // Footnotes
            if (!spec.footnotes.empty()) {
                emit_text_groups(doc_w, spec.footnotes,
                                  resolver.resolve_footnote_style(), resolver);
            }

            continue;
        }

        // Table/Figure spec: paginated rendering
        if (pages_it == resolved_pages.end() ||
            rows_it == resolved_rows.end() ||
            headers_it == resolved_headers.end()) {
            continue;  // Skip if no pagination data
        }

        const auto& pagination = pages_it->second;
        const auto& rows = rows_it->second;
        const auto& header_grid = headers_it->second;

        // Emit each segment (horizontal pagination)
        for (const auto& segment : pagination.segments) {
            for (size_t pi = 0; pi < segment.pages.size(); ++pi) {
                const auto& page = segment.pages[pi];

                // Page break between pages (not before first page of first segment)
                if (pi > 0 || segment.segment_index > 0) {
                    emit_page_break(doc_w);
                }

                emit_page(doc_w, spec, page, segment, rows, header_grid,
                          resolver);
            }
        }

        // Non-body footnotes (rendered after all pages)
        if (!spec.document.body_footnotes && !spec.footnotes.empty()) {
            StyleDef fn_style = resolver.resolve_footnote_style();
            emit_text_groups(doc_w, spec.footnotes, fn_style, resolver);
        }
    }

    // Final section properties (for the last section — direct child of w:body)
    if (!doc.specs.empty()) {
        size_t last_idx = doc.specs.size() - 1;
        const auto& last_spec = doc.specs[last_idx];
        StyleResolver last_resolver(tmpl_, last_spec.spec_styles);
        PageConfig last_page = last_resolver.resolve_page_config(last_spec);
        const auto& last_refs = spec_hdr_ftr_refs[last_idx];
        emit_section_props(doc_w, last_page,
                           last_refs.header_rid, last_refs.footer_rid,
                           /*continuous=*/false, /*is_body_level=*/true);
    }

    doc_w.end_element();  // w:body
    doc_w.end_element();  // w:document

    // ======================================================================
    // Phase 3: Assemble the DOCX ZIP package
    // ======================================================================

    // TOC 1–9 tab position: use first section's content width so TOC spans full width
    // for whatever page size and orientation the document uses.
    std::optional<int> toc_tab_twips;
    if (!doc.specs.empty()) {
        StyleResolver first_resolver(tmpl_, doc.specs[0].spec_styles);
        PageConfig first_page = first_resolver.resolve_page_config(doc.specs[0]);
        toc_tab_twips = static_cast<int>(first_page.usable_width().to_twips());
    }

    ZipWriter zip(output_path);

    zip.add_entry("[Content_Types].xml", emit_content_types(doc, all_hdr_ftr_parts));
    zip.add_entry("_rels/.rels", emit_rels());
    zip.add_entry("word/_rels/document.xml.rels",
                  emit_document_rels(doc, all_hdr_ftr_parts));
    zip.add_entry("word/document.xml", doc_w.str());
    zip.add_entry("word/styles.xml", emit_styles(toc_tab_twips));
    zip.add_entry("word/settings.xml", emit_settings());
    zip.add_entry("word/fontTable.xml", emit_font_table());

    // Add header/footer parts
    for (const auto& part : all_hdr_ftr_parts) {
        zip.add_entry(part.part_path, part.xml);
    }

    // Embed figures
    int img_idx = 4;
    for (const auto& spec : doc.specs) {
        if (spec.document.doc_type == DocType::Figure && !spec.figure_path.empty()) {
            std::string ext = "png";
            size_t dot = spec.figure_path.rfind('.');
            if (dot != std::string::npos) ext = spec.figure_path.substr(dot + 1);
            zip.add_file("word/media/image" + std::to_string(img_idx) + "." + ext,
                         spec.figure_path);
            img_idx++;
        }
    }

    zip.close();
    measurer_ = nullptr;  // clear after emit
}

}  // namespace kstfl
