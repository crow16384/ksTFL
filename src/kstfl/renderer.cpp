// kstfl/renderer.cpp — Main rendering orchestrator
//
// Pipeline: Parse → Resolve → Model → Measure → Paginate → Emit
// Implements spec §3.1: full execution sequence.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "renderer.h"
#include "docx_emitter.h"
#include "font_cache.h"
#include "json_parser.h"
#include "logical_table.h"
#include "paginator.h"
#include "style_resolver.h"
#include "text_measurer.h"

#include <Rcpp.h>
#include <algorithm>
#include <filesystem>
#include <format>
#include <fstream>
#include <nlohmann/json.hpp>
#include <unordered_map>

namespace fs = std::filesystem;

namespace kstfl {

using json = nlohmann::json;

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

void Renderer::add_font_path(const std::string &path) {
  config_.font_dirs.push_back(path);
}

void Renderer::set_fallback_font(const std::string &path) {
  config_.fallback_font_path = path;
}

void Renderer::set_config(const RendererConfig &config) {
  config_ = config;
}

// ---------------------------------------------------------------------------
// Helper: read file to string
// ---------------------------------------------------------------------------

static std::string read_file_to_string(const std::string &path) {
  std::ifstream ifs(path, std::ios::binary | std::ios::ate);
  if (!ifs) { throw RenderError(std::format("Cannot read file: {}", path)); }
  auto size = ifs.tellg();
  if (size < 0) {
    // because tellg() can return -1 and read() can fail on I/O errors.
    throw RenderError(std::format("Failed to determine size of the file: {}", path));
  }
  ifs.seekg(0);
  std::string content(static_cast<size_t>(size), '\0');
  ifs.read(content.data(), size);
  return content;
}

struct TemplateBundle {
  StylesTemplate default_template;
  std::unordered_map<std::string, StylesTemplate> per_spec_templates;
};

static TemplateBundle parse_template_bundle(const std::string &template_json) {
  TemplateBundle bundle;

  json root;
  try {
    root = json::parse(template_json);
  } catch (...) {
    // Keep the existing parse error behavior for single-template mode.
    bundle.default_template = parse_template_json_string(template_json);
    return bundle;
  }

  bool is_multi_payload = root.is_object() && root.contains("_ksTFL_multi_template") &&
                          root["_ksTFL_multi_template"].is_boolean() && root["_ksTFL_multi_template"].get<bool>() &&
                          root.contains("default") && root.contains("per_spec") && root["per_spec"].is_object();

  if (!is_multi_payload) {
    bundle.default_template = parse_template_json_string(template_json);
    return bundle;
  }

  bundle.default_template = parse_template_json_string(root["default"].dump());

  for (auto it = root["per_spec"].begin(); it != root["per_spec"].end(); ++it) {
    if (it.value().is_object()) { bundle.per_spec_templates[it.key()] = parse_template_json_string(it.value().dump()); }
  }

  return bundle;
}

// ---------------------------------------------------------------------------
// Helper: restore deduped values at page boundaries
//
// Performance note: the previous implementation scanned backwards through
// all rows for every (page, dedupe column) pair, which is
// O(pages * dedupe_cols * rows).  We now do a single forward pass through
// the rows, maintaining the "last non-empty text" per dedupe column, and
// snapshot it at each target row (first DataRow of every page after the
// first).  This reduces the hot path to O(rows + pages * dedupe_cols).
// ---------------------------------------------------------------------------
static void restore_dedupe_at_page_boundaries(const TFLSpec &spec, std::vector<LogicalRow> &rows,
                                              const PaginationResult &pagination, bool verbose) {

  std::vector<size_t> dedupe_indices;
  for (size_t i = 0; i < spec.columns.size(); ++i) {
    if (spec.columns[i].dedupe) { dedupe_indices.push_back(i); }
  }
  if (dedupe_indices.empty()) return;

  if (verbose) {
    Rcpp::Rcerr << "[ksTFL]   Dedupe columns: ";
    for (size_t di : dedupe_indices) {
      Rcpp::Rcerr << di << "(" << spec.columns[di].id << ") ";
    }
    Rcpp::Rcerr << "\n";
  }

  // Collect the first DataRow of every non-leading page into a sorted list.
  // We restore there; `segment.pages[0]` already holds the natural first
  // value so we skip it.
  std::vector<size_t> target_rows;
  for (const auto &seg : pagination.segments) {
    if (verbose) { Rcpp::Rcerr << "[ksTFL]   Segment " << seg.segment_index << ": " << seg.pages.size() << " pages\n"; }
    for (size_t pi = 1; pi < seg.pages.size(); ++pi) {
      const auto &pg = seg.pages[pi];
      if (verbose) {
        Rcpp::Rcerr << "[ksTFL]     Page " << pi << ": rows [" << pg.first_row << ".." << pg.last_row << "]\n";
      }
      for (size_t ri = pg.first_row; ri <= pg.last_row && ri < rows.size(); ++ri) {
        if (rows[ri].type != LogicalRowType::DataRow) continue;
        target_rows.push_back(ri);
        break;
      }
    }
  }
  if (target_rows.empty()) return;
  std::ranges::sort(target_rows);
  target_rows.erase(std::unique(target_rows.begin(), target_rows.end()), target_rows.end());

  // Single forward pass: maintain running last-non-empty value per dedupe
  // column, and snapshot at each target row.
  std::vector<std::string> last_text(dedupe_indices.size());
  size_t next_target = 0;
  size_t restorations = 0;
  for (size_t ri = 0; ri < rows.size() && next_target < target_rows.size(); ++ri) {
    const auto &row = rows[ri];
    if (row.type == LogicalRowType::DataRow) {
      for (size_t k = 0; k < dedupe_indices.size(); ++k) {
        size_t col_idx = dedupe_indices[k];
        if (col_idx < row.cells.size() && !row.cells[col_idx].text.empty()) { last_text[k] = row.cells[col_idx].text; }
      }
    }
    if (ri == target_rows[next_target]) {
      auto &target = rows[ri];
      if (verbose) {
        Rcpp::Rcerr << "[ksTFL]     First DataRow at " << ri << ", cells=" << target.cells.size() << ":";
        for (size_t ci = 0; ci < target.cells.size() && ci < 4; ++ci) {
          Rcpp::Rcerr << " [" << ci << "]='" << target.cells[ci].text.substr(0, 20) << "'";
        }
        Rcpp::Rcerr << "\n";
      }
      for (size_t k = 0; k < dedupe_indices.size(); ++k) {
        size_t col_idx = dedupe_indices[k];
        if (col_idx >= target.cells.size()) continue;
        if (!target.cells[col_idx].text.empty()) continue;
        if (last_text[k].empty()) continue;
        target.cells[col_idx].text = last_text[k];
        restorations++;
        if (verbose) { Rcpp::Rcerr << "[ksTFL]       Restored col " << col_idx << " = '" << last_text[k] << "'\n"; }
      }
      ++next_target;
    }
  }
  if (verbose) { Rcpp::Rcerr << "[ksTFL]   Dedupe: " << restorations << " values restored at page boundaries\n"; }
}

// ---------------------------------------------------------------------------
// render: from file paths
// ---------------------------------------------------------------------------

size_t Renderer::render(const std::string &spec_json_path, const std::string &template_json_path,
                        const std::string &output_path) {
  std::string spec_json = read_file_to_string(spec_json_path);
  std::string template_json = read_file_to_string(template_json_path);

  // Determine data directory from spec path
  std::string data_dir = fs::path(spec_json_path).parent_path().string();

  return render_from_strings(spec_json, template_json, output_path, data_dir);
}

// ---------------------------------------------------------------------------
// render_from_strings: main pipeline
// ---------------------------------------------------------------------------

size_t Renderer::render_from_strings(const std::string &spec_json, const std::string &template_json,
                                     const std::string &output_path, const std::string &data_dir) {
  if (config_.verbose) { Rcpp::Rcerr << "[ksTFL] Starting render pipeline...\n"; }

  // -----------------------------------------------------------------------
  // Phase 1: Parse JSON inputs (spec §22.1)
  // -----------------------------------------------------------------------

  if (config_.verbose) { Rcpp::Rcerr << "[ksTFL] Phase 1: Parsing JSON inputs...\n"; }

  // Parse template (single-template or multi-template payload)
  TemplateBundle template_bundle = parse_template_bundle(template_json);

  auto template_for_spec = [&](const std::string &spec_key) -> const StylesTemplate & {
    auto it = template_bundle.per_spec_templates.find(spec_key);
    if (it != template_bundle.per_spec_templates.end()) { return it->second; }
    return template_bundle.default_template;
  };

  // Parse spec document
  TFLDocument doc = parse_spec_json_string(spec_json);

  // Load data JSON files
  std::unordered_map<std::string, DataTable> data_tables;
  for (const auto &spec : doc.specs) {
    if (spec.data_ref.empty()) continue;
    if (data_tables.count(spec.data_ref)) continue; // already loaded

    // Resolve data file path — try bare name first, then with .json suffix
    std::string data_path;
    if (!data_dir.empty()) {
      data_path = data_dir + "/" + spec.data_ref;
    } else {
      data_path = spec.data_ref;
    }
    if (!fs::exists(data_path) && fs::exists(data_path + ".json")) { data_path += ".json"; }

    if (fs::exists(data_path)) {
      std::string data_json = read_file_to_string(data_path);
      data_tables[spec.data_ref] = parse_data_json_string(data_json);
      if (config_.verbose) {
        Rcpp::Rcerr << "[ksTFL]   Loaded data: " << spec.data_ref << " (" << data_tables[spec.data_ref].n_rows
                    << " rows)\n";
      }
    } else {
      if (config_.verbose) { Rcpp::Rcerr << "[ksTFL]   WARNING: Data file not found: " << data_path << "\n"; }
    }
  }

  // Resolve figure file paths for Figure specs (data_ref ->
  // <data_dir>/<data_ref>.<ext>)
  for (auto &spec : doc.specs) {
    if (spec.document.doc_type != DocType::Figure) continue;
    if (spec.data_ref.empty()) continue;

    const std::vector<std::string> img_exts = {"png", "jpg", "jpeg", "svg"};
    for (const auto &ext : img_exts) {
      std::string candidate;
      if (!data_dir.empty()) {
        candidate = data_dir + "/" + spec.data_ref + "." + ext;
      } else {
        candidate = spec.data_ref + "." + ext;
      }
      if (fs::exists(candidate)) {
        spec.figure_path = candidate;
        if (config_.verbose) {
          Rcpp::Rcerr << "[ksTFL]   Loaded figure: " << spec.data_ref << " -> " << candidate << "\n";
        }
        break;
      }
    }
    if (spec.figure_path.empty() && config_.verbose) {
      Rcpp::Rcerr << "[ksTFL]   WARNING: Figure file not found for dataRef: " << spec.data_ref << "\n";
    }
  }

  // -----------------------------------------------------------------------
  // Phase 1b: Enforce layout constraints for isColBreak specs
  // When any column uses isColBreak, row breaks across pages must be
  // disabled and header repetition must be enabled to ensure correct
  // pagination of horizontal segments.
  // -----------------------------------------------------------------------

  for (const auto &spec : doc.specs) {
    bool has_col_break =
        std::any_of(spec.columns.begin(), spec.columns.end(), [](const ColumnSpec &c) { return c.is_col_break; });
    if (!has_col_break) continue;

    // Look up (or create) a per-spec template so we don't mutate the
    // shared default template for specs that don't use col breaks.
    auto &tmpl_map = template_bundle.per_spec_templates;
    if (tmpl_map.find(spec.key) == tmpl_map.end()) { tmpl_map[spec.key] = template_bundle.default_template; }

    auto &ts = tmpl_map[spec.key].table_style;
    bool needs_override = ts.allow_row_break_across_pages || !ts.repeat_header_on_each_page;

    if (needs_override) {
      ts.allow_row_break_across_pages = false;
      ts.repeat_header_on_each_page = true;
      Rcpp::warning("Spec '%s': isColBreak is active — forcing "
                    "allow_row_break_across_pages=false and "
                    "repeat_header_on_each_page=true for correct pagination.",
                    spec.key.c_str());
    }

    if (config_.verbose) {
      Rcpp::Rcerr << "[ksTFL]   Spec " << spec.key << ": isColBreak detected, layout constraints enforced"
                  << (needs_override ? " (values overridden)" : " (already compliant)") << "\n";
    }
  }

  // -----------------------------------------------------------------------
  // Phase 2: Initialize font cache + text measurer (spec §22.4)
  // -----------------------------------------------------------------------

  if (config_.verbose) { Rcpp::Rcerr << "[ksTFL] Phase 2: Initializing font cache...\n"; }

  FontCache font_cache;
  for (const auto &dir : config_.font_dirs) {
    font_cache.add_font_dir(dir);
  }

  // Add fallback font path if specified
  if (!config_.fallback_font_path.empty()) {
    std::string parent = fs::path(config_.fallback_font_path).parent_path().string();
    if (!parent.empty()) { font_cache.add_font_dir(parent); }
  }

  TextMeasurer measurer(font_cache);

  // -----------------------------------------------------------------------
  // Phase 3: Per-spec processing: Resolve → Model → Measure → Paginate
  // -----------------------------------------------------------------------

  std::unordered_map<std::string, PaginationResult> all_pages;
  std::unordered_map<std::string, std::vector<LogicalRow>> all_rows;
  std::unordered_map<std::string, HeaderGrid> all_headers;

  for (auto &spec : doc.specs) {
    if (config_.verbose) { Rcpp::Rcerr << "[ksTFL] Processing spec: " << spec.key << "\n"; }

    // --- Phase 3a: Resolve styles and page config (spec §22.2) ---
    if (config_.verbose) { Rcpp::Rcerr << "[ksTFL]   Phase 3a: Resolving styles...\n"; }
    const StylesTemplate &spec_tmpl = template_for_spec(spec.key);
    StyleResolver resolver(spec_tmpl, spec.spec_styles);

    PageConfig page_config = resolver.resolve_page_config(spec);
    if (config_.verbose) {
      Rcpp::Rcerr << "[ksTFL]   Page config resolved, usable_width=" << page_config.usable_width().emu << " emu\n";
    }
    Length usable_width = page_config.usable_width();
    Length table_width = resolver.resolve_table_width(spec, usable_width);
    if (config_.verbose) {
      Rcpp::Rcerr << "[ksTFL]   Table width=" << table_width.emu << " emu, columns=" << spec.columns.size() << "\n";
    }

    // Resolve column widths
    resolver.resolve_column_widths(spec.columns, table_width);
    if (config_.verbose) { Rcpp::Rcerr << "[ksTFL]   Column widths resolved\n"; }

    if (spec.document.doc_type != DocType::Table || !spec.document.has_data) {
      // No table to paginate (Text or Figure)
      if (config_.verbose) { Rcpp::Rcerr << "[ksTFL]   Non-table spec, skipping model/paginate\n"; }
      continue;
    }

    // --- Phase 3b: Build logical table (spec §22.3) ---
    if (config_.verbose) {
      Rcpp::Rcerr << "[ksTFL]   Phase 3b: Building logical table...\n";
      Rcpp::Rcerr << "[ksTFL]     data_ref='" << spec.data_ref << "'\n";
    }
    DataTable *data = nullptr;
    auto dt_it = data_tables.find(spec.data_ref);
    if (dt_it != data_tables.end()) { data = &dt_it->second; }

    if (!data) {
      if (config_.verbose) { Rcpp::Rcerr << "[ksTFL]   WARNING: No data for spec " << spec.key << "\n"; }
      continue;
    }

    if (config_.verbose) {
      Rcpp::Rcerr << "[ksTFL]   Data loaded: " << data->n_rows << " rows, " << data->columns.size()
                  << " data columns\n";
      Rcpp::Rcerr << "[ksTFL]   Calling LogicalTableBuilder::build...\n";
    }
    auto table_result = LogicalTableBuilder::build(spec, *data);
    if (config_.verbose) {
      Rcpp::Rcerr << "[ksTFL]   Logical table built: " << table_result.rows.size() << " rows, "
                  << table_result.header_grid.rows.size() << " header rows\n";
    }
    auto &rows = table_result.rows;
    auto &header_grid = table_result.header_grid;

    // --- Phase 3c: Measure (spec §22.4) ---
    if (config_.verbose) { Rcpp::Rcerr << "[ksTFL]   Phase 3c: Measuring...\n"; }

    // Measure header grid cells.
    // Stamp the template's text_orientation only onto the label row
    // (the last row of the header grid).  Stub/span header rows must
    // NOT inherit rotation — their labels are horizontal.
    {
      ColumnSpec dummy_col;
      StyleDef proto_hdr_style = resolver.resolve_header_cell_style(dummy_col);
      std::optional<TextOrientation> hdr_orientation;
      if (proto_hdr_style.table_style.has_value()) { hdr_orientation = proto_hdr_style.table_style->text_orientation; }
      if (!header_grid.rows.empty()) {
        auto &label_row = header_grid.rows.back();
        for (auto &cell : label_row) {
          if (!cell.text_orientation.has_value()) { cell.text_orientation = hdr_orientation; }
        }
      }
    }

    // --- Measure per-row heights ----------------------------------
    // First pass: compute each row's height from non-vertically-merged
    // cells only.  vMerge::Restart cells span multiple rows, so their
    // full measured height must not inflate a single row.
    // Also record every Restart cell's measured height for the second
    // pass below.
    struct VMergeEntry {
      size_t row_idx;
      size_t source_col_index;
      Length measured_height;
    };
    std::vector<VMergeEntry> vmerge_entries;

    Length total_header_height{0};
    header_grid.row_heights.clear();
    for (size_t ri = 0; ri < header_grid.rows.size(); ++ri) {
      auto &header_row = header_grid.rows[ri];
      Length max_row_height{0};
      for (auto &cell : header_row) {
        // Resolve header cell style (carries text_orientation via table_style)
        ColumnSpec dummy;
        dummy.label_style_ref = cell.style_ref;
        StyleDef hdr_style = resolver.resolve_header_cell_style(dummy);

        // Ensure the resolved style carries the cell's orientation so
        // the measurer performs the correct width/height swap.
        if (cell.text_orientation.has_value()) {
          if (!hdr_style.table_style.has_value()) { hdr_style.table_style = TableCellProps{}; }
          if (!hdr_style.table_style->text_orientation.has_value()) {
            hdr_style.table_style->text_orientation = cell.text_orientation;
          }
        }

        MeasuredText m = measurer.measure_plain(cell.label, hdr_style, cell.width);

        if (cell.v_merge == VMergeState::Restart) {
          // Defer — height will be distributed in second pass.
          vmerge_entries.push_back({ri, cell.source_col_index, m.height});
        } else if (cell.v_merge == VMergeState::Continue) {
          // Skip — empty continuation cell.
        } else {
          if (m.height > max_row_height) { max_row_height = m.height; }
        }
      }
      header_grid.row_heights.push_back(max_row_height);
    }

    // Second pass: ensure vMerge groups have enough combined height.
    // A Restart cell at row ri merges down through all consecutive
    // Continue rows for the same source column.  If the sum of row
    // heights in the group is less than the cell's measured height,
    // increase the last row in the group by the deficit.
    for (const auto &entry : vmerge_entries) {
      size_t ri = entry.row_idx;
      // Find the last row in the merge group (consecutive Continue rows
      // for the same source column).
      size_t last_ri = ri;
      for (size_t nri = ri + 1; nri < header_grid.rows.size(); ++nri) {
        bool found_continue = false;
        for (const auto &c : header_grid.rows[nri]) {
          if (c.v_merge == VMergeState::Continue && c.source_col_index == entry.source_col_index) {
            found_continue = true;
            break;
          }
        }
        if (found_continue) {
          last_ri = nri;
        } else {
          break;
        }
      }
      // Sum row heights in the merge group.
      Length group_height{0};
      for (size_t gri = ri; gri <= last_ri; ++gri) {
        group_height = group_height + header_grid.row_heights[gri];
      }
      // If deficit exists, add it to the last row of the group.
      if (entry.measured_height > group_height) {
        Length deficit{entry.measured_height.emu - group_height.emu};
        header_grid.row_heights[last_ri] = header_grid.row_heights[last_ri] + deficit;
      }
    }

    // Compute total header height from (possibly adjusted) row heights.
    for (const auto &rh : header_grid.row_heights) {
      total_header_height = total_header_height + rh;
    }
    header_grid.total_height = total_header_height;

    // --- Phase 3d: Paginate (spec §22.5) ---
    // Paginator computes baseline row heights and per-segment row heights
    // (for colBreak segments with scaled column widths).
    if (config_.verbose) { Rcpp::Rcerr << "[ksTFL]   Phase 3d: Paginating...\n"; }
    PaginationResult pagination =
        Paginator::paginate(spec, rows, header_grid, page_config, table_width, measurer, resolver);

    if (config_.verbose) {
      Rcpp::Rcerr << "[ksTFL]   Paginated: " << pagination.total_pages << " total pages across "
                  << pagination.segments.size() << " segments\n";

      // Detailed page geometry diagnostics
      Rcpp::Rcerr << "[ksTFL]   Page geometry: "
                  << "page_h=" << page_config.page_height().to_pt() << "pt"
                  << " top=" << page_config.margins.top.to_pt() << "pt"
                  << " bot=" << page_config.margins.bottom.to_pt() << "pt"
                  << " usable_h=" << page_config.usable_height().to_pt() << "pt"
                  << "\n";
      Rcpp::Rcerr << "[ksTFL]   Header grid: total_h=" << header_grid.total_height.to_pt() << "pt"
                  << " rows=" << header_grid.rows.size();
      for (size_t i = 0; i < header_grid.row_heights.size(); ++i) {
        Rcpp::Rcerr << " rh[" << i << "]=" << header_grid.row_heights[i].to_pt() << "pt";
      }
      Rcpp::Rcerr << "\n";

      // Show first 5 body row heights
      Rcpp::Rcerr << "[ksTFL]   Body row heights (first 5): ";
      for (size_t i = 0; i < 5 && i < rows.size(); ++i) {
        Rcpp::Rcerr << "[" << i << "]=" << rows[i].measured_height.to_pt() << "pt ";
      }
      Rcpp::Rcerr << "\n";

      // Per-page details (first 3 pages)
      for (const auto &seg : pagination.segments) {
        for (size_t pi = 0; pi < seg.pages.size() && pi < 3; ++pi) {
          const auto &p = seg.pages[pi];
          Length body_h{0};
          for (size_t ri = p.first_row; ri <= p.last_row && ri < rows.size(); ++ri) {
            body_h = body_h + rows[ri].measured_height;
          }
          Length total_content = p.titles_height + p.subtitles_height + p.table_header_height + body_h +
                                 p.header_section_height + p.footer_section_height;
          if (p.has_footnotes) { total_content = total_content + p.footnotes_height; }
          Rcpp::Rcerr << "[ksTFL]   Page " << p.page_number << ": rows[" << p.first_row << ".." << p.last_row << "]"
                      << " nrows=" << (p.last_row - p.first_row + 1) << " body_h=" << body_h.to_pt() << "pt"
                      << " titles=" << p.has_titles << "\n";
          Rcpp::Rcerr << "[ksTFL]     titles_h=" << p.titles_height.to_pt() << "pt"
                      << " sub_h=" << p.subtitles_height.to_pt() << "pt"
                      << " hdr_tbl_h=" << p.table_header_height.to_pt() << "pt"
                      << " hdr_sec_h=" << p.header_section_height.to_pt() << "pt"
                      << " ftr_sec_h=" << p.footer_section_height.to_pt() << "pt"
                      << " fn_h=" << p.footnotes_height.to_pt() << "pt"
                      << "\n";
          Rcpp::Rcerr << "[ksTFL]     total_content=" << total_content.to_pt() << "pt"
                      << " usable=" << page_config.usable_height().to_pt() << "pt"
                      << " slack=" << (page_config.usable_height() - total_content).to_pt() << "pt"
                      << "\n";
        }
      }
    }

    // --- Phase 3e: Restore dedupe values at page boundaries ---
    restore_dedupe_at_page_boundaries(spec, rows, pagination, config_.verbose);

    all_pages[spec.key] = std::move(pagination);
    all_rows[spec.key] = std::move(rows);
    all_headers[spec.key] = std::move(header_grid);
  }

  // -----------------------------------------------------------------------
  // Phase 4: Emit DOCX (spec §22.6)
  // -----------------------------------------------------------------------

  if (config_.verbose) { Rcpp::Rcerr << "[ksTFL] Phase 4: Emitting DOCX...\n"; }

  DocxEmitter emitter(template_bundle.default_template,
                      template_bundle.per_spec_templates.empty() ? nullptr : &template_bundle.per_spec_templates,
                      config_);
  emitter.emit(doc, data_tables, output_path, all_pages, all_rows, all_headers, &measurer);

  // Compute total page count across all specs.
  // Table specs use paginator counts; Text/Figure specs always emit one
  // section page in document.xml.
  size_t total_pages = doc.metadata.insert_toc ? 1 : 0;
  for (const auto &spec : doc.specs) {
    if (spec.document.doc_type == DocType::Table && spec.document.has_data) {
      auto it = all_pages.find(spec.key);
      if (it != all_pages.end()) {
        total_pages += it->second.total_pages;
      } else {
        // Fallback safety: table section is still emitted as one page.
        total_pages += 1;
      }
    } else {
      total_pages += 1;
    }
  }

  if (config_.verbose) { Rcpp::Rcerr << "[ksTFL] Render complete: " << output_path << "\n"; }
  if (config_.verbose) { Rcpp::Rcerr << "[ksTFL] Pages produced: " << total_pages << "\n"; }

  return total_pages;
}

} // namespace kstfl
