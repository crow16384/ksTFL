// kstfl/docx_toc.cpp — TOC and field emission for DocxEmitter

#include "docx_emitter.h"
#include <cstdio>

namespace kstfl {

// ---------------------------------------------------------------------------
// Page field (PAGE)
// ---------------------------------------------------------------------------

void DocxEmitter::emit_page_field(XmlWriter& w) const {
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "begin");
    w.end_element();
    w.end_element();

    w.start_element("w:r");
    w.start_element("w:instrText");
    w.attribute("xml:space", "preserve");
    w.text(" PAGE ");
    w.end_element();
    w.end_element();

    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "separate");
    w.end_element();
    w.end_element();

    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "end");
    w.end_element();
    w.end_element();
}

// ---------------------------------------------------------------------------
// NUMPAGES field
// ---------------------------------------------------------------------------

void DocxEmitter::emit_numpages_field(XmlWriter& w) const {
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "begin");
    w.end_element();
    w.end_element();

    w.start_element("w:r");
    w.start_element("w:instrText");
    w.attribute("xml:space", "preserve");
    w.text(" NUMPAGES ");
    w.end_element();
    w.end_element();

    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "separate");
    w.end_element();
    w.end_element();

    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "end");
    w.end_element();
    w.end_element();
}

// ---------------------------------------------------------------------------
// TC (Table of Contents Entry) field runs (no w:p wrapper — caller owns the paragraph).
//
// TC fields must NOT use w:vanish on their runs. Word hides TC fields via its own
// internal mechanism; adding w:vanish causes Word to skip them during TOC generation.
// Structure: bookmarkStart → begin → instrText → separate → end → bookmarkEnd
// The 'separate' fldChar is required even though TC fields have no visible result;
// without it Word treats the field as malformed and renders instrText as visible text.
//
// The w:bookmarkStart/End pair (name "_TocXXXXXX") is required for two reasons:
//   1. When the TOC field uses \h, Word generates internal hyperlinks that point to
//      these bookmarks — not external file paths — so PDF navigation works correctly.
//   2. Word's "Generate Bookmarks" option in PDF export becomes active when the
//      document contains named bookmarks, enabling clickable PDF bookmarks.
// ---------------------------------------------------------------------------

void DocxEmitter::emit_tc_field(XmlWriter& w, const std::string& entry_text, int level) const {
    // Allocate a unique bookmark ID and build the _Toc name.
    int bm_id = ++toc_bookmark_counter_;
    // Format as _Toc + zero-padded 9-digit number (matches Word's own naming).
    char bm_name[32];
    std::snprintf(bm_name, sizeof(bm_name), "_Toc%09d", bm_id);

    // Escape double-quotes for Word field code: " -> ""
    std::string escaped;
    escaped.reserve(entry_text.size() + 4);
    for (char c : entry_text) {
        if (c == '"') escaped += "\"\"";
        else escaped += c;
    }
    // Leading and trailing spaces required by OOXML field instruction syntax.
    // No \f type — untyped TC entries are collected by { TOC \f } (no letter).
    std::string instr = " TC \"" + escaped + "\" \\l " + std::to_string(level) + " ";

    // bookmarkStart — wraps the TC field so the TOC \h switch can target it
    w.start_element("w:bookmarkStart");
    w.attribute("w:id", std::to_string(bm_id));
    w.attribute("w:name", bm_name);
    w.end_element();

    // begin — no w:rPr, no w:vanish
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "begin");
    w.end_element();
    w.end_element();

    // instrText
    w.start_element("w:r");
    w.start_element("w:instrText");
    w.attribute("xml:space", "preserve");
    w.text(instr);
    w.end_element();
    w.end_element();

    // separate — required so Word hides the instrText
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "separate");
    w.end_element();
    w.end_element();

    // end
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "end");
    w.end_element();
    w.end_element();

    // bookmarkEnd
    w.start_element("w:bookmarkEnd");
    w.attribute("w:id", std::to_string(bm_id));
    w.end_element();
}

// ---------------------------------------------------------------------------
// TOC page — a separate Word section prepended before all specs.
//
// Structure emitted into w:body:
//   [optional] <w:p> title paragraph (e.g. "Table of Contents")
//   <w:p> containing the { TOC \f \h \z } complex field
//   <w:p> section-break paragraph (nextPage) that ends the TOC section
//
// The TOC field uses:
//   \f  — collect all untyped TC fields (no letter = all TC entries)
//   \h  — make entries hyperlinks; safe because each TC field paragraph carries a
//          w:bookmarkStart/End (_TocXXXXXX), so Word generates internal #anchor
//          links rather than external file:// paths — no security prompt, and PDF
//          navigation (Ctrl+Click in Word, clickable bookmarks in PDF) works correctly.
//   \z  — hide tab leader and page numbers in Web Layout view
// ---------------------------------------------------------------------------

void DocxEmitter::emit_toc_page(XmlWriter& w,
                                 const std::string& toc_title,
                                 const PageConfig& page,
                                 const std::string& header_rid,
                                 const std::string& footer_rid) const
{
    // Optional title paragraph
    if (!toc_title.empty()) {
        StyleResolver toc_resolver(tmpl_, StyleMap{});
        StyleDef toc_title_style = toc_resolver.resolve_toc_title_style();
        stamp_exact_line_height(toc_title_style);
        emit_paragraph(w, toc_title, toc_title_style);
    }

    // TOC field paragraph: { TOC \f \z }
    // \f  — collect all untyped TC fields
    // \z  — hide tab/page numbers in Web Layout view
    // No \h — omitting hyperlinks avoids the "fields that may refer to other files" prompt.
    // No fldLock — field must remain unlocked so the user can press F9 to update it.
    // Complex field: begin → instrText → separate → (result placeholder) → end
    w.start_element("w:p");

    // begin
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "begin");
    w.end_element();
    w.end_element();

    // instrText — \f \h \z: collect TC fields, make entries hyperlinks, hide in Web view.
    // \h is safe here because TC field paragraphs carry _Toc bookmarks, so Word
    // generates internal #anchor links (not file:// paths) — no security prompt.
    w.start_element("w:r");
    w.start_element("w:instrText");
    w.attribute("xml:space", "preserve");
    w.text(" TOC \\f \\h \\z ");
    w.end_element();
    w.end_element();

    // separate
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "separate");
    w.end_element();
    w.end_element();

    // placeholder result run (empty — Word fills this on F9 update)
    w.start_element("w:r");
    w.start_element("w:rPr");
    w.self_closing_element("w:noProof");
    w.end_element();
    w.end_element();

    // end
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "end");
    w.end_element();
    w.end_element();

    w.end_element();  // w:p (TOC field)

    // Section-break paragraph — ends the TOC section with a nextPage break.
    // This paragraph carries the sectPr for the TOC section (same page config as first spec).
    w.start_element("w:p");
    w.start_element("w:pPr");
    emit_section_props(w, page, header_rid, footer_rid, /*continuous=*/false, /*is_body_level=*/false);
    w.end_element();  // w:pPr
    w.end_element();  // w:p
}

}  // namespace kstfl
