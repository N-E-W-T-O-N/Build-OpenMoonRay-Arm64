// Copyright 2023-2024 DreamWorks Animation LLC
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "TextureTLState.hh"
#include <moonray/rendering/mcrt_common/ThreadLocalState.h>

//  OiiO includes for access to texture system.
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

#pragma push_macro("COLOR")
#pragma push_macro("NORMAL")
#undef COLOR
#undef NORMAL
#include <Imath/ImathVec.h>  // OIIO uses the Vector classes from Imath but defines its own version if not already defined.
#include <OpenImageIO/version.h>
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
#pragma pop_macro("COLOR")
#pragma pop_macro("NORMAL")

namespace moonray {
namespace texture {

class TextureSampler;
class TextureSystem;

// Expose for HUD validation.
class TLState;
typedef texture::TLState TextureTLState;

//-----------------------------------------------------------------------------

// This class can't be instantiated directly. It is meant to be used as a base
// class for the shading::TLState class to provide texturing related hooks.

class TLState : public mcrt_common::BaseTLState
{
public:
    virtual void reset() override;

    void initTexturingSupport();

    /// HUD validation.
    static uint32_t hudValidation(bool verbose) { TEXTURE_TL_STATE_VALIDATION; }

    typedef OIIO::TextureSystem TextureSystem;
    typedef OIIO::TextureSystem::Perthread Perthread;
    TEXTURE_TL_STATE_MEMBERS;

private:
    friend class shading::TLState;

    TLState(mcrt_common::ThreadLocalState *tls,
            const mcrt_common::TLSInitParams &initParams,
            bool okToAllocBundledResources);

    static void initPrivate(const mcrt_common::TLSInitParams &initParams);
    static void cleanUpPrivate();

    DISALLOW_COPY_OR_ASSIGNMENT(TLState);
};

// Get the global texture sampler.
TextureSampler *getTextureSampler();

//-----------------------------------------------------------------------------

} // namespace texture

inline mcrt_common::ExclusiveAccumulators *
getExclusiveAccumulators(texture::TLState *tls)
{
    MNRY_ASSERT(tls);
    return tls->getInternalExclusiveAccumulatorsPtr();
}

} // namespace moonray

