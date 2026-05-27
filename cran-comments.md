## R CMD check results

0 errors | 0 warnings | 2 notes

---

### Note 1 — Non-standard top-level file

> Non-standard file/directory found at top level: 'CLAUDE.md'

`CLAUDE.md` is an AI-assistant context file used during development. It is listed in `.Rbuildignore` and is not included in the package tarball.

---

### Note 2 — Compiled code: use of `stderr`, `rand`, `srand`

> Found 'stderr' in the following object(s): ksTFL.so
> Found 'rand'/'srand' in the following object(s): ksTFL.so

These come from two vendored C libraries that are statically compiled into the package:

- **HarfBuzz** (text shaping engine, `src/vendor/harfbuzz/`): uses `fprintf(stderr, ...)` internally for optional debug output that is compiled away in our build (`HB_NO_MT` is defined; debug paths are never reached from R). No debug output is produced during normal use.

- **minizip** (`src/vendor/minizip/`): uses `rand()` internally for generating temporary file name suffixes when creating ZIP archives. This is not used for statistical randomness and does not affect reproducibility of results from R code.

Neither library is accessible to R users and neither alters R's global state (e.g., R's RNG seed is not touched).

---

### Vendored libraries

The package bundles the following C/C++ libraries to avoid external system dependencies:

| Library       | Version   | License     | Source                         |
|---------------|-----------|-------------|--------------------------------|
| HarfBuzz      | 11.2.0    | MIT         | https://harfbuzz.github.io     |
| FreeType      | 2.13.3    | FTL / GPLv2 | https://freetype.org           |
| nlohmann/json | 3.11.3    | MIT         | https://github.com/nlohmann/json |
| minizip-ng    | 4.0.8     | MIT         | https://github.com/zlib-ng/minizip-ng |

All vendored sources are in `src/vendor/` and compiled as part of the package. No system libraries are required.
