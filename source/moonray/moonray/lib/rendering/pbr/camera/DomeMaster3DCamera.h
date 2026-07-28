// Copyright 2023-2024 DreamWorks Animation LLC
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "Camera.h"

#include <moonray/rendering/texturing/sampler/TextureSampler.h>
#include <scene_rdl2/common/math/Mat4.h>
#include <scene_rdl2/common/math/Vec3.h>

#ifdef __ARM_NEON__
// Platform.hh masquerades x86 SIMD macros on aarch64 (sse2neon). OIIO's headers
// dispatch on them: leaving them set makes OIIO try to include <immintrin.h> and
// select x86 SIMD layouts. Every TU that includes OIIO must agree on this state,
// otherwise struct layouts differ across TUs (ODR/ABI mismatch -> crashes).
#define __IMMINTRIN_H
#define __NMMINTRIN_H
#define OIIO_NO_SSE 1
#define OIIO_NO_AVX 1
#define OIIO_NO_AVX2 1
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
#include <OpenImageIO/imagebuf.h>
#include <OpenImageIO/imagebufalgo.h>
#include <OpenImageIO/texture.h>
#if defined(__aarch64__)
// restore Platform.hh's masquerade for the rest of this TU
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

#include <memory>

namespace moonray {
namespace pbr {

class DomeMaster3DCamera : public Camera
{
public:
    /// Constructor
    explicit DomeMaster3DCamera(const scene_rdl2::rdl2::Camera* rdlCamera);

private:
    void initAttributeKeys(const scene_rdl2::rdl2::SceneClass& sceneClass);

    bool getIsDofEnabledImpl() const override;

    void updateImpl(const scene_rdl2::math::Mat4d& world2render) override;

    void createRayImpl(mcrt_common::RayDifferential* dstRay,
                       float x,
                       float y,
                       float time,
                       float lensU,
                       float lensV) const override;

    StereoView getStereoViewImpl() const override;

    inline scene_rdl2::math::Vec3f createDirection(const scene_rdl2::math::Vec3f& camOrigin, float x, float y) const;
    // utility helper function
    inline void computePhiAndTheta(float x,
                                   float y,
                                   float& sinPhi,
                                   float& cosPhi,
                                   float& sinTheta,
                                   float& cosTheta) const;
    inline void flipXVector(scene_rdl2::math::Vec3f& vec) const;
    inline void flipYVector(scene_rdl2::math::Vec3f& vec) const;
    inline void applyParallax(scene_rdl2::math::Vec3f& vec) const;

    // Camera focal point in camera space (non-zero for stereo views L/R)
    float mInterocularOffset;
    float mImageResolutionWidthReciprocal;   // 1.0 / x pixel resolution (width)
    float mImageResolutionHeightReciprocal;  // 1.0 / y pixel resolution (height)

    static bool                            sAttributeKeyInitialized;

    static scene_rdl2::rdl2::AttributeKey<scene_rdl2::rdl2::Int>   sStereoViewKey;
    static scene_rdl2::rdl2::AttributeKey<scene_rdl2::rdl2::Float> sStereoInterocularDistanceKey;
    static scene_rdl2::rdl2::AttributeKey<scene_rdl2::rdl2::Float> sParallaxDistanceKey;

    static scene_rdl2::rdl2::AttributeKey<scene_rdl2::rdl2::Float> sFOVVerticalAngleKey;
    static scene_rdl2::rdl2::AttributeKey<scene_rdl2::rdl2::Float> sFOVHorizontalAngleKey;
    static scene_rdl2::rdl2::AttributeKey<scene_rdl2::rdl2::Bool>  sFlipRayXKey;
    static scene_rdl2::rdl2::AttributeKey<scene_rdl2::rdl2::Bool>  sFlipRayYKey;

    static scene_rdl2::rdl2::AttributeKey<scene_rdl2::rdl2::String> sCameraSeparationMapFileNameKey;

    static scene_rdl2::rdl2::AttributeKey<scene_rdl2::rdl2::Float> sHeadTiltMapKey;
    static scene_rdl2::rdl2::AttributeKey<scene_rdl2::rdl2::Bool>  sZenithModeKey;

    StereoView mStereoView;
    float mFOVHorizontalAngleRadians;
    float mFOVVerticalAngleRadians;
    bool mZenithMode;
    bool mFlipRayX;
    bool mFlipRayY;
    float mParallaxDistance;
    std::string mInterocularDistanceFileName;

    // OIIO Functionality used to sample mInterocularDistance map distance
    texture::TextureHandle* mTextureHandle;
#   if OIIO_VERSION < OIIO_MAKE_VERSION(3,0,0)
    OIIO::TextureSystem* mOIIOTextureSystem;
#   else
    std::shared_ptr<OIIO::TextureSystem> mOIIOTextureSystem;
#   endif
    OIIO::ImageSpec mImageSpec;
    OIIO::TextureOpt mTextureOption;
};

} // namespace pbr
} // namespace moonray


