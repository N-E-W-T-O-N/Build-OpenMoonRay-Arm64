# Copyright 2023-2024 DreamWorks Animation LLC
# SPDX-License-Identifier: Apache-2.0

function(${PROJECT_NAME}_cxx_compile_definitions target)
    # ProgMcrtMergeComputation has TBB_ONEAPI code paths (task_scheduler_init was
    # removed in oneTBB 2021+) but this define was never wired up here, unlike
    # moonray/MoonrayCompileDefinitions.cmake which it mirrors.
    if(DEFINED TBB_VERSION AND TBB_VERSION VERSION_GREATER_EQUAL "2021.0")
        set(tbb_oneapi TBB_ONEAPI)
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
            ${GLOBAL_COMPILE_DEFINITIONS}
            ${tbb_oneapi}                           # define TBB_ONEAPI if TBB version >= 2021.0
            GL_GLEXT_PROTOTYPES=1                   # This define makes function symbols to be available as extern declarations.
            TBB_SUPPRESS_DEPRECATED_MESSAGES        # Suppress 'deprecated' messages from TBB
    )
endfunction()
