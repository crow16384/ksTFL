// kstfl/docx_document.cpp — document.xml emission for DocxEmitter

#include "docx_emitter.h"
#include "inline_parser.h"
#include <algorithm>
#include <cmath>

namespace kstfl {

static constexpr const char* W_NS_DOC = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
static constexpr const char* R_NS_DOC = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
static constexpr const char* MC_NS_DOC = "http://schemas.openxmlformats.org/markup-compatibility/2006";

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

static void fit_within_bounds(Length& w, Length& h,
                              Length max_w, Length max_h) {
    if (w.emu <= 0 || h.emu <= 0) return;

    long double scale = 1.0L;
    if (w > max_w && w.emu > 0) {
        scale = std::min(scale,
                         static_cast<long double>(max_w.emu) /
                         static_cast<long double>(w.emu));
    }
    if (h > max_h && h.emu > 0) {
        scale = std::min(scale,
                         static_cast<long double>(max_h.emu) /
                         static_cast<long double>(h.emu));
    }

    if (scale < 1.0L) {
        w = Length{std::max<int64_t>(1, static_cast<int64_t>(std::llround(
            static_cast<long double>(w.emu) * scale)))};
        h = Length{std::max<int64_t>(1, static_cast<int64_t>(std::llround(
            static_cast<long double>(h.emu) * scale)))};
    }
}

static std::pair<int64_t, int64_t> resolve_figure_size_emu(const TFLSpec& spec,
                                                            const PageConfig& page,
                                                            const StyleResolver& resolver,
                                                            Length max_figure_height) {
    Length usable_w = page.usable_width();
    Length content_w = resolver.resolve_table_width(spec, usable_w);
    Length usable_h = page.usable_height();

    if (max_figure_height.emu <= 0 || max_figure_height > usable_h) {
        max_figure_height = usable_h;
    }

    Length default_w = Length::from_in(6.0);
    Length default_h = Length::from_in(4.0);

    Length requested_w = parse_figure_length(spec.figure.width, content_w, default_w);
    Length requested_h = parse_figure_length(spec.figure.height, max_figure_height, default_h);

    if (requested_w.emu <= 0) requested_w = default_w;
    if (requested_h.emu <= 0) requested_h = default_h;

    const double fallback_ar =
        (default_h.emu > 0)
            ? static_cast<double>(default_w.emu) / static_cast<double>(default_h.emu)
            : 1.5;
    double requested_ar =
        (requested_h.emu > 0)
            ? static_cast<double>(requested_w.emu) / static_cast<double>(requested_h.emu)
            : fallback_ar;
    if (requested_ar <= 0.0) requested_ar = fallback_ar;

    Length w = requested_w;
    Length h = requested_h;

    if (spec.figure.scale_mode == "fitWidth") {
        w = content_w;
        h = Length{std::max<int64_t>(1, static_cast<int64_t>(std::llround(
            static_cast<double>(w.emu) / requested_ar)))};
    } else if (spec.figure.scale_mode == "fitPage") {
        Length fit_h_from_w{std::max<int64_t>(1, static_cast<int64_t>(std::llround(
            static_cast<double>(content_w.emu) / requested_ar)))};
        if (fit_h_from_w <= max_figure_height) {
            w = content_w;
            h = fit_h_from_w;
        } else {
            h = max_figure_height;
            w = Length{std::max<int64_t>(1, static_cast<int64_t>(std::llround(
                static_cast<double>(h.emu) * requested_ar)))};
        }
    } else {
        // fixed: if one dimension is missing, infer from default 6:4 ratio.
        bool has_w = spec.figure.width.has_value();
        bool has_h = spec.figure.height.has_value();
        if (has_w && !has_h) {
            h = Length{std::max<int64_t>(1, static_cast<int64_t>(std::llround(
                static_cast<double>(w.emu) / fallback_ar)))};
        } else if (!has_w && has_h) {
            w = Length{std::max<int64_t>(1, static_cast<int64_t>(std::llround(
                static_cast<double>(h.emu) * fallback_ar)))};
        }
    }

    // Preserve aspect ratio while fitting into the remaining body area.
    fit_within_bounds(w, h, content_w, max_figure_height);

    // Clamp one more time for safety.
    if (w > content_w) w = content_w;
    if (h > max_figure_height) h = max_figure_height;
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
        const auto& first_tmpl = template_for_spec(doc.specs[0].key);
        StyleResolver first_resolver(first_tmpl, doc.specs[0].spec_styles);
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
        const auto& spec_tmpl = template_for_spec(spec.key);
        StyleResolver resolver(spec_tmpl, spec.spec_styles);

        // ----- Emit section break for previous spec (not before first) -----
        if (spec_idx > 0) {
            // Section break paragraph with previous spec's section properties
            const auto& prev_spec = doc.specs[spec_idx - 1];
            const auto& prev_tmpl = template_for_spec(prev_spec.key);
            StyleResolver prev_resolver(prev_tmpl, prev_spec.spec_styles);
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
                    Length content_w = resolver.resolve_table_width(spec, page_cfg.usable_width());

                    auto measure_text_groups_height = [&](const std::vector<TextGroup>& groups,
                                                          const char* role) -> Length {
                        if (!measurer_ || groups.empty()) return Length{0};

                        Length total{0};
                        for (const auto& group : groups) {
                            StyleDef style;
                            if (std::string(role) == "title") {
                                style = resolver.resolve_title_style(group.style_refs);
                            } else if (std::string(role) == "caption") {
                                style = resolver.resolve_figure_caption_style(group.style_refs);
                            } else {
                                style = resolver.resolve_footnote_style(group.style_refs);
                            }

                            std::string combined;
                            for (size_t i = 0; i < group.text.size(); ++i) {
                                if (i > 0) combined += "<br>";
                                combined += group.text[i];
                            }
                            if (combined.empty()) continue;

                            MeasuredText measured = measurer_->measure_plain(combined, style, content_w);
                            total = total + measured.height;
                        }

                        return total;
                    };

                    Length reserved_height{0};
                    reserved_height = reserved_height + measure_text_groups_height(spec.titles, "title");
                    reserved_height = reserved_height + measure_text_groups_height(spec.footnotes, "footnote");
                    if (!spec.subtitles.empty()) {
                        reserved_height = reserved_height + measure_text_groups_height(spec.subtitles, "caption");
                    }

                    if (spec_tmpl.figure_style.space_before.has_value()) {
                        reserved_height = reserved_height + *spec_tmpl.figure_style.space_before;
                    }
                    if (spec_tmpl.figure_style.space_after.has_value()) {
                        reserved_height = reserved_height + *spec_tmpl.figure_style.space_after;
                    }

                    Length max_figure_height = page_cfg.usable_height() - reserved_height;
                    if (max_figure_height.emu <= 0) {
                        max_figure_height = Length::from_pt(1.0);
                    }

                    auto size_emu = resolve_figure_size_emu(
                        spec, page_cfg, resolver, max_figure_height);
                    int64_t cx = size_emu.first;
                    int64_t cy = size_emu.second;

                    std::optional<ParagraphProps> figure_pp = std::nullopt;
                    if (spec_tmpl.figure_style.alignment.has_value() ||
                        spec_tmpl.figure_style.space_before.has_value() ||
                        spec_tmpl.figure_style.space_after.has_value()) {
                        ParagraphProps pp;
                        if (spec_tmpl.figure_style.alignment.has_value()) {
                            pp.alignment = spec_tmpl.figure_style.alignment;
                        }
                        if (spec_tmpl.figure_style.space_before.has_value() ||
                            spec_tmpl.figure_style.space_after.has_value()) {
                            SpacingProps sp;
                            sp.before = spec_tmpl.figure_style.space_before;
                            sp.after = spec_tmpl.figure_style.space_after;
                            pp.spacing = sp;
                        }
                        figure_pp = pp;
                    }

                    auto emit_caption = [&]() {
                        if (!spec.subtitles.empty()) {
                            emit_text_groups(doc_w, spec.subtitles,
                                             resolver.resolve_figure_caption_style(),
                                             resolver);
                        }
                    };

                    if (spec_tmpl.figure_style.caption_position == "above") {
                        emit_caption();
                    }

                    emit_figure_drawing(doc_w, rid_it->second,
                                        cx, cy, figure_img_counter, figure_pp);

                    if (spec_tmpl.figure_style.caption_position != "above") {
                        emit_caption();
                    }
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
        const auto& last_tmpl = template_for_spec(last_spec.key);
        StyleResolver last_resolver(last_tmpl, last_spec.spec_styles);
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
