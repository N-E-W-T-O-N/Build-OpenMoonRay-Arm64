// Copyright 2023-2024 DreamWorks Animation LLC
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <scene_rdl2/scene/rdl2/Metadata.h>

#ifdef __ARM_NEON__
// This works around OIIO including x86 based headers due to detection of SSE
// support due to sse2neon.h being included elsewhere
#define __IMMINTRIN_H
#define __NMMINTRIN_H
#define OIIO_NO_SSE 1
#define OIIO_NO_AVX 1
#define OIIO_NO_AVX2 1
// GCC on Linux aarch64: the include-guard trick above only works for clang
// (GCC's immintrin guard differs and the header doesn't even exist on arm).
// OIIO's vendored farmhash.h does `#if defined(__SSSE3__) ... #include
// <immintrin.h>`, and Platform.hh deliberately defines the SSE macros on
// aarch64 (ISA masquerade for sse2neon). Undefine them here: moonray headers
// above are already preprocessed, and OIIO must take its generic paths.
#undef __SSE__
#undef __SSE2__
#undef __SSE3__
#undef __SSSE3__
#undef __SSE4_1__
#undef __SSE4_2__
#undef __AVX__
#undef __AVX2__
#endif
#include <OpenImageIO/imageio.h>
// Restore Platform.hh's aarch64 ISA masquerade (undef'd above only so OIIO
// headers take generic paths). Later headers dispatch on these (geom/Types.h).
#if defined(__aarch64__)
  #ifndef MOONRAY_ISA_NEON2X
    #ifndef __SSE3__
    #define __SSE3__
    #endif
    #ifndef __SSSE3__
    #define __SSSE3__
    #endif
    #ifndef __SSE4_1__
    #define __SSE4_1__
    #endif
    #ifndef __SSE4_2__
    #define __SSE4_2__
    #endif
  #endif
#endif

namespace moonray {
namespace rndr {

/**
 * Writes metadata to an exr header by parsing lists of strings.
 * Must convert the string into the appropriate data type.
 * Data types supported:
 *      * box2i
 *      * box2f
 *      * chromaticities
 *      * double
 *      * float
 *      * int
 *      * m33f
 *      * m44f
 *      * string
 *      * v2i
 *      * v2f
 *      * v3i
 *      * v3f
 *
 * @param   spec      The ImageSpec. We add the attributes to the ImageSpec,
 *                    which then get written to the exr header.
 * @param   metadata  The metadata object contains the list of attributes.
 */

void writeExrHeader(OIIO::ImageSpec& spec, const scene_rdl2::rdl2::Metadata *metadata);

void writeExrHeader(OIIO::ImageSpec &spec,
                    const std::vector<std::string> &attrNames,
                    const std::vector<std::string> &attrTypes,
                    const std::vector<std::string> &attrValues,
                    const std::string &metadataName);

void writeExrHeader(OIIO::ImageSpec &spec,
                    const std::string &attrNames,
                    const std::string &attrTypes,
                    const std::string &attrValues,
                    const std::string &metadataName);

} // namespace rndr
} // namespace moonray

