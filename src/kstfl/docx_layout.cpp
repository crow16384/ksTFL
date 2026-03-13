// kstfl/docx_layout.cpp — header/footer and section layout helpers for DocxEmitter

#include "docx_emitter.h"
#include "inline_parser.h"
#include <cstring>

namespace kstfl {

static constexpr const char* W_NS_LAYOUT = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
static constexpr const char* R_NS_LAYOUT = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";

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
// Generate a standalone header/footer XML part
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_hdr_ftr_xml_part(
    const std::vector<HeaderFooterRow>& rows,
    const StyleDef& style,
    Length usable_w,
    const char* root_element,
    const std::vector<TextGroup>* footnotes,
    const StyleResolver* resolver) const
{
    XmlWriter w;
    w.write_declaration();
    w.start_element(root_element);
    w.namespace_decl("w", W_NS_LAYOUT);
    w.namespace_decl("r", R_NS_LAYOUT);

    // When doc_footer footnotes are present, emit them first so they appear
    // directly below the table content, then the footer rows underneath.
    if (footnotes && resolver && !footnotes->empty()) {
        StyleDef fn_style = resolver->resolve_footnote_style();
        emit_text_groups(w, *footnotes, fn_style, *resolver, {});
    }

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
    w.start_element("w:pPr");
    w.start_element("w:spacing");
    w.attribute("w:before", "0");
    w.attribute("w:after", "0");
    w.attribute("w:line", "20");
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

}  // namespace kstfl
