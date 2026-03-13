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

    // TOC field paragraph: { TOC \o "1-9" \h \z }
    // \o "1-9" — collect paragraphs by outline level (body title/subtitle styles with w:outlineLvl)
    // \h       — hyperlink each entry to the heading paragraph
    // \z       — hide tab/page numbers in Web Layout view
    // No fldLock — field must remain unlocked so the user can press F9 to update it.
    // Complex field: begin → instrText → separate → (result placeholder) → end
    w.start_element("w:p");

    // begin
    w.start_element("w:r");
    w.start_element("w:fldChar");
    w.attribute("w:fldCharType", "begin");
    w.end_element();
    w.end_element();

    // instrText — \o "1-9" \h \z: collect by outline level, hyperlinks, hide in Web view
    w.start_element("w:r");
    w.start_element("w:instrText");
    w.attribute("xml:space", "preserve");
    w.text(" TOC \\o \"1-9\" \\h \\z ");
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
