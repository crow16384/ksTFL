// kstfl/zip_writer.h — ZIP file packaging for DOCX output
//
// Uses classic minizip (from zlib) for ZIP creation.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_ZIP_WRITER_H
#define KSTFL_ZIP_WRITER_H

#include <minizip/zip.h>
#include <cstdint>
#include <string>
#include <vector>

namespace kstfl {

/// Simple ZIP file writer for assembling DOCX packages.
class ZipWriter {
public:
  /// Open a new ZIP file for writing.
  explicit ZipWriter(const std::string &path);
  ~ZipWriter();

  // Non-copyable
  ZipWriter(const ZipWriter &) = delete;
  ZipWriter &operator=(const ZipWriter &) = delete;

  /// Add a file entry to the ZIP.
  /// @param entry_path  Path within ZIP (e.g. "word/document.xml").
  /// @param content     Raw file content.
  void add_entry(const std::string &entry_path, const std::string &content);

  /// Add a binary file entry (for images).
  void add_binary_entry(const std::string &entry_path, const std::vector<uint8_t> &content);

  /// Add a file from disk to the ZIP.
  void add_file(const std::string &entry_path, const std::string &file_path);

  /// Close the ZIP file (must be called to finalize).
  void close();

private:
  zipFile zip_handle_ = nullptr;
  bool closed_ = false;
};

} // namespace kstfl

#endif // KSTFL_ZIP_WRITER_H
