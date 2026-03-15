// init.cpp — R package DLL registration
//
// Generated for Rcpp integration. Registers compiled functions with R.
//
// Copyright (c) 2026 I.Aleschenkov, V.Larchenko. GPL-3.0 License.

#include <Rcpp.h>

// Forward declarations for Rcpp exports
RcppExport SEXP _ksTFL_render_docx_impl(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
RcppExport SEXP _ksTFL_render_docx_from_strings_impl(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
RcppExport SEXP _ksTFL_cpp_test_units();
RcppExport SEXP _ksTFL_cpp_test_inline_parser();
RcppExport SEXP _ksTFL_cpp_test_xml_writer();
RcppExport SEXP _ksTFL_cpp_test_format_validator();

static const R_CallMethodDef CallEntries[] = {
    {"_ksTFL_render_docx_impl", (DL_FUNC)&_ksTFL_render_docx_impl, 6},
    {"_ksTFL_render_docx_from_strings_impl", (DL_FUNC)&_ksTFL_render_docx_from_strings_impl, 7},
    {"_ksTFL_cpp_test_units", (DL_FUNC)&_ksTFL_cpp_test_units, 0},
    {"_ksTFL_cpp_test_inline_parser", (DL_FUNC)&_ksTFL_cpp_test_inline_parser, 0},
    {"_ksTFL_cpp_test_xml_writer", (DL_FUNC)&_ksTFL_cpp_test_xml_writer, 0},
    {"_ksTFL_cpp_test_format_validator", (DL_FUNC)&_ksTFL_cpp_test_format_validator, 0},
    {NULL, NULL, 0}};

RcppExport void R_init_ksTFL(DllInfo *dll) {
  R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
}
