#!/usr/bin/env bash
# Package the complete ${INSTALL_ROOT} dependency tree and upload to Hugging Face
# so it can be reused in CI and on native aarch64 devices.
#
# IMPORTANT: we use tar.zst, NOT zip — zip does not preserve symlinks, and the
# shared-library chains (libembree4.so -> libembree4.so.4 -> libembree4.so.4.4.1)
# would break, along with executable permission bits.
#
# Usage:  HF_TOKEN=hf_xxx ./scripts/pack_and_upload_deps.sh [artifact-label]
set -euo pipefail

INSTALL_ROOT="${INSTALL_ROOT:-/opt/MoonRay/installs}"
HF_REPO="${HF_REPO:-Prince-1/Codes}"
LABEL="${1:-ubuntu2604}"
OUT="moonray-deps-aarch64-${LABEL}.tar.zst"

# Record provenance inside the artifact
{
    echo "built:    $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "glibc:    $(ldd --version | head -1)"
    echo "distro:   $(. /etc/os-release && echo "$PRETTY_NAME")"
    echo "arch:     $(uname -m)"
    echo "contents:"
    ls "${INSTALL_ROOT}/lib" 2>/dev/null | sed 's/^/  /'
} > "${INSTALL_ROOT}/MANIFEST.txt"

tar -C "$(dirname "${INSTALL_ROOT}")" -I 'zstd -19 -T0' -cf "${OUT}" "$(basename "${INSTALL_ROOT}")"
echo "packed: ${OUT} ($(du -h "${OUT}" | cut -f1))"

python3 -m pip install --quiet --break-system-packages -U "huggingface_hub[cli]"
hf upload "${HF_REPO}" "${OUT}" "moonray-deps/${OUT}" --token "${HF_TOKEN}"

cat <<EOF
Uploaded to https://huggingface.co/${HF_REPO}/tree/main/moonray-deps

To use on a native device or another machine (needs Ubuntu 26.04 / matching glibc):
    hf download ${HF_REPO} moonray-deps/${OUT} --local-dir . --token \$HF_TOKEN
    sudo mkdir -p /opt/MoonRay
    sudo tar -C /opt/MoonRay -I zstd -xf moonray-deps/${OUT}
    # deps are then at /opt/MoonRay/installs (same prefix they were built with)
EOF
