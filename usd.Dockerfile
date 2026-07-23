# moonray:usd — carries the COMPLETE OpenUSD tree (source + build + manifest),
# exactly as built locally at ~/moonray-work/USD. Serves two purposes:
#   1. backup of the whole multi-hour build (nothing is lost or filtered)
#   2. final.Dockerfile installs USD from it via `cmake --install` on a mount
#
# FROM scratch: pure data, nothing runs here. Stored at /work/USD so the
# build tree's baked absolute paths (it was configured under /work/USD)
# still resolve when mounted at the same location.
#
# Build + push (context = ~/moonray-work; .dockerignore there limits it to USD/):
#   docker build -f ~/Build-OpenMoonRay-Arm64/usd.Dockerfile \
#       -t newton2022/moonray:usd ~/moonray-work
#   docker push newton2022/moonray:usd
#
# USD changes rarely — rebuild this only after re-running scripts/build_usd.sh.
FROM scratch
COPY USD/ /work/USD/
