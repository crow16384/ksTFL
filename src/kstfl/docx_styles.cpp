// kstfl/docx_styles.cpp — DOCX styles/settings/font table parts
//
// Extracted from docx_emitter.cpp to keep emitter orchestration focused.

#include "docx_emitter.h"

namespace kstfl {

static constexpr const char *W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main";
static constexpr const char *R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";

// ---------------------------------------------------------------------------
// word/styles.xml
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_styles(std::optional<int> toc_tab_pos_twips,
                                     const std::vector<TocHeadingEntry> &toc_headings) const {
  XmlWriter w;
  w.write_declaration();
  w.start_element("w:styles");
  w.namespace_decl("w", W_NS);
  w.namespace_decl("r", R_NS);

  w.start_element("w:docDefaults");

  w.start_element("w:rPrDefault");
  w.start_element("w:rPr");
  const auto &df = tmpl_.text_styles.default_style.font.value_or(FontProps{});
  if (df.font_name.has_value()) {
    w.start_element("w:rFonts");
    w.attribute("w:ascii", df.font_name.value());
    w.attribute("w:hAnsi", df.font_name.value());
    w.attribute("w:cs", df.font_name.value());
    w.end_element();
  }
  if (df.font_size.has_value()) {
    int half_pt = static_cast<int>(df.font_size.value() * 2.0);
    w.element_with_attr("w:sz", "w:val", std::to_string(half_pt));
    w.element_with_attr("w:szCs", "w:val", std::to_string(half_pt));
  }
  w.end_element();
  w.end_element();

  w.start_element("w:pPrDefault");
  w.start_element("w:pPr");
  const auto &dp = tmpl_.text_styles.default_style.paragraph.value_or(ParagraphProps{});
  if (dp.spacing.has_value()) {
    w.start_element("w:spacing");
    if (dp.spacing->before.has_value()) { w.attribute("w:before", std::to_string(dp.spacing->before->to_twips())); }
    if (dp.spacing->after.has_value()) { w.attribute("w:after", std::to_string(dp.spacing->after->to_twips())); }
    if (dp.spacing->line_spacing_multiplier.has_value()) {
      int line_val = static_cast<int>(dp.spacing->line_spacing_multiplier.value() * 240.0);
      w.attribute("w:line", std::to_string(line_val));
      w.attribute("w:lineRule", "auto");
    }
    w.end_element();
  }
  w.end_element();
  w.end_element();

  w.end_element();

  w.start_element("w:style");
  w.attribute("w:type", "paragraph");
  w.attribute("w:default", "1");
  w.attribute("w:styleId", "Normal");
  w.element_with_attr("w:name", "w:val", "Normal");
  w.end_element();

  const int toc_tab_twips = toc_tab_pos_twips.value_or(15840);
  StyleResolver toc_resolver(tmpl_, StyleMap{});
  StyleDef toc_entry_style = toc_resolver.resolve_toc_entry_style();
  for (int level = 1; level <= 9; ++level) {
    std::string style_id = "TOC" + std::to_string(level);
    std::string style_name = "toc " + std::to_string(level);
    int indent_twips = (level - 1) * 360;
    w.start_element("w:style");
    w.attribute("w:type", "paragraph");
    w.attribute("w:styleId", style_id);
    w.element_with_attr("w:name", "w:val", style_name);
    w.element_with_attr("w:basedOn", "w:val", "Normal");
    w.start_element("w:pPr");
    if (toc_entry_style.paragraph.has_value()) { emit_para_props(w, *toc_entry_style.paragraph); }
    if (indent_twips > 0) {
      w.start_element("w:ind");
      w.attribute("w:left", std::to_string(indent_twips));
      w.end_element();
    }
    w.start_element("w:tabs");
    w.start_element("w:tab");
    w.attribute("w:val", "right");
    w.attribute("w:leader", "dot");
    w.attribute("w:pos", std::to_string(toc_tab_twips));
    w.end_element();
    w.end_element();
    w.end_element();

    if (toc_entry_style.font.has_value()) { emit_run_props(w, *toc_entry_style.font); }

    w.end_element();
  }

  // TOC-heading styles: body title/subtitle appearance + outline level (for TOC \o and PDF bookmarks)
  for (const auto &entry : toc_headings) {
    w.start_element("w:style");
    w.attribute("w:type", "paragraph");
    w.attribute("w:styleId", entry.style_id);
    w.element_with_attr("w:name", "w:val", entry.style_id);
    w.element_with_attr("w:basedOn", "w:val", "Normal");
    if (entry.style.paragraph.has_value()) {
      ParagraphProps pp = *entry.style.paragraph;
      pp.outline_level = entry.toc_level - 1; // OOXML: 0-8 for levels 1-9
      emit_para_props(w, pp);
    } else {
      w.start_element("w:pPr");
      w.element_with_attr("w:outlineLvl", "w:val", std::to_string(entry.toc_level - 1));
      w.end_element();
    }
    if (entry.style.font.has_value()) { emit_run_props(w, *entry.style.font); }
    w.end_element();
  }

  w.end_element();
  return w.str();
}

// ---------------------------------------------------------------------------
// word/settings.xml
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_settings() const {
  XmlWriter w;
  w.write_declaration();
  w.start_element("w:settings");
  w.namespace_decl("w", W_NS);

  w.start_element("w:compat");
  w.start_element("w:compatSetting");
  w.attribute("w:name", "compatibilityMode");
  w.attribute("w:uri", "http://schemas.microsoft.com/office/word");
  w.attribute("w:val", "15");
  w.end_element();
  w.end_element();

  w.start_element("w:updateFields");
  w.attribute("w:val", "false");
  w.end_element();

  if (tmpl_.widow_control.value_or(true)) { w.self_closing_element("w:widowControl"); }

  w.end_element();
  return w.str();
}

// ---------------------------------------------------------------------------
// word/fontTable.xml
// ---------------------------------------------------------------------------

std::string DocxEmitter::emit_font_table() const {
  XmlWriter w;
  w.write_declaration();
  w.start_element("w:fonts");
  w.namespace_decl("w", W_NS);

  auto default_font = tmpl_.text_styles.default_style.font;
  std::string font_name = default_font.has_value() ? default_font->font_name.value_or("Courier New") : "Courier New";

  w.start_element("w:font");
  w.attribute("w:name", font_name);
  w.element_with_attr("w:charset", "w:val", "00");
  w.element_with_attr("w:family", "w:val", "modern");
  w.element_with_attr("w:pitch", "w:val", "fixed");
  w.end_element();

  w.start_element("w:font");
  w.attribute("w:name", "Times New Roman");
  w.element_with_attr("w:charset", "w:val", "00");
  w.element_with_attr("w:family", "w:val", "roman");
  w.element_with_attr("w:pitch", "w:val", "variable");
  w.end_element();

  w.end_element();
  return w.str();
}

} // namespace kstfl
