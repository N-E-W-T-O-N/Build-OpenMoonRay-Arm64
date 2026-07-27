#!/usr/bin/env bash
# Sprint 1.6 guard: after configuring MoonRay for aarch64, verify NO x86 flags
# leaked into the generated build files. This is the check that would have
# caught the v3 "configured fine, compiled nothing" failure at configure time.
#
# Usage:  ./check_arch_flags.sh <build-dir>
# Exit 0 = clean (pure aarch64); exit 1 = x86 flags found (port fix didn't take).
set -uo pipefail

BUILD="${1:-/build}"
if [ ! -d "${BUILD}" ]; then echo "usage: $0 <build-dir>" >&2; exit 2; fi

echo "Scanning ${BUILD} for leaked x86 flags/defines..."
# Ninja puts flags in build.ninja; Make puts them in CMakeFiles/**/flags.make.
# NOTE: --include options must come BEFORE '--' (end-of-options marker),
# otherwise grep treats them as file operands and scans everything.
hits=$(grep -rEn \
        --include='flags.make' --include='build.ninja' --include='*.cmake' \
        -e '-march=core-avx2|-mavx\b|-mfma\b|(^|[^A-Z_])__AVX__|avx2-i32x8' \
        "${BUILD}" \
        2>/dev/null)

if [ -n "${hits}" ]; then
    echo "FAIL: x86 arch flags found in generated build files:" >&2
    echo "${hits}" | head -20 >&2
    echo "  -> OMR_Platform/CompileOptions aarch64 path did NOT take. Check" >&2
    echo "     CMAKE_SYSTEM_PROCESSOR is aarch64 and the port patches applied." >&2
    exit 1
fi

echo "PASS: no x86 arch flags in generated build files."
# Positive confirmation that the NEON path is active
neon=$(grep -rEl -- '-march=armv8|neon-i32x4|__ARM_NEON__' "${BUILD}" \
        --include='flags.make' --include='build.ninja' 2>/dev/null | head -1)
[ -n "${neon}" ] && echo "confirmed NEON flags present (e.g. ${neon})" \
                 || echo "note: no NEON flags seen yet (ok if only C/cmake targets configured)"
