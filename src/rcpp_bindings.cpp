// rcpp_bindings.cpp — Rcpp interface for the ksTFL C++ renderer
//
// Exposes render_docx_impl() to R via .Call().
// Spec §23: R integration via Rcpp.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include <Rcpp.h>
#include "kstfl/renderer.h"

// [[Rcpp::export]]
void render_docx_impl(const std::string& spec_json_path,
                       const std::string& template_json_path,
                       const std::string& output_path,
                       Rcpp::Nullable<Rcpp::CharacterVector> font_dirs = R_NilValue,
                       const std::string& fallback_font = "",
                       bool verbose = false) {
    try {
        kstfl::Renderer renderer;
        kstfl::RendererConfig config;
        config.verbose = verbose;
        config.fallback_font_path = fallback_font;

        // Process font directories
        if (font_dirs.isNotNull()) {
            Rcpp::CharacterVector dirs(font_dirs);
            for (int i = 0; i < dirs.size(); ++i) {
                config.font_dirs.push_back(Rcpp::as<std::string>(dirs[i]));
            }
        }

        // Always include default system fonts
        config.font_dirs.push_back("__default__");

        renderer.set_config(config);
        renderer.render(spec_json_path, template_json_path, output_path);

    } catch (const kstfl::RenderError& e) {
        Rcpp::stop("ksTFL render error: %s", e.what());
    } catch (const std::exception& e) {
        Rcpp::stop("ksTFL internal error: %s", e.what());
    }
}

// [[Rcpp::export]]
void render_docx_from_strings_impl(const std::string& spec_json,
                                    const std::string& template_json,
                                    const std::string& output_path,
                                    const std::string& data_dir = "",
                                    Rcpp::Nullable<Rcpp::CharacterVector> font_dirs = R_NilValue,
                                    const std::string& fallback_font = "",
                                    bool verbose = false) {
    try {
        kstfl::Renderer renderer;
        kstfl::RendererConfig config;
        config.verbose = verbose;
        config.fallback_font_path = fallback_font;

        if (font_dirs.isNotNull()) {
            Rcpp::CharacterVector dirs(font_dirs);
            for (int i = 0; i < dirs.size(); ++i) {
                config.font_dirs.push_back(Rcpp::as<std::string>(dirs[i]));
            }
        }
        config.font_dirs.push_back("__default__");

        renderer.set_config(config);
        renderer.render_from_strings(spec_json, template_json, output_path, data_dir);

    } catch (const kstfl::RenderError& e) {
        Rcpp::stop("ksTFL render error: %s", e.what());
    } catch (const std::exception& e) {
        Rcpp::stop("ksTFL internal error: %s", e.what());
    }
}
