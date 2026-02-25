// kstfl/zip_writer.cpp — ZIP file packaging for DOCX output
//
// Uses minizip-ng for ZIP creation.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include "zip_writer.h"
#include "types.h"

// minizip-ng includes
#include <mz.h>
#include <mz_os.h>
#include <mz_strm.h>
#include <mz_zip.h>
#include <mz_zip_rw.h>

#include <cstring>
#include <fstream>
#include <vector>

namespace kstfl {

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

ZipWriter::ZipWriter(const std::string& path) {
    void* writer = mz_zip_writer_create(&zip_handle_);
    if (!zip_handle_) {
        throw RenderError("Failed to create ZIP writer");
    }

    int32_t err = mz_zip_writer_open_file(zip_handle_, path.c_str(), 0, 0);
    if (err != MZ_OK) {
        mz_zip_writer_delete(&zip_handle_);
        throw RenderError("Failed to open ZIP file for writing: " + path +
                          " (error " + std::to_string(err) + ")");
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
    if (zip_handle_) {
        mz_zip_writer_delete(&zip_handle_);
    }
}

// ---------------------------------------------------------------------------
// Add a text entry
// ---------------------------------------------------------------------------

void ZipWriter::add_entry(const std::string& entry_path, const std::string& content) {
    if (closed_) {
        throw RenderError("Cannot add entry to closed ZIP file");
    }

    mz_zip_file file_info;
    std::memset(&file_info, 0, sizeof(file_info));
    file_info.filename = entry_path.c_str();
    file_info.compression_method = MZ_COMPRESS_METHOD_DEFLATE;
    file_info.flag = MZ_ZIP_FLAG_UTF8;
    file_info.uncompressed_size = static_cast<int64_t>(content.size());

    int32_t err = mz_zip_writer_entry_open(zip_handle_, &file_info);
    if (err != MZ_OK) {
        throw RenderError("Failed to open ZIP entry: " + entry_path);
    }

    int32_t written = mz_zip_writer_entry_write(
        zip_handle_,
        content.data(),
        static_cast<int32_t>(content.size()));
    if (written < 0) {
        throw RenderError("Failed to write ZIP entry: " + entry_path);
    }

    err = mz_zip_writer_entry_close(zip_handle_);
    if (err != MZ_OK) {
        throw RenderError("Failed to close ZIP entry: " + entry_path);
    }
}

// ---------------------------------------------------------------------------
// Add a binary entry (for images)
// ---------------------------------------------------------------------------

void ZipWriter::add_binary_entry(const std::string& entry_path,
                                  const std::vector<uint8_t>& content) {
    if (closed_) {
        throw RenderError("Cannot add entry to closed ZIP file");
    }

    mz_zip_file file_info;
    std::memset(&file_info, 0, sizeof(file_info));
    file_info.filename = entry_path.c_str();
    file_info.compression_method = MZ_COMPRESS_METHOD_DEFLATE;
    file_info.flag = MZ_ZIP_FLAG_UTF8;
    file_info.uncompressed_size = static_cast<int64_t>(content.size());

    int32_t err = mz_zip_writer_entry_open(zip_handle_, &file_info);
    if (err != MZ_OK) {
        throw RenderError("Failed to open ZIP entry: " + entry_path);
    }

    int32_t written = mz_zip_writer_entry_write(
        zip_handle_,
        reinterpret_cast<const void*>(content.data()),
        static_cast<int32_t>(content.size()));
    if (written < 0) {
        throw RenderError("Failed to write ZIP entry: " + entry_path);
    }

    err = mz_zip_writer_entry_close(zip_handle_);
    if (err != MZ_OK) {
        throw RenderError("Failed to close ZIP entry: " + entry_path);
    }
}

// ---------------------------------------------------------------------------
// Add file from disk
// ---------------------------------------------------------------------------

void ZipWriter::add_file(const std::string& entry_path, const std::string& file_path) {
    // Read file into memory
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
        int32_t err = mz_zip_writer_close(zip_handle_);
        if (err != MZ_OK) {
            throw RenderError("Failed to finalize ZIP file (error " +
                              std::to_string(err) + ")");
        }
    }
}

}  // namespace kstfl
