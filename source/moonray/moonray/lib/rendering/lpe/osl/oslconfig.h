// Copyright 2023-2024 DreamWorks Animation LLC
// SPDX-License-Identifier: Apache-2.0

/// @file oslconfig.h
/// @note this is an extremely pared down and highly modified version
/// of oslconfig.h from OSL's distribution.  It is sufficient for
/// compiling just the lpe aspects of the osl library that we
/// are interested in.

/*
Copyright (c) 2009-2010 Sony Pictures Imageworks Inc., et al.
All Rights Reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
* Neither the name of Sony Pictures Imageworks nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#pragma once

// All the things we need from OpenImageIO
#ifdef __ARM_NEON__
// Platform.hh masquerades x86 SIMD macros on aarch64 (sse2neon); OIIO's headers
// dispatch on them. Every TU including OIIO must agree on this state or struct
// layouts differ across TUs.
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
#include <OpenImageIO/ustring.h>
#if defined(__aarch64__) && !defined(MOONRAY_ISA_NEON2X)
// restore Platform.hh's masquerade for the remainder of this TU
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

#define OSL_NAMESPACE_ENTER namespace moonray { namespace lpe { namespace osl {
#define OSL_NAMESPACE_EXIT } } }

OSL_NAMESPACE_ENTER

// And some other things we borrow from OIIO...
using OIIO::ustring;
#if OIIO_VERSION < OIIO_MAKE_VERSION(2,4,8)
using OIIO::ustringHash;
#endif
using OIIO::string_view;

OSL_NAMESPACE_EXIT


