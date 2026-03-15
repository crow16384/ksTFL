// kstfl/docx_content.cpp — text and property emission helpers for DocxEmitter

#include "docx_emitter.h"
#include "inline_parser.h"
#include <unordered_map>

namespace kstfl {

// ---------------------------------------------------------------------------
// Exact line height stamping
// ---------------------------------------------------------------------------

void DocxEmitter::stamp_exact_line_height(StyleDef &style) const {
  if (!measurer_) return;  // no measurer available, skip
  if (!style.font) return; // no font info, skip

  const auto &fp = *style.font;
  double mult = 1.0;
  if (style.paragraph && style.paragraph->spacing && style.paragraph->spacing->line_spacing_multiplier) {
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

void DocxEmitter::emit_run_props(XmlWriter &w, const FontProps &font, const InlineRunStyle &run_style) const {
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
  if (underline) { w.element_with_attr("w:u", "w:val", "single"); }

  if (font.font_size.has_value()) {
    double size = font.font_size.value();
    // Note: do NOT reduce font size for superscript/subscript here.
    // Word handles the visual sizing via w:vertAlign; manual reduction
    // would double-apply the size change.
    int half_pt = static_cast<int>(size * 2.0);
    w.element_with_attr("w:sz", "w:val", std::to_string(half_pt));
    w.element_with_attr("w:szCs", "w:val", std::to_string(half_pt));
  }

  if (font.color.has_value() && !font.color->empty()) { w.element_with_attr("w:color", "w:val", font.color->hex); }

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

  w.end_element(); // w:rPr
}

// ---------------------------------------------------------------------------
// Paragraph properties (<w:pPr>)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_para_props(XmlWriter &w, const ParagraphProps &pp) const {
  w.start_element("w:pPr");

  if (pp.outline_level.has_value()) {
    int lvl = pp.outline_level.value();
    if (lvl >= 0 && lvl <= 8) { w.element_with_attr("w:outlineLvl", "w:val", std::to_string(lvl)); }
  }
  if (pp.alignment.has_value()) { w.element_with_attr("w:jc", "w:val", alignment_to_ooxml(pp.alignment.value())); }

  if (pp.spacing.has_value()) {
    w.start_element("w:spacing");
    if (pp.spacing->before.has_value()) { w.attribute("w:before", std::to_string(pp.spacing->before->to_twips())); }
    if (pp.spacing->after.has_value()) { w.attribute("w:after", std::to_string(pp.spacing->after->to_twips())); }
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
    if (pp.indents->left.has_value()) { w.attribute("w:left", std::to_string(pp.indents->left->to_twips())); }
    if (pp.indents->right.has_value()) { w.attribute("w:right", std::to_string(pp.indents->right->to_twips())); }
    if (pp.indents->first_line.has_value()) {
      w.attribute("w:firstLine", std::to_string(pp.indents->first_line->to_twips()));
    }
    if (pp.indents->hanging.has_value()) { w.attribute("w:hanging", std::to_string(pp.indents->hanging->to_twips())); }
    w.end_element();
  }

  if (pp.keep_next.value_or(false)) { w.self_closing_element("w:keepNext"); }
  if (pp.keep_lines.value_or(false)) { w.self_closing_element("w:keepLines"); }
  if (pp.widow_control.value_or(false)) { w.self_closing_element("w:widowControl"); }

  w.end_element(); // w:pPr
}

// ---------------------------------------------------------------------------
// Table cell properties (<w:tcPr>)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_cell_props(XmlWriter &w, const TableCellProps &tcp, Length cell_width, int grid_span,
                                  VMergeState v_merge) const {
  w.start_element("w:tcPr");

  // Cell width in twips
  w.start_element("w:tcW");
  w.attribute("w:w", std::to_string(cell_width.to_twips()));
  w.attribute("w:type", "dxa");
  w.end_element();

  // Grid span for merged cells
  if (grid_span > 1) { w.element_with_attr("w:gridSpan", "w:val", std::to_string(grid_span)); }

  // Vertical merge
  if (v_merge == VMergeState::Restart) {
    w.element_with_attr("w:vMerge", "w:val", "restart");
  } else if (v_merge == VMergeState::Continue) {
    w.self_closing_element("w:vMerge");
  }

  // Vertical alignment
  if (tcp.vertical_alignment.has_value()) {
    static const std::unordered_map<VerticalAlignment, const char *> valign_map{
        {VerticalAlignment::Top, "top"}, {VerticalAlignment::Center, "center"}, {VerticalAlignment::Bottom, "bottom"}};
    auto it = valign_map.find(tcp.vertical_alignment.value());
    w.element_with_attr("w:vAlign", "w:val", (it != valign_map.end()) ? it->second : "top");
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
    static const std::unordered_map<TextOrientation, const char *> orient_map{{TextOrientation::BottomToTop, "btLr"},
                                                                              {TextOrientation::TopToBottom, "tbRl"}};
    auto oit = orient_map.find(tcp.text_orientation.value());
    if (oit != orient_map.end()) { w.element_with_attr("w:textDirection", "w:val", oit->second); }
    // For vertical text, prevent Word from wrapping; we measure and size
    // the row for a single unwrapped line.
    if (tcp.text_orientation.value() != TextOrientation::Horizontal) { w.self_closing_element("w:noWrap"); }
  }

  // Cell borders
  if (tcp.borders.has_value()) {
    w.start_element("w:tcBorders");
    auto emit_border = [&](const char *name, const std::optional<Border> &b) {
      if (!b.has_value()) return;
      w.start_element(name);
      if (b->line_style.has_value()) {
        w.attribute("w:val", border_line_style_to_ooxml(b->line_style.value()));
      } else {
        w.attribute("w:val", "single");
      }
      if (b->width.has_value()) {
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
    w.end_element(); // w:tcBorders
  }

  // Cell margins — only left/right are emitted.  Top/bottom are zeroed
  // because Word adds tcMar top/bottom OUTSIDE trHeight even with
  // hRule="exact".  Vertical padding is already included in the row height
  // computed by the paginator.
  bool has_margins = tcp.cell_margin_left.has_value() || tcp.cell_margin_right.has_value();
  if (has_margins) {
    w.start_element("w:tcMar");
    auto emit_margin = [&](const char *name, const std::optional<Length> &m) {
      if (!m.has_value()) return;
      w.start_element(name);
      w.attribute("w:w", std::to_string(m->to_twips()));
      w.attribute("w:type", "dxa");
      w.end_element();
    };
    emit_margin("w:left", tcp.cell_margin_left);
    emit_margin("w:right", tcp.cell_margin_right);
    w.end_element(); // w:tcMar
  }

  w.end_element(); // w:tcPr
}

// ---------------------------------------------------------------------------
// Emit a paragraph with plain text + style
// ---------------------------------------------------------------------------

void DocxEmitter::emit_paragraph(XmlWriter &w, const std::string &text, const StyleDef &style) const {
  ParsedCell parsed = parse_inline_markup(text);

  if (parsed.paragraphs.empty()) {
    w.start_element("w:p");
    if (style.paragraph.has_value()) { emit_para_props(w, style.paragraph.value()); }
    w.end_element();
    return;
  }

  for (const auto &para : parsed.paragraphs) {
    emit_parsed_paragraph(w, para, style);
  }
}

// ---------------------------------------------------------------------------
// Emit a parsed paragraph (with inline markup runs)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_parsed_paragraph(XmlWriter &w, const ParsedParagraph &para, const StyleDef &base_style) const {
  w.start_element("w:p");

  if (base_style.paragraph.has_value()) { emit_para_props(w, base_style.paragraph.value()); }

  emit_parsed_paragraph_runs(w, para, base_style);
  w.end_element(); // w:p
}

void DocxEmitter::emit_parsed_paragraph_runs(XmlWriter &w, const ParsedParagraph &para,
                                             const StyleDef &base_style) const {
  FontProps base_font = base_style.font.value_or(FontProps{});

  for (const auto &run : para.runs) {
    w.start_element("w:r");
    emit_run_props(w, base_font, run.style);

    if (run.text == "\n") {
      w.self_closing_element("w:br");
    } else {
      w.element_with_text("w:t", run.text);
    }

    w.end_element(); // w:r
  }
}

// ---------------------------------------------------------------------------
// Emit text groups (titles, subtitles, footnotes)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_text_groups(XmlWriter &w, const std::vector<TextGroup> &groups, const StyleDef &base_style,
                                   const StyleResolver &resolver,
                                   const std::vector<TocHeadingEntry> &toc_headings) const {
  for (const auto &group : groups) {
    StyleDef style = base_style;
    for (const auto &ref : group.style_refs) {
      const StyleDef *ref_style = resolver.find_style(ref);
      if (ref_style) { style.merge_from(*ref_style); }
    }

    stamp_exact_line_height(style);

    // Parse each text element individually; emit all within one <w:p>
    // with soft line breaks (<w:br/>) between elements.
    std::vector<ParsedCell> parsed_elements;
    parsed_elements.reserve(group.text.size());
    for (const auto &txt : group.text) {
      parsed_elements.push_back(parse_inline_markup(txt));
    }

    w.start_element("w:p");
    std::optional<std::string> toc_style_id;
    if (group.toc_level > 0) { toc_style_id = find_toc_heading_style_id(toc_headings, style, group.toc_level); }
    if (toc_style_id.has_value()) {
      w.start_element("w:pPr");
      w.element_with_attr("w:pStyle", "w:val", toc_style_id.value());
      w.end_element();
    } else if (style.paragraph.has_value()) {
      emit_para_props(w, style.paragraph.value());
    }

    FontProps base_font = style.font.value_or(FontProps{});
    bool need_break = false;
    for (const auto &parsed : parsed_elements) {
      if (need_break) {
        // Soft line break between text elements
        w.start_element("w:r");
        emit_run_props(w, base_font);
        w.self_closing_element("w:br");
        w.end_element(); // w:r
      }
      for (const auto &para : parsed.paragraphs) {
        emit_parsed_paragraph_runs(w, para, style);
      }
      need_break = true;
    }

    w.end_element(); // w:p
  }
}

// ---------------------------------------------------------------------------
// Emit all text groups combined in one paragraph with soft breaks
// ---------------------------------------------------------------------------

void DocxEmitter::emit_text_groups_combined(XmlWriter &w, const std::vector<TextGroup> &groups,
                                            const StyleDef &base_style, const StyleResolver &resolver,
                                            const std::string &prefix) const {
  w.start_element("w:p");

  if (base_style.paragraph.has_value()) { emit_para_props(w, base_style.paragraph.value()); }

  bool first_run = true;

  auto emit_break = [&](const FontProps &font) {
    w.start_element("w:r");
    emit_run_props(w, font);
    w.self_closing_element("w:br");
    w.end_element();
  };

  if (!prefix.empty()) {
    FontProps base_font = base_style.font.value_or(FontProps{});
    w.start_element("w:r");
    emit_run_props(w, base_font);
    w.element_with_text("w:t", prefix);
    w.end_element();
    first_run = false;
  }

  for (const auto &group : groups) {
    StyleDef style = base_style;
    for (const auto &ref : group.style_refs) {
      const StyleDef *ref_style = resolver.find_style(ref);
      if (ref_style) { style.merge_from(*ref_style); }
    }
    FontProps font = style.font.value_or(FontProps{});

    for (size_t i = 0; i < group.text.size(); ++i) {
      if (!first_run) { emit_break(font); }

      w.start_element("w:r");
      emit_run_props(w, font);
      w.element_with_text("w:t", group.text[i]);
      w.end_element();
      first_run = false;
    }
  }

  w.end_element(); // w:p
}

} // namespace kstfl
