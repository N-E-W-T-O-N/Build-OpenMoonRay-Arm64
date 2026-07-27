# SPDX-License-Identifier: Apache-2.0
# Copyright Contributors to the Moonray Project

function(${PROJECT_NAME}_cxx_compile_definitions target)
    if(CMAKE_BINARY_DIR MATCHES ".*refplat-vfx2020.*")
        # Use openvdb abi version 7 for vfx2020 to match up with Houdini 18.5
        set(abi 7)
    else()
        set(abi 8)
    endif()

    target_compile_definitions(${target}
        PRIVATE
            $<$<CONFIG:DEBUG>:
                DEBUG                               # Enables extra validation/debugging code
            >
            $<$<CONFIG:RELWITHDEBINFO>:
                BOOST_DISABLE_ASSERTS               # Disable BOOST_ASSERT macro
            >
            $<$<CONFIG:RELEASE>:
                BOOST_DISABLE_ASSERTS               # Disable BOOST_ASSERT macro
            >

        PUBLIC
            ${GLOBAL_CPP_FLAGS}     # __AVX__ on x86-64, __ARM_NEON__ on aarch64 (was hardcoded __AVX__)
            GL_GLEXT_PROTOTYPES=1                   # This define makes function symbols to be available as extern declarations.
            TBB_SUPPRESS_DEPRECATED_MESSAGES        # Suppress 'deprecated' messages from TBB
    )
endfunction()
