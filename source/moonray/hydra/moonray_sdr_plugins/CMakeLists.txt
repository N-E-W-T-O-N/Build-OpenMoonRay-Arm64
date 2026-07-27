# Copyright 2023-2024 DreamWorks Animation LLC
# SPDX-License-Identifier: Apache-2.0

# TODO: setting this/these should not be necessary before calling find_package.
# see: https://stackoverflow.com/questions/55217771/boostcmake-no-suitable-build-variant
set(BUILD_SHARED_LIBS ON)
find_package(Boost REQUIRED)
add_compile_definitions(BOOST_NO_CXX98_FUNCTION_BASE)

# the DWA installation of pxrConfig.cmake lives in
# the usd_imaging Rez package. To work correctly, it
# requires env vars REZ_USD_CORE_ROOT, REZ_USD_IMAGING_ROOT
# and PXR_INCLUDE_DIRS to be set (e.g. in CMake preset).
# A standard installation should not require these...
if(NOT pxr_FOUND)
    find_package(pxr REQUIRED)

    # USD 26.x monolithic export quirk: component targets (arch/tf/hd/...) are
    # INTERFACE libs that never link the actual monolithic library (usd_m), so
    # consumers get headers but no USD symbols (mass undefined references).
    # Append usd_m to the root component 'arch' — every pxr component reaches it
    # transitively, which puts libusd_m.so on all consumers' link lines.
    if(TARGET usd_m AND TARGET arch)
        # usd_m's interface reaches garch -> OpenGL::GL; make sure it exists here
        if(NOT TARGET OpenGL::GL)
            find_package(OpenGL REQUIRED)
        endif()
        set_property(TARGET arch APPEND PROPERTY INTERFACE_LINK_LIBRARIES usd_m)
    endif()
endif()

find_package(Python REQUIRED COMPONENTS Development)

add_subdirectory(moonrayShaderDiscovery)
add_subdirectory(moonrayShaderParser)
