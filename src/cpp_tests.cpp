// cpp_tests.cpp — Unit tests for C++ modules (units, inline_parser, xml_writer)
//
// Each exported function runs a suite of tests and returns a list with two
// character vectors:
//   - passed: names of tests that passed
//   - failed: "<name>: <message>" for tests that failed
//
// Called from R via .Call() in tests/testthat/test-18-cpp-units.R.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "kstfl/inline_parser.h"
#include "kstfl/logical_table.h"
#include "kstfl/types.h"
#include "kstfl/units.h"
#include "kstfl/xml_writer.h"
#include <Rcpp.h>

#include <cmath>
#include <functional>
#include <string>
#include <vector>

using namespace kstfl;

// ---------------------------------------------------------------------------
// Simple test harness
// ---------------------------------------------------------------------------

struct TestResult {
  std::vector<std::string> passed;
  std::vector<std::string> failed;

  void ok(const std::string &name) { passed.push_back(name); }

  void fail(const std::string &name, const std::string &msg) { failed.push_back(name + ": " + msg); }

  void check(bool cond, const std::string &name, const std::string &msg = "") {
    cond ? ok(name) : fail(name, msg.empty() ? "false" : msg);
  }

  void check_eq(int64_t actual, int64_t expected, const std::string &name) {
    if (actual == expected)
      ok(name);
    else
      fail(name, "expected " + std::to_string(expected) + ", got " + std::to_string(actual));
  }

  void check_eq(int actual, int expected, const std::string &name) {
    if (actual == expected)
      ok(name);
    else
      fail(name, "expected " + std::to_string(expected) + ", got " + std::to_string(actual));
  }

  void check_eq(size_t actual, size_t expected, const std::string &name) {
    if (actual == expected)
      ok(name);
    else
      fail(name, "expected " + std::to_string(expected) + ", got " + std::to_string(actual));
  }

  void check_eq(const std::string &actual, const std::string &expected, const std::string &name) {
    if (actual == expected)
      ok(name);
    else
      fail(name, "expected \"" + expected + "\", got \"" + actual + "\"");
  }

  void check_throw(std::function<void()> fn, const std::string &name) {
    try {
      fn();
      fail(name, "expected exception but none was thrown");
    } catch (...) { ok(name); }
  }

  void check_no_throw(std::function<void()> fn, const std::string &name) {
    try {
      fn();
      ok(name);
    } catch (const std::exception &e) { fail(name, std::string("unexpected exception: ") + e.what()); }
  }

  Rcpp::List to_list() const {
    return Rcpp::List::create(Rcpp::Named("passed") = Rcpp::wrap(passed), Rcpp::Named("failed") = Rcpp::wrap(failed));
  }
};

// ---------------------------------------------------------------------------
// Units tests
// ---------------------------------------------------------------------------

// [[Rcpp::export]]
Rcpp::List cpp_test_units() {
  TestResult t;

  // --- parse_length: basic units ---

  // 1in = 914400 EMU
  t.check_no_throw(
      [&]() {
        auto len = parse_length("1in");
        t.check_eq(len.emu, int64_t(914400), "parse_length 1in");
      },
      "parse_length 1in no throw");

  // 1cm = 360000 EMU
  t.check_no_throw(
      [&]() {
        auto len = parse_length("1cm");
        t.check_eq(len.emu, int64_t(360000), "parse_length 1cm");
      },
      "parse_length 1cm no throw");

  // 1pt = 12700 EMU
  t.check_no_throw(
      [&]() {
        auto len = parse_length("1pt");
        t.check_eq(len.emu, int64_t(12700), "parse_length 1pt");
      },
      "parse_length 1pt no throw");

  // 1mm = 36000 EMU
  t.check_no_throw(
      [&]() {
        auto len = parse_length("1mm");
        t.check_eq(len.emu, int64_t(36000), "parse_length 1mm");
      },
      "parse_length 1mm no throw");

  // 72pt == 1in
  t.check_no_throw(
      [&]() {
        auto len = parse_length("72pt");
        t.check_eq(len.emu, int64_t(72 * 12700), "parse_length 72pt = 1in");
      },
      "parse_length 72pt no throw");

  // 2.54cm ≈ 1in  (allow ±200 EMU floating-point rounding)
  t.check_no_throw(
      [&]() {
        auto len = parse_length("2.54cm");
        int64_t diff = std::abs(len.emu - int64_t(914400));
        t.check(diff <= 200, "parse_length 2.54cm ≈ 1in", "got " + std::to_string(len.emu) + " expected ~914400");
      },
      "parse_length 2.54cm no throw");

  // Percent: 50% of 200000 = 100000
  t.check_no_throw(
      [&]() {
        auto len = parse_length("50%", 200000);
        t.check_eq(len.emu, int64_t(100000), "parse_length 50% of 200000");
      },
      "parse_length 50% no throw");

  // Zero value
  t.check_no_throw(
      [&]() {
        auto len = parse_length("0pt");
        t.check_eq(len.emu, int64_t(0), "parse_length 0pt");
      },
      "parse_length 0pt no throw");

  // emu unit suffix
  t.check_no_throw(
      [&]() {
        auto len = parse_length("914400emu");
        t.check_eq(len.emu, int64_t(914400), "parse_length 914400emu");
      },
      "parse_length 914400emu no throw");

  // Bare number (no unit = raw EMU)
  t.check_no_throw(
      [&]() {
        auto len = parse_length("12700");
        t.check_eq(len.emu, int64_t(12700), "parse_length bare number = EMU");
      },
      "parse_length bare number no throw");

  // Negative value
  t.check_no_throw(
      [&]() {
        auto len = parse_length("-1pt");
        t.check_eq(len.emu, int64_t(-12700), "parse_length -1pt");
      },
      "parse_length -1pt no throw");

  // Whitespace trimming
  t.check_no_throw(
      [&]() {
        auto len = parse_length("  1in  ");
        t.check_eq(len.emu, int64_t(914400), "parse_length whitespace trimming");
      },
      "parse_length whitespace trim no throw");

  // Length::parse static method (delegates to parse_length)
  t.check_no_throw(
      [&]() {
        auto len = Length::parse("1in");
        t.check_eq(len.emu, int64_t(914400), "Length::parse 1in");
      },
      "Length::parse 1in no throw");

  // --- parse_length: error cases ---
  t.check_throw([]() { parse_length(""); }, "parse_length empty string throws");
  t.check_throw([]() { parse_length("abc"); }, "parse_length no number throws");
  t.check_throw([]() { parse_length("50%"); }, "parse_length % without reference throws");
  t.check_throw([]() { parse_length("1xyz"); }, "parse_length unknown unit throws");

  // --- emu_to_twips ---
  // 1 in = 914400 EMU = 1440 twips
  t.check_eq(emu_to_twips(int64_t(914400)), int64_t(1440), "emu_to_twips 1in = 1440t");
  t.check_eq(emu_to_twips(int64_t(0)), int64_t(0), "emu_to_twips 0");
  t.check_eq(emu_to_twips(int64_t(635)), int64_t(1), "emu_to_twips 1 twip = 635 EMU");
  // 1pt = 12700 EMU = 20 twips
  t.check_eq(emu_to_twips(int64_t(12700)), int64_t(20), "emu_to_twips 1pt = 20t");

  // --- emu_to_half_points ---
  // 1pt = 12700 EMU → 2 half-points
  t.check_eq(emu_to_half_points(int64_t(12700)), 2, "emu_to_half_points 1pt");
  // 12pt → 24 half-points
  t.check_eq(emu_to_half_points(int64_t(12700 * 12)), 24, "emu_to_half_points 12pt");
  t.check_eq(emu_to_half_points(int64_t(0)), 0, "emu_to_half_points 0");
  // 9pt → 18 half-points
  t.check_eq(emu_to_half_points(int64_t(12700 * 9)), 18, "emu_to_half_points 9pt");

  // --- pt_to_half_points ---
  t.check_eq(pt_to_half_points(12.0), 24, "pt_to_half_points 12pt");
  t.check_eq(pt_to_half_points(9.0), 18, "pt_to_half_points 9pt");
  t.check_eq(pt_to_half_points(0.0), 0, "pt_to_half_points 0pt");
  t.check_eq(pt_to_half_points(8.5), 17, "pt_to_half_points 8.5pt");

  // --- pt_to_eighth_points ---
  t.check_eq(pt_to_eighth_points(1.0), 8, "pt_to_eighth_points 1pt");
  t.check_eq(pt_to_eighth_points(0.5), 4, "pt_to_eighth_points 0.5pt");
  t.check_eq(pt_to_eighth_points(1.5), 12, "pt_to_eighth_points 1.5pt");
  t.check_eq(pt_to_eighth_points(0.0), 0, "pt_to_eighth_points 0pt");
  t.check_eq(pt_to_eighth_points(0.25), 2, "pt_to_eighth_points 0.25pt");

  // --- page_size_dimensions ---
  {
    auto [w, h] = page_size_dimensions(PageSize::A4);
    t.check_eq(w, int64_t(7560000), "A4 width EMU");
    t.check_eq(h, int64_t(10692000), "A4 height EMU");
  }
  {
    auto [w, h] = page_size_dimensions(PageSize::Letter);
    t.check_eq(w, LETTER_WIDTH_EMU, "Letter width EMU");
    t.check_eq(h, LETTER_HEIGHT_EMU, "Letter height EMU");
  }
  {
    auto [w, h] = page_size_dimensions(PageSize::Legal);
    t.check_eq(w, LEGAL_WIDTH_EMU, "Legal width EMU");
    t.check_eq(h, LEGAL_HEIGHT_EMU, "Legal height EMU");
  }
  {
    auto [w, h] = page_size_dimensions(PageSize::A3);
    t.check_eq(w, A3_WIDTH_EMU, "A3 width EMU");
    t.check_eq(h, A3_HEIGHT_EMU, "A3 height EMU");
  }
  {
    auto [w, h] = page_size_dimensions(PageSize::Executive);
    t.check_eq(w, EXECUTIVE_WIDTH_EMU, "Executive width EMU");
    t.check_eq(h, EXECUTIVE_HEIGHT_EMU, "Executive height EMU");
  }

  // --- Color::parse ---
  {
    auto c = Color::parse("#FF0000");
    t.check_eq(c.hex, std::string("FF0000"), "Color::parse #FF0000");
  }
  {
    // lowercase input → uppercase output
    auto c = Color::parse("ff0000");
    t.check_eq(c.hex, std::string("FF0000"), "Color::parse lowercase → uppercase");
  }
  {
    auto c = Color::parse("#000000");
    t.check_eq(c.hex, std::string("000000"), "Color::parse black");
  }
  {
    auto c = Color::parse("#FFFFFF");
    t.check_eq(c.hex, std::string("FFFFFF"), "Color::parse white");
  }
  {
    auto c = Color::parse("A0B1C2");
    t.check_eq(c.hex, std::string("A0B1C2"), "Color::parse mixed alphanumeric");
  }
  t.check_throw([]() { static_cast<void>(Color::parse("XYZ")); }, "Color::parse invalid chars throws");
  t.check_throw([]() { static_cast<void>(Color::parse("#12345")); }, "Color::parse 5-char hex throws");
  t.check_throw([]() { static_cast<void>(Color::parse("#1234567")); }, "Color::parse 7-char hex throws");
  t.check_throw([]() { static_cast<void>(Color::parse("#GGGGGG")); }, "Color::parse non-hex G throws");

  // --- Length arithmetic operators ---
  {
    Length a = Length::from_pt(10.0);
    Length b = Length::from_pt(5.0);
    t.check_eq((a + b).emu, int64_t(15 * 12700), "Length operator+");
    t.check_eq((a - b).emu, int64_t(5 * 12700), "Length operator-");
  }
  {
    Length a = Length::from_in(1.0);
    t.check_eq((a * 0.5).emu, int64_t(914400 / 2), "Length operator* 0.5");
    t.check_eq((a / 2.0).emu, int64_t(914400 / 2), "Length operator/ 2.0");
  }
  {
    t.check(Length::from_pt(10.0) > Length::from_pt(5.0), "Length operator>");
    t.check(Length::from_pt(5.0) < Length::from_pt(10.0), "Length operator<");
    t.check(Length::from_pt(5.0) == Length::from_pt(5.0), "Length operator==");
    t.check(Length::from_pt(5.0) != Length::from_pt(10.0), "Length operator!=");
    t.check(Length::from_pt(5.0) <= Length::from_pt(5.0), "Length operator<= equal");
    t.check(Length::from_pt(5.0) <= Length::from_pt(6.0), "Length operator<= less");
    t.check(Length::from_pt(6.0) >= Length::from_pt(6.0), "Length operator>= equal");
  }

  // --- Length conversion methods ---
  {
    Length one_inch = Length::from_in(1.0);
    t.check_eq(one_inch.to_emu(), int64_t(914400), "to_emu 1in");
    // to_twips: rounds to nearest twip
    t.check_eq(one_inch.to_twips(), int64_t(1440), "to_twips 1in");
  }

  // --- border_line_style_to_ooxml ---
  {
    t.check_eq(std::string(border_line_style_to_ooxml(BorderLineStyle::None)), std::string("nil"), "OOXML border None");
    t.check_eq(std::string(border_line_style_to_ooxml(BorderLineStyle::Single)), std::string("single"),
               "OOXML border Single");
    t.check_eq(std::string(border_line_style_to_ooxml(BorderLineStyle::Double)), std::string("double"),
               "OOXML border Double");
    t.check_eq(std::string(border_line_style_to_ooxml(BorderLineStyle::Dashed)), std::string("dashed"),
               "OOXML border Dashed");
    t.check_eq(std::string(border_line_style_to_ooxml(BorderLineStyle::Dotted)), std::string("dotted"),
               "OOXML border Dotted");
    t.check_eq(std::string(border_line_style_to_ooxml(BorderLineStyle::Thick)), std::string("thick"),
               "OOXML border Thick");
    t.check_eq(std::string(border_line_style_to_ooxml(BorderLineStyle::Wave)), std::string("wave"),
               "OOXML border Wave");
    t.check_eq(std::string(border_line_style_to_ooxml(BorderLineStyle::DashSmallGap)), std::string("dashSmallGap"),
               "OOXML border DashSmallGap");
  }

  // --- alignment_to_ooxml ---
  {
    t.check_eq(std::string(alignment_to_ooxml(Alignment::Left)), std::string("left"), "OOXML alignment Left");
    t.check_eq(std::string(alignment_to_ooxml(Alignment::Center)), std::string("center"), "OOXML alignment Center");
    t.check_eq(std::string(alignment_to_ooxml(Alignment::Right)), std::string("right"), "OOXML alignment Right");
    t.check_eq(std::string(alignment_to_ooxml(Alignment::Justify)), std::string("both"), "OOXML alignment Justify");
  }

  return t.to_list();
}

// ---------------------------------------------------------------------------
// Inline parser tests
// ---------------------------------------------------------------------------

// [[Rcpp::export]]
Rcpp::List cpp_test_inline_parser() {
  TestResult t;

  // --- has_inline_markup ---
  t.check(!has_inline_markup("plain text"), "no markup: plain text");
  t.check(!has_inline_markup(""), "no markup: empty string");
  t.check(has_inline_markup("<b>bold</b>"), "has markup: b tag");
  t.check(has_inline_markup("text <i>ital</i>"), "has markup: i tag in middle");
  t.check(has_inline_markup("<sup>1</sup>"), "has markup: sup");
  t.check(has_inline_markup("x<br/>y"), "has markup: br");
  t.check(has_inline_markup("<u>under</u>"), "has markup: u");
  t.check(has_inline_markup("<s>struck</s>"), "has markup: s");
  t.check(!has_inline_markup("\\<i>literal\\</i>"), "no markup: escaped i tags");
  t.check(has_inline_markup("\\<i>literal\\</i> <b>real</b>"), "has markup: escaped + real tag");

  // --- Plain text (no markup) ---
  {
    auto cell = parse_inline_markup("hello");
    t.check_eq(cell.paragraphs.size(), size_t(1), "plain: 1 paragraph");
    t.check_eq(cell.paragraphs[0].runs.size(), size_t(1), "plain: 1 run");
    t.check_eq(cell.paragraphs[0].runs[0].text, std::string("hello"), "plain: text content");
    t.check(!cell.paragraphs[0].runs[0].style.bold_override, "plain: not bold");
    t.check(!cell.paragraphs[0].runs[0].style.italic_override, "plain: not italic");
    t.check(!cell.paragraphs[0].runs[0].style.underline_override, "plain: not underline");
    t.check(!cell.paragraphs[0].runs[0].style.strikethrough_override, "plain: not strikethrough");
    t.check(!cell.paragraphs[0].runs[0].style.superscript, "plain: not superscript");
    t.check(!cell.paragraphs[0].runs[0].style.subscript, "plain: not subscript");
  }

  // --- Empty string ---
  {
    auto cell = parse_inline_markup("");
    // Parser should always return at least one paragraph
    t.check(cell.paragraphs.size() >= size_t(1), "empty: at least 1 paragraph");
  }

  // --- Bold (<b>...</b>) ---
  {
    auto cell = parse_inline_markup("<b>bold text</b>");
    t.check_eq(cell.paragraphs.size(), size_t(1), "bold: 1 paragraph");
    bool found_bold = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "bold text" && run.style.bold_override) found_bold = true;
    }
    t.check(found_bold, "bold: run has bold_override=true and correct text");
  }

  // --- Italic (<i>...</i>) ---
  {
    auto cell = parse_inline_markup("<i>italic text</i>");
    bool found = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "italic text" && run.style.italic_override) found = true;
    }
    t.check(found, "italic: run has italic_override=true");
  }

  // --- Underline (<u>...</u>) ---
  {
    auto cell = parse_inline_markup("<u>underlined</u>");
    bool found = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "underlined" && run.style.underline_override) found = true;
    }
    t.check(found, "underline: run has underline_override=true");
  }

  // --- Strikethrough (<s>...</s>) ---
  {
    auto cell = parse_inline_markup("<s>struck</s>");
    bool found = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "struck" && run.style.strikethrough_override) found = true;
    }
    t.check(found, "strikethrough: run has strikethrough_override=true");
  }

  // --- Superscript (<sup>...</sup>) ---
  {
    auto cell = parse_inline_markup("<sup>1</sup>");
    bool found_sup = false;
    bool false_sub = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "1" && run.style.superscript) found_sup = true;
      if (run.text == "1" && run.style.subscript) false_sub = true;
    }
    t.check(found_sup, "superscript: superscript=true");
    t.check(!false_sub, "superscript: subscript=false");
  }

  // --- Subscript (<sub>...</sub>) ---
  {
    auto cell = parse_inline_markup("<sub>2</sub>");
    bool found_sub = false;
    bool false_sup = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "2" && run.style.subscript) found_sub = true;
      if (run.text == "2" && run.style.superscript) false_sup = true;
    }
    t.check(found_sub, "subscript: subscript=true");
    t.check(!false_sup, "subscript: superscript=false");
  }

  // --- Mixed: bold + plain text after ---
  {
    auto cell = parse_inline_markup("<b>bold</b> and plain");
    t.check_eq(cell.paragraphs.size(), size_t(1), "mixed b+plain: 1 paragraph");
    t.check(cell.paragraphs[0].runs.size() >= size_t(2), "mixed b+plain: >= 2 runs");
    bool has_bold = false;
    bool has_plain = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.style.bold_override && run.text.find("bold") != std::string::npos) has_bold = true;
      if (!run.style.bold_override && run.text.find("plain") != std::string::npos) has_plain = true;
    }
    t.check(has_bold, "mixed b+plain: bold run found");
    t.check(has_plain, "mixed b+plain: plain run found");
  }

  // --- Mixed: bold + italic in sequence ---
  {
    auto cell = parse_inline_markup("<b>bold</b> <i>italic</i>");
    bool has_bold = false;
    bool has_italic = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.style.bold_override && run.text.find("bold") != std::string::npos) has_bold = true;
      if (run.style.italic_override && run.text.find("italic") != std::string::npos) has_italic = true;
    }
    t.check(has_bold, "mixed b+i: bold run found");
    t.check(has_italic, "mixed b+i: italic run found");
  }

  // --- Nested: <b><i>both</i></b> → bold AND italic ---
  {
    auto cell = parse_inline_markup("<b><i>both</i></b>");
    bool found = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "both" && run.style.bold_override && run.style.italic_override) found = true;
    }
    t.check(found, "nested b+i: run has both bold_override and italic_override");
  }

  // --- Line break <br/> creates soft break (\\n run) within one paragraph ---
  {
    auto cell = parse_inline_markup("line1<br/>line2");
    t.check_eq(cell.paragraphs.size(), size_t(1), "br/: 1 paragraph (soft break)");
    bool found_line1 = false, found_br = false, found_line2 = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "line1") found_line1 = true;
      if (run.text == "\n") found_br = true;
      if (run.text == "line2") found_line2 = true;
    }
    t.check(found_line1, "br/: line1 text present");
    t.check(found_br, "br/: \\n run present");
    t.check(found_line2, "br/: line2 text present");
  }

  // --- <br> (without /) also creates soft break ---
  {
    auto cell = parse_inline_markup("a<br>b");
    t.check_eq(cell.paragraphs.size(), size_t(1), "br no slash: 1 paragraph");
    bool has_br = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "\n") has_br = true;
    }
    t.check(has_br, "br no slash: \\n run present");
  }

  // --- <p> tag creates new paragraph ---
  {
    auto cell = parse_inline_markup("para1<p>para2");
    t.check(cell.paragraphs.size() >= size_t(2), "<p>: >= 2 paragraphs");
  }

  // --- <p> with explicit open/close tags ---
  {
    auto cell = parse_inline_markup("<p>Para1</p><p>Para2</p>");
    t.check_eq(cell.paragraphs.size(), size_t(2), "<p> open/close: 2 paragraphs");
    bool found_p1 = false, found_p2 = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "Para1") found_p1 = true;
    }
    for (const auto &run : cell.paragraphs[1].runs) {
      if (run.text == "Para2") found_p2 = true;
    }
    t.check(found_p1, "<p> open/close: Para1 in paragraph 0");
    t.check(found_p2, "<p> open/close: Para2 in paragraph 1");
  }

  // --- <p> without closing tag ---
  {
    auto cell = parse_inline_markup("text1<p>text2");
    t.check_eq(cell.paragraphs.size(), size_t(2), "<p> no close: 2 paragraphs");
    bool found_t1 = false, found_t2 = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "text1") found_t1 = true;
    }
    for (const auto &run : cell.paragraphs[1].runs) {
      if (run.text == "text2") found_t2 = true;
    }
    t.check(found_t1, "<p> no close: text1 in paragraph 0");
    t.check(found_t2, "<p> no close: text2 in paragraph 1");
  }

  // --- Formatting across <p> boundary (tag stack persists) ---
  {
    auto cell = parse_inline_markup("<b>bold<p>still bold</b>");
    t.check_eq(cell.paragraphs.size(), size_t(2), "<p> fmt across: 2 paragraphs");
    bool p1_bold = false, p2_bold = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "bold" && run.style.bold_override) p1_bold = true;
    }
    for (const auto &run : cell.paragraphs[1].runs) {
      if (run.text == "still bold" && run.style.bold_override) p2_bold = true;
    }
    t.check(p1_bold, "<p> fmt across: 'bold' has bold_override");
    t.check(p2_bold, "<p> fmt across: 'still bold' has bold_override");
  }

  // --- Mixed <br> and <p> ---
  {
    auto cell = parse_inline_markup("line1<br>line2<p>line3");
    t.check_eq(cell.paragraphs.size(), size_t(2), "<p>+br: 2 paragraphs");
    // First paragraph: line1 + \n + line2
    bool has_l1 = false, has_br = false, has_l2 = false, has_l3 = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "line1") has_l1 = true;
      if (run.text == "\n") has_br = true;
      if (run.text == "line2") has_l2 = true;
    }
    for (const auto &run : cell.paragraphs[1].runs) {
      if (run.text == "line3") has_l3 = true;
    }
    t.check(has_l1, "<p>+br: line1 in paragraph 0");
    t.check(has_br, "<p>+br: \\n run in paragraph 0");
    t.check(has_l2, "<p>+br: line2 in paragraph 0");
    t.check(has_l3, "<p>+br: line3 in paragraph 1");
  }

  // --- Multiple line breaks → one paragraph with multiple \\n runs ---
  {
    auto cell = parse_inline_markup("a<br/>b<br/>c");
    t.check_eq(cell.paragraphs.size(), size_t(1), "multi br/: 1 paragraph");
    size_t br_count = 0;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "\n") ++br_count;
    }
    t.check_eq(br_count, size_t(2), "multi br/: 2 \\n runs");
  }

  // --- Case-insensitive tag names ---
  {
    auto cell = parse_inline_markup("<B>BOLD</B>");
    bool found = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "BOLD" && run.style.bold_override) found = true;
    }
    t.check(found, "case-insensitive: <B> treated as bold");
  }
  {
    auto cell = parse_inline_markup("<I>ITALIC</I>");
    bool found = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "ITALIC" && run.style.italic_override) found = true;
    }
    t.check(found, "case-insensitive: <I> treated as italic");
  }
  {
    auto cell = parse_inline_markup("<SUP>x</SUP>");
    bool found = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "x" && run.style.superscript) found = true;
    }
    t.check(found, "case-insensitive: <SUP> treated as superscript");
  }
  {
    auto cell = parse_inline_markup("<S>STRUCK</S>");
    bool found = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "STRUCK" && run.style.strikethrough_override) found = true;
    }
    t.check(found, "case-insensitive: <S> treated as strikethrough");
  }

  // --- Escaped tag openers are treated as literal text ---
  {
    auto cell = parse_inline_markup("\\<i>literal\\</i>");
    t.check_eq(cell.paragraphs.size(), size_t(1), "escape: literal i tags -> 1 paragraph");
    bool found_literal = false;
    bool any_italic = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text.find("<i>literal</i>") != std::string::npos) found_literal = true;
      if (run.style.italic_override) any_italic = true;
    }
    t.check(found_literal, "escape: literal i tags preserved");
    t.check(!any_italic, "escape: escaped i does not enable italic");
  }

  {
    auto cell = parse_inline_markup("<b>bold \\<i>tag\\</i></b>");
    bool found_literal_bold = false;
    bool any_italic = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text.find("<i>tag</i>") != std::string::npos && run.style.bold_override) found_literal_bold = true;
      if (run.style.italic_override) any_italic = true;
    }
    t.check(found_literal_bold, "escape: escaped i remains literal inside bold");
    t.check(!any_italic, "escape: escaped i inside bold does not enable italic");
  }

  {
    auto cell = parse_inline_markup("a\\<br/>b");
    bool has_soft_break = false;
    std::string merged;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "\n") has_soft_break = true;
      merged += run.text;
    }
    t.check(!has_soft_break, "escape: escaped br does not create soft break");
    t.check_eq(merged, std::string("a<br/>b"), "escape: escaped br rendered literally");
  }

  // --- Unknown tags are ignored, text content preserved ---
  {
    auto cell = parse_inline_markup("<span>text</span>");
    t.check_eq(cell.paragraphs.size(), size_t(1), "unknown tag: 1 paragraph");
    bool found_text = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text.find("text") != std::string::npos) found_text = true;
    }
    t.check(found_text, "unknown tag: text content preserved");
  }

  // --- Text with no tags at all ---
  {
    auto cell = parse_inline_markup("value = 42");
    t.check_eq(cell.paragraphs.size(), size_t(1), "no tags: 1 paragraph");
    t.check_eq(cell.paragraphs[0].runs.size(), size_t(1), "no tags: 1 run");
    t.check_eq(cell.paragraphs[0].runs[0].text, std::string("value = 42"), "no tags: text intact");
  }

  // --- Nested: <b><s>both</s></b> → bold AND strikethrough ---
  {
    auto cell = parse_inline_markup("<b><s>bold struck</s></b>");
    bool found = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text == "bold struck" && run.style.bold_override && run.style.strikethrough_override) found = true;
    }
    t.check(found, "nested b+s: run has both bold_override and strikethrough_override");
  }

  // --- BUG-B: Same-type nesting preserves outer tag ---
  {
    auto cell = parse_inline_markup("<b>outer <b>inner</b> still bold</b>");
    t.check_eq(cell.paragraphs.size(), size_t(1), "same-type nesting: 1 paragraph");
    // "still bold" must still have bold_override = true
    bool found_still_bold = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text.find("still bold") != std::string::npos) { found_still_bold = run.style.bold_override; }
    }
    t.check(found_still_bold, "same-type nesting: 'still bold' has bold_override");
  }

  // --- BUG-B: Same-type nesting with italic ---
  {
    auto cell = parse_inline_markup("<i>a <i>b</i> c</i>");
    bool c_italic = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text.find("c") != std::string::npos) { c_italic = run.style.italic_override; }
    }
    t.check(c_italic, "same-type nesting italic: 'c' has italic_override");
  }

  // --- BUG-B: Mixed nesting — bold wraps italic wraps bold ---
  {
    auto cell = parse_inline_markup("<b>A <i>B <b>C</b> D</i> E</b>");
    // "D" should be bold+italic, "E" should be bold only
    bool d_bold = false, d_italic = false, e_bold = false, e_no_italic = false;
    for (const auto &run : cell.paragraphs[0].runs) {
      if (run.text.find("D") != std::string::npos) {
        d_bold = run.style.bold_override;
        d_italic = run.style.italic_override;
      }
      if (run.text.find("E") != std::string::npos) {
        e_bold = run.style.bold_override;
        e_no_italic = !run.style.italic_override;
      }
    }
    t.check(d_bold && d_italic, "mixed nesting: 'D' bold+italic");
    t.check(e_bold && e_no_italic, "mixed nesting: 'E' bold only");
  }

  // --- get_plain_text ---
  t.check_eq(get_plain_text("hello"), std::string("hello"), "plain_text: no markup passthrough");
  t.check_eq(get_plain_text(""), std::string(""), "plain_text: empty string");
  t.check_eq(get_plain_text("<b>bold</b>"), std::string("bold"), "plain_text: strip bold");
  t.check_eq(get_plain_text("<i>ital</i>"), std::string("ital"), "plain_text: strip italic");
  t.check_eq(get_plain_text("<u>under</u>"), std::string("under"), "plain_text: strip underline");
  t.check_eq(get_plain_text("<s>struck</s>"), std::string("struck"), "plain_text: strip strikethrough");
  t.check_eq(get_plain_text("<sup>1</sup>"), std::string("1"), "plain_text: strip sup");
  t.check_eq(get_plain_text("<sub>2</sub>"), std::string("2"), "plain_text: strip sub");
  t.check_eq(get_plain_text("x<br/>y"), std::string("x y"), "plain_text: br/ to space");
  t.check_eq(get_plain_text("x<br>y"), std::string("x y"), "plain_text: br to space");
  t.check_eq(get_plain_text("<p>A</p><p>B</p>"), std::string("AB"), "plain_text: p tags stripped");
  t.check_eq(get_plain_text("<b><i>nested</i></b>"), std::string("nested"), "plain_text: nested tags");
  t.check_eq(get_plain_text("Hello <b>world</b>!"), std::string("Hello world!"), "plain_text: mixed content");
  t.check_eq(get_plain_text("a<br/>b<br/>c"), std::string("a b c"), "plain_text: multiple br");
  t.check_eq(get_plain_text("no < tags > here"), std::string("no < tags > here"),
             "plain_text: angle brackets not tags");
  t.check_eq(get_plain_text("<B>UPPER</B>"), std::string("UPPER"), "plain_text: case-insensitive");
  t.check_eq(get_plain_text("\\<i>ital\\</i>"), std::string("<i>ital</i>"), "plain_text: escaped i literal");
  t.check_eq(get_plain_text("a\\<br/>b"), std::string("a<br/>b"), "plain_text: escaped br literal");
  t.check_eq(get_plain_text("\\<p>A\\</p>"), std::string("<p>A</p>"), "plain_text: escaped p literal");

  return t.to_list();
}

// ---------------------------------------------------------------------------
// XML writer tests
// ---------------------------------------------------------------------------

// [[Rcpp::export]]
Rcpp::List cpp_test_xml_writer() {
  TestResult t;

  // --- XML declaration ---
  {
    XmlWriter w;
    w.write_declaration();
    const std::string &xml = w.str();
    t.check(xml.find("<?xml") != std::string::npos, "declaration: ?xml present");
    t.check(xml.find("UTF-8") != std::string::npos, "declaration: UTF-8 encoding");
    t.check(xml.find("standalone=\"yes\"") != std::string::npos, "declaration: standalone=yes");
  }

  // --- Self-closing element (no content) ---
  {
    XmlWriter w;
    w.start_element("w:p");
    w.end_element();
    t.check_eq(w.str(), std::string("<w:p/>"), "self-close via end_element: <w:p/>");
  }

  // --- Element with text content ---
  {
    XmlWriter w;
    w.start_element("w:t");
    w.text("Hello");
    w.end_element();
    t.check_eq(w.str(), std::string("<w:t>Hello</w:t>"), "element_with_text: <w:t>Hello</w:t>");
  }

  // --- String attribute ---
  {
    XmlWriter w;
    w.start_element("w:jc");
    w.attribute("w:val", std::string("center"));
    w.end_element();
    t.check_eq(w.str(), std::string("<w:jc w:val=\"center\"/>"), "string attribute");
  }

  // --- Integer attribute ---
  {
    XmlWriter w;
    w.start_element("w:sz");
    w.attribute("w:val", int64_t(24));
    w.end_element();
    t.check_eq(w.str(), std::string("<w:sz w:val=\"24\"/>"), "int64 attribute");
  }

  // --- Multiple attributes on one element ---
  {
    XmlWriter w;
    w.start_element("w:rPr");
    w.attribute("a", std::string("1"));
    w.attribute("b", std::string("2"));
    w.end_element();
    const std::string &xml = w.str();
    t.check(xml.find("a=\"1\"") != std::string::npos, "multiple attrs: a=1");
    t.check(xml.find("b=\"2\"") != std::string::npos, "multiple attrs: b=2");
  }

  // --- self_closing_element ---
  {
    XmlWriter w;
    w.self_closing_element("w:br");
    t.check_eq(w.str(), std::string("<w:br/>"), "self_closing_element: <w:br/>");
  }

  // --- Nested elements ---
  {
    XmlWriter w;
    w.start_element("w:p");
    w.start_element("w:r");
    w.start_element("w:t");
    w.text("text");
    w.end_element(); // w:t
    w.end_element(); // w:r
    w.end_element(); // w:p
    t.check_eq(w.str(), std::string("<w:p><w:r><w:t>text</w:t></w:r></w:p>"), "nested 3-level elements");
  }

  // --- Text escaping: & ---
  {
    XmlWriter w;
    w.start_element("w:t");
    w.text("a & b");
    w.end_element();
    t.check(w.str().find("&amp;") != std::string::npos, "text escape: & → &amp;");
  }

  // --- Text escaping: < ---
  {
    XmlWriter w;
    w.start_element("w:t");
    w.text("a < b");
    w.end_element();
    t.check(w.str().find("&lt;") != std::string::npos, "text escape: < → &lt;");
  }

  // --- Text escaping: > ---
  {
    XmlWriter w;
    w.start_element("w:t");
    w.text("a > b");
    w.end_element();
    t.check(w.str().find("&gt;") != std::string::npos, "text escape: > → &gt;");
  }

  // --- Attribute escaping: " ---
  {
    XmlWriter w;
    w.start_element("w:t");
    w.attribute("val", std::string("say \"hi\""));
    w.end_element();
    t.check(w.str().find("&quot;") != std::string::npos, "attr escape: \" → &quot;");
  }

  // --- element_with_text convenience method ---
  {
    XmlWriter w;
    w.element_with_text("w:t", "content");
    const std::string &xml = w.str();
    t.check(xml.find("<w:t") != std::string::npos, "element_with_text: tag present");
    t.check(xml.find("content") != std::string::npos, "element_with_text: content present");
  }

  // --- element_with_attr convenience: string overload ---
  {
    XmlWriter w;
    w.element_with_attr("w:jc", "w:val", std::string("center"));
    const std::string &xml = w.str();
    t.check(xml.find("<w:jc") != std::string::npos, "element_with_attr str: tag");
    t.check(xml.find("w:val=\"center\"") != std::string::npos, "element_with_attr str: attr");
  }

  // --- element_with_attr convenience: int overload ---
  {
    XmlWriter w;
    w.element_with_attr("w:sz", "w:val", int64_t(18));
    t.check(w.str().find("w:val=\"18\"") != std::string::npos, "element_with_attr int: attr=18");
  }

  // --- raw() writes unescaped XML fragment ---
  {
    XmlWriter w;
    w.start_element("w:p");
    w.raw("<w:pPr/>");
    w.end_element();
    t.check(w.str().find("<w:pPr/>") != std::string::npos, "raw: unescaped fragment");
  }

  // --- comment() ---
  {
    XmlWriter w;
    w.comment("test comment");
    const std::string &xml = w.str();
    t.check(xml.find("<!--") != std::string::npos, "comment: opening <!--");
    t.check(xml.find("-->") != std::string::npos, "comment: closing -->");
    t.check(xml.find("test comment") != std::string::npos, "comment: text content");
  }

  // --- clear() resets buffer and tag stack ---
  {
    XmlWriter w;
    w.start_element("w:p");
    w.end_element();
    w.clear();
    t.check_eq(w.str(), std::string(""), "clear: buffer empty");
    t.check_eq(w.depth(), size_t(0), "clear: depth=0");
  }

  // --- depth() tracking ---
  {
    XmlWriter w;
    t.check_eq(w.depth(), size_t(0), "depth: initial=0");
    w.start_element("a");
    t.check_eq(w.depth(), size_t(1), "depth: after start=1");
    w.start_element("b");
    t.check_eq(w.depth(), size_t(2), "depth: after nested start=2");
    w.end_element();
    t.check_eq(w.depth(), size_t(1), "depth: after one end=1");
    w.end_element();
    t.check_eq(w.depth(), size_t(0), "depth: back to 0");
  }

  // --- namespace_decl ---
  {
    XmlWriter w;
    w.start_element("w:document");
    w.namespace_decl("w", "http://schemas.openxmlformats.org/wordprocessingml/2006/main");
    w.end_element();
    t.check(w.str().find("xmlns:w=") != std::string::npos, "namespace_decl: xmlns:w present");
  }

  // --- take() moves buffer out and leaves writer empty ---
  {
    XmlWriter w;
    w.start_element("w:p");
    w.end_element();
    std::string xml = w.take();
    t.check_eq(xml, std::string("<w:p/>"), "take: returned xml");
    t.check_eq(w.str(), std::string(""), "take: buffer cleared after take");
  }

  // --- Error: attribute() after start tag is closed ---
  {
    XmlWriter w;
    w.start_element("w:p");
    w.text("x"); // closes the start tag → start_tag_open_ = false
    t.check_throw([&w]() { w.attribute("a", std::string("b")); }, "error: attribute() after text throws");
  }

  // --- Error: end_element() with empty stack ---
  {
    XmlWriter w;
    t.check_throw([&w]() { w.end_element(); }, "error: end_element() on empty stack throws");
  }

  return t.to_list();
}

// ---------------------------------------------------------------------------
// is_safe_numeric_format tests
// ---------------------------------------------------------------------------

// [[Rcpp::export]]
Rcpp::List cpp_test_format_validator() {
  TestResult t;

  // Valid format strings
  t.check(is_safe_numeric_format("%d"), "fmt: %d");
  t.check(is_safe_numeric_format("%i"), "fmt: %i");
  t.check(is_safe_numeric_format("%u"), "fmt: %u");
  t.check(is_safe_numeric_format("%f"), "fmt: %f");
  t.check(is_safe_numeric_format("%e"), "fmt: %e");
  t.check(is_safe_numeric_format("%g"), "fmt: %g");
  t.check(is_safe_numeric_format("%G"), "fmt: %G");
  t.check(is_safe_numeric_format("%x"), "fmt: %x");
  t.check(is_safe_numeric_format("%X"), "fmt: %X");
  t.check(is_safe_numeric_format("%o"), "fmt: %o");

  // Width and precision
  t.check(is_safe_numeric_format("%.2f"), "fmt: %.2f");
  t.check(is_safe_numeric_format("%10d"), "fmt: %10d");
  t.check(is_safe_numeric_format("%10.3f"), "fmt: %10.3f");
  t.check(is_safe_numeric_format("%.17g"), "fmt: %.17g");

  // Flags
  t.check(is_safe_numeric_format("%-10d"), "fmt: %-10d");
  t.check(is_safe_numeric_format("%+.2f"), "fmt: %+.2f");
  t.check(is_safe_numeric_format("%010d"), "fmt: %010d");
  t.check(is_safe_numeric_format("% d"), "fmt: % d");
  t.check(is_safe_numeric_format("%#x"), "fmt: %#x");

  // Prefix and suffix
  t.check(is_safe_numeric_format("Value: %d"), "fmt: prefix %d");
  t.check(is_safe_numeric_format("%d units"), "fmt: %d suffix");
  t.check(is_safe_numeric_format("($%.2f)"), "fmt: ($%.2f)");

  // Invalid: no conversion specifier
  t.check(!is_safe_numeric_format(""), "fmt reject: empty");
  t.check(!is_safe_numeric_format("hello"), "fmt reject: no %");
  t.check(!is_safe_numeric_format("%%"), "fmt reject: %%");

  // Invalid: unsafe specifiers
  t.check(!is_safe_numeric_format("%s"), "fmt reject: %s");
  t.check(!is_safe_numeric_format("%n"), "fmt reject: %n");
  t.check(!is_safe_numeric_format("%p"), "fmt reject: %p");
  t.check(!is_safe_numeric_format("%c"), "fmt reject: %c");

  // Invalid: multiple conversions
  t.check(!is_safe_numeric_format("%d %d"), "fmt reject: %d %d");
  t.check(!is_safe_numeric_format("%d%%"), "fmt reject: %d%%");

  return t.to_list();
}
