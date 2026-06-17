## R CMD check results

0 errors | 0 warnings | 1 note

---

### Note 1 — Compilation flags used

> Compilation used the following non-portable flag(s):
> `-Wdate-time` `-Werror=format-security` `-Wformat`

This note comes from the Ubuntu R 4.6.0 build environment used for the local
check, not from ksTFL package flags. The package `src/Makevars` files do not add
these flags; they are inherited from the platform `CFLAGS`/`CXXFLAGS` configured
into that R build.

Per the R check documentation, such toolchain-supplied flags can be declared as
known for local checks via `_R_CHECK_COMPILATION_FLAGS_KNOWN_`. The package
source itself is clean after removing vendored-source pragma warnings and the
compiled-code notes from the previous check run.

---

### Bundled third-party components

The package bundles the following third-party components to avoid external system
dependencies at install time:

| Component | Version | License | Notes |
|-----------|---------|---------|-------|
| HarfBuzz | 10.2.0 | HarfBuzz permissive license | Vendored in `src/vendor/harfbuzz/` |
| FreeType | 2.13.3 | FTL / GPL-2.0-or-later | Redistributed under the FTL option |
| minizip | zlib 1.3.1 contrib/minizip | zlib | ZIP-writing subset only |
| nlohmann/json | 3.12.0 | MIT | Single bundled header |
| Liberation fonts | 2.1.5 font metadata | SIL OFL 1.1 | Bundled in `inst/fonts/` |

Third-party redistribution details are recorded in `LICENSE.note`. The bundled
font license text required for redistribution is included in `inst/fonts/OFL.txt`.
