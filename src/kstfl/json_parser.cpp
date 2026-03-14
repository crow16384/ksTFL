// kstfl/json_parser.cpp — Parse spec JSON, template JSON, data JSON
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "json_parser.h"
#include <Rcpp.h>
#include <algorithm>
#include <cstdio>
#include <fstream>
#include <nlohmann/json.hpp>
#include <string_view>
#include <unordered_map>

using json = nlohmann::json;

namespace kstfl {

// ---------------------------------------------------------------------------
// Helpers: safe JSON accessors
// ---------------------------------------------------------------------------

namespace jutil {

/// Type-strict check — nlohmann has no generic is<T>().
template <typename T> bool is_type(const json &v) {
  if constexpr (std::is_same_v<T, std::string>)
    return v.is_string();
  else if constexpr (std::is_same_v<T, std::string_view>)
    return v.is_string();
  else if constexpr (std::is_same_v<T, bool>)
    return v.is_boolean();
  else if constexpr (std::is_same_v<T, int>)
    return v.is_number_integer();
  else if constexpr (std::is_same_v<T, double>)
    return v.is_number();
  else
    static_assert(!sizeof(T), "Unsupported type for jutil");
}

/// Get JSON value with default (null-safe, type-strict).
template <typename T>
T get(const json &j, const std::string &key, const T &def = T{}) {
  auto it = j.find(key);

  if (it == j.end() || it->is_null())
    return def;

  if (!is_type<T>(*it))
    return def;

  return it->template get<T>();
}

/// Get optional JSON value (nullopt if missing, null, or wrong type).
template <typename T>
std::optional<T> opt(const json &j, const std::string &key) {
  auto it = j.find(key);

  if (it == j.end() || it->is_null())
    return std::nullopt;

  if (!is_type<T>(*it))
    return std::nullopt;

  return it->template get<T>();
}

/// Get array of T (items of wrong type are silently skipped).
template <typename T>
std::vector<T> get_array(const json &j, const std::string &key) {
  std::vector<T> result;

  auto it = j.find(key);
  if (it == j.end() || !it->is_array())
    return result;

  for (const auto &item : *it) {
    if (is_type<T>(item))
      result.push_back(item.template get<T>());
  }

  return result;
}

} // namespace jutil

/// Read a JSON file to nlohmann::json.
static json read_json_file(const std::string &path) {
  std::ifstream file(path);
  if (!file.is_open()) {
    throw RenderError("Cannot open JSON file: " + path);
  }
  json j;
  try {
    file >> j;
  } catch (const json::parse_error &e) {
    throw RenderError("JSON parse error in '" + path + "': " + e.what());
  }
  return j;
}

// ---------------------------------------------------------------------------
// Parse Border
// ---------------------------------------------------------------------------

static Border parse_border(const json &j) {
  Border b;
  auto c = jutil::opt<std::string>(j, "color");
  if (c.has_value())
    b.color = Color::parse(*c);

  auto w = jutil::opt<std::string>(j, "width");
  if (w.has_value())
    b.width = Length::parse(*w);

  auto ls = jutil::opt<std::string_view>(j, "line_style");

  static const std::unordered_map<std::string_view, BorderLineStyle> map{
      {"none", BorderLineStyle::None},     {"single", BorderLineStyle::Single},
      {"double", BorderLineStyle::Double}, {"dashed", BorderLineStyle::Dashed},
      {"dotted", BorderLineStyle::Dotted}, {"thick", BorderLineStyle::Thick}};

  if (ls.has_value()) {
    auto it = map.find(*ls);
    b.line_style = (it != map.end()) ? it->second : BorderLineStyle::Single;
  }

  return b;
}

static Borders parse_borders(const json &j) {
  Borders borders;

  static const std::array<
      std::pair<const char *, std::optional<Border> Borders::*>, 6>
      border_map{{{"top", &Borders::top},
                  {"bottom", &Borders::bottom},
                  {"left", &Borders::left},
                  {"right", &Borders::right},
                  {"insideH", &Borders::insideH},
                  {"insideV", &Borders::insideV}}};

  for (const auto &[key, member] : border_map) {
    auto it = j.find(key);
    if (it != j.end() && it->is_object()) {
      borders.*member = parse_border(*it);
    }
  }

  return borders;
}

// ---------------------------------------------------------------------------
// Parse Font properties
// ---------------------------------------------------------------------------

static FontProps parse_font_props(const json &j) {
  FontProps fp;
  fp.font_name = jutil::opt<std::string>(j, "font_name");

  // font_size can be "9pt" or just a number
  auto fs = jutil::opt<std::string>(j, "font_size");
  if (fs.has_value()) {
    // Strip "pt" and parse as double
    std::string s = *fs;
    if (s.ends_with("pt")) {
      s.resize(s.size() - 2);
    }
    try {
      size_t idx = 0;
      double val = std::stod(s, &idx);
      if (idx != s.size()) {
        throw RenderError("Invalid font_size: '" + *fs +
                          "' — unexpected characters after number");
      }
      fp.font_size = val;
    } catch (const RenderError &) {
      throw;
    } catch (const std::exception &) {
      throw RenderError("Invalid font_size: '" + *fs + "'");
    }
  }

  fp.bold = jutil::opt<bool>(j, "bold");
  fp.italic = jutil::opt<bool>(j, "italic");
  fp.underline = jutil::opt<bool>(j, "underline");

  auto c = jutil::opt<std::string>(j, "color");
  if (c.has_value())
    fp.color = Color::parse(*c);

  auto h = jutil::opt<std::string>(j, "highlight");
  if (h.has_value())
    fp.highlight = Color::parse(*h);

  return fp;
}

// ---------------------------------------------------------------------------
// Parse Spacing / Indent / Paragraph
// ---------------------------------------------------------------------------

static SpacingProps parse_spacing(const json &j) {
  SpacingProps sp;
  auto b = jutil::opt<std::string>(j, "before");
  if (b.has_value())
    sp.before = Length::parse(*b);
  auto a = jutil::opt<std::string>(j, "after");
  if (a.has_value())
    sp.after = Length::parse(*a);
  sp.line_spacing_multiplier = jutil::opt<double>(j, "line_spacing");
  return sp;
}

static IndentProps parse_indents(const json &j) {
  IndentProps ip;
  auto l = jutil::opt<std::string>(j, "left");
  if (l.has_value())
    ip.left = Length::parse(*l);
  auto r = jutil::opt<std::string>(j, "right");
  if (r.has_value())
    ip.right = Length::parse(*r);
  auto fl = jutil::opt<std::string>(j, "first_line");
  if (fl.has_value())
    ip.first_line = Length::parse(*fl);
  return ip;
}

static Alignment parse_alignment(const std::string &s) {
  static const std::unordered_map<std::string_view, Alignment> map{
      {"left", Alignment::Left},
      {"center", Alignment::Center},
      {"right", Alignment::Right},
      {"justify", Alignment::Justify},
      {"distributed", Alignment::Justify}};
  auto it = map.find(s);
  return (it != map.end()) ? it->second : Alignment::Left;
}

static ParagraphProps parse_paragraph_props(const json &j) {
  ParagraphProps pp;
  auto align = jutil::opt<std::string>(j, "alignment");
  if (align.has_value())
    pp.alignment = parse_alignment(*align);
  if (j.contains("spacing") && j["spacing"].is_object())
    pp.spacing = parse_spacing(j["spacing"]);
  if (j.contains("indents") && j["indents"].is_object())
    pp.indents = parse_indents(j["indents"]);
  pp.widow_control = jutil::opt<bool>(j, "widow_control");
  pp.keep_next = jutil::opt<bool>(j, "keep_next");
  pp.keep_lines = jutil::opt<bool>(j, "keep_lines");
  return pp;
}

// ---------------------------------------------------------------------------
// Parse Table Cell Props
// ---------------------------------------------------------------------------

static VerticalAlignment parse_valign(const std::string &s) {
  static const std::unordered_map<std::string_view, VerticalAlignment> map{
      {"top", VerticalAlignment::Top},
      {"center", VerticalAlignment::Center},
      {"bottom", VerticalAlignment::Bottom}};
  auto it = map.find(s);
  return (it != map.end()) ? it->second : VerticalAlignment::Center;
}

static TextOrientation parse_text_orient(const std::string &s) {
  static const std::unordered_map<std::string_view, TextOrientation> map{
      {"horizontal", TextOrientation::Horizontal},
      {"vertical_90", TextOrientation::BottomToTop},
      {"btLr", TextOrientation::BottomToTop},
      {"vertical_270", TextOrientation::TopToBottom},
      {"tbRl", TextOrientation::TopToBottom}};
  auto it = map.find(s);
  return (it != map.end()) ? it->second : TextOrientation::Horizontal;
}

static TableCellProps parse_table_cell_props(const json &j) {
  TableCellProps tcp;
  auto bg = jutil::opt<std::string>(j, "background_color");
  if (bg.has_value())
    tcp.background_color = Color::parse(*bg);

  auto rh = jutil::opt<std::string>(j, "row_height");
  if (rh.has_value() && *rh != "auto")
    tcp.row_height = Length::parse(*rh);

  auto va = jutil::opt<std::string>(j, "vertical_alignment");
  if (va.has_value())
    tcp.vertical_alignment = parse_valign(*va);

  auto to = jutil::opt<std::string>(j, "text_orientation");
  if (to.has_value())
    tcp.text_orientation = parse_text_orient(*to);

  if (j.contains("borders") && j["borders"].is_object())
    tcp.borders = parse_borders(j["borders"]);

  // Cell margins
  if (j.contains("cell_margins") && j["cell_margins"].is_object()) {
    const auto &cm = j["cell_margins"];
    auto mt = jutil::opt<std::string>(cm, "top");
    if (mt.has_value())
      tcp.cell_margin_top = Length::parse(*mt);
    auto mb = jutil::opt<std::string>(cm, "bottom");
    if (mb.has_value())
      tcp.cell_margin_bottom = Length::parse(*mb);
    auto ml = jutil::opt<std::string>(cm, "left");
    if (ml.has_value())
      tcp.cell_margin_left = Length::parse(*ml);
    auto mr = jutil::opt<std::string>(cm, "right");
    if (mr.has_value())
      tcp.cell_margin_right = Length::parse(*mr);
  }

  return tcp;
}

// ---------------------------------------------------------------------------
// Parse StyleDef (composite: font + paragraph + table_style)
// ---------------------------------------------------------------------------

static StyleDef parse_style_def(const json &j) {
  StyleDef sd;
  if (j.contains("font") && j["font"].is_object())
    sd.font = parse_font_props(j["font"]);
  if (j.contains("paragraph") && j["paragraph"].is_object())
    sd.paragraph = parse_paragraph_props(j["paragraph"]);
  if (j.contains("table_style") && j["table_style"].is_object())
    sd.table_style = parse_table_cell_props(j["table_style"]);
  return sd;
}

/// Parse a text style from template (has word_style + paragraph + font
/// structure).
static StyleDef parse_text_style(const json &j) {
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

static PageSize parse_page_size(const std::string &s) {
  static const std::unordered_map<std::string_view, PageSize> map{
      {"A4", PageSize::A4},
      {"A3", PageSize::A3},
      {"Letter", PageSize::Letter},
      {"Legal", PageSize::Legal},
      {"Executive", PageSize::Executive}};
  auto it = map.find(s);
  return (it != map.end()) ? it->second : PageSize::A4;
}

static Orientation parse_orientation(const std::string &s) {
  static const std::unordered_map<std::string_view, Orientation> map{
      {"portrait", Orientation::Portrait},
      {"landscape", Orientation::Landscape}};
  auto it = map.find(s);
  return (it != map.end()) ? it->second : Orientation::Landscape;
}

static PageMargins parse_margins(const json &j) {
  PageMargins m;
  auto top = jutil::opt<std::string>(j, "top");
  if (top.has_value())
    m.top = Length::parse(*top);
  auto bot = jutil::opt<std::string>(j, "bottom");
  if (bot.has_value())
    m.bottom = Length::parse(*bot);
  auto left = jutil::opt<std::string>(j, "left");
  if (left.has_value())
    m.left = Length::parse(*left);
  auto right = jutil::opt<std::string>(j, "right");
  if (right.has_value())
    m.right = Length::parse(*right);
  auto hdr = jutil::opt<std::string>(j, "header");
  if (hdr.has_value())
    m.header_distance = Length::parse(*hdr);
  auto ftr = jutil::opt<std::string>(j, "footer");
  if (ftr.has_value())
    m.footer_distance = Length::parse(*ftr);
  return m;
}

static PageMarginsOverride parse_margins_override(const json &j) {
  PageMarginsOverride m;
  auto top = jutil::opt<std::string>(j, "top");
  if (top.has_value())
    m.top = Length::parse(*top);
  auto bot = jutil::opt<std::string>(j, "bottom");
  if (bot.has_value())
    m.bottom = Length::parse(*bot);
  auto left = jutil::opt<std::string>(j, "left");
  if (left.has_value())
    m.left = Length::parse(*left);
  auto right = jutil::opt<std::string>(j, "right");
  if (right.has_value())
    m.right = Length::parse(*right);
  auto hdr = jutil::opt<std::string>(j, "header");
  if (hdr.has_value())
    m.header_distance = Length::parse(*hdr);
  auto ftr = jutil::opt<std::string>(j, "footer");
  if (ftr.has_value())
    m.footer_distance = Length::parse(*ftr);
  return m;
}

static PageConfig parse_page_config(const json &j) {
  PageConfig pc;
  auto sz = jutil::opt<std::string>(j, "size");
  if (sz.has_value())
    pc.size = parse_page_size(*sz);
  auto orient = jutil::opt<std::string>(j, "orientation");
  if (orient.has_value())
    pc.orientation = parse_orientation(*orient);
  if (j.contains("margins") && j["margins"].is_object())
    pc.margins = parse_margins(j["margins"]);
  return pc;
}

// ---------------------------------------------------------------------------
// Parse StyleMap (attribs.styles)
// ---------------------------------------------------------------------------

static StyleMap parse_style_map(const json &j) {
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

static std::vector<TextGroup> parse_text_groups(const json &j) {
  std::vector<TextGroup> groups;
  if (j.is_null())
    return groups;
  for (auto it = j.begin(); it != j.end(); ++it) {
    if (!it->is_object())
      continue;
    TextGroup tg;
    tg.text = jutil::get_array<std::string>(*it, "text");
    tg.order = jutil::get<int>(*it, "order", 0);
    tg.style_refs = jutil::get_array<std::string>(*it, "styleRef");
    int toc = jutil::get<int>(*it, "toclevel", 0);
    if (toc >= 1 && toc <= 9)
      tg.toc_level = toc;
    groups.push_back(std::move(tg));
  }
  // Sort by order
  std::sort(
      groups.begin(), groups.end(),
      [](const TextGroup &a, const TextGroup &b) { return a.order < b.order; });
  return groups;
}

// ---------------------------------------------------------------------------
// Parse Headers / Footers (arrays of 3-element string arrays)
// ---------------------------------------------------------------------------

static std::vector<HeaderFooterRow> parse_header_footer(const json &j) {
  std::vector<HeaderFooterRow> rows;
  if (j.is_null() || !j.is_array())
    return rows;
  int order = 0;
  for (const auto &row : j) {
    if (!row.is_array())
      continue;
    HeaderFooterRow hfr;
    hfr.order = order++;
    // Placement rule:
    //   1 value  → left only
    //   2 values → left + right (center empty)
    //   3 values → left + center + right
    if (row.size() == 1 && row[0].is_string()) {
      hfr.left = row[0].get<std::string>();
    } else if (row.size() == 2) {
      if (row[0].is_string())
        hfr.left = row[0].get<std::string>();
      if (row[1].is_string())
        hfr.right = row[1].get<std::string>();
    } else if (row.size() >= 3) {
      if (row[0].is_string())
        hfr.left = row[0].get<std::string>();
      if (row[1].is_string())
        hfr.center = row[1].get<std::string>();
      if (row[2].is_string())
        hfr.right = row[2].get<std::string>();
    }
    rows.push_back(std::move(hfr));
  }
  return rows;
}

// ---------------------------------------------------------------------------
// Parse StubColumns
// ---------------------------------------------------------------------------

static std::vector<StubColumn> parse_stub_columns(const json &j) {
  std::vector<StubColumn> stubs;
  if (j.is_null())
    return stubs;
  for (auto it = j.begin(); it != j.end(); ++it) {
    if (!it->is_object())
      continue;
    StubColumn sc;
    // Label may be a string or an array of strings (joined with <br>).
    if (it->contains("label") && !(*it)["label"].is_null()) {
      if ((*it)["label"].is_string()) {
        sc.label = (*it)["label"].get<std::string>();
      } else if ((*it)["label"].is_array()) {
        std::string combined;
        for (const auto &elem : (*it)["label"]) {
          if (elem.is_string()) {
            if (!combined.empty())
              combined += "<br>";
            combined += elem.get<std::string>();
          }
        }
        sc.label = combined;
      }
    }
    sc.stub_order = jutil::get<int>(*it, "stubOrder", 0);
    sc.cols = jutil::get_array<std::string>(*it, "cols");
    auto lsr = jutil::get_array<std::string>(*it, "labelStyleRef");
    if (!lsr.empty())
      sc.label_style_ref = lsr[0];
    stubs.push_back(std::move(sc));
  }
  // Sort by stubOrder (descending for depth)
  std::sort(stubs.begin(), stubs.end(),
            [](const StubColumn &a, const StubColumn &b) {
              return a.stub_order > b.stub_order;
            });
  return stubs;
}

// ---------------------------------------------------------------------------
// Parse Columns
// ---------------------------------------------------------------------------

static std::vector<ColumnSpec> parse_columns(const json &j) {
  std::vector<ColumnSpec> cols;
  if (j.is_null())
    return cols;
  for (auto it = j.begin(); it != j.end(); ++it) {
    if (!it->is_object())
      continue;
    ColumnSpec cs;
    cs.id = it.key();
    cs.col_order = jutil::get<int>(*it, "colOrder", 0);
    cs.label = jutil::get<std::string>(*it, "label");
    cs.is_id = jutil::get<bool>(*it, "isID", false);
    cs.is_visible = jutil::get<bool>(*it, "isVisible", true);
    cs.is_grouping = jutil::get<bool>(*it, "isGrouping", false);
    cs.is_col_break = jutil::get<bool>(*it, "isColBreak", false);
    cs.dedupe = jutil::get<bool>(*it, "dedupe", false);
    cs.is_paging = jutil::get<bool>(*it, "isPaging", false);

    auto lsr = jutil::get_array<std::string>(*it, "labelStyleRef");
    if (!lsr.empty())
      cs.label_style_ref = lsr[0];

    // Parse format sub-object
    if (it->contains("format") && (*it)["format"].is_object()) {
      const auto &fmt = (*it)["format"];
      cs.format.type = jutil::opt<std::string>(fmt, "type");
      cs.format.format = jutil::opt<std::string>(fmt, "format");
      cs.format.missings = jutil::opt<std::string>(fmt, "missings");
      cs.format.col_width_raw = jutil::opt<std::string>(fmt, "colWidth");
      auto vsr = jutil::get_array<std::string>(fmt, "valueStyleRef");
      if (!vsr.empty())
        cs.format.value_style_ref = vsr[0];
    }

    cols.push_back(std::move(cs));
  }
  // Sort by colOrder
  std::sort(cols.begin(), cols.end(),
            [](const ColumnSpec &a, const ColumnSpec &b) {
              return a.col_order < b.col_order;
            });
  // Invisible columns are kept in the vector so that grouping/paging
  // columns (isGrouping, isPaging) still participate in #ByGroupX
  // resolution and group-boundary detection even when hidden.
  // Rendering code checks is_visible to skip them in visual output.
  return cols;
}

// ---------------------------------------------------------------------------
// Parse styleRows (array of JSON strings -> RowActionSet)
// ---------------------------------------------------------------------------

static RowActionSet parse_row_action_set(const std::string &json_str) {
  RowActionSet ras;
  if (json_str.empty() || json_str == "{}")
    return ras;

  json j;
  try {
    j = json::parse(json_str);
  } catch (const json::parse_error &e) {
    throw RenderError("Failed to parse styleRows entry: " +
                      std::string(e.what()));
  }

  // style actions
  if (j.contains("style") && j["style"].is_array()) {
    for (const auto &item : j["style"]) {
      StyleAction sa;
      sa.cols = jutil::get_array<std::string>(item, "cols");
      sa.style_ref = jutil::get<std::string>(item, "styleRef");
      ras.styles.push_back(std::move(sa));
    }
  }

  // clear actions
  if (j.contains("clear") && j["clear"].is_array()) {
    for (const auto &item : j["clear"]) {
      ClearAction ca;
      ca.cols = jutil::get_array<std::string>(item, "cols");
      ras.clears.push_back(std::move(ca));
    }
  }

  // merge actions
  if (j.contains("merge") && j["merge"].is_array()) {
    for (const auto &item : j["merge"]) {
      MergeAction ma;
      ma.cols = jutil::get_array<std::string>(item, "cols");
      ma.style_ref = jutil::opt<std::string>(item, "styleRef");
      ras.merges.push_back(std::move(ma));
    }
  }

  // add_row actions
  if (j.contains("add_row") && j["add_row"].is_array()) {
    for (const auto &item : j["add_row"]) {
      AddRowAction ara;
      auto pos = jutil::get<std::string>(item, "pos");
      ara.pos = (pos == "above") ? AddRowAction::Position::Above
                                 : AddRowAction::Position::Below;
      ara.value_from = jutil::get<std::string>(item, "value_from");
      ara.style_ref = jutil::opt<std::string>(item, "styleRef");
      ras.add_rows.push_back(std::move(ara));
    }
  }

  // glue actions
  if (j.contains("glue") && j["glue"].is_array()) {
    for (const auto &item : j["glue"]) {
      GlueAction ga;
      ga.cols = jutil::get_array<std::string>(item, "cols");
      ga.position = jutil::get<std::string>(item, "position");
      ga.glue_col = jutil::opt<std::string>(item, "glue_col");
      ga.text = jutil::opt<std::string>(item, "text");
      ga.separator = jutil::get<std::string>(item, "separator");
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

static std::vector<RowActionSet> parse_style_rows(const json &j) {
  std::vector<RowActionSet> result;
  if (j.is_null() || !j.is_array())
    return result;
  for (const auto &item : j) {
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

static DocumentInfo parse_document_info(const json &j) {
  DocumentInfo di;
  auto dt = jutil::get<std::string>(j, "docType");
  if (dt == "Table")
    di.doc_type = DocType::Table;
  else if (dt == "Figure")
    di.doc_type = DocType::Figure;
  else if (dt == "Text")
    di.doc_type = DocType::Text;

  di.has_data = jutil::get<bool>(j, "hasData", true);
  di.glue_num_type = jutil::get<bool>(j, "glueNumType", false);

  di.doc_order = jutil::get<int>(j, "docOrder", 0);
  di.is_continues = jutil::get<bool>(j, "isContinues", false);
  // footnotePlace: "doc_footer" | "repeated" | "last_page" (default "repeated")
  auto fp = jutil::get<std::string>(j, "footnotePlace");
  if (fp == "doc_footer")
    di.footnote_place = FootnotePlace::DocFooter;
  else if (fp == "last_page")
    di.footnote_place = FootnotePlace::LastPage;
  else
    di.footnote_place = FootnotePlace::Repeated;

  di.content_width_raw = jutil::opt<std::string>(j, "contentWidth");
  auto top_el = jutil::opt<std::string>(j, "topEmptyLine");
  if (top_el.has_value())
    di.top_empty_line = Length::parse(*top_el);
  auto bottom_el = jutil::opt<std::string>(j, "bottomEmptyLine");
  if (bottom_el.has_value())
    di.bottom_empty_line = Length::parse(*bottom_el);

  return di;
}

static FigureInfo parse_figure_info(const json &j) {
  FigureInfo fi;
  fi.width = jutil::opt<std::string>(j, "width");
  fi.height = jutil::opt<std::string>(j, "height");
  auto sm = jutil::opt<std::string>(j, "figureScaleMode");
  if (sm.has_value())
    fi.scale_mode = *sm;
  auto dev = jutil::opt<std::string>(j, "device");
  if (dev.has_value())
    fi.device = *dev;
  return fi;
}

// ---------------------------------------------------------------------------
// Parse a single TFLSpec
// ---------------------------------------------------------------------------

static TFLSpec parse_single_spec(const std::string &key, const json &j) {
  TFLSpec spec;
  spec.key = key;

  // Document
  if (j.contains("document") && j["document"].is_object())
    spec.document = parse_document_info(j["document"]);

  // Attribs
  if (j.contains("attribs") && j["attribs"].is_object()) {
    const auto &attribs = j["attribs"];

    // documentStyle.page
    if (attribs.contains("documentStyle") &&
        attribs["documentStyle"].is_object()) {
      const auto &ds = attribs["documentStyle"];
      if (ds.contains("page") && ds["page"].is_object()) {
        spec.page_override = parse_page_config(ds["page"]);
        spec.has_page_override = true;
        if (ds["page"].contains("margins") &&
            ds["page"]["margins"].is_object()) {
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
  auto refs = jutil::get_array<std::string>(j, "dataRef");
  if (!refs.empty())
    spec.data_ref = refs[0];

  // Figure properties
  if (j.contains("figure") && j["figure"].is_object()) {
    spec.figure = parse_figure_info(j["figure"]);
  }

  return spec;
}

// ---------------------------------------------------------------------------
// Parse complete spec JSON
// ---------------------------------------------------------------------------

static TFLDocument parse_spec_internal(const json &root) {
  TFLDocument doc;

  // _metadata
  if (root.contains("_metadata") && root["_metadata"].is_object()) {
    const auto &meta = root["_metadata"];
    doc.metadata.out_dir = jutil::get<std::string>(meta, "outDir");
    doc.metadata.doc_file_name = jutil::get<std::string>(meta, "docFileName");
    doc.metadata.datetime = jutil::get<std::string>(meta, "datetime");
    doc.metadata.insert_toc = jutil::get<bool>(meta, "insertTOC", false);
    auto tt = jutil::opt<std::string>(meta, "tocTitle");
    if (tt.has_value())
      doc.metadata.toc_title = *tt;
  }

  // Parse each spec entry (keys matching pattern ^[A-Za-z0-9]..._[a-f0-9]{16}$)
  for (auto it = root.begin(); it != root.end(); ++it) {
    if (it.key() == "_metadata")
      continue;
    if (!it->is_object())
      continue;
    TFLSpec spec = parse_single_spec(it.key(), *it);
    doc.specs.push_back(std::move(spec));
  }

  // Sort specs by docOrder
  std::sort(doc.specs.begin(), doc.specs.end(),
            [](const TFLSpec &a, const TFLSpec &b) {
              return a.document.doc_order < b.document.doc_order;
            });

  return doc;
}

TFLDocument parse_spec_json(const std::string &json_path) {
  json root = read_json_file(json_path);
  return parse_spec_internal(root);
}

TFLDocument parse_spec_json_string(const std::string &json_str) {
  json root;
  try {
    root = json::parse(json_str);
  } catch (const json::parse_error &e) {
    throw RenderError("JSON parse error: " + std::string(e.what()));
  }
  return parse_spec_internal(root);
}

// ---------------------------------------------------------------------------
// Parse StylesTemplate
// ---------------------------------------------------------------------------

static StylesTemplate parse_template_internal(const json &root) {
  StylesTemplate tmpl;

  // document.page
  if (root.contains("document") && root["document"].is_object()) {
    const auto &doc = root["document"];
    if (doc.contains("page") && doc["page"].is_object())
      tmpl.page = parse_page_config(doc["page"]);
    if (doc.contains("paragraphDefaults") &&
        doc["paragraphDefaults"].is_object()) {
      tmpl.widow_control =
          jutil::opt<bool>(doc["paragraphDefaults"], "widow_control");
    }
  }

  // textStyles
  if (root.contains("textStyles") && root["textStyles"].is_object()) {
    const auto &ts = root["textStyles"];
    if (ts.contains("default"))
      tmpl.text_styles.default_style = parse_text_style(ts["default"]);
    if (ts.contains("docHeader"))
      tmpl.text_styles.doc_header = parse_text_style(ts["docHeader"]);
    if (ts.contains("docFooter"))
      tmpl.text_styles.doc_footer = parse_text_style(ts["docFooter"]);
    if (ts.contains("titles"))
      tmpl.text_styles.titles = parse_text_style(ts["titles"]);
    if (ts.contains("subtitles"))
      tmpl.text_styles.subtitles = parse_text_style(ts["subtitles"]);
    if (ts.contains("footnotes"))
      tmpl.text_styles.footnotes = parse_text_style(ts["footnotes"]);
    if (ts.contains("tableHeader"))
      tmpl.text_styles.table_header = parse_text_style(ts["tableHeader"]);
    if (ts.contains("tableBody"))
      tmpl.text_styles.table_body = parse_text_style(ts["tableBody"]);
    if (ts.contains("tocTitle"))
      tmpl.text_styles.toc_title = parse_text_style(ts["tocTitle"]);
    if (ts.contains("tocEntry"))
      tmpl.text_styles.toc_entry = parse_text_style(ts["tocEntry"]);
    if (ts.contains("figureCaption"))
      tmpl.text_styles.figure_caption = parse_text_style(ts["figureCaption"]);
  }

  // tableStyle
  if (root.contains("tableStyle") && root["tableStyle"].is_object()) {
    const auto &tbl = root["tableStyle"];

    // layout
    if (tbl.contains("layout") && tbl["layout"].is_object()) {
      const auto &layout = tbl["layout"];
      auto ta = jutil::opt<std::string>(layout, "table_alignment");
      if (ta.has_value()) {
        if (*ta == "center")
          tmpl.table_style.table_alignment = Alignment::Center;
        else if (*ta == "right")
          tmpl.table_style.table_alignment = Alignment::Right;
        else if (*ta == "left")
          tmpl.table_style.table_alignment = Alignment::Left;
      }
      auto top_el = jutil::opt<std::string>(layout, "topEmptyLine");
      if (top_el.has_value())
        tmpl.table_style.top_empty_line = Length::parse(*top_el);
      auto bottom_el = jutil::opt<std::string>(layout, "bottomEmptyLine");
      if (bottom_el.has_value())
        tmpl.table_style.bottom_empty_line = Length::parse(*bottom_el);
      if (layout.contains("table_borders") &&
          layout["table_borders"].is_object())
        tmpl.table_style.table_borders = parse_borders(layout["table_borders"]);
      auto arb = jutil::opt<bool>(layout, "allow_row_break_across_pages");
      if (arb.has_value())
        tmpl.table_style.allow_row_break_across_pages = *arb;
      auto rh = jutil::opt<bool>(layout, "repeat_header_on_each_page");
      if (rh.has_value())
        tmpl.table_style.repeat_header_on_each_page = *rh;
    }

    // structural
    if (tbl.contains("structural") && tbl["structural"].is_object()) {
      const auto &struc = tbl["structural"];
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
      if (struc.contains("header_top_border") &&
          struc["header_top_border"].is_object()) {
        tmpl.table_style.structural.header_top_border =
            parse_border(struc["header_top_border"]);
      }
      if (struc.contains("header_bottom_border") &&
          struc["header_bottom_border"].is_object()) {
        tmpl.table_style.structural.header_bottom_border =
            parse_border(struc["header_bottom_border"]);
      }
      if (struc.contains("table_bottom_border") &&
          struc["table_bottom_border"].is_object()) {
        tmpl.table_style.structural.table_bottom_border =
            parse_border(struc["table_bottom_border"]);
      }
    }

    // header row defaults
    if (tbl.contains("header") && tbl["header"].is_object()) {
      const auto &hdr = tbl["header"];
      if (hdr.contains("row") && hdr["row"].is_object()) {
        StyleDef hrd;
        hrd.table_style = parse_table_cell_props(hdr["row"]);
        tmpl.table_style.header_row = hrd;
      }
    }

    // body row defaults
    if (tbl.contains("body") && tbl["body"].is_object()) {
      const auto &body = tbl["body"];
      if (body.contains("row") && body["row"].is_object()) {
        StyleDef brd;
        brd.table_style = parse_table_cell_props(body["row"]);
        tmpl.table_style.body_row = brd;
      }
    }

    // cellDefaults
    if (tbl.contains("cellDefaults") && tbl["cellDefaults"].is_object()) {
      const auto &cd = tbl["cellDefaults"];
      if (cd.contains("cell_margins") && cd["cell_margins"].is_object()) {
        const auto &cm = cd["cell_margins"];
        auto mt = jutil::opt<std::string>(cm, "top");
        if (mt.has_value())
          tmpl.table_style.default_cell_margin_top = Length::parse(*mt);
        auto mb = jutil::opt<std::string>(cm, "bottom");
        if (mb.has_value())
          tmpl.table_style.default_cell_margin_bottom = Length::parse(*mb);
        auto ml = jutil::opt<std::string>(cm, "left");
        if (ml.has_value())
          tmpl.table_style.default_cell_margin_left = Length::parse(*ml);
        auto mr = jutil::opt<std::string>(cm, "right");
        if (mr.has_value())
          tmpl.table_style.default_cell_margin_right = Length::parse(*mr);
      }
    }

    // figureStyle
    if (root.contains("figureStyle") && root["figureStyle"].is_object()) {
      const auto &fig = root["figureStyle"];

      if (fig.contains("layout") && fig["layout"].is_object()) {
        const auto &layout = fig["layout"];
        auto a = jutil::opt<std::string>(layout, "alignment");
        if (a.has_value()) {
          if (*a == "center")
            tmpl.figure_style.alignment = Alignment::Center;
          else if (*a == "right")
            tmpl.figure_style.alignment = Alignment::Right;
          else if (*a == "left")
            tmpl.figure_style.alignment = Alignment::Left;
        }

        auto sb = jutil::opt<std::string>(layout, "space_before");
        if (sb.has_value())
          tmpl.figure_style.space_before = Length::parse(*sb);
        auto sa = jutil::opt<std::string>(layout, "space_after");
        if (sa.has_value())
          tmpl.figure_style.space_after = Length::parse(*sa);
      }

      if (fig.contains("caption") && fig["caption"].is_object()) {
        const auto &cap = fig["caption"];
        auto p = jutil::opt<std::string>(cap, "position");
        if (p.has_value())
          tmpl.figure_style.caption_position = *p;
        auto sr = jutil::opt<std::string>(cap, "textStyleRef");
        if (sr.has_value())
          tmpl.figure_style.caption_text_style_ref = *sr;
      }
    }
  }

  return tmpl;
}

StylesTemplate parse_template_json(const std::string &json_path) {
  json root = read_json_file(json_path);
  return parse_template_internal(root);
}

StylesTemplate parse_template_json_string(const std::string &json_str) {
  json root;
  try {
    root = json::parse(json_str);
  } catch (const json::parse_error &e) {
    throw RenderError("Template JSON parse error: " + std::string(e.what()));
  }
  return parse_template_internal(root);
}

// ---------------------------------------------------------------------------
// Parse Data JSON (column-oriented)
// ---------------------------------------------------------------------------

static DataTable parse_data_internal(const json &root) {
  DataTable dt;
  for (auto it = root.begin(); it != root.end(); ++it) {
    if (!it->is_array())
      continue;
    const std::string &col_name = it.key();
    dt.col_names.push_back(col_name);
    std::vector<std::string> values;
    for (const auto &val : *it) {
      if (val.is_string()) {
        values.push_back(val.get<std::string>());
      } else if (val.is_null()) {
        values.push_back("");
      } else if (val.is_number()) {
        if (val.is_number_integer()) {
          values.push_back(std::to_string(val.get<int64_t>()));
        } else {
          // Use %.17g for full double precision (avoids the
          // limited 6-decimal formatting of std::to_string).
          char buf[64];
          std::snprintf(buf, sizeof(buf), "%.17g", val.get<double>());
          values.push_back(buf);
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

  // Validate and fix ragged data: pad shorter columns to n_rows with empty
  // strings.
  for (const auto &col_name : dt.col_names) {
    auto col_it = dt.columns.find(col_name);
    if (col_it != dt.columns.end() && col_it->second.size() != dt.n_rows) {
      Rcpp::Rcerr << "[ksTFL] WARNING: Column '" << col_name << "' has "
                  << col_it->second.size() << " rows but expected " << dt.n_rows
                  << ". Padding with empty strings.\n";
      col_it->second.resize(dt.n_rows, "");
    }
  }

  return dt;
}

DataTable parse_data_json(const std::string &json_path) {
  json root = read_json_file(json_path);
  return parse_data_internal(root);
}

DataTable parse_data_json_string(const std::string &json_str) {
  json root;
  try {
    root = json::parse(json_str);
  } catch (const json::parse_error &e) {
    throw RenderError("Data JSON parse error: " + std::string(e.what()));
  }
  return parse_data_internal(root);
}

} // namespace kstfl
