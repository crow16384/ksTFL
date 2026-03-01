// kstfl/inline_parser.cpp — Stack-based inline markup parser
//
// Supported tags: <sup>, <sub>, <b>, <i>, <u>, <br>, <p>
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include "inline_parser.h"
#include <algorithm>
#include <cctype>
#include <stack>

namespace kstfl {

// ---------------------------------------------------------------------------
// Tag detection
// ---------------------------------------------------------------------------

/// Recognized inline tag names.
enum class TagType {
    Unknown,
    Sup,    // <sup>
    Sub,    // <sub>
    Bold,   // <b>
    Italic, // <i>
    Underline, // <u>
    Br,     // <br> or <br/>
    Para    // <p>
};

static TagType classify_tag(const std::string& name) {
    std::string lower;
    lower.reserve(name.size());
    for (char c : name)
        lower += static_cast<char>(std::tolower(static_cast<unsigned char>(c)));

    if (lower == "sup")       return TagType::Sup;
    if (lower == "sub")       return TagType::Sub;
    if (lower == "b")         return TagType::Bold;
    if (lower == "i")         return TagType::Italic;
    if (lower == "u")         return TagType::Underline;
    if (lower == "br")        return TagType::Br;
    if (lower == "p")         return TagType::Para;
    return TagType::Unknown;
}

// ---------------------------------------------------------------------------
// Quick check
// ---------------------------------------------------------------------------

bool has_inline_markup(const std::string& text) {
    return text.find('<') != std::string::npos;
}

// ---------------------------------------------------------------------------
// Parser implementation
// ---------------------------------------------------------------------------

/// State machine for parsing inline markup.
struct ParserState {
    bool bold = false;
    bool italic = false;
    bool underline = false;
    bool superscript = false;
    bool subscript = false;

    InlineRunStyle to_run_style() const {
        InlineRunStyle rs;
        rs.bold_override = bold;
        rs.italic_override = italic;
        rs.underline_override = underline;
        rs.superscript = superscript;
        rs.subscript = subscript;
        return rs;
    }
};

/// Extract tag name from position after '<'. Returns tag name (lowered) and
/// advances `pos` past the closing '>'. Sets `is_closing` if it's a </tag>.
/// Sets `is_self_closing` if it ends with />.
static std::string extract_tag(const std::string& text, size_t& pos,
                                bool& is_closing, bool& is_self_closing) {
    is_closing = false;
    is_self_closing = false;

    if (pos >= text.size()) return "";

    // Skip '<'
    size_t start = pos;
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
static void flush_run(const std::string& buffer,
                      const ParserState& state,
                      ParsedParagraph& para) {
    if (buffer.empty()) return;
    TextRun run;
    run.text = buffer;
    run.style = state.to_run_style();
    para.runs.push_back(std::move(run));
}

ParsedCell parse_inline_markup(const std::string& text) {
    ParsedCell cell;

    // Quick path: no markup
    if (!has_inline_markup(text)) {
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
                // Add everything from tag_start up to the next non-alphabetic or non-tag char
                size_t recover_start = tag_start;
                size_t recover_end = tag_start + 1;
                // If after '<' идёт буква, захватить всю последовательность букв (например, <b, <foo)
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
                // Line break within paragraph — add a break run
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
                // Pop formatting state
                if (!tag_stack.empty() && tag_stack.top() == type) {
                    tag_stack.pop();
                }
                switch (type) {
                    case TagType::Bold:      state.bold = false;        break;
                    case TagType::Italic:    state.italic = false;      break;
                    case TagType::Underline: state.underline = false;   break;
                    case TagType::Sup:       state.superscript = false; break;
                    case TagType::Sub:       state.subscript = false;   break;
                    default: break;
                }
            } else {
                // Push formatting state
                tag_stack.push(type);
                switch (type) {
                    case TagType::Bold:      state.bold = true;        break;
                    case TagType::Italic:    state.italic = true;      break;
                    case TagType::Underline: state.underline = true;   break;
                    case TagType::Sup:       state.superscript = true; break;
                    case TagType::Sub:       state.subscript = true; state.superscript = false; break;
                    default: break;
                }
            }
        } else {
            buffer += text[pos++];
        }
    }

    // Flush remaining buffer
    flush_run(buffer, state, current_para);
    if (!current_para.runs.empty()) {
        cell.paragraphs.push_back(std::move(current_para));
    }

    // Удаляем пустые параграфы (без runs)
    cell.paragraphs.erase(
        std::remove_if(cell.paragraphs.begin(), cell.paragraphs.end(),
            [](const ParsedParagraph& para) { return para.runs.empty(); }),
        cell.paragraphs.end());

    // Если после фильтрации ничего не осталось — возвращаем исходную строку как один run
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

}  // namespace kstfl
