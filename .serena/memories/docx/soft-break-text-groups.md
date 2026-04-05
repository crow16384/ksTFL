DOCX soft-break rendering for multi-string text groups:
- Contract: one TextGroup stays one Word paragraph; multiple strings inside group.text become soft line breaks via <w:br/>.
- Non-table path: src/kstfl/docx_content.cpp emit_text_groups() now parses each text element separately, emits one <w:p>, inserts <w:br/> between elements, and keeps TC field in the same paragraph when toc_level > 0.
- Table path: src/kstfl/docx_page.cpp emit_page() titles and subtitles now use per-element parsed content and the same soft-break behavior; separate groups still produce separate paragraphs.
- Pre-parsing: src/kstfl/docx_document.cpp now stores parsed_titles as vector<vector<ParsedCell>> so table title elements are parsed individually.
- Interface: src/kstfl/docx_emitter.h emit_page() signature updated to take vector<vector<ParsedCell>>.
- Footnotes/body text/footer sections inherit the fix through emit_text_groups().
- Verified previously by generated DOCX XML: first title paragraph contains text run + <w:br/> + second text run; second add_title() call stays a separate <w:p>.
- Serena status on 2026-03-12: list/write memory work, but get_symbols_overview failed with internal error `AttributeError: Project object has no attribute _lsp_init_error`.