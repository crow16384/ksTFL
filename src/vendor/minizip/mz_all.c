/*
 * mz_all.c — minizip single compilation unit for ksTFL vendored build
 *
 * minizip from zlib 1.3.1; only the zip-writing subset is needed.
 * ZIP encryption is unused by ksTFL and is disabled here to avoid
 * bundling RNG-based encryption helpers into the package binary.
 */

#ifndef NOCRYPT
#define NOCRYPT
#endif

#include "ioapi.c"
#include "zip.c"
