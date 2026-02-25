// init.cpp — R package DLL registration
//
// Generated for Rcpp integration. Registers compiled functions with R.
//
// Copyright (c) 2026 KeyStat Solutions. MIT License.

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <Rcpp.h>

// Forward declarations for Rcpp exports
RcppExport SEXP _ksTFL_render_docx_impl(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
RcppExport SEXP _ksTFL_render_docx_from_strings_impl(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);

static const R_CallMethodDef CallEntries[] = {
    {"_ksTFL_render_docx_impl", (DL_FUNC) &_ksTFL_render_docx_impl, 6},
    {"_ksTFL_render_docx_from_strings_impl", (DL_FUNC) &_ksTFL_render_docx_from_strings_impl, 7},
    {NULL, NULL, 0}
};

RcppExport void R_init_ksTFL(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynLib(dll, .registration = TRUE);
}
