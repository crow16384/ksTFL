// kstfl/docx_emitter.cpp — OOXML emission for DOCX documents
//
// Implements spec §19: streaming OOXML emission, fixed-layout tables,
// header repetition, page/section breaks, field codes.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "docx_emitter.h"
#include "inline_parser.h"
#include <Rcpp.h>
#include <cmath>
#include <unordered_set>

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
        // For vertical text, prevent Word from wrapping; we measure and size
        // the row for a single unwrapped line.
        if (tcp.text_orientation.value() != TextOrientation::Horizontal) {
            w.self_closing_element("w:noWrap");
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

    // Cell margins — only left/right are emitted.  Top/bottom are zeroed
    // because Word adds tcMar top/bottom OUTSIDE trHeight even with
    // hRule="exact".  Vertical padding is already included in the row height
    // computed by the paginator.
    bool has_margins = tcp.cell_margin_left.has_value() || tcp.cell_margin_right.has_value();
    if (has_margins) {
        w.start_element("w:tcMar");
        auto emit_margin = [&](const char* name, const std::optional<Length>& m) {
            if (!m.has_value()) return;
            w.start_element(name);
            w.attribute("w:w", std::to_string(m->to_twips()));
            w.attribute("w:type", "dxa");
            w.end_element();
        };
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
                style.merge_from(*ref_style);
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
            ParsedCell parsed = parse_inline_markup(combined);
            // First paragraph carries the TC field
            w.start_element("w:p");
            if (style.paragraph.has_value()) {
                emit_para_props(w, style.paragraph.value());
            }
            emit_tc_field(w, toc_plain, group.toc_level);
            if (!parsed.paragraphs.empty()) {
                emit_parsed_paragraph_runs(w, parsed.paragraphs[0], style);
            }
            w.end_element();  // w:p
            // Remaining paragraphs (from <br> splits) emitted without TC field
            for (size_t pi = 1; pi < parsed.paragraphs.size(); ++pi) {
                emit_parsed_paragraph(w, parsed.paragraphs[pi], style);
            }
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
                style.merge_from(*ref_style);
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
// TOC/field emission helpers are implemented in docx_toc.cpp.
// Header/footer and section layout helpers are implemented in docx_layout.cpp.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Table emission helpers are implemented in docx_table.cpp.
// ---------------------------------------------------------------------------

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
                             const std::vector<ParsedCell>& parsed_titles) const {

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
                    style.merge_from(*ref_style);
                }
            }

            // Stamp exact line height so Word uses same height as paginator
            stamp_exact_line_height(style);

            // Use precomputed parsed titles to avoid re-parsing on every page.
            const ParsedCell& parsed = parsed_titles[gi];

            // When toclevel is set, emit TC field in same paragraph as title.
            // Only emit TC for the first horizontal segment to avoid duplicate
            // TOC entries when isColBreak splits the table into multiple segments.
            if (page.is_first_page && segment.segment_index == 0 && group.toc_level > 0) {
                std::string toc_plain;
                for (size_t i = 0; i < group.text.size(); ++i) {
                    if (i > 0) toc_plain += ' ';
                    toc_plain += get_plain_text(group.text[i]);
                }
                // First paragraph carries the TC field
                w.start_element("w:p");
                if (style.paragraph.has_value()) {
                    emit_para_props(w, style.paragraph.value());
                }
                emit_tc_field(w, toc_plain, group.toc_level);
                if (!parsed.paragraphs.empty()) {
                    emit_parsed_paragraph_runs(w, parsed.paragraphs[0], style);
                }
                w.end_element();  // w:p
                // Remaining paragraphs (from <br> splits) emitted without TC field
                for (size_t pi = 1; pi < parsed.paragraphs.size(); ++pi) {
                    emit_parsed_paragraph(w, parsed.paragraphs[pi], style);
                }
            } else {
                // Emit parsed paragraphs directly (no TC field)
                if (parsed.paragraphs.empty()) {
                    w.start_element("w:p");
                    if (style.paragraph.has_value()) {
                        emit_para_props(w, style.paragraph.value());
                    }
                    w.end_element();
                } else {
                    for (const auto& para : parsed.paragraphs) {
                        emit_parsed_paragraph(w, para, style);
                    }
                }
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
        // In both cases, TC is restricted to segment 0 to avoid duplicate TOC
        // entries when isColBreak splits the table into multiple segments.
        for (size_t gi = 0; gi < resolved_subtitles.size(); ++gi) {
            const auto& group = resolved_subtitles[gi];
            StyleDef style = sub_style;
            for (const auto& ref : group.style_refs) {
                const StyleDef* ref_style = resolver.find_style(ref);
                if (ref_style) style.merge_from(*ref_style);
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

                bool emit_tc = (is_dynamic || page.is_first_page)
                               && segment.segment_index == 0;
                if (emit_tc) {
                    // Build plain-text TC entry from the resolved (substituted) lines.
                    std::string toc_plain;
                    for (size_t li = 0; li < group.text.size(); ++li) {
                        if (li > 0) toc_plain += ' ';
                        toc_plain += get_plain_text(group.text[li]);
                    }
                    ParsedCell parsed = parse_inline_markup(combined);
                    // First paragraph carries the TC field
                    w.start_element("w:p");
                    if (style.paragraph.has_value()) {
                        emit_para_props(w, style.paragraph.value());
                    }
                    emit_tc_field(w, toc_plain, group.toc_level);
                    if (!parsed.paragraphs.empty()) {
                        emit_parsed_paragraph_runs(w, parsed.paragraphs[0], style);
                    }
                    w.end_element();  // w:p
                    // Remaining paragraphs (from <br> splits) emitted without TC field
                    for (size_t pi = 1; pi < parsed.paragraphs.size(); ++pi) {
                        emit_parsed_paragraph(w, parsed.paragraphs[pi], style);
                    }
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

    // 4. Footnotes (if this page should show them per footnote_place strategy)
    if (page.has_footnotes && !spec.footnotes.empty()) {
        StyleDef fn_style = resolver.resolve_footnote_style();
        emit_text_groups(w, spec.footnotes, fn_style, resolver);
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
    const std::unordered_map<std::string, HeaderGrid>& resolved_headers,
    TextMeasurer* measurer) {

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
