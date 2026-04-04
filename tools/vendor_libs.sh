#!/bin/bash
# tools/vendor_libs.sh
#
# Downloads and vendors FreeType, HarfBuzz, and minizip sources
# for static compilation within the ksTFL R package.
#
# Usage: cd <package_root> && bash tools/vendor_libs.sh

set -euo pipefail

FREETYPE_VERSION="2.13.3"
HARFBUZZ_VERSION="10.2.0"
ZLIB_VERSION="1.3.1"

VENDOR_DIR="src/vendor"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "=== Downloading library sources ==="

# FreeType
echo "Downloading FreeType ${FREETYPE_VERSION}..."
curl -sL "https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.xz" \
    -o "$TMPDIR/freetype.tar.xz"

# HarfBuzz
echo "Downloading HarfBuzz ${HARFBUZZ_VERSION}..."
curl -sL "https://github.com/harfbuzz/harfbuzz/releases/download/${HARFBUZZ_VERSION}/harfbuzz-${HARFBUZZ_VERSION}.tar.xz" \
    -o "$TMPDIR/harfbuzz.tar.xz"

# zlib (for minizip contrib)
echo "Downloading zlib ${ZLIB_VERSION} (for minizip)..."
curl -sL "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz" \
    -o "$TMPDIR/zlib.tar.gz"

echo "=== Extracting ==="
cd "$TMPDIR"
tar xf freetype.tar.xz
tar xf harfbuzz.tar.xz
tar xf zlib.tar.gz
cd - > /dev/null

# ---- FreeType ----
echo "=== Vendoring FreeType ${FREETYPE_VERSION} ==="
rm -rf "$VENDOR_DIR/freetype"
mkdir -p "$VENDOR_DIR/freetype"

# Copy include directory (public headers)
cp -r "$TMPDIR/freetype-${FREETYPE_VERSION}/include" "$VENDOR_DIR/freetype/"

# Copy source directory (needed modules only)
mkdir -p "$VENDOR_DIR/freetype/src"
for module in base truetype type1 cff cid sfnt psnames pshinter smooth autofit psaux gzip; do
    if [ -d "$TMPDIR/freetype-${FREETYPE_VERSION}/src/$module" ]; then
        cp -r "$TMPDIR/freetype-${FREETYPE_VERSION}/src/$module" "$VENDOR_DIR/freetype/src/"
    fi
done

# Customise ftmodule.h to list only the modules we ship
cat > "$VENDOR_DIR/freetype/include/freetype/config/ftmodule.h" << 'FTMOD'
/*
 * This file registers the FreeType modules compiled into the library.
 *
 * Customised for ksTFL vendored build: only modules whose source is
 * included under src/vendor/freetype/src/ are listed here.
 */

FT_USE_MODULE( FT_Module_Class, autofit_module_class )
FT_USE_MODULE( FT_Driver_ClassRec, tt_driver_class )
FT_USE_MODULE( FT_Driver_ClassRec, t1_driver_class )
FT_USE_MODULE( FT_Driver_ClassRec, cff_driver_class )
FT_USE_MODULE( FT_Driver_ClassRec, t1cid_driver_class )
FT_USE_MODULE( FT_Module_Class, psaux_module_class )
FT_USE_MODULE( FT_Module_Class, psnames_module_class )
FT_USE_MODULE( FT_Module_Class, pshinter_module_class )
FT_USE_MODULE( FT_Module_Class, sfnt_module_class )
FT_USE_MODULE( FT_Renderer_Class, ft_smooth_renderer_class )

/* EOF */
FTMOD

# ---- HarfBuzz ----
echo "=== Vendoring HarfBuzz ${HARFBUZZ_VERSION} ==="
rm -rf "$VENDOR_DIR/harfbuzz"
mkdir -p "$VENDOR_DIR/harfbuzz/src"

# Copy source files (.cc, .hh, .h) from src/ (skip tests, tools)
find "$TMPDIR/harfbuzz-${HARFBUZZ_VERSION}/src" -maxdepth 1 \
    \( -name "*.cc" -o -name "*.hh" -o -name "*.h" \) \
    ! -name "test-*" ! -name "main.cc" ! -name "failing-alloc.c" \
    -exec cp {} "$VENDOR_DIR/harfbuzz/src/" \;

# Copy subdirectories needed by the amalgamation
for subdir in graph OT; do
    if [ -d "$TMPDIR/harfbuzz-${HARFBUZZ_VERSION}/src/$subdir" ]; then
        cp -r "$TMPDIR/harfbuzz-${HARFBUZZ_VERSION}/src/$subdir" "$VENDOR_DIR/harfbuzz/src/"
    fi
done

# ---- minizip ----
echo "=== Vendoring minizip (from zlib ${ZLIB_VERSION}) ==="
rm -rf "$VENDOR_DIR/minizip"
mkdir -p "$VENDOR_DIR/minizip"

for f in zip.c zip.h unzip.c unzip.h ioapi.c ioapi.h crypt.h; do
    if [ -f "$TMPDIR/zlib-${ZLIB_VERSION}/contrib/minizip/$f" ]; then
        cp "$TMPDIR/zlib-${ZLIB_VERSION}/contrib/minizip/$f" "$VENDOR_DIR/minizip/"
    fi
done

echo ""
echo "=== Summary ==="
echo "FreeType: $(du -sh "$VENDOR_DIR/freetype" | cut -f1)"
echo "HarfBuzz: $(du -sh "$VENDOR_DIR/harfbuzz" | cut -f1)"
echo "minizip:  $(du -sh "$VENDOR_DIR/minizip" | cut -f1)"
echo "Total:    $(du -sh "$VENDOR_DIR" | cut -f1)"
echo ""
echo "Done! Vendored sources placed in $VENDOR_DIR/"
