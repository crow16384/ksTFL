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
        if (dir == "__default__") {
            font_cache.add_default_font_paths();
        } else {
            font_cache.add_font_dir(dir);
        }
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
                  all_pages, all_rows, all_headers);

    if (config_.verbose) {
        std::cerr << "[ksTFL] Render complete: " << output_path << "\n";
    }
}

}  // namespace kstfl
