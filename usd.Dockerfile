# moonray:usd — USD-only carrier image (pure data; FROM scratch, nothing runs).
# OpenUSD is the one dep too slow for CI, so it's built locally once and frozen
# here for final.Dockerfile to pull with COPY --from.
#
# Prereq: USD already built via scripts/build_usd.sh — its build tree is at
# ~/moonray-work/USD/build (the install itself went into the moonray-installs
# volume, but we don't need that here).
#
# 1) Stage a clean USD-only tree onto the host by re-running ONLY the install
#    step from the existing build tree (no rebuild). DESTDIR redirects the
#    output; no volume needed:
#
#      docker run --rm --platform arm64 -v ~/moonray-work:/work \
#        newton2022/moonray:deps-heavy-ubuntu26.04 \
#        env DESTDIR=/work/OpenUsd cmake --install /work/USD/build
#
#    -> ~/moonray-work/OpenUsd/opt/MoonRay/installs/{lib,include,cmake,plugin,...}
#    (USD-only: DESTDIR captures exactly the files USD's install rules emit;
#     baked paths stay /opt/MoonRay/installs, so it drops back in correctly.)
#
# 2) Build + push. Context = the staged dir, so it stays tiny (no USD build
#    tree, no other deps get sent):
#
#      docker build -f ~/Build-OpenMoonRay-Arm64/usd.Dockerfile \
#        -t newton2022/moonray:usd ~/moonray-work/OpenUsd
#      docker push newton2022/moonray:usd
#
# 3) Pushing updates the carrier; fire the final build (see build-final-image.yml):
#      gh api repos/N-E-W-T-O-N/Build-OpenMoonRay-Arm64/dispatches \
#        -f event_type=usd-updated
FROM scratch
COPY opt/MoonRay/installs/ /opt/MoonRay/installs/
