// kstfl/inline_parser.h — Parse inline markup tags in cell values
//
// Supported tags: <sup>, <sub>, <b>, <i>, <u>, <s>, <br>, <p>
// Escape literal '<' before a tag-like sequence with '\<' (e.g. "\<i>").
// Stack-based state machine (no regex).
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_INLINE_PARSER_H
#define KSTFL_INLINE_PARSER_H

#include "types.h"
#include <string>

namespace kstfl {

/// Parse a cell value that may contain inline markup.
/// Returns a ParsedCell with paragraphs and runs.
[[nodiscard]] ParsedCell parse_inline_markup(const std::string &text);

/// Check if a string contains any inline markup tags.
[[nodiscard]] bool has_inline_markup(const std::string &text);

/// Return plain text with all inline markup stripped (for TOC entry text,
/// etc.).
[[nodiscard]] std::string get_plain_text(const std::string &text);

} // namespace kstfl

#endif // KSTFL_INLINE_PARSER_H
