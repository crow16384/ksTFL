// kstfl/zip_writer.cpp — ZIP file packaging for DOCX output
//
// Uses classic minizip (from zlib) for ZIP creation.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include "zip_writer.h"
#include "types.h"

#include <cstring>
#include <fstream>
#include <vector>

namespace kstfl {

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

ZipWriter::ZipWriter(const std::string& path) {
    zip_handle_ = zipOpen(path.c_str(), APPEND_STATUS_CREATE);
    if (!zip_handle_) {
        throw RenderError("Failed to open ZIP file for writing: " + path);
    }
}

// ---------------------------------------------------------------------------
// Destructor
// ---------------------------------------------------------------------------

ZipWriter::~ZipWriter() {
    if (!closed_ && zip_handle_) {
        try {
            close();
        } catch (...) {
            // Suppress exceptions in destructor
        }
    }
}

// ---------------------------------------------------------------------------
// Helper: write raw bytes to a fresh ZIP entry
// ---------------------------------------------------------------------------

static void write_entry(zipFile zf, const std::string& entry_path,
                        const void* data, size_t size) {
    zip_fileinfo fi;
    std::memset(&fi, 0, sizeof(fi));

    int err = zipOpenNewFileInZip(
        zf,
        entry_path.c_str(),
        &fi,
        nullptr, 0,        // extra field (local)
        nullptr, 0,        // extra field (global)
        nullptr,            // comment
        Z_DEFLATED,
        Z_DEFAULT_COMPRESSION);
    if (err != ZIP_OK) {
        throw RenderError("Failed to open ZIP entry: " + entry_path);
    }

    if (size > 0) {
        err = zipWriteInFileInZip(zf, data, static_cast<unsigned>(size));
        if (err != ZIP_OK) {
            zipCloseFileInZip(zf);
            throw RenderError("Failed to write ZIP entry: " + entry_path);
        }
    }

    err = zipCloseFileInZip(zf);
    if (err != ZIP_OK) {
        throw RenderError("Failed to close ZIP entry: " + entry_path);
    }
}

// ---------------------------------------------------------------------------
// Add a text entry
// ---------------------------------------------------------------------------

void ZipWriter::add_entry(const std::string& entry_path,
                          const std::string& content) {
    if (closed_) {
        throw RenderError("Cannot add entry to closed ZIP file");
    }
    write_entry(zip_handle_, entry_path, content.data(), content.size());
}

// ---------------------------------------------------------------------------
// Add a binary entry (for images)
// ---------------------------------------------------------------------------

void ZipWriter::add_binary_entry(const std::string& entry_path,
                                  const std::vector<uint8_t>& content) {
    if (closed_) {
        throw RenderError("Cannot add entry to closed ZIP file");
    }
    write_entry(zip_handle_, entry_path, content.data(), content.size());
}

// ---------------------------------------------------------------------------
// Add file from disk
// ---------------------------------------------------------------------------

void ZipWriter::add_file(const std::string& entry_path,
                         const std::string& file_path) {
    std::ifstream ifs(file_path, std::ios::binary | std::ios::ate);
    if (!ifs) {
        throw RenderError("Cannot read file for ZIP inclusion: " + file_path);
    }

    auto size = ifs.tellg();
    ifs.seekg(0);

    std::vector<uint8_t> data(static_cast<size_t>(size));
    ifs.read(reinterpret_cast<char*>(data.data()), size);
    ifs.close();

    add_binary_entry(entry_path, data);
}

// ---------------------------------------------------------------------------
// Close
// ---------------------------------------------------------------------------

void ZipWriter::close() {
    if (closed_) return;
    closed_ = true;

    if (zip_handle_) {
        int err = zipClose(zip_handle_, nullptr);
        zip_handle_ = nullptr;
        if (err != ZIP_OK) {
            throw RenderError("Failed to finalize ZIP file (error " +
                              std::to_string(err) + ")");
        }
    }
}

}  // namespace kstfl
