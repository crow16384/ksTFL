/*
 * ft_all.c — FreeType single compilation unit for ksTFL vendored build
 *
 * Compiles all needed FreeType modules in one translation unit.
 * Include path must have: -I<vendor>/freetype/include
 *
 * FreeType version: 2.14.3
 */

#include <ft2build.h>

/* ---- Base components ---- */
#include "src/base/ftsystem.c"
#include "src/base/ftinit.c"
#include "src/base/ftdebug.c"
#include "src/base/ftbase.c"
#include "src/base/ftbbox.c"
#include "src/base/ftglyph.c"
#include "src/base/ftbitmap.c"
#include "src/base/ftmm.c"

/* ---- Font drivers ---- */
#include "src/truetype/truetype.c"
#include "src/cff/cff.c"
#include "src/type1/type1.c"
#include "src/cid/type1cid.c"

/* ---- Auxiliary modules ---- */
#include "src/sfnt/sfnt.c"
#include "src/psnames/psnames.c"
#include "src/psaux/psaux.c"
#include "src/pshinter/pshinter.c"

/* ---- Rasterisers ---- */
#include "src/smooth/smooth.c"
#include "src/autofit/autofit.c"

/* ---- Compression (for WOFF) ---- */
#include "src/gzip/ftgzip.c"
