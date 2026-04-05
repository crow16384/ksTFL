// kstfl/inline_parser.cpp — Stack-based inline markup parser
//
// Supported tags: <sup>, <sub>, <b>, <i>, <u>, <s>, <br>, <p>
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "inline_parser.h"
#include <algorithm>
#include <cctype>
#include <stack>
#include <string_view>
#include <unordered_map>

namespace kstfl {

// ---------------------------------------------------------------------------
// Tag detection
// ---------------------------------------------------------------------------

/// Recognized inline tag names.
enum class TagType {
  Unknown,
  Sup,           // <sup>
  Sub,           // <sub>
  Bold,          // <b>
  Italic,        // <i>
  Underline,     // <u>
  Strikethrough, // <s>
  Br,            // <br> or <br/>
  Para           // <p>
};

static TagType classify_tag(const std::string &name) {
  static const std::unordered_map<std::string_view, TagType> tag_map{
      {"sup", TagType::Sup},     {"sub", TagType::Sub},         {"b", TagType::Bold}, {"i", TagType::Italic},
      {"u", TagType::Underline}, {"s", TagType::Strikethrough}, {"br", TagType::Br},  {"p", TagType::Para}};
  // Tag names are at most 3 chars; use a stack buffer to avoid heap allocation.
  char lower_buf[8];
  size_t len = std::min(name.size(), sizeof(lower_buf) - 1);
  for (size_t i = 0; i < len; ++i)
    lower_buf[i] = static_cast<char>(std::tolower(static_cast<unsigned char>(name[i])));
  lower_buf[len] = '\0';
  auto it = tag_map.find(std::string_view{lower_buf, len});
  return (it != tag_map.end()) ? it->second : TagType::Unknown;
}

// ---------------------------------------------------------------------------
// Quick check
// ---------------------------------------------------------------------------

bool has_inline_markup(const std::string &text) {
  size_t pos = 0;
  while ((pos = text.find('<', pos)) != std::string::npos) {
    size_t start = pos + 1;
    if (start >= text.size()) return false;
    // Skip optional '/'
    if (text[start] == '/') start++;
    if (start >= text.size()) {
      pos++;
      continue;
    }
    // Extract tag name (sequence of alpha chars)
    size_t name_start = start;
    while (start < text.size() && std::isalpha(static_cast<unsigned char>(text[start])))
      start++;
    if (start == name_start) {
      pos++;
      continue;
    }
    std::string tag_name = text.substr(name_start, start - name_start);
    if (classify_tag(tag_name) != TagType::Unknown) return true;
    pos++;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Parser implementation
// ---------------------------------------------------------------------------

/// State machine for parsing inline markup.
/// State is derived from the tag stack — each active tag contributes its
/// formatting flag.  This correctly handles nested same-type tags:
/// e.g. <b>outer <b>inner</b> still bold</b>.
struct ParserState {
  bool bold = false;
  bool italic = false;
  bool underline = false;
  bool strikethrough = false;
  bool superscript = false;
  bool subscript = false;

  InlineRunStyle to_run_style() const {
    InlineRunStyle rs;
    rs.bold_override = bold;
    rs.italic_override = italic;
    rs.underline_override = underline;
    rs.strikethrough_override = strikethrough;
    rs.superscript = superscript;
    rs.subscript = subscript;
    return rs;
  }

  /// Rebuild state from the tag stack.  Called after every push/pop.
  static ParserState from_stack(const std::stack<TagType> &stk) {
    ParserState s;
    // Walk the stack contents via a copy (stack has no iterator).
    std::stack<TagType> tmp = stk;
    while (!tmp.empty()) {
      switch (tmp.top()) {
        using enum TagType;
      case Bold:
        s.bold = true;
        break;
      case Italic:
        s.italic = true;
        break;
      case Underline:
        s.underline = true;
        break;
      case Strikethrough:
        s.strikethrough = true;
        break;
      case Sup:
        s.superscript = true;
        break;
      case Sub:
        s.subscript = true;
        break;
      default:
        break;
      }
      tmp.pop();
    }
    // Sub clears super (mutual exclusion) — if both are on the stack,
    // the most-recently-pushed one wins.  Re-walk to enforce.
    if (s.superscript && s.subscript) {
      // Find which was pushed later by walking the original stack
      // (top = most recent).
      std::stack<TagType> tmp2 = stk;
      while (!tmp2.empty()) {
        if (tmp2.top() == TagType::Sub) {
          s.superscript = false;
          break;
        }
        if (tmp2.top() == TagType::Sup) {
          s.subscript = false;
          break;
        }
        tmp2.pop();
      }
    }
    return s;
  }
};

/// Extract tag name from position after '<'. Returns tag name (lowered) and
/// advances `pos` past the closing '>'. Sets `is_closing` if it's a </tag>.
/// Sets `is_self_closing` if it ends with />.
static std::string extract_tag(const std::string &text, size_t &pos, bool &is_closing, bool &is_self_closing) {
  is_closing = false;
  is_self_closing = false;

  if (pos >= text.size()) return "";

  // Skip '<'
  // size_t start = pos;
  if (text[pos] == '<') ++pos;

  // Check closing tag
  if (pos < text.size() && text[pos] == '/') {
    is_closing = true;
    ++pos;
  } else {
    // If not closing, must start with alpha for valid tag
    if (pos >= text.size() || !std::isalpha(static_cast<unsigned char>(text[pos]))) {
      // Not a tag, let caller treat as literal '<'
      --pos; // step back so main loop sees '<' as normal char
      return "";
    }
  }

  // Extract tag name (alphanumeric)
  std::string name;
  size_t name_start = pos;
  while (pos < text.size() && std::isalpha(static_cast<unsigned char>(text[pos]))) {
    name += text[pos++];
  }

  // Only allow tags with no attributes/whitespace after name
  // Next char must be '>' or '/' (for self-closing)
  if (name.empty() || pos >= text.size() || (text[pos] != '>' && text[pos] != '/')) {
    // Not a valid tag, roll back to before '<'
    pos = name_start - (is_closing ? 2 : 1); // back to '<' or '</'
    return "";
  }

  // Handle self-closing
  if (text[pos] == '/' && pos + 1 < text.size() && text[pos + 1] == '>') {
    is_self_closing = true;
    pos += 2;
    return name;
  }

  // Skip '>'
  if (text[pos] == '>') ++pos;

  return name;
}

/// Flush accumulated text into a run and add to current paragraph.
static void flush_run(const std::string &buffer, const ParserState &state, ParsedParagraph &para) {
  if (buffer.empty()) return;
  TextRun run;
  run.text = buffer;
  run.style = state.to_run_style();
  para.runs.push_back(std::move(run));
}

ParsedCell parse_inline_markup(const std::string &text) {
  ParsedCell cell;

  // Quick path: no '<' means no markup possible — skip tag classification
  if (text.find('<') == std::string::npos || !has_inline_markup(text)) {
    ParsedParagraph para;
    if (!text.empty()) {
      TextRun run;
      run.text = text;
      para.runs.push_back(std::move(run));
    }
    cell.paragraphs.push_back(std::move(para));
    return cell;
  }

  // Stack-based parser
  ParsedParagraph current_para;
  std::string buffer;
  ParserState state;
  std::stack<TagType> tag_stack;

  size_t pos = 0;
  while (pos < text.size()) {
    if (text[pos] == '<') {
      size_t tag_start = pos;
      bool is_closing = false;
      bool is_self_closing = false;
      std::string tag_name = extract_tag(text, pos, is_closing, is_self_closing);
      TagType type = classify_tag(tag_name);

      if (type == TagType::Unknown) {
        // Not a recognized tag — treat as literal text
        // Add everything from tag_start up to the next non-alphabetic or
        // non-tag char
        size_t recover_start = tag_start;
        size_t recover_end = tag_start + 1;
        // If after '<' there is a letter, capture the entire sequence of
        // letters (e.g. <b, <foo)
        if (tag_start + 1 < text.size() && std::isalpha(static_cast<unsigned char>(text[tag_start + 1]))) {
          recover_end = tag_start + 2;
          while (recover_end < text.size() && std::isalpha(static_cast<unsigned char>(text[recover_end]))) {
            ++recover_end;
          }
        }
        buffer += text.substr(recover_start, recover_end - recover_start);
        pos = recover_end;
        continue;
      }

      // Flush buffer before processing tag
      flush_run(buffer, state, current_para);
      buffer.clear();

      if (type == TagType::Br) {
        // <br> and <br/> insert a soft line break (\n run)
        // within the current paragraph — emitted as <w:br/> in OOXML.
        // Use <p> for actual paragraph breaks.
        TextRun br_run;
        br_run.text = "\n";
        br_run.style = state.to_run_style();
        current_para.runs.push_back(std::move(br_run));
        continue;
      }

      if (type == TagType::Para) {
        if (is_closing) {
          // End of paragraph
          cell.paragraphs.push_back(std::move(current_para));
          current_para = ParsedParagraph{};
        } else {
          // Start of new paragraph (flush current if has content)
          if (!current_para.runs.empty()) {
            cell.paragraphs.push_back(std::move(current_para));
            current_para = ParsedParagraph{};
          }
        }
        continue;
      }

      // Formatting tags
      if (is_closing) {
        // Pop the matching tag from the stack (search from top).
        // We use a temp stack to find and remove the first match.
        std::stack<TagType> tmp;
        bool found = false;
        while (!tag_stack.empty()) {
          if (!found && tag_stack.top() == type) {
            tag_stack.pop();
            found = true;
            break;
          }
          tmp.push(tag_stack.top());
          tag_stack.pop();
        }
        // Restore popped-off non-matching tags
        while (!tmp.empty()) {
          tag_stack.push(tmp.top());
          tmp.pop();
        }
      } else {
        // Push formatting state
        tag_stack.push(type);
      }
      // Rebuild state from the stack — handles same-type nesting correctly
      state = ParserState::from_stack(tag_stack);
    } else {
      buffer += text[pos++];
    }
  }

  // Flush remaining buffer
  flush_run(buffer, state, current_para);
  if (!current_para.runs.empty()) { cell.paragraphs.push_back(std::move(current_para)); }

  // Remove empty paragraphs (no runs)
  std::erase_if(cell.paragraphs, [](const ParsedParagraph &para) { return para.runs.empty(); });

  // If nothing remains after filtering — return the original string as a
  // single run
  if (cell.paragraphs.empty()) {
    if (!text.empty()) {
      ParsedParagraph para;
      TextRun run;
      run.text = text;
      para.runs.push_back(std::move(run));
      cell.paragraphs.push_back(std::move(para));
    }
  }
  return cell;
}

// ---------------------------------------------------------------------------
// Plain text extraction (strip all inline markup)
// ---------------------------------------------------------------------------

std::string get_plain_text(const std::string &text) {
  ParsedCell cell = parse_inline_markup(text);
  std::string out;
  for (const auto &para : cell.paragraphs) {
    for (const auto &run : para.runs) {
      for (char c : run.text) {
        out += (c == '\n') ? ' ' : c;
      }
    }
  }
  return out;
}

} // namespace kstfl
