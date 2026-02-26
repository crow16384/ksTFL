// kstfl/renderer.cpp — Main rendering orchestrator
//
// Pipeline: Parse → Resolve → Model → Measure → Paginate → Emit
// Implements spec §3.1: full execution sequence.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include "renderer.h"
#include "json_parser.h"
#include "style_resolver.h"
#include "logical_table.h"
#include "inline_parser.h"
#include "font_cache.h"
#include "text_measurer.h"
#include "paginator.h"
#include "docx_emitter.h"

#include <filesystem>
#include <fstream>
#include <iostream>

namespace fs = std::filesystem;

namespace kstfl {

// ---------------------------------------------------------------------------
// Constructor / Destructor
// ---------------------------------------------------------------------------

Renderer::Renderer() = default;
Renderer::~Renderer() = default;

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

void Renderer::add_default_font_paths() {
    // Will be used during render()
    config_.font_dirs.clear();
    // Add marker so render() knows to call font_cache.add_default_font_paths()
    config_.font_dirs.push_back("__default__");
}

void Renderer::add_font_path(const std::string& path) {
    config_.font_dirs.push_back(path);
}

void Renderer::set_fallback_font(const std::string& path) {
    config_.fallback_font_path = path;
}

void Renderer::set_config(const RendererConfig& config) {
    config_ = config;
}

// ---------------------------------------------------------------------------
// Helper: read file to string
// ---------------------------------------------------------------------------

static std::string read_file_to_string(const std::string& path) {
    std::ifstream ifs(path, std::ios::binary | std::ios::ate);
    if (!ifs) {
        throw RenderError("Cannot read file: " + path);
    }
    auto size = ifs.tellg();
    ifs.seekg(0);
    std::string content(static_cast<size_t>(size), '\0');
    ifs.read(content.data(), size);
    return content;
}

// ---------------------------------------------------------------------------
// render: from file paths
// ---------------------------------------------------------------------------

void Renderer::render(const std::string& spec_json_path,
                       const std::string& template_json_path,
                       const std::string& output_path) {
    std::string spec_json = read_file_to_string(spec_json_path);
    std::string template_json = read_file_to_string(template_json_path);

    // Determine data directory from spec path
    std::string data_dir = fs::path(spec_json_path).parent_path().string();

    render_from_strings(spec_json, template_json, output_path, data_dir);
}

// ---------------------------------------------------------------------------
// render_from_strings: main pipeline
// ---------------------------------------------------------------------------

void Renderer::render_from_strings(const std::string& spec_json,
                                    const std::string& template_json,
                                    const std::string& output_path,
                                    const std::string& data_dir) {
    if (config_.verbose) {
        std::cerr << "[ksTFL] Starting render pipeline...\n";
    }

    // -----------------------------------------------------------------------
    // Phase 1: Parse JSON inputs (spec §22.1)
    // -----------------------------------------------------------------------

    if (config_.verbose) {
        std::cerr << "[ksTFL] Phase 1: Parsing JSON inputs...\n";
    }

    // Parse template
    StylesTemplate tmpl = parse_template_json_string(template_json);

    // Parse spec document
    TFLDocument doc = parse_spec_json_string(spec_json);

    // Load data JSON files
    std::unordered_map<std::string, DataTable> data_tables;
    for (const auto& spec : doc.specs) {
        if (spec.data_ref.empty()) continue;
        if (data_tables.count(spec.data_ref)) continue;  // already loaded

        // Resolve data file path — try bare name first, then with .json suffix
        std::string data_path;
        if (!data_dir.empty()) {
            data_path = data_dir + "/" + spec.data_ref;
        } else {
            data_path = spec.data_ref;
        }
        if (!fs::exists(data_path) && fs::exists(data_path + ".json")) {
            data_path += ".json";
        }

        if (fs::exists(data_path)) {
            std::string data_json = read_file_to_string(data_path);
            data_tables[spec.data_ref] = parse_data_json_string(data_json);
            if (config_.verbose) {
                std::cerr << "[ksTFL]   Loaded data: " << spec.data_ref
                          << " (" << data_tables[spec.data_ref].n_rows << " rows)\n";
            }
        } else {
            if (config_.verbose) {
                std::cerr << "[ksTFL]   WARNING: Data file not found: " << data_path << "\n";
            }
        }
    }

    // -----------------------------------------------------------------------
    // Phase 2: Initialize font cache + text measurer (spec §22.4)
    // -----------------------------------------------------------------------

    if (config_.verbose) {
        std::cerr << "[ksTFL] Phase 2: Initializing font cache...\n";
    }

    FontCache font_cache;
    for (const auto& dir : config_.font_dirs) {
        font_cache.add_font_dir(dir);
    }

    // Add fallback font path if specified
    if (!config_.fallback_font_path.empty()) {
        std::string parent = fs::path(config_.fallback_font_path).parent_path().string();
        if (!parent.empty()) {
            font_cache.add_font_dir(parent);
        }
    }

    TextMeasurer measurer(font_cache);

    // -----------------------------------------------------------------------
    // Phase 3: Per-spec processing: Resolve → Model → Measure → Paginate
    // -----------------------------------------------------------------------

    std::unordered_map<std::string, PaginationResult> all_pages;
    std::unordered_map<std::string, std::vector<LogicalRow>> all_rows;
    std::unordered_map<std::string, HeaderGrid> all_headers;

    for (auto& spec : doc.specs) {
        if (config_.verbose) {
            std::cerr << "[ksTFL] Processing spec: " << spec.key << "\n";
        }

        // --- Phase 3a: Resolve styles and page config (spec §22.2) ---
        if (config_.verbose) {
            std::cerr << "[ksTFL]   Phase 3a: Resolving styles...\n";
        }
        StyleResolver resolver(tmpl, spec.spec_styles);

        PageConfig page_config = resolver.resolve_page_config(spec);
        if (config_.verbose) {
            std::cerr << "[ksTFL]   Page config resolved, usable_width="
                      << page_config.usable_width().emu << " emu\n";
        }
        Length usable_width = page_config.usable_width();
        Length table_width = resolver.resolve_table_width(spec, usable_width);
        if (config_.verbose) {
            std::cerr << "[ksTFL]   Table width=" << table_width.emu
                      << " emu, columns=" << spec.columns.size() << "\n";
        }

        // Resolve column widths
        resolver.resolve_column_widths(spec.columns, table_width);
        if (config_.verbose) {
            std::cerr << "[ksTFL]   Column widths resolved\n";
        }

        if (spec.document.doc_type != DocType::Table || !spec.document.has_data) {
            // No table to paginate (Text or Figure)
            if (config_.verbose) {
                std::cerr << "[ksTFL]   Non-table spec, skipping model/paginate\n";
            }
            continue;
        }

        // --- Phase 3b: Build logical table (spec §22.3) ---
        if (config_.verbose) {
            std::cerr << "[ksTFL]   Phase 3b: Building logical table...\n";
            std::cerr << "[ksTFL]     data_ref='" << spec.data_ref << "'\n";
        }
        DataTable* data = nullptr;
        auto dt_it = data_tables.find(spec.data_ref);
        if (dt_it != data_tables.end()) {
            data = &dt_it->second;
        }

        if (!data) {
            if (config_.verbose) {
                std::cerr << "[ksTFL]   WARNING: No data for spec " << spec.key << "\n";
            }
            continue;
        }

        if (config_.verbose) {
            std::cerr << "[ksTFL]   Data loaded: " << data->n_rows << " rows, "
                      << data->columns.size() << " data columns\n";
            std::cerr << "[ksTFL]   Calling LogicalTableBuilder::build...\n";
        }
        auto table_result = LogicalTableBuilder::build(spec, *data);
        if (config_.verbose) {
            std::cerr << "[ksTFL]   Logical table built: " << table_result.rows.size()
                      << " rows, " << table_result.header_grid.rows.size() << " header rows\n";
        }
        auto& rows = table_result.rows;
        auto& header_grid = table_result.header_grid;

        // --- Phase 3c: Measure (spec §22.4) ---
        if (config_.verbose) {
            std::cerr << "[ksTFL]   Phase 3c: Measuring...\n";
        }

        // Measure header grid cells
        Length total_header_height{0};
        header_grid.row_heights.clear();
        for (auto& header_row : header_grid.rows) {
            Length max_row_height{0};
            for (auto& cell : header_row) {
                // Resolve header cell style
                StyleDef hdr_style;
                ColumnSpec dummy;
                dummy.label_style_ref = cell.style_ref;
                hdr_style = resolver.resolve_header_cell_style(dummy);

                MeasuredText m = measurer.measure_plain(cell.label, hdr_style, cell.width);
                if (m.height > max_row_height) {
                    max_row_height = m.height;
                }
            }
            header_grid.row_heights.push_back(max_row_height);
            total_header_height = total_header_height + max_row_height;
        }
        header_grid.total_height = total_header_height;

        // Measure body row heights (spec §16: row_height = max(cell_heights))
        for (auto& row : rows) {
            Length max_height{0};
            for (size_t ci = 0; ci < row.cells.size() && ci < spec.columns.size(); ++ci) {
                const auto& cell = row.cells[ci];
                if (cell.is_merged && !cell.is_merge_leader) continue;

                Length cell_width = cell.is_merge_leader
                    ? cell.merged_width
                    : spec.columns[ci].resolved_width;

                StyleDef cell_style = resolver.resolve_body_cell_style(
                    spec.columns[ci], row.row_style_ref);
                if (cell.style_ref.has_value()) {
                    const StyleDef* override_style = resolver.find_style(cell.style_ref.value());
                    if (override_style) {
                        cell_style = cell_style.merged_with(*override_style);
                    }
                }

                MeasuredText m = measurer.measure_plain(cell.text, cell_style, cell_width);
                if (m.height > max_height) {
                    max_height = m.height;
                }
            }
            row.measured_height = max_height;
        }

        // --- Phase 3d: Paginate (spec §22.5) ---
        if (config_.verbose) {
            std::cerr << "[ksTFL]   Phase 3d: Paginating...\n";
        }
        PaginationResult pagination = Paginator::paginate(
            spec, rows, header_grid, page_config, table_width,
            measurer, resolver);

        if (config_.verbose) {
            std::cerr << "[ksTFL]   Paginated: " << pagination.total_pages
                      << " total pages across "
                      << pagination.segments.size() << " segments\n";

            // Detailed page geometry diagnostics
            std::cerr << "[ksTFL]   Page geometry: "
                      << "page_h=" << page_config.page_height().to_pt() << "pt"
                      << " top=" << page_config.margins.top.to_pt() << "pt"
                      << " bot=" << page_config.margins.bottom.to_pt() << "pt"
                      << " usable_h=" << page_config.usable_height().to_pt() << "pt"
                      << "\n";
            std::cerr << "[ksTFL]   Header grid: total_h=" << header_grid.total_height.to_pt() << "pt"
                      << " rows=" << header_grid.rows.size();
            for (size_t i = 0; i < header_grid.row_heights.size(); ++i) {
                std::cerr << " rh[" << i << "]=" << header_grid.row_heights[i].to_pt() << "pt";
            }
            std::cerr << "\n";

            // Show first 5 body row heights
            std::cerr << "[ksTFL]   Body row heights (first 5): ";
            for (size_t i = 0; i < 5 && i < rows.size(); ++i) {
                std::cerr << "[" << i << "]=" << rows[i].measured_height.to_pt() << "pt ";
            }
            std::cerr << "\n";

            // Per-page details (first 3 pages)
            for (const auto& seg : pagination.segments) {
                for (size_t pi = 0; pi < seg.pages.size() && pi < 3; ++pi) {
                    const auto& p = seg.pages[pi];
                    Length body_h{0};
                    for (size_t ri = p.first_row; ri <= p.last_row && ri < rows.size(); ++ri) {
                        body_h = body_h + rows[ri].measured_height;
                    }
                    Length total_content = p.titles_height + p.subtitles_height
                        + p.table_header_height + body_h
                        + p.header_section_height + p.footer_section_height;
                    if (p.is_last_page) {
                        total_content = total_content + p.footnotes_height;
                    }
                    std::cerr << "[ksTFL]   Page " << p.page_number
                              << ": rows[" << p.first_row << ".." << p.last_row << "]"
                              << " nrows=" << (p.last_row - p.first_row + 1)
                              << " body_h=" << body_h.to_pt() << "pt"
                              << " titles=" << p.has_titles
                              << "\n";
                    std::cerr << "[ksTFL]     titles_h=" << p.titles_height.to_pt() << "pt"
                              << " sub_h=" << p.subtitles_height.to_pt() << "pt"
                              << " hdr_tbl_h=" << p.table_header_height.to_pt() << "pt"
                              << " hdr_sec_h=" << p.header_section_height.to_pt() << "pt"
                              << " ftr_sec_h=" << p.footer_section_height.to_pt() << "pt"
                              << " fn_h=" << p.footnotes_height.to_pt() << "pt"
                              << "\n";
                    std::cerr << "[ksTFL]     total_content=" << total_content.to_pt() << "pt"
                              << " usable=" << page_config.usable_height().to_pt() << "pt"
                              << " slack=" << (page_config.usable_height() - total_content).to_pt() << "pt"
                              << "\n";
                }
            }
        }

        // --- Phase 3e: Restore dedupe values at page boundaries ---
        // apply_dedupe() blanks consecutive duplicate cell values globally,
        // but when a page break falls within a group the first row of the
        // new page appears with empty group/ID cells.  Fix: scan backward
        // from each page boundary to find the last non-blank value and
        // restore it in the first DataRow of the new page.
        {
            std::vector<size_t> dedupe_indices;
            for (size_t i = 0; i < spec.columns.size(); ++i) {
                if (spec.columns[i].dedupe) {
                    dedupe_indices.push_back(i);
                }
            }

            if (!dedupe_indices.empty()) {
                if (config_.verbose) {
                    std::cerr << "[ksTFL]   Dedupe columns: ";
                    for (size_t di : dedupe_indices) {
                        std::cerr << di << "(" << spec.columns[di].id << ") ";
                    }
                    std::cerr << "\n";
                }
                size_t restorations = 0;
                for (const auto& seg : pagination.segments) {
                    if (config_.verbose) {
                        std::cerr << "[ksTFL]   Segment " << seg.segment_index
                                  << ": " << seg.pages.size() << " pages\n";
                    }
                    for (size_t pi = 1; pi < seg.pages.size(); ++pi) {
                        const auto& pg = seg.pages[pi];
                        if (config_.verbose) {
                            std::cerr << "[ksTFL]     Page " << pi
                                      << ": rows [" << pg.first_row
                                      << ".." << pg.last_row << "]\n";
                        }
                        // Find the first DataRow on this page
                        for (size_t ri = pg.first_row;
                             ri <= pg.last_row && ri < rows.size(); ++ri) {
                            if (rows[ri].type != LogicalRowType::DataRow) continue;
                            auto& row = rows[ri];
                            if (config_.verbose) {
                                std::cerr << "[ksTFL]     First DataRow at " << ri
                                          << ", cells=" << row.cells.size() << ":";
                                for (size_t ci = 0; ci < row.cells.size() && ci < 4; ++ci) {
                                    std::cerr << " [" << ci << "]='"
                                              << row.cells[ci].text.substr(0, 20) << "'";
                                }
                                std::cerr << "\n";
                            }
                            for (size_t col_idx : dedupe_indices) {
                                if (col_idx >= row.cells.size()) continue;
                                if (!row.cells[col_idx].text.empty()) continue;
                                // Scan backward for last non-blank value
                                for (size_t bk = ri; bk > 0; --bk) {
                                    const auto& prev = rows[bk - 1];
                                    if (prev.type != LogicalRowType::DataRow) continue;
                                    if (col_idx >= prev.cells.size()) continue;
                                    if (!prev.cells[col_idx].text.empty()) {
                                        row.cells[col_idx].text =
                                            prev.cells[col_idx].text;
                                        restorations++;
                                        if (config_.verbose) {
                                            std::cerr << "[ksTFL]       Restored col "
                                                      << col_idx << " = '"
                                                      << prev.cells[col_idx].text << "'\n";
                                        }
                                        break;
                                    }
                                }
                            }
                            break;  // only restore the first DataRow per page
                        }
                    }
                }
                if (config_.verbose) {
                    std::cerr << "[ksTFL]   Dedupe: " << restorations
                              << " values restored at page boundaries\n";
                }
            }
        }

        all_pages[spec.key] = std::move(pagination);
        all_rows[spec.key] = std::move(rows);
        all_headers[spec.key] = std::move(header_grid);
    }

    // -----------------------------------------------------------------------
    // Phase 4: Emit DOCX (spec §22.6)
    // -----------------------------------------------------------------------

    if (config_.verbose) {
        std::cerr << "[ksTFL] Phase 4: Emitting DOCX...\n";
    }

    DocxEmitter emitter(tmpl, config_);
    emitter.emit(doc, data_tables, output_path,
                  all_pages, all_rows, all_headers, &measurer);

    if (config_.verbose) {
        std::cerr << "[ksTFL] Render complete: " << output_path << "\n";
    }
}

}  // namespace kstfl
