include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(flyio_challenges_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(flyio_challenges_setup_options)
  option(flyio_challenges_ENABLE_HARDENING "Enable hardening" ON)
  option(flyio_challenges_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    flyio_challenges_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    flyio_challenges_ENABLE_HARDENING
    OFF)

  flyio_challenges_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR flyio_challenges_PACKAGING_MAINTAINER_MODE)
    option(flyio_challenges_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(flyio_challenges_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(flyio_challenges_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(flyio_challenges_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(flyio_challenges_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(flyio_challenges_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(flyio_challenges_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(flyio_challenges_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(flyio_challenges_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(flyio_challenges_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(flyio_challenges_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(flyio_challenges_ENABLE_PCH "Enable precompiled headers" OFF)
    option(flyio_challenges_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(flyio_challenges_ENABLE_IPO "Enable IPO/LTO" ON)
    option(flyio_challenges_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(flyio_challenges_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(flyio_challenges_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(flyio_challenges_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(flyio_challenges_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(flyio_challenges_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(flyio_challenges_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(flyio_challenges_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(flyio_challenges_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(flyio_challenges_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(flyio_challenges_ENABLE_PCH "Enable precompiled headers" OFF)
    option(flyio_challenges_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      flyio_challenges_ENABLE_IPO
      flyio_challenges_WARNINGS_AS_ERRORS
      flyio_challenges_ENABLE_USER_LINKER
      flyio_challenges_ENABLE_SANITIZER_ADDRESS
      flyio_challenges_ENABLE_SANITIZER_LEAK
      flyio_challenges_ENABLE_SANITIZER_UNDEFINED
      flyio_challenges_ENABLE_SANITIZER_THREAD
      flyio_challenges_ENABLE_SANITIZER_MEMORY
      flyio_challenges_ENABLE_UNITY_BUILD
      flyio_challenges_ENABLE_CLANG_TIDY
      flyio_challenges_ENABLE_CPPCHECK
      flyio_challenges_ENABLE_COVERAGE
      flyio_challenges_ENABLE_PCH
      flyio_challenges_ENABLE_CACHE)
  endif()

  flyio_challenges_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (flyio_challenges_ENABLE_SANITIZER_ADDRESS OR flyio_challenges_ENABLE_SANITIZER_THREAD OR flyio_challenges_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(flyio_challenges_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(flyio_challenges_global_options)
  if(flyio_challenges_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    flyio_challenges_enable_ipo()
  endif()

  flyio_challenges_supports_sanitizers()

  if(flyio_challenges_ENABLE_HARDENING AND flyio_challenges_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR flyio_challenges_ENABLE_SANITIZER_UNDEFINED
       OR flyio_challenges_ENABLE_SANITIZER_ADDRESS
       OR flyio_challenges_ENABLE_SANITIZER_THREAD
       OR flyio_challenges_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${flyio_challenges_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${flyio_challenges_ENABLE_SANITIZER_UNDEFINED}")
    flyio_challenges_enable_hardening(flyio_challenges_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(flyio_challenges_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(flyio_challenges_warnings INTERFACE)
  add_library(flyio_challenges_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  flyio_challenges_set_project_warnings(
    flyio_challenges_warnings
    ${flyio_challenges_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(flyio_challenges_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(flyio_challenges_options)
  endif()

  include(cmake/Sanitizers.cmake)
  flyio_challenges_enable_sanitizers(
    flyio_challenges_options
    ${flyio_challenges_ENABLE_SANITIZER_ADDRESS}
    ${flyio_challenges_ENABLE_SANITIZER_LEAK}
    ${flyio_challenges_ENABLE_SANITIZER_UNDEFINED}
    ${flyio_challenges_ENABLE_SANITIZER_THREAD}
    ${flyio_challenges_ENABLE_SANITIZER_MEMORY})

  set_target_properties(flyio_challenges_options PROPERTIES UNITY_BUILD ${flyio_challenges_ENABLE_UNITY_BUILD})

  if(flyio_challenges_ENABLE_PCH)
    target_precompile_headers(
      flyio_challenges_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(flyio_challenges_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    flyio_challenges_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(flyio_challenges_ENABLE_CLANG_TIDY)
    flyio_challenges_enable_clang_tidy(flyio_challenges_options ${flyio_challenges_WARNINGS_AS_ERRORS})
  endif()

  if(flyio_challenges_ENABLE_CPPCHECK)
    flyio_challenges_enable_cppcheck(${flyio_challenges_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(flyio_challenges_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    flyio_challenges_enable_coverage(flyio_challenges_options)
  endif()

  if(flyio_challenges_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(flyio_challenges_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(flyio_challenges_ENABLE_HARDENING AND NOT flyio_challenges_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR flyio_challenges_ENABLE_SANITIZER_UNDEFINED
       OR flyio_challenges_ENABLE_SANITIZER_ADDRESS
       OR flyio_challenges_ENABLE_SANITIZER_THREAD
       OR flyio_challenges_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    flyio_challenges_enable_hardening(flyio_challenges_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
