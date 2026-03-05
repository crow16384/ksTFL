// kstfl/json_parser.cpp — Parse spec JSON, template JSON, data JSON
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "json_parser.h"
#include <nlohmann/json.hpp>
#include <algorithm>
#include <fstream>
#include <Rcpp.h>

using json = nlohmann::json;

namespace kstfl {

// ---------------------------------------------------------------------------
// Helpers: safe JSON accessors
// ---------------------------------------------------------------------------

/// Get string or empty.
static std::string get_str(const json& j, const std::string& key) {
    if (j.contains(key) && !j[key].is_null()) {
        if (j[key].is_string()) return j[key].get<std::string>();
    }
    return "";
}

/// Get bool with default.
static bool get_bool(const json& j, const std::string& key, bool def = false) {
    if (j.contains(key) && j[key].is_boolean()) return j[key].get<bool>();
    return def;
}

/// Get int with default.
static int get_int(const json& j, const std::string& key, int def = 0) {
    if (j.contains(key) && j[key].is_number_integer()) return j[key].get<int>();
    return def;
}

/// Get optional string (nullopt if missing or null).
static std::optional<std::string> get_opt_str(const json& j, const std::string& key) {
    if (j.contains(key) && j[key].is_string()) return j[key].get<std::string>();
    return std::nullopt;
}

/// Get optional double.
static std::optional<double> get_opt_dbl(const json& j, const std::string& key) {
    if (j.contains(key) && j[key].is_number()) return j[key].get<double>();
    return std::nullopt;
}

/// Get optional bool.
static std::optional<bool> get_opt_bool(const json& j, const std::string& key) {
    if (j.contains(key) && j[key].is_boolean()) return j[key].get<bool>();
    return std::nullopt;
}

/// Get string array.
static std::vector<std::string> get_str_array(const json& j, const std::string& key) {
    std::vector<std::string> result;
    if (j.contains(key) && j[key].is_array()) {
        for (const auto& item : j[key]) {
            if (item.is_string()) result.push_back(item.get<std::string>());
        }
    }
    return result;
}

/// Read a JSON file to nlohmann::json.
static json read_json_file(const std::string& path) {
    std::ifstream file(path);
    if (!file.is_open()) {
        throw RenderError("Cannot open JSON file: " + path);
    }
    json j;
    try {
        file >> j;
    } catch (const json::parse_error& e) {
        throw RenderError("JSON parse error in '" + path + "': " + e.what());
    }
    return j;
}

// ---------------------------------------------------------------------------
// Parse Border
// ---------------------------------------------------------------------------

static Border parse_border(const json& j) {
    Border b;
    auto c = get_opt_str(j, "color");
    if (c.has_value()) b.color = Color::parse(*c);

    auto w = get_opt_str(j, "width");
    if (w.has_value()) b.width = Length::parse(*w);

    auto ls = get_opt_str(j, "line_style");
    if (ls.has_value()) {
        const std::string& s = *ls;
        if (s == "none")        b.line_style = BorderLineStyle::None;
        else if (s == "single") b.line_style = BorderLineStyle::Single;
        else if (s == "double") b.line_style = BorderLineStyle::Double;
        else if (s == "dashed") b.line_style = BorderLineStyle::Dashed;
        else if (s == "dotted") b.line_style = BorderLineStyle::Dotted;
        else if (s == "thick")  b.line_style = BorderLineStyle::Thick;
        else b.line_style = BorderLineStyle::Single; // default
    }
    return b;
}

static Borders parse_borders(const json& j) {
    Borders borders;
    if (j.contains("top") && j["top"].is_object())
        borders.top = parse_border(j["top"]);
    if (j.contains("bottom") && j["bottom"].is_object())
        borders.bottom = parse_border(j["bottom"]);
    if (j.contains("left") && j["left"].is_object())
        borders.left = parse_border(j["left"]);
    if (j.contains("right") && j["right"].is_object())
        borders.right = parse_border(j["right"]);
    return borders;
}

// ---------------------------------------------------------------------------
// Parse Font properties
// ---------------------------------------------------------------------------

static FontProps parse_font_props(const json& j) {
    FontProps fp;
    fp.font_name = get_opt_str(j, "font_name");

    // font_size can be "9pt" or just a number
    auto fs = get_opt_str(j, "font_size");
    if (fs.has_value()) {
        // Strip "pt" and parse as double
        std::string s = *fs;
        if (s.size() > 2 && s.substr(s.size() - 2) == "pt") {
            s = s.substr(0, s.size() - 2);
        }
        try {
            fp.font_size = std::stod(s);
        } catch (...) {
            throw RenderError("Invalid font_size: '" + *fs + "'");
        }
    }

    fp.bold = get_opt_bool(j, "bold");
    fp.italic = get_opt_bool(j, "italic");
    fp.underline = get_opt_bool(j, "underline");

    auto c = get_opt_str(j, "color");
    if (c.has_value()) fp.color = Color::parse(*c);

    auto h = get_opt_str(j, "highlight");
    if (h.has_value()) fp.highlight = Color::parse(*h);

    return fp;
}

// ---------------------------------------------------------------------------
// Parse Spacing / Indent / Paragraph
// ---------------------------------------------------------------------------

static SpacingProps parse_spacing(const json& j) {
    SpacingProps sp;
    auto b = get_opt_str(j, "before");
    if (b.has_value()) sp.before = Length::parse(*b);
    auto a = get_opt_str(j, "after");
    if (a.has_value()) sp.after = Length::parse(*a);
    sp.line_spacing_multiplier = get_opt_dbl(j, "line_spacing");
    return sp;
}

static IndentProps parse_indents(const json& j) {
    IndentProps ip;
    auto l = get_opt_str(j, "left");
    if (l.has_value()) ip.left = Length::parse(*l);
    auto r = get_opt_str(j, "right");
    if (r.has_value()) ip.right = Length::parse(*r);
    auto fl = get_opt_str(j, "first_line");
    if (fl.has_value()) ip.first_line = Length::parse(*fl);
    return ip;
}

static Alignment parse_alignment(const std::string& s) {
    if (s == "left")    return Alignment::Left;
    if (s == "center")  return Alignment::Center;
    if (s == "right")   return Alignment::Right;
    if (s == "justify" || s == "distributed") return Alignment::Justify;
    return Alignment::Left;
}

static ParagraphProps parse_paragraph_props(const json& j) {
    ParagraphProps pp;
    auto align = get_opt_str(j, "alignment");
    if (align.has_value()) pp.alignment = parse_alignment(*align);
    if (j.contains("spacing") && j["spacing"].is_object())
        pp.spacing = parse_spacing(j["spacing"]);
    if (j.contains("indents") && j["indents"].is_object())
        pp.indents = parse_indents(j["indents"]);
    pp.widow_control = get_opt_bool(j, "widow_control");
    pp.keep_next = get_opt_bool(j, "keep_next");
    pp.keep_lines = get_opt_bool(j, "keep_lines");
    return pp;
}

// ---------------------------------------------------------------------------
// Parse Table Cell Props
// ---------------------------------------------------------------------------

static VerticalAlignment parse_valign(const std::string& s) {
    if (s == "top")    return VerticalAlignment::Top;
    if (s == "center") return VerticalAlignment::Center;
    if (s == "bottom") return VerticalAlignment::Bottom;
    return VerticalAlignment::Center;
}

static TextOrientation parse_text_orient(const std::string& s) {
    if (s == "horizontal")    return TextOrientation::Horizontal;
    if (s == "vertical_90" || s == "btLr")  return TextOrientation::BottomToTop;
    if (s == "vertical_270" || s == "tbRl") return TextOrientation::TopToBottom;
    return TextOrientation::Horizontal;
}

static TableCellProps parse_table_cell_props(const json& j) {
    TableCellProps tcp;
    auto bg = get_opt_str(j, "background_color");
    if (bg.has_value()) tcp.background_color = Color::parse(*bg);

    auto rh = get_opt_str(j, "row_height");
    if (rh.has_value() && *rh != "auto") tcp.row_height = Length::parse(*rh);

    auto va = get_opt_str(j, "vertical_alignment");
    if (va.has_value()) tcp.vertical_alignment = parse_valign(*va);

    auto to = get_opt_str(j, "text_orientation");
    if (to.has_value()) tcp.text_orientation = parse_text_orient(*to);

    if (j.contains("borders") && j["borders"].is_object())
        tcp.borders = parse_borders(j["borders"]);

    // Cell margins
    if (j.contains("cell_margins") && j["cell_margins"].is_object()) {
        const auto& cm = j["cell_margins"];
        auto mt = get_opt_str(cm, "top");
        if (mt.has_value()) tcp.cell_margin_top = Length::parse(*mt);
        auto mb = get_opt_str(cm, "bottom");
        if (mb.has_value()) tcp.cell_margin_bottom = Length::parse(*mb);
        auto ml = get_opt_str(cm, "left");
        if (ml.has_value()) tcp.cell_margin_left = Length::parse(*ml);
        auto mr = get_opt_str(cm, "right");
        if (mr.has_value()) tcp.cell_margin_right = Length::parse(*mr);
    }

    return tcp;
}

// ---------------------------------------------------------------------------
// Parse StyleDef (composite: font + paragraph + table_style)
// ---------------------------------------------------------------------------

static StyleDef parse_style_def(const json& j) {
    StyleDef sd;
    if (j.contains("font") && j["font"].is_object())
        sd.font = parse_font_props(j["font"]);
    if (j.contains("paragraph") && j["paragraph"].is_object())
        sd.paragraph = parse_paragraph_props(j["paragraph"]);
    if (j.contains("table_style") && j["table_style"].is_object())
        sd.table_style = parse_table_cell_props(j["table_style"]);
    return sd;
}

/// Parse a text style from template (has word_style + paragraph + font structure).
static StyleDef parse_text_style(const json& j) {
    StyleDef sd;
    if (j.contains("font") && j["font"].is_object())
        sd.font = parse_font_props(j["font"]);
    if (j.contains("paragraph") && j["paragraph"].is_object())
        sd.paragraph = parse_paragraph_props(j["paragraph"]);
    return sd;
}

// ---------------------------------------------------------------------------
// Parse PageConfig + margins
// ---------------------------------------------------------------------------

static PageSize parse_page_size(const std::string& s) {
    if (s == "A4")        return PageSize::A4;
    if (s == "A3")        return PageSize::A3;
    if (s == "Letter")    return PageSize::Letter;
    if (s == "Legal")     return PageSize::Legal;
    if (s == "Executive") return PageSize::Executive;
    return PageSize::A4;
}

static Orientation parse_orientation(const std::string& s) {
    if (s == "portrait")  return Orientation::Portrait;
    if (s == "landscape") return Orientation::Landscape;
    return Orientation::Landscape;
}

static PageMargins parse_margins(const json& j) {
    PageMargins m;
    auto top = get_opt_str(j, "top");
    if (top.has_value()) m.top = Length::parse(*top);
    auto bot = get_opt_str(j, "bottom");
    if (bot.has_value()) m.bottom = Length::parse(*bot);
    auto left = get_opt_str(j, "left");
    if (left.has_value()) m.left = Length::parse(*left);
    auto right = get_opt_str(j, "right");
    if (right.has_value()) m.right = Length::parse(*right);
    auto hdr = get_opt_str(j, "header");
    if (hdr.has_value()) m.header_distance = Length::parse(*hdr);
    auto ftr = get_opt_str(j, "footer");
    if (ftr.has_value()) m.footer_distance = Length::parse(*ftr);
    return m;
}

static PageMarginsOverride parse_margins_override(const json& j) {
    PageMarginsOverride m;
    auto top = get_opt_str(j, "top");
    if (top.has_value()) m.top = Length::parse(*top);
    auto bot = get_opt_str(j, "bottom");
    if (bot.has_value()) m.bottom = Length::parse(*bot);
    auto left = get_opt_str(j, "left");
    if (left.has_value()) m.left = Length::parse(*left);
    auto right = get_opt_str(j, "right");
    if (right.has_value()) m.right = Length::parse(*right);
    auto hdr = get_opt_str(j, "header");
    if (hdr.has_value()) m.header_distance = Length::parse(*hdr);
    auto ftr = get_opt_str(j, "footer");
    if (ftr.has_value()) m.footer_distance = Length::parse(*ftr);
    return m;
}

static PageConfig parse_page_config(const json& j) {
    PageConfig pc;
    auto sz = get_opt_str(j, "size");
    if (sz.has_value()) pc.size = parse_page_size(*sz);
    auto orient = get_opt_str(j, "orientation");
    if (orient.has_value()) pc.orientation = parse_orientation(*orient);
    if (j.contains("margins") && j["margins"].is_object())
        pc.margins = parse_margins(j["margins"]);
    return pc;
}

// ---------------------------------------------------------------------------
// Parse StyleMap (attribs.styles)
// ---------------------------------------------------------------------------

static StyleMap parse_style_map(const json& j) {
    StyleMap map;
    for (auto it = j.begin(); it != j.end(); ++it) {
        if (it->is_object()) {
            StyleDef sd = parse_style_def(*it);
            sd.id = it.key();
            map[it.key()] = std::move(sd);
        }
    }
    return map;
}

// ---------------------------------------------------------------------------
// Parse TextGroup (titles, subtitles, footnotes, bodyText)
// ---------------------------------------------------------------------------

static std::vector<TextGroup> parse_text_groups(const json& j) {
    std::vector<TextGroup> groups;
    if (j.is_null()) return groups;
    for (auto it = j.begin(); it != j.end(); ++it) {
        if (!it->is_object()) continue;
        TextGroup tg;
        tg.text = get_str_array(*it, "text");
        tg.order = get_int(*it, "order", 0);
        tg.style_refs = get_str_array(*it, "styleRef");
        int toc = get_int(*it, "toclevel", 0);
        if (toc >= 1 && toc <= 9) tg.toc_level = toc;
        groups.push_back(std::move(tg));
    }
    // Sort by order
    std::sort(groups.begin(), groups.end(),
              [](const TextGroup& a, const TextGroup& b) { return a.order < b.order; });
    return groups;
}

// ---------------------------------------------------------------------------
// Parse Headers / Footers (arrays of 3-element string arrays)
// ---------------------------------------------------------------------------

static std::vector<HeaderFooterRow> parse_header_footer(const json& j) {
    std::vector<HeaderFooterRow> rows;
    if (j.is_null() || !j.is_array()) return rows;
    int order = 0;
    for (const auto& row : j) {
        if (!row.is_array()) continue;
        HeaderFooterRow hfr;
        hfr.order = order++;
        // Placement rule:
        //   1 value  → left only
        //   2 values → left + right (center empty)
        //   3 values → left + center + right
        if (row.size() == 1 && row[0].is_string()) {
            hfr.left = row[0].get<std::string>();
        } else if (row.size() == 2) {
            if (row[0].is_string()) hfr.left  = row[0].get<std::string>();
            if (row[1].is_string()) hfr.right = row[1].get<std::string>();
        } else if (row.size() >= 3) {
            if (row[0].is_string()) hfr.left   = row[0].get<std::string>();
            if (row[1].is_string()) hfr.center = row[1].get<std::string>();
            if (row[2].is_string()) hfr.right  = row[2].get<std::string>();
        }
        rows.push_back(std::move(hfr));
    }
    return rows;
}

// ---------------------------------------------------------------------------
// Parse StubColumns
// ---------------------------------------------------------------------------

static std::vector<StubColumn> parse_stub_columns(const json& j) {
    std::vector<StubColumn> stubs;
    if (j.is_null()) return stubs;
    for (auto it = j.begin(); it != j.end(); ++it) {
        if (!it->is_object()) continue;
        StubColumn sc;
        sc.label = get_str(*it, "label");
        sc.stub_order = get_int(*it, "stubOrder", 0);
        sc.cols = get_str_array(*it, "cols");
        auto lsr = get_str_array(*it, "labelStyleRef");
        if (!lsr.empty()) sc.label_style_ref = lsr[0];
        stubs.push_back(std::move(sc));
    }
    // Sort by stubOrder (descending for depth)
    std::sort(stubs.begin(), stubs.end(),
              [](const StubColumn& a, const StubColumn& b) { return a.stub_order > b.stub_order; });
    return stubs;
}

// ---------------------------------------------------------------------------
// Parse Columns
// ---------------------------------------------------------------------------

static std::vector<ColumnSpec> parse_columns(const json& j) {
    std::vector<ColumnSpec> cols;
    if (j.is_null()) return cols;
    for (auto it = j.begin(); it != j.end(); ++it) {
        if (!it->is_object()) continue;
        ColumnSpec cs;
        cs.id = it.key();
        cs.col_order = get_int(*it, "colOrder", 0);
        cs.label = get_str(*it, "label");
        cs.is_id = get_bool(*it, "isID", false);
        cs.is_visible = get_bool(*it, "isVisible", true);
        cs.is_grouping = get_bool(*it, "isGrouping", false);
        cs.is_col_break = get_bool(*it, "isColBreak", false);
        cs.dedupe = get_bool(*it, "dedupe", false);
        cs.is_paging = get_bool(*it, "isPaging", false);

        auto lsr = get_str_array(*it, "labelStyleRef");
        if (!lsr.empty()) cs.label_style_ref = lsr[0];

        // Parse format sub-object
        if (it->contains("format") && (*it)["format"].is_object()) {
            const auto& fmt = (*it)["format"];
            cs.format.type = get_opt_str(fmt, "type");
            cs.format.format = get_opt_str(fmt, "format");
            cs.format.missings = get_opt_str(fmt, "missings");
            cs.format.col_width_raw = get_opt_str(fmt, "colWidth");
            auto vsr = get_str_array(fmt, "valueStyleRef");
            if (!vsr.empty()) cs.format.value_style_ref = vsr[0];
        }

        cols.push_back(std::move(cs));
    }
    // Sort by colOrder
    std::sort(cols.begin(), cols.end(),
              [](const ColumnSpec& a, const ColumnSpec& b) { return a.col_order < b.col_order; });
    // Invisible columns are kept in the vector so that grouping/paging
    // columns (isGrouping, isPaging) still participate in #ByGroupX
    // resolution and group-boundary detection even when hidden.
    // Rendering code checks is_visible to skip them in visual output.
    return cols;
}

// ---------------------------------------------------------------------------
// Parse styleRows (array of JSON strings -> RowActionSet)
// ---------------------------------------------------------------------------

static RowActionSet parse_row_action_set(const std::string& json_str) {
    RowActionSet ras;
    if (json_str.empty() || json_str == "{}") return ras;

    json j;
    try {
        j = json::parse(json_str);
    } catch (const json::parse_error& e) {
        throw RenderError("Failed to parse styleRows entry: " + std::string(e.what()));
    }

    // style actions
    if (j.contains("style") && j["style"].is_array()) {
        for (const auto& item : j["style"]) {
            StyleAction sa;
            sa.cols = get_str_array(item, "cols");
            sa.style_ref = get_str(item, "styleRef");
            ras.styles.push_back(std::move(sa));
        }
    }

    // clear actions
    if (j.contains("clear") && j["clear"].is_array()) {
        for (const auto& item : j["clear"]) {
            ClearAction ca;
            ca.cols = get_str_array(item, "cols");
            ras.clears.push_back(std::move(ca));
        }
    }

    // merge actions
    if (j.contains("merge") && j["merge"].is_array()) {
        for (const auto& item : j["merge"]) {
            MergeAction ma;
            ma.cols = get_str_array(item, "cols");
            ma.style_ref = get_opt_str(item, "styleRef");
            ras.merges.push_back(std::move(ma));
        }
    }

    // add_row actions
    if (j.contains("add_row") && j["add_row"].is_array()) {
        for (const auto& item : j["add_row"]) {
            AddRowAction ara;
            auto pos = get_str(item, "pos");
            ara.pos = (pos == "above") ? AddRowAction::Position::Above : AddRowAction::Position::Below;
            ara.value_from = get_str(item, "value_from");
            ara.style_ref = get_opt_str(item, "styleRef");
            ras.add_rows.push_back(std::move(ara));
        }
    }

    // glue actions
    if (j.contains("glue") && j["glue"].is_array()) {
        for (const auto& item : j["glue"]) {
            GlueAction ga;
            ga.cols      = get_str_array(item, "cols");
            ga.position  = get_str(item, "position");
            ga.glue_col  = get_opt_str(item, "glue_col");
            ga.text      = get_opt_str(item, "text");
            ga.separator = get_str(item, "separator");
            ras.glues.push_back(std::move(ga));
        }
    }

    // page_break actions
    if (j.contains("page_break") && j["page_break"].is_array()) {
        for (size_t i = 0; i < j["page_break"].size(); ++i) {
            ras.page_breaks.push_back(PageBreakAction{});
        }
    }

    return ras;
}

static std::vector<RowActionSet> parse_style_rows(const json& j) {
    std::vector<RowActionSet> result;
    if (j.is_null() || !j.is_array()) return result;
    for (const auto& item : j) {
        if (item.is_string()) {
            result.push_back(parse_row_action_set(item.get<std::string>()));
        } else {
            result.push_back(RowActionSet{}); // empty actions for non-string entries
        }
    }
    return result;
}

// ---------------------------------------------------------------------------
// Parse DocumentInfo
// ---------------------------------------------------------------------------

static DocumentInfo parse_document_info(const json& j) {
    DocumentInfo di;
    auto dt = get_str(j, "docType");
    if (dt == "Table")       di.doc_type = DocType::Table;
    else if (dt == "Figure") di.doc_type = DocType::Figure;
    else if (dt == "Text")   di.doc_type = DocType::Text;

    di.has_data = get_bool(j, "hasData", true);
    di.glue_num_type = get_bool(j, "glueNumType", false);

    di.doc_order = get_int(j, "docOrder", 0);
    di.is_continues = get_bool(j, "isContinues", false);
    // footnotePlace: "doc_footer" | "repeated" | "last_page" (default "repeated")
    auto fp = get_str(j, "footnotePlace");
    if (fp == "doc_footer")       di.footnote_place = FootnotePlace::DocFooter;
    else if (fp == "last_page")   di.footnote_place = FootnotePlace::LastPage;
    else                          di.footnote_place = FootnotePlace::Repeated;

    di.content_width_raw = get_opt_str(j, "contentWidth");

    return di;
}

static FigureInfo parse_figure_info(const json& j) {
    FigureInfo fi;
    fi.width = get_opt_str(j, "width");
    fi.height = get_opt_str(j, "height");
    fi.aspect_ratio = get_opt_dbl(j, "aspectRatio");
    auto sm = get_opt_str(j, "figureScaleMode");
    if (sm.has_value()) fi.scale_mode = *sm;
    auto dev = get_opt_str(j, "device");
    if (dev.has_value()) fi.device = *dev;
    return fi;
}

// ---------------------------------------------------------------------------
// Parse a single TFLSpec
// ---------------------------------------------------------------------------

static TFLSpec parse_single_spec(const std::string& key, const json& j) {
    TFLSpec spec;
    spec.key = key;

    // Document
    if (j.contains("document") && j["document"].is_object())
        spec.document = parse_document_info(j["document"]);

    // Attribs
    if (j.contains("attribs") && j["attribs"].is_object()) {
        const auto& attribs = j["attribs"];

        // documentStyle.page
        if (attribs.contains("documentStyle") && attribs["documentStyle"].is_object()) {
            const auto& ds = attribs["documentStyle"];
            if (ds.contains("page") && ds["page"].is_object()) {
                spec.page_override = parse_page_config(ds["page"]);
                spec.has_page_override = true;
                if (ds["page"].contains("margins") && ds["page"]["margins"].is_object()) {
                    spec.margin_overrides = parse_margins_override(ds["page"]["margins"]);
                }
            }
        }

        // styles
        if (attribs.contains("styles") && attribs["styles"].is_object())
            spec.spec_styles = parse_style_map(attribs["styles"]);
    }

    // Headers / footers
    if (j.contains("headers"))
        spec.headers = parse_header_footer(j["headers"]);
    if (j.contains("footers"))
        spec.footers = parse_header_footer(j["footers"]);

    // Stub columns
    if (j.contains("stubColumns"))
        spec.stub_columns = parse_stub_columns(j["stubColumns"]);

    // Columns
    if (j.contains("columns"))
        spec.columns = parse_columns(j["columns"]);

    // StyleRows
    if (j.contains("styleRows"))
        spec.style_rows = parse_style_rows(j["styleRows"]);

    // Text groups
    if (j.contains("titles"))
        spec.titles = parse_text_groups(j["titles"]);
    if (j.contains("subtitles"))
        spec.subtitles = parse_text_groups(j["subtitles"]);
    if (j.contains("footnotes"))
        spec.footnotes = parse_text_groups(j["footnotes"]);
    if (j.contains("bodyText"))
        spec.body_text = parse_text_groups(j["bodyText"]);

    // DataRef
    auto refs = get_str_array(j, "dataRef");
    if (!refs.empty()) spec.data_ref = refs[0];

    // Figure properties
    if (j.contains("figure") && j["figure"].is_object()) {
        spec.figure = parse_figure_info(j["figure"]);
    }

    return spec;
}

// ---------------------------------------------------------------------------
// Parse complete spec JSON
// ---------------------------------------------------------------------------

static TFLDocument parse_spec_internal(const json& root) {
    TFLDocument doc;

    // _metadata
    if (root.contains("_metadata") && root["_metadata"].is_object()) {
        const auto& meta = root["_metadata"];
        doc.metadata.out_dir       = get_str(meta, "outDir");
        doc.metadata.doc_file_name = get_str(meta, "docFileName");
        doc.metadata.datetime      = get_str(meta, "datetime");
        doc.metadata.insert_toc    = get_bool(meta, "insertTOC", false);
        auto tt = get_opt_str(meta, "tocTitle");
        if (tt.has_value()) doc.metadata.toc_title = *tt;
    }

    // Parse each spec entry (keys matching pattern ^[A-Za-z0-9]..._[a-f0-9]{16}$)
    for (auto it = root.begin(); it != root.end(); ++it) {
        if (it.key() == "_metadata") continue;
        if (!it->is_object()) continue;
        TFLSpec spec = parse_single_spec(it.key(), *it);
        doc.specs.push_back(std::move(spec));
    }

    // Sort specs by docOrder
    std::sort(doc.specs.begin(), doc.specs.end(),
              [](const TFLSpec& a, const TFLSpec& b) {
                  return a.document.doc_order < b.document.doc_order;
              });

    return doc;
}

TFLDocument parse_spec_json(const std::string& json_path) {
    json root = read_json_file(json_path);
    return parse_spec_internal(root);
}

TFLDocument parse_spec_json_string(const std::string& json_str) {
    json root;
    try {
        root = json::parse(json_str);
    } catch (const json::parse_error& e) {
        throw RenderError("JSON parse error: " + std::string(e.what()));
    }
    return parse_spec_internal(root);
}

// ---------------------------------------------------------------------------
// Parse StylesTemplate
// ---------------------------------------------------------------------------

static StylesTemplate parse_template_internal(const json& root) {
    StylesTemplate tmpl;

    // document.page
    if (root.contains("document") && root["document"].is_object()) {
        const auto& doc = root["document"];
        if (doc.contains("page") && doc["page"].is_object())
            tmpl.page = parse_page_config(doc["page"]);
        if (doc.contains("paragraphDefaults") && doc["paragraphDefaults"].is_object()) {
            tmpl.widow_control = get_opt_bool(doc["paragraphDefaults"], "widow_control");
        }
    }

    // textStyles
    if (root.contains("textStyles") && root["textStyles"].is_object()) {
        const auto& ts = root["textStyles"];
        if (ts.contains("default"))     tmpl.text_styles.default_style = parse_text_style(ts["default"]);
        if (ts.contains("docHeader"))   tmpl.text_styles.doc_header    = parse_text_style(ts["docHeader"]);
        if (ts.contains("docFooter"))   tmpl.text_styles.doc_footer    = parse_text_style(ts["docFooter"]);
        if (ts.contains("titles"))      tmpl.text_styles.titles        = parse_text_style(ts["titles"]);
        if (ts.contains("subtitles"))   tmpl.text_styles.subtitles     = parse_text_style(ts["subtitles"]);
        if (ts.contains("footnotes"))   tmpl.text_styles.footnotes     = parse_text_style(ts["footnotes"]);
        if (ts.contains("tableHeader")) tmpl.text_styles.table_header  = parse_text_style(ts["tableHeader"]);
        if (ts.contains("tableBody"))   tmpl.text_styles.table_body    = parse_text_style(ts["tableBody"]);
        if (ts.contains("tocTitle"))    tmpl.text_styles.toc_title     = parse_text_style(ts["tocTitle"]);
        if (ts.contains("tocEntry"))    tmpl.text_styles.toc_entry     = parse_text_style(ts["tocEntry"]);
        if (ts.contains("figureCaption")) tmpl.text_styles.figure_caption = parse_text_style(ts["figureCaption"]);
    }

    // tableStyle
    if (root.contains("tableStyle") && root["tableStyle"].is_object()) {
        const auto& tbl = root["tableStyle"];

        // layout
        if (tbl.contains("layout") && tbl["layout"].is_object()) {
            const auto& layout = tbl["layout"];
            auto ta = get_opt_str(layout, "table_alignment");
            if (ta.has_value()) {
                if (*ta == "center")      tmpl.table_style.table_alignment = Alignment::Center;
                else if (*ta == "right")  tmpl.table_style.table_alignment = Alignment::Right;
                else if (*ta == "left")   tmpl.table_style.table_alignment = Alignment::Left;
            }
        }

        // structural
        if (tbl.contains("structural") && tbl["structural"].is_object()) {
            const auto& struc = tbl["structural"];
            if (struc.contains("allHeaders") && struc["allHeaders"].is_object()) {
                StyleDef ahsd;
                ahsd.table_style = parse_table_cell_props(struc["allHeaders"]);
                tmpl.table_style.structural.all_headers = ahsd;
            }
            if (struc.contains("tableBody") && struc["tableBody"].is_object()) {
                StyleDef tbsd;
                tbsd.table_style = parse_table_cell_props(struc["tableBody"]);
                tmpl.table_style.structural.table_body = tbsd;
            }
            // structural borders
            if (struc.contains("header_top_border") && struc["header_top_border"].is_object()) {
                tmpl.table_style.structural.header_top_border = parse_border(struc["header_top_border"]);
            }
            if (struc.contains("header_bottom_border") && struc["header_bottom_border"].is_object()) {
                tmpl.table_style.structural.header_bottom_border = parse_border(struc["header_bottom_border"]);
            }
            if (struc.contains("table_bottom_border") && struc["table_bottom_border"].is_object()) {
                tmpl.table_style.structural.table_bottom_border = parse_border(struc["table_bottom_border"]);
            }
        }

        // header row defaults
        if (tbl.contains("header") && tbl["header"].is_object()) {
            const auto& hdr = tbl["header"];
            if (hdr.contains("row") && hdr["row"].is_object()) {
                StyleDef hrd;
                hrd.table_style = parse_table_cell_props(hdr["row"]);
                tmpl.table_style.header_row = hrd;
            }
        }

        // body row defaults
        if (tbl.contains("body") && tbl["body"].is_object()) {
            const auto& body = tbl["body"];
            if (body.contains("row") && body["row"].is_object()) {
                StyleDef brd;
                brd.table_style = parse_table_cell_props(body["row"]);
                tmpl.table_style.body_row = brd;
            }
        }

        // cellDefaults
        if (tbl.contains("cellDefaults") && tbl["cellDefaults"].is_object()) {
            const auto& cd = tbl["cellDefaults"];
            if (cd.contains("cell_margins") && cd["cell_margins"].is_object()) {
                const auto& cm = cd["cell_margins"];
                auto mt = get_opt_str(cm, "top");
                if (mt.has_value()) tmpl.table_style.default_cell_margin_top = Length::parse(*mt);
                auto mb = get_opt_str(cm, "bottom");
                if (mb.has_value()) tmpl.table_style.default_cell_margin_bottom = Length::parse(*mb);
                auto ml = get_opt_str(cm, "left");
                if (ml.has_value()) tmpl.table_style.default_cell_margin_left = Length::parse(*ml);
                auto mr = get_opt_str(cm, "right");
                if (mr.has_value()) tmpl.table_style.default_cell_margin_right = Length::parse(*mr);
            }
        }

        // figureStyle
        if (root.contains("figureStyle") && root["figureStyle"].is_object()) {
            const auto& fig = root["figureStyle"];

            if (fig.contains("layout") && fig["layout"].is_object()) {
                const auto& layout = fig["layout"];
                auto a = get_opt_str(layout, "alignment");
                if (a.has_value()) {
                    if (*a == "center") tmpl.figure_style.alignment = Alignment::Center;
                    else if (*a == "right") tmpl.figure_style.alignment = Alignment::Right;
                    else if (*a == "left") tmpl.figure_style.alignment = Alignment::Left;
                }

                auto sb = get_opt_str(layout, "space_before");
                if (sb.has_value()) tmpl.figure_style.space_before = Length::parse(*sb);
                auto sa = get_opt_str(layout, "space_after");
                if (sa.has_value()) tmpl.figure_style.space_after = Length::parse(*sa);
            }

            if (fig.contains("caption") && fig["caption"].is_object()) {
                const auto& cap = fig["caption"];
                auto p = get_opt_str(cap, "position");
                if (p.has_value()) tmpl.figure_style.caption_position = *p;
                auto sr = get_opt_str(cap, "textStyleRef");
                if (sr.has_value()) tmpl.figure_style.caption_text_style_ref = *sr;
            }
        }
    }

    return tmpl;
}

StylesTemplate parse_template_json(const std::string& json_path) {
    json root = read_json_file(json_path);
    return parse_template_internal(root);
}

StylesTemplate parse_template_json_string(const std::string& json_str) {
    json root;
    try {
        root = json::parse(json_str);
    } catch (const json::parse_error& e) {
        throw RenderError("Template JSON parse error: " + std::string(e.what()));
    }
    return parse_template_internal(root);
}

// ---------------------------------------------------------------------------
// Parse Data JSON (column-oriented)
// ---------------------------------------------------------------------------

static DataTable parse_data_internal(const json& root) {
    DataTable dt;
    for (auto it = root.begin(); it != root.end(); ++it) {
        if (!it->is_array()) continue;
        const std::string& col_name = it.key();
        dt.col_names.push_back(col_name);
        std::vector<std::string> values;
        for (const auto& val : *it) {
            if (val.is_string()) {
                values.push_back(val.get<std::string>());
            } else if (val.is_null()) {
                values.push_back("");
            } else if (val.is_number()) {
                if (val.is_number_integer()) {
                    values.push_back(std::to_string(val.get<int64_t>()));
                } else {
                    values.push_back(std::to_string(val.get<double>()));
                }
            } else if (val.is_boolean()) {
                values.push_back(val.get<bool>() ? "TRUE" : "FALSE");
            } else {
                values.push_back(val.dump());
            }
        }
        dt.columns[col_name] = std::move(values);
        if (dt.n_rows == 0 && !dt.columns[col_name].empty()) {
            dt.n_rows = dt.columns[col_name].size();
        }
    }

    // Validate that all columns have the same length (detect ragged data)
    for (const auto& col_name : dt.col_names) {
        auto col_it = dt.columns.find(col_name);
        if (col_it != dt.columns.end() && col_it->second.size() != dt.n_rows) {
            Rcpp::Rcerr << "[ksTFL] WARNING: Column '" << col_name
                      << "' has " << col_it->second.size()
                      << " rows but expected " << dt.n_rows
                      << ". Data may be ragged.\n";
        }
    }

    return dt;
}

DataTable parse_data_json(const std::string& json_path) {
    json root = read_json_file(json_path);
    return parse_data_internal(root);
}

DataTable parse_data_json_string(const std::string& json_str) {
    json root;
    try {
        root = json::parse(json_str);
    } catch (const json::parse_error& e) {
        throw RenderError("Data JSON parse error: " + std::string(e.what()));
    }
    return parse_data_internal(root);
}

}  // namespace kstfl
