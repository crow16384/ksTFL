// kstfl/inline_parser.h — Parse inline markup tags in cell values
//
// Supported tags: <sup>, <sub>, <b>, <i>, <u>, <br>, <p>
// Stack-based state machine (no regex).
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#ifndef KSTFL_INLINE_PARSER_H
#define KSTFL_INLINE_PARSER_H

#include "types.h"
#include <string>

namespace kstfl {

/// Parse a cell value that may contain inline markup.
/// Returns a ParsedCell with paragraphs and runs.
ParsedCell parse_inline_markup(const std::string& text);

/// Check if a string contains any inline markup tags.
bool has_inline_markup(const std::string& text);

}  // namespace kstfl

#endif  // KSTFL_INLINE_PARSER_H
