#!/usr/bin/env bash
# Enter the deps-heavy container with persistent mounts, ready to build USD.
# Inside, run:  WORK=/work /scripts/build_usd.sh
#
# Mounts:
#   moonray-installs (named volume) -> /opt/MoonRay/installs  (seeded from image; keeps USD install)
#   $WORK_DIR (host ext4)           -> /work                  (keeps USD src + build tree; resumable)
#   ./scripts                       -> /scripts               (live-edit scripts from host)
set -euo pipefail

IMAGE="${IMAGE:-newton2022/moonray:deps-heavy-ubuntu26.04}"
WORK_DIR="${WORK_DIR:-$HOME/moonray-work}"   # MUST be native ext4, NOT /mnt/c or /mnt/d (drvfs)
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/scripts" && pwd)"

case "${WORK_DIR}" in
    /mnt/*) echo "WARNING: ${WORK_DIR} is on drvfs — USD build will be very slow and may break symlinks." >&2 ;;
esac

mkdir -p "${WORK_DIR}"

exec docker run -it --pull always   --platform arm64 \
    -v moonray-installs:/opt/MoonRay/installs \
    -v /tmp:/tmp \
    -v "${WORK_DIR}:/work" \
    -v "${SCRIPTS_DIR}:/scripts" \
    "${IMAGE}" bash
