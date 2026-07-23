# moonray:ubuntu-final — complete build environment.
#   deps-heavy (all non-USD deps, built in CI)  +  OpenUSD installed from the
#   moonray:usd carrier (the complete local build tree).
#
# The carrier is attached as a BuildKit RUN mount (not COPY): `cmake --install`
# reads the mounted build tree and installs into /opt/MoonRay/installs; the
# mount vanishes after the RUN, so the multi-GB USD tree never becomes an
# image layer — "install it, then delete it" with zero leftover bytes.
# Mounted at /work/USD because the tree was configured there (absolute paths).
# `rw` lets cmake write install_manifest.txt into the (discarded) mount.
#
#   docker build -f final.Dockerfile \
#     --build-arg DEPS_IMAGE=newton2022/moonray:deps-heavy-ubuntu26.04 \
#     --build-arg USD_IMAGE=newton2022/moonray:usd \
#     -t newton2022/moonray:ubuntu-final .
ARG DEPS_IMAGE=newton2022/moonray:deps-heavy-ubuntu26.04
ARG USD_IMAGE=newton2022/moonray:usd

FROM ${USD_IMAGE} AS usd

FROM ${DEPS_IMAGE}
RUN --mount=type=bind,from=usd,source=/work/USD,target=/work/USD,rw \
    cmake --install /work/USD/build && \
    ls /opt/MoonRay/installs/lib/libusd_ms.so
