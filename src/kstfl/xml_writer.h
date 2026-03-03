// kstfl/xml_writer.h — Streaming XML writer for OOXML emission
//
// No DOM. Writes directly to a string buffer. Manages tag stack,
// proper escaping, and self-closing tags.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_XML_WRITER_H
#define KSTFL_XML_WRITER_H

#include <string>
#include <vector>

namespace kstfl {

/// Streaming XML writer — appends to an internal string buffer.
/// Supports start/end elements, attributes, text content, raw XML,
/// and self-closing tags.
class XmlWriter {
public:
    XmlWriter();
    ~XmlWriter() = default;

    // Non-copyable, movable
    XmlWriter(const XmlWriter&) = delete;
    XmlWriter& operator=(const XmlWriter&) = delete;
    XmlWriter(XmlWriter&&) = default;
    XmlWriter& operator=(XmlWriter&&) = default;

    /// Write XML declaration: <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    void write_declaration();

    /// Open an element tag. Must be closed with end_element() or self_close().
    /// Example: start_element("w:p") -> <w:p>
    void start_element(const std::string& name);

    /// Close the most recently opened element.
    /// Example: end_element() for "w:p" -> </w:p>
    void end_element();

    /// Write a self-closing element with no content.
    /// Example: self_closing_element("w:br") -> <w:br/>
    void self_closing_element(const std::string& name);

    /// Add an attribute to the currently open start tag.
    /// Must be called after start_element() and before any content/child elements.
    /// Example: attribute("w:val", "single") on <w:bdr -> <w:bdr w:val="single"...>
    void attribute(const std::string& name, const std::string& value);

    /// Overload for integer attribute values.
    void attribute(const std::string& name, int64_t value);

    /// Write escaped text content inside the current element.
    void text(const std::string& content);

    /// Write raw (unescaped) XML. Use with caution.
    void raw(const std::string& xml);

    /// Write an XML comment.
    void comment(const std::string& text);

    /// Write a namespace declaration on the current element.
    void namespace_decl(const std::string& prefix, const std::string& uri);

    /// Convenience: write a complete element with text content.
    /// Example: element("w:t", "Hello") -> <w:t>Hello</w:t>
    void element_with_text(const std::string& name, const std::string& content);

    /// Convenience: write a self-closing element with one attribute.
    /// Example: element_with_attr("w:sz", "w:val", "18") -> <w:sz w:val="18"/>
    void element_with_attr(const std::string& name,
                           const std::string& attr_name,
                           const std::string& attr_value);

    /// Convenience: write a self-closing element with one int attribute.
    void element_with_attr(const std::string& name,
                           const std::string& attr_name,
                           int64_t attr_value);

    /// Get the complete XML string built so far.
    [[nodiscard]] const std::string& str() const;

    /// Move the internal buffer out (consumes writer state).
    [[nodiscard]] std::string take();

    /// Reset writer to empty state.
    void clear();

    /// Current nesting depth (for debugging).
    [[nodiscard]] size_t depth() const;

private:
    /// Close the pending start tag if needed (write '>').
    void close_start_tag();

    /// Escape text for XML content.
    static std::string escape_text(const std::string& s);

    /// Escape text for XML attribute values.
    static std::string escape_attr(const std::string& s);

    std::string buffer_;
    std::vector<std::string> tag_stack_;
    bool start_tag_open_ = false;  // start tag written but not yet closed with '>'
};

}  // namespace kstfl

#endif  // KSTFL_XML_WRITER_H
