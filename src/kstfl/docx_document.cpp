// kstfl/docx_document.cpp — document.xml emission for DocxEmitter

#include "docx_emitter.h"
#include "inline_parser.h"
#include <algorithm>

namespace kstfl {

static constexpr const char* W_NS_DOC = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
static constexpr const char* R_NS_DOC = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
static constexpr const char* MC_NS_DOC = "http://schemas.openxmlformats.org/markup-compatibility/2006";

static double safe_aspect_ratio(const TFLSpec& spec) {
    if (spec.figure.aspect_ratio.has_value() && *spec.figure.aspect_ratio > 0.0) {
        return *spec.figure.aspect_ratio;
    }
    return 1.5; // Default 6:4
}

static Length parse_figure_length(const std::optional<std::string>& raw,
                                  Length reference,
                                  Length fallback) {
    if (!raw.has_value() || raw->empty()) return fallback;
    try {
        return Length::parse(*raw, reference.emu);
    } catch (...) {
        return fallback;
    }
}

static std::pair<int64_t, int64_t> resolve_figure_size_emu(const TFLSpec& spec,
                                                            const PageConfig& page,
                                                            const StyleResolver& resolver) {
    Length usable_w = page.usable_width();
    Length usable_h = page.usable_height();
    Length content_w = resolver.resolve_table_width(spec, usable_w);
    double ar = safe_aspect_ratio(spec); // width / height

    Length default_w = Length::from_in(6.0);
    Length default_h = Length::from_in(4.0);

    Length w = parse_figure_length(spec.figure.width, content_w, default_w);
    Length h = parse_figure_length(spec.figure.height, usable_h, default_h);

    if (spec.figure.scale_mode == "fitWidth") {
        w = content_w;
        h = Length{static_cast<int64_t>(w.emu / ar)};
    } else if (spec.figure.scale_mode == "fitPage") {
        Length max_w = content_w;
        Length max_h = usable_h;
        Length fit_h_from_w{static_cast<int64_t>(max_w.emu / ar)};
        if (fit_h_from_w <= max_h) {
            w = max_w;
            h = fit_h_from_w;
        } else {
            h = max_h;
            w = Length{static_cast<int64_t>(h.emu * ar)};
        }
    } else {
        // fixed: if only one dimension provided, infer the other from aspect ratio
        bool has_w = spec.figure.width.has_value();
        bool has_h = spec.figure.height.has_value();
        if (has_w && !has_h) {
            h = Length{static_cast<int64_t>(w.emu / ar)};
        } else if (!has_w && has_h) {
            w = Length{static_cast<int64_t>(h.emu * ar)};
        }
    }

    // Clamp to page bounds for safety.
    if (w > content_w) w = content_w;
    if (h > usable_h) h = usable_h;
    if (w.emu <= 0) w = default_w;
    if (h.emu <= 0) h = default_h;

    return {w.emu, h.emu};
}

std::string DocxEmitter::emit_document_xml(
        const TFLDocument& doc,
        const std::unordered_map<std::string, PaginationResult>& resolved_pages,
        const std::unordered_map<std::string, std::vector<LogicalRow>>& resolved_rows,
        const std::unordered_map<std::string, HeaderGrid>& resolved_headers,
        const std::vector<SpecHdrFtrRefs>& spec_hdr_ftr_refs) const {
    XmlWriter doc_w;
    doc_w.write_declaration();
    doc_w.start_element("w:document");
    doc_w.namespace_decl("w", W_NS_DOC);
    doc_w.namespace_decl("r", R_NS_DOC);
    doc_w.namespace_decl("mc", MC_NS_DOC);

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
                    PageConfig page_cfg = resolver.resolve_page_config(spec);
                    auto size_emu = resolve_figure_size_emu(spec, page_cfg, resolver);
                    int64_t cx = size_emu.first;
                    int64_t cy = size_emu.second;
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

        // Emit pages interleaved across horizontal segments so that all
        // segments for the same row range are adjacent in the document.
        // Order: seg1-pg1, seg2-pg1, seg1-pg2, seg2-pg2, ...
        size_t max_pages = 0;
        for (const auto& seg : pagination.segments) {
            max_pages = std::max(max_pages, seg.pages.size());
        }
        // Pre-parse title inline markup once — titles are the same on every
        // page, so we avoid re-parsing on each emit_page() call.
        std::vector<ParsedCell> parsed_titles;
        parsed_titles.reserve(spec.titles.size());
        for (const auto& group : spec.titles) {
            std::string combined;
            for (size_t i = 0; i < group.text.size(); ++i) {
                if (i > 0) combined += "<br>";
                combined += group.text[i];
            }
            parsed_titles.push_back(parse_inline_markup(combined));
        }

        bool first_physical_page = true;
        for (size_t pi = 0; pi < max_pages; ++pi) {
            for (const auto& segment : pagination.segments) {
                if (pi >= segment.pages.size()) continue;
                const auto& page = segment.pages[pi];

                if (!first_physical_page) {
                    emit_page_break(doc_w);
                }
                first_physical_page = false;

                emit_page(doc_w, spec, page, segment, rows, header_grid,
                          resolver, parsed_titles);
            }
        }

        // doc_footer footnotes are now emitted inside the Word footer XML part
        // (w:ftr) rather than in the body, so they appear below the footer rows.
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

    return doc_w.str();
}

}  // namespace kstfl
