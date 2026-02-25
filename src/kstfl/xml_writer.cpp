// kstfl/xml_writer.cpp — Streaming XML writer implementation
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include "xml_writer.h"
#include "types.h"
#include <stdexcept>

namespace kstfl {

XmlWriter::XmlWriter() {
    buffer_.reserve(64 * 1024);  // Pre-allocate 64KB
}

void XmlWriter::write_declaration() {
    buffer_ += "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
}

void XmlWriter::start_element(const std::string& name) {
    close_start_tag();
    buffer_ += '<';
    buffer_ += name;
    tag_stack_.push_back(name);
    start_tag_open_ = true;
}

void XmlWriter::end_element() {
    if (tag_stack_.empty()) {
        throw RenderError("XmlWriter::end_element() called with empty tag stack");
    }
    const std::string& tag = tag_stack_.back();
    if (start_tag_open_) {
        // Write self-closing tag instead
        buffer_ += "/>";
        start_tag_open_ = false;
    } else {
        buffer_ += "</";
        buffer_ += tag;
        buffer_ += '>';
    }
    tag_stack_.pop_back();
}

void XmlWriter::self_closing_element(const std::string& name) {
    close_start_tag();
    buffer_ += '<';
    buffer_ += name;
    buffer_ += "/>";
}

void XmlWriter::attribute(const std::string& name, const std::string& value) {
    if (!start_tag_open_) {
        throw RenderError("XmlWriter::attribute() called outside of start tag");
    }
    buffer_ += ' ';
    buffer_ += name;
    buffer_ += "=\"";
    buffer_ += escape_attr(value);
    buffer_ += '"';
}

void XmlWriter::attribute(const std::string& name, int64_t value) {
    attribute(name, std::to_string(value));
}

void XmlWriter::text(const std::string& content) {
    close_start_tag();
    buffer_ += escape_text(content);
}

void XmlWriter::raw(const std::string& xml) {
    close_start_tag();
    buffer_ += xml;
}

void XmlWriter::comment(const std::string& text) {
    close_start_tag();
    buffer_ += "<!-- ";
    buffer_ += text;  // NOTE: caller must ensure no "--" in text
    buffer_ += " -->";
}

void XmlWriter::namespace_decl(const std::string& prefix, const std::string& uri) {
    if (prefix.empty()) {
        attribute("xmlns", uri);
    } else {
        attribute("xmlns:" + prefix, uri);
    }
}

void XmlWriter::element_with_text(const std::string& name, const std::string& content) {
    start_element(name);
    text(content);
    end_element();
}

void XmlWriter::element_with_attr(const std::string& name,
                                   const std::string& attr_name,
                                   const std::string& attr_value) {
    close_start_tag();
    buffer_ += '<';
    buffer_ += name;
    buffer_ += ' ';
    buffer_ += attr_name;
    buffer_ += "=\"";
    buffer_ += escape_attr(attr_value);
    buffer_ += "\"/>";
}

void XmlWriter::element_with_attr(const std::string& name,
                                   const std::string& attr_name,
                                   int64_t attr_value) {
    element_with_attr(name, attr_name, std::to_string(attr_value));
}

const std::string& XmlWriter::str() const {
    return buffer_;
}

std::string XmlWriter::take() {
    std::string result = std::move(buffer_);
    clear();
    return result;
}

void XmlWriter::clear() {
    buffer_.clear();
    tag_stack_.clear();
    start_tag_open_ = false;
}

size_t XmlWriter::depth() const {
    return tag_stack_.size();
}

void XmlWriter::close_start_tag() {
    if (start_tag_open_) {
        buffer_ += '>';
        start_tag_open_ = false;
    }
}

std::string XmlWriter::escape_text(const std::string& s) {
    std::string result;
    result.reserve(s.size() + s.size() / 8);
    for (char c : s) {
        switch (c) {
            case '&':  result += "&amp;";  break;
            case '<':  result += "&lt;";   break;
            case '>':  result += "&gt;";   break;
            default:   result += c;        break;
        }
    }
    return result;
}

std::string XmlWriter::escape_attr(const std::string& s) {
    std::string result;
    result.reserve(s.size() + s.size() / 8);
    for (char c : s) {
        switch (c) {
            case '&':  result += "&amp;";  break;
            case '<':  result += "&lt;";   break;
            case '>':  result += "&gt;";   break;
            case '"':  result += "&quot;"; break;
            case '\'': result += "&apos;"; break;
            default:   result += c;        break;
        }
    }
    return result;
}

}  // namespace kstfl
