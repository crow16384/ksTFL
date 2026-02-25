// kstfl/docx_emitter.cpp — OOXML emission for DOCX documents
//
// Implements spec §19: streaming OOXML emission, fixed-layout tables,
// header repetition, page/section breaks, field codes.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include "docx_emitter.h"
#include "inline_parser.h"
#include <algorithm>
#include <sstream>
#include <cmath>
#include <iomanip>

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

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

DocxEmitter::DocxEmitter(const StylesTemplate& tmpl, const RendererConfig& config)
    : tmpl_(tmpl), config_(config) {}

// ---------------------------------------------------------------------------
// [Content_Types].xml
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_content_types(const TFLDocument& doc) const {
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

std::string DocxEmitter::emit_document_rels(const TFLDocument& doc) const {
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

    w.end_element();
    return w.str();
}

// ---------------------------------------------------------------------------
// word/styles.xml
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_styles() const {
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
        // Superscript/subscript at 65% size
        if (run_style.superscript || run_style.subscript) {
            size *= 0.65;
        }
        int half_pt = static_cast<int>(size * 2.0);
        w.element_with_attr("w:sz", "w:val", std::to_string(half_pt));
        w.element_with_attr("w:szCs", "w:val", std::to_string(half_pt));
    }

    if (font.color.has_value() && !font.color->empty()) {
        w.element_with_attr("w:color", "w:val", font.color->hex);
    }

    if (font.highlight.has_value() && !font.highlight->empty()) {
        w.element_with_attr("w:highlight", "w:val", font.highlight->hex);
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
        if (pp.spacing->line_spacing_multiplier.has_value()) {
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
                                   int grid_span) const {
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

    FontProps base_font = base_style.font.value_or(FontProps{});

    for (const auto& run : para.runs) {
        w.start_element("w:r");
        emit_run_props(w, base_font, run.style);

        // Check for line breaks in text
        // The inline parser should have handled <br> tags, but we still
        // need to emit w:br for them.
        if (run.text == "\n") {
            w.self_closing_element("w:br");
        } else {
            w.element_with_text("w:t", run.text);
        }

        w.end_element();  // w:r
    }

    w.end_element();  // w:p
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
        if (group.style_ref.has_value()) {
            const StyleDef* ref_style = resolver.find_style(group.style_ref.value());
            if (ref_style) {
                style = style.merged_with(*ref_style);
            }
        }

        // Concatenate text lines with soft break (within one paragraph)
        std::string combined;
        for (size_t i = 0; i < group.text.size(); ++i) {
            if (i > 0) combined += "<br>";
            combined += group.text[i];
        }
        emit_paragraph(w, combined, style);
    }
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

    for (const auto& row : rows) {
        w.start_element("w:p");

        // Paragraph properties with tab stops for center and right alignment
        w.start_element("w:pPr");
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
        if (!row.left.empty()) {
            w.start_element("w:r");
            emit_run_props(w, font);
            w.element_with_text("w:t", row.left);
            w.end_element();
        }

        // Tab to center
        w.start_element("w:r");
        w.self_closing_element("w:tab");
        w.end_element();

        // Center content
        if (!row.center.empty()) {
            w.start_element("w:r");
            emit_run_props(w, font);
            w.element_with_text("w:t", row.center);
            w.end_element();
        }

        // Tab to right
        w.start_element("w:r");
        w.self_closing_element("w:tab");
        w.end_element();

        // Right content (may contain page number placeholders)
        if (!row.right.empty()) {
            // Replace #page and #pages with field codes or literal values
            std::string right_text = row.right;
            size_t page_pos = right_text.find("#page");
            size_t pages_pos = right_text.find("#pages");

            if (use_fields && (page_pos != std::string::npos || pages_pos != std::string::npos)) {
                // Emit pieces with field codes interleaved
                // Simple approach: emit any text before #page, then PAGE field, then between, etc.
                size_t pos = 0;
                while (pos < right_text.size()) {
                    size_t next_page = right_text.find("#page", pos);
                    size_t next_pages = right_text.find("#pages", pos);

                    size_t next = std::min(
                        next_page != std::string::npos ? next_page : right_text.size(),
                        next_pages != std::string::npos ? next_pages : right_text.size()
                    );

                    // Emit literal text before the field
                    if (next > pos) {
                        w.start_element("w:r");
                        emit_run_props(w, font);
                        w.element_with_text("w:t", right_text.substr(pos, next - pos));
                        w.end_element();
                    }

                    if (next >= right_text.size()) break;

                    // Determine which placeholder we hit
                    if (next == next_pages && next_pages != std::string::npos) {
                        emit_numpages_field(w);
                        pos = next + 6;  // skip "#pages"
                    } else if (next == next_page && next_page != std::string::npos) {
                        emit_page_field(w);
                        pos = next + 5;  // skip "#page"
                    } else {
                        break;
                    }
                }
            } else {
                w.start_element("w:r");
                emit_run_props(w, font);
                w.element_with_text("w:t", right_text);
                w.end_element();
            }
        }

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
// Page break paragraph
// ---------------------------------------------------------------------------

void DocxEmitter::emit_page_break(XmlWriter& w) const {
    w.start_element("w:p");
    w.start_element("w:r");
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
                                      bool continuous) const {
    w.start_element("w:sectPr");

    if (continuous) {
        w.element_with_attr("w:type", "w:val", "continuous");
    } else {
        w.element_with_attr("w:type", "w:val", "nextPage");
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
                                     const StyleResolver& resolver) const {
    for (const auto& header_row : header_grid.rows) {
        w.start_element("w:tr");

        // Row properties: header repetition + cantSplit
        w.start_element("w:trPr");
        w.self_closing_element("w:tblHeader");
        w.self_closing_element("w:cantSplit");
        w.end_element();

        // Emit cells for this segment's columns
        for (const auto& cell : header_row) {
            w.start_element("w:tc");

            // Cell properties
            TableCellProps tcp;
            // Get style for header cell
            // (simplified - use basic header style)
            StyleDef hdr_style = resolver.resolve_doc_header_style();

            emit_cell_props(w, tcp, cell.width, cell.col_span);

            // Cell content
            emit_paragraph(w, cell.label, hdr_style);

            w.end_element();  // w:tc
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
                                  const StyleResolver& resolver) const {
    w.start_element("w:tr");

    // Row properties
    w.start_element("w:trPr");
    w.self_closing_element("w:cantSplit");
    if (row.measured_height.emu > 0) {
        w.start_element("w:trHeight");
        w.attribute("w:val", std::to_string(row.measured_height.to_twips()));
        w.attribute("w:hRule", "atLeast");
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
            cell_style = resolver.resolve_body_cell_style(
                spec.columns[col_idx],
                row.row_style_ref,
                std::nullopt,
                std::nullopt
            );
            if (cell.style_ref.has_value()) {
                const StyleDef* override_style = resolver.find_style(cell.style_ref.value());
                if (override_style) {
                    cell_style = cell_style.merged_with(*override_style);
                }
            }
        }

        // Cell properties
        Length cell_width = cell.is_merge_leader
            ? cell.merged_width
            : (col_idx < spec.columns.size() ? spec.columns[col_idx].resolved_width : Length{0});

        TableCellProps tcp = cell_style.table_style.value_or(TableCellProps{});
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

    // Table width
    Length total_width{0};
    for (size_t col_idx : segment.column_indices) {
        if (col_idx < spec.columns.size()) {
            total_width = total_width + spec.columns[col_idx].resolved_width;
        }
    }
    w.start_element("w:tblW");
    w.attribute("w:w", std::to_string(total_width.to_twips()));
    w.attribute("w:type", "dxa");
    w.end_element();

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

    // Grid definition (spec §19.3: gridCol widths in twips)
    w.start_element("w:tblGrid");
    for (size_t col_idx : segment.column_indices) {
        if (col_idx < spec.columns.size()) {
            w.start_element("w:gridCol");
            w.attribute("w:w", std::to_string(spec.columns[col_idx].resolved_width.to_twips()));
            w.end_element();
        }
    }
    w.end_element();

    // Header rows
    emit_table_header(w, header_grid, segment, resolver);

    // Body rows for this page slice
    for (size_t ri = page.first_row; ri <= page.last_row && ri < rows.size(); ++ri) {
        if (rows[ri].type == LogicalRowType::GroupBreak) continue;
        emit_table_row(w, rows[ri], segment, spec, resolver);
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
                             const StyleResolver& resolver,
                             size_t total_pages) const {

    PageConfig page_config = resolver.resolve_page_config(spec);
    Length usable_w = page_config.usable_width();

    // 1. Header section
    if (!spec.headers.empty()) {
        StyleDef hdr_style = resolver.resolve_doc_header_style();
        emit_header_footer_section(w, spec.headers, hdr_style, usable_w,
                                    page.page_number, total_pages,
                                    config_.use_field_codes);
    }

    // 2. Titles (on first page, or repeated per spec §13.6)
    if (page.has_titles && !spec.titles.empty()) {
        StyleDef title_style = resolver.resolve_title_style();

        // Handle glue prefix: prepend to first title
        if (!spec.document.doc_prefix.empty() && !spec.document.glue_num_type.empty()) {
            std::string prefix = spec.document.doc_prefix + " " +
                                 spec.document.glue_num_type;
            if (!spec.document.glue_prefix.empty()) {
                prefix += spec.document.glue_prefix;
            }

            // Emit prefix + first title as one paragraph
            if (!spec.titles.empty() && !spec.titles[0].text.empty()) {
                std::string combined = prefix + spec.titles[0].text[0];
                emit_paragraph(w, combined, title_style);

                // Remaining lines of first group
                for (size_t i = 1; i < spec.titles[0].text.size(); ++i) {
                    emit_paragraph(w, spec.titles[0].text[i], title_style);
                }

                // Remaining title groups
                std::vector<TextGroup> remaining(spec.titles.begin() + 1, spec.titles.end());
                emit_text_groups(w, remaining, title_style, resolver);
            } else {
                emit_paragraph(w, prefix, title_style);
            }
        } else {
            emit_text_groups(w, spec.titles, title_style, resolver);
        }
    }

    // 3. Subtitles
    if (page.has_subtitles && !spec.subtitles.empty()) {
        StyleDef sub_style = resolver.resolve_subtitle_style();

        // Handle dynamic subtitles (#ByGroupX)
        std::vector<TextGroup> resolved_subtitles = spec.subtitles;
        for (auto& group : resolved_subtitles) {
            for (auto& line : group.text) {
                // Replace #ByGroup1, #ByGroup2, etc. with actual values
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
        emit_text_groups(w, resolved_subtitles, sub_style, resolver);
    }

    // 4. Table (for Table docType) or Figure or bodyText
    if (spec.document.doc_type == DocType::Table && spec.document.has_data) {
        emit_table(w, spec, page, segment, rows, header_grid, resolver);
    } else if (spec.document.doc_type == DocType::Text || !spec.document.has_data) {
        // Render bodyText
        StyleDef body_style = resolver.resolve_body_text_style();
        emit_text_groups(w, spec.body_text, body_style, resolver);
    }
    // Figure handling would go here (embed image via drawing ML)

    // 5. Footnotes (if body placement and last page)
    if (spec.document.body_footnotes && page.is_last_page && !spec.footnotes.empty()) {
        StyleDef fn_style = resolver.resolve_footnote_style();
        emit_text_groups(w, spec.footnotes, fn_style, resolver);
    }

    // 6. Footer section
    if (!spec.footers.empty()) {
        StyleDef ftr_style = resolver.resolve_doc_footer_style();
        emit_header_footer_section(w, spec.footers, ftr_style, usable_w,
                                    page.page_number, total_pages,
                                    config_.use_field_codes);
    }
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
    const std::unordered_map<std::string, HeaderGrid>& resolved_headers) {

    // Generate document.xml
    XmlWriter doc_w;
    doc_w.write_declaration();
    doc_w.start_element("w:document");
    doc_w.namespace_decl("w", W_NS);
    doc_w.namespace_decl("r", R_NS);
    doc_w.namespace_decl("mc", MC_NS);

    doc_w.start_element("w:body");

    bool first_spec = true;
    for (size_t spec_idx = 0; spec_idx < doc.specs.size(); ++spec_idx) {
        const auto& spec = doc.specs[spec_idx];

        // Section break between specs (spec §19: single doc with section breaks)
        if (!first_spec) {
            // Emit page break as section break
            emit_page_break(doc_w);
        }
        first_spec = false;

        // Create style resolver for this spec
        StyleResolver resolver(tmpl_, spec.spec_styles);

        // Get pagination result for this spec
        auto pages_it = resolved_pages.find(spec.key);
        auto rows_it = resolved_rows.find(spec.key);
        auto headers_it = resolved_headers.find(spec.key);

        if (spec.document.doc_type == DocType::Text || !spec.document.has_data) {
            // No table: just emit bodyText
            StyleDef body_style = resolver.resolve_body_text_style();

            // Headers
            if (!spec.headers.empty()) {
                StyleDef hdr_style = resolver.resolve_doc_header_style();
                PageConfig pc = resolver.resolve_page_config(spec);
                emit_header_footer_section(doc_w, spec.headers, hdr_style,
                                            pc.usable_width(), 1, 1,
                                            config_.use_field_codes);
            }

            // Titles
            if (!spec.titles.empty()) {
                emit_text_groups(doc_w, spec.titles,
                                  resolver.resolve_title_style(), resolver);
            }

            // Body text
            emit_text_groups(doc_w, spec.body_text, body_style, resolver);

            // Footnotes
            if (!spec.footnotes.empty()) {
                emit_text_groups(doc_w, spec.footnotes,
                                  resolver.resolve_footnote_style(), resolver);
            }

            // Footers
            if (!spec.footers.empty()) {
                StyleDef ftr_style = resolver.resolve_doc_footer_style();
                PageConfig pc = resolver.resolve_page_config(spec);
                emit_header_footer_section(doc_w, spec.footers, ftr_style,
                                            pc.usable_width(), 1, 1,
                                            config_.use_field_codes);
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
                          resolver, pagination.total_pages);
            }
        }

        // Non-body footnotes (rendered after all pages)
        if (!spec.document.body_footnotes && !spec.footnotes.empty()) {
            StyleDef fn_style = resolver.resolve_footnote_style();
            emit_text_groups(doc_w, spec.footnotes, fn_style, resolver);
        }
    }

    // Final section properties (for the last section)
    if (!doc.specs.empty()) {
        const auto& last_spec = doc.specs.back();
        StyleResolver last_resolver(tmpl_, last_spec.spec_styles);
        PageConfig last_page = last_resolver.resolve_page_config(last_spec);
        emit_section_props(doc_w, last_page);
    }

    doc_w.end_element();  // w:body
    doc_w.end_element();  // w:document

    // Assemble the DOCX ZIP package
    ZipWriter zip(output_path);

    zip.add_entry("[Content_Types].xml", emit_content_types(doc));
    zip.add_entry("_rels/.rels", emit_rels());
    zip.add_entry("word/_rels/document.xml.rels", emit_document_rels(doc));
    zip.add_entry("word/document.xml", doc_w.str());
    zip.add_entry("word/styles.xml", emit_styles());
    zip.add_entry("word/settings.xml", emit_settings());
    zip.add_entry("word/fontTable.xml", emit_font_table());

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
}

}  // namespace kstfl
