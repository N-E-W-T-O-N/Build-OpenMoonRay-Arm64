// Copyright 2023-2024 DreamWorks Animation LLC
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <moonray/rendering/shading/Intersection.h>
#include <moonray/rendering/shading/State.h>

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
#include <OpenImageIO/texture.h>
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

// -------------------------------------------------
// Types and functions used by both BasicTexture and
// UdimTexture classes.
// -------------------------------------------------

namespace moonray {

namespace texture {
class TextureSampler;
typedef OIIO::TextureSystem::TextureHandle TextureHandle;
}

namespace shading {

enum TextureQuality {
    TrilinearAnisotropic = 0,
    TrilinearIsotropic,
    LinearMipClosestTexel,
    ClosestMipClosestTexel,
    QualityCount
};

// Chooses from one of the foloowing texture option indices based
// on the path type at the current intersection.
// * ClosestMipClosestTexel
// * LinearMipClosestTexel
// * TrilinearAnisotropic
// * TrilinearIsotropic
int getTextureOptionIndex(bool isDisplacement, const shading::State &state);
int getTextureOptionIndex(bool isDisplacement, shading::Intersection::PathType pathType);

// checks if data and display windows have valid
// (non-negative) pixel coordinates
bool checkTextureWindow(texture::TextureSampler* textureSampler,
                        texture::TextureHandle* handle,
                        const std::string &filename,
                        std::string &errorMsg);

} // namespace shading
} // namespace moonray

