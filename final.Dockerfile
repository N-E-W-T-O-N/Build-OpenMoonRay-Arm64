# moonray:ubuntu-final — complete build environment:
#   deps-heavy (all non-USD deps: TBB, OpenSubdiv, OIDN, Embree, OCIO, OIIO,
#   GLFW, Random123, OptiX headers)  +  OpenUSD (from the moonray:usd carrier).
#
# COPY --from merges USD's files into the same /opt/MoonRay/installs prefix and
# leaves nothing to clean up (no temp dir, no extra layer to delete) — USD's
# baked absolute paths line up because it lands back at its original prefix.
#
#   docker build -f final.Dockerfile \
#     --build-arg DEPS_IMAGE=newton2022/moonray:deps-heavy-ubuntu26.04 \
#     --build-arg USD_IMAGE=newton2022/moonray:usd \
#     -t newton2022/moonray:ubuntu-final .
ARG DEPS_IMAGE=newton2022/moonray:deps-heavy-ubuntu26.04
ARG USD_IMAGE=newton2022/moonray:usd
FROM ${DEPS_IMAGE}
ARG USD_IMAGE
COPY --from=${USD_IMAGE} /opt/MoonRay/installs /opt/MoonRay/installs
