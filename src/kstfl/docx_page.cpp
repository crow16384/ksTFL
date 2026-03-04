// kstfl/docx_page.cpp — per-page content emission for DocxEmitter

#include "docx_emitter.h"
#include "inline_parser.h"
#include <Rcpp.h>

namespace kstfl {

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

}  // namespace kstfl
