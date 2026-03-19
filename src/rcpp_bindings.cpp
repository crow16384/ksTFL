// rcpp_bindings.cpp — Rcpp interface for the ksTFL C++ renderer
//
// Exposes render_docx_impl() to R via .Call().
// Spec §23: R integration via Rcpp.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include <Rcpp.h>
#include "kstfl/renderer.h"
#include "kstfl/font_scanner.h"

// [[Rcpp::export]]
int render_docx_impl(const std::string &spec_json_path, const std::string &template_json_path,
                     const std::string &output_path, Rcpp::Nullable<Rcpp::CharacterVector> font_dirs = R_NilValue,
                     const std::string &fallback_font = "", bool verbose = false) {
  try {
    kstfl::Renderer renderer;
    kstfl::RendererConfig config;
    config.verbose = verbose;
    config.fallback_font_path = fallback_font;

    // Process font directories (only explicit dirs — no system fonts)
    if (font_dirs.isNotNull()) {
      Rcpp::CharacterVector dirs(font_dirs);
      for (int i = 0; i < dirs.size(); ++i) {
        config.font_dirs.push_back(Rcpp::as<std::string>(dirs[i]));
      }
    }

    renderer.set_config(config);
    return static_cast<int>(renderer.render(spec_json_path, template_json_path, output_path));

  } catch (const kstfl::RenderError &e) {
    Rcpp::stop(std::string("ksTFL render error: ") + e.what());
  } catch (const std::exception &e) { Rcpp::stop(std::string("ksTFL internal error: ") + e.what()); }
  return 0;
}

// [[Rcpp::export]]
int render_docx_from_strings_impl(const std::string &spec_json, const std::string &template_json,
                                  const std::string &output_path, const std::string &data_dir = "",
                                  Rcpp::Nullable<Rcpp::CharacterVector> font_dirs = R_NilValue,
                                  const std::string &fallback_font = "", bool verbose = false) {
  try {
    kstfl::Renderer renderer;
    kstfl::RendererConfig config;
    config.verbose = verbose;
    config.fallback_font_path = fallback_font;

    // Process font directories (only explicit dirs — no system fonts)
    if (font_dirs.isNotNull()) {
      Rcpp::CharacterVector dirs(font_dirs);
      for (int i = 0; i < dirs.size(); ++i) {
        config.font_dirs.push_back(Rcpp::as<std::string>(dirs[i]));
      }
    }

    renderer.set_config(config);
    return static_cast<int>(renderer.render_from_strings(spec_json, template_json, output_path, data_dir));

  } catch (const kstfl::RenderError &e) {
    Rcpp::stop(std::string("ksTFL render error: ") + e.what());
  } catch (const std::exception &e) { Rcpp::stop(std::string("ksTFL internal error: ") + e.what()); }
  return 0;
}

// [[Rcpp::export]]
Rcpp::List init_font_registry_impl(const std::string &fallback_font_dir,
                                   Rcpp::Nullable<Rcpp::CharacterVector> extra_dirs = R_NilValue) {
  std::vector<std::string> extras;
  if (extra_dirs.isNotNull()) {
    Rcpp::CharacterVector dirs(extra_dirs);
    for (int i = 0; i < dirs.size(); ++i) {
      extras.push_back(Rcpp::as<std::string>(dirs[i]));
    }
  }

  auto report = kstfl::initialize_font_registry(fallback_font_dir, extras);

  Rcpp::List resolutions;
  for (const auto &r : report.resolutions) {
    resolutions.push_back(
        Rcpp::List::create(Rcpp::Named("target") = r.target, Rcpp::Named("resolved_family") = r.resolved_family,
                           Rcpp::Named("resolved_path") = r.resolved_path, Rcpp::Named("is_fallback") = r.is_fallback));
  }

  return Rcpp::List::create(Rcpp::Named("resolutions") = resolutions,
                            Rcpp::Named("dirs_scanned") = Rcpp::wrap(report.dirs_scanned));
}

// [[Rcpp::export]]
Rcpp::CharacterVector get_font_dirs_impl() {
  const auto &dirs = kstfl::get_all_font_dirs();
  return Rcpp::wrap(dirs);
}
