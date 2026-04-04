// kstfl/renderer.h — Main rendering orchestrator
//
// Pipeline: Parse → Resolve → Model → Measure → Paginate → Emit
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#ifndef KSTFL_RENDERER_H
#define KSTFL_RENDERER_H

#include "types.h"
#include <string>

namespace kstfl {

/// Main renderer class. Orchestrates the full pipeline.
class Renderer {
public:
  Renderer();
  ~Renderer();

  /// Add default system font directories.
  void add_default_font_paths();

  /// Add a custom font search directory.
  void add_font_path(const std::string &path);

  /// Set the path to the fallback font (Liberation Sans).
  void set_fallback_font(const std::string &path);

  /// Set renderer configuration.
  void set_config(const RendererConfig &config);

  /// Render a complete report.
  /// @param spec_json_path     Path to the spec JSON file.
  /// @param template_json_path Path to the styles template JSON file.
  /// @param output_path        Path for the output .docx file.
  /// @return Total number of pages produced across all specs.
  size_t render(const std::string &spec_json_path, const std::string &template_json_path,
                const std::string &output_path);

  /// Render from strings (for testing / Rcpp).
  /// @return Total number of pages produced across all specs.
  size_t render_from_strings(const std::string &spec_json, const std::string &template_json,
                             const std::string &output_path, const std::string &data_dir = "");

private:
  RendererConfig config_;
};

} // namespace kstfl

#endif // KSTFL_RENDERER_H
