// kstfl/xml_writer.cpp — Streaming XML writer implementation
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include "xml_writer.h"
#include "types.h"

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
    escape_attr_into(buffer_, value);
    buffer_ += '"';
}

void XmlWriter::attribute(const std::string& name, int64_t value) {
    attribute(name, std::to_string(value));
}

void XmlWriter::text(const std::string& content) {
    close_start_tag();
    escape_text_into(buffer_, content);
}

void XmlWriter::raw(const std::string& xml) {
    close_start_tag();
    buffer_ += xml;
}

void XmlWriter::comment(const std::string& text) {
    close_start_tag();
    buffer_ += "<!-- ";
    std::string sanitized = text;
    for (size_t pos = sanitized.find("--"); pos != std::string::npos;
         pos = sanitized.find("--", pos + 2)) {
        sanitized.replace(pos, 2, "- -");
    }
    buffer_ += sanitized;
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
    // For w:t elements, always preserve whitespace (OOXML requirement)
    if (name == "w:t") {
        attribute("xml:space", "preserve");
    }
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
    escape_attr_into(buffer_, attr_value);
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

void XmlWriter::escape_text_into(std::string& dest, const std::string& s) {
    dest.reserve(dest.size() + s.size() + s.size() / 8);
    for (char c : s) {
        switch (c) {
            case '&':  dest += "&amp;";  break;
            case '<':  dest += "&lt;";   break;
            case '>':  dest += "&gt;";   break;
            default:   dest += c;        break;
        }
    }
}

void XmlWriter::escape_attr_into(std::string& dest, const std::string& s) {
    dest.reserve(dest.size() + s.size() + s.size() / 8);
    for (char c : s) {
        switch (c) {
            case '&':  dest += "&amp;";  break;
            case '<':  dest += "&lt;";   break;
            case '>':  dest += "&gt;";   break;
            case '"':  dest += "&quot;"; break;
            case '\'': dest += "&apos;"; break;
            default:   dest += c;        break;
        }
    }
}

}  // namespace kstfl
