include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(cpp_startup_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(cpp_startup_setup_options)
  option(cpp_startup_ENABLE_HARDENING "Enable hardening" ON)
  option(cpp_startup_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    cpp_startup_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    cpp_startup_ENABLE_HARDENING
    OFF)

  cpp_startup_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR cpp_startup_PACKAGING_MAINTAINER_MODE)
    option(cpp_startup_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(cpp_startup_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(cpp_startup_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cpp_startup_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(cpp_startup_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cpp_startup_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(cpp_startup_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cpp_startup_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cpp_startup_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cpp_startup_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(cpp_startup_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(cpp_startup_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cpp_startup_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(cpp_startup_ENABLE_IPO "Enable IPO/LTO" ON)
    option(cpp_startup_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(cpp_startup_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cpp_startup_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(cpp_startup_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cpp_startup_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(cpp_startup_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cpp_startup_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cpp_startup_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cpp_startup_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(cpp_startup_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(cpp_startup_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cpp_startup_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      cpp_startup_ENABLE_IPO
      cpp_startup_WARNINGS_AS_ERRORS
      cpp_startup_ENABLE_USER_LINKER
      cpp_startup_ENABLE_SANITIZER_ADDRESS
      cpp_startup_ENABLE_SANITIZER_LEAK
      cpp_startup_ENABLE_SANITIZER_UNDEFINED
      cpp_startup_ENABLE_SANITIZER_THREAD
      cpp_startup_ENABLE_SANITIZER_MEMORY
      cpp_startup_ENABLE_UNITY_BUILD
      cpp_startup_ENABLE_CLANG_TIDY
      cpp_startup_ENABLE_CPPCHECK
      cpp_startup_ENABLE_COVERAGE
      cpp_startup_ENABLE_PCH
      cpp_startup_ENABLE_CACHE)
  endif()

  cpp_startup_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (cpp_startup_ENABLE_SANITIZER_ADDRESS OR cpp_startup_ENABLE_SANITIZER_THREAD OR cpp_startup_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(cpp_startup_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(cpp_startup_global_options)
  if(cpp_startup_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    cpp_startup_enable_ipo()
  endif()

  cpp_startup_supports_sanitizers()

  if(cpp_startup_ENABLE_HARDENING AND cpp_startup_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cpp_startup_ENABLE_SANITIZER_UNDEFINED
       OR cpp_startup_ENABLE_SANITIZER_ADDRESS
       OR cpp_startup_ENABLE_SANITIZER_THREAD
       OR cpp_startup_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${cpp_startup_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${cpp_startup_ENABLE_SANITIZER_UNDEFINED}")
    cpp_startup_enable_hardening(cpp_startup_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(cpp_startup_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(cpp_startup_warnings INTERFACE)
  add_library(cpp_startup_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  cpp_startup_set_project_warnings(
    cpp_startup_warnings
    ${cpp_startup_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(cpp_startup_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    cpp_startup_configure_linker(cpp_startup_options)
  endif()

  include(cmake/Sanitizers.cmake)
  cpp_startup_enable_sanitizers(
    cpp_startup_options
    ${cpp_startup_ENABLE_SANITIZER_ADDRESS}
    ${cpp_startup_ENABLE_SANITIZER_LEAK}
    ${cpp_startup_ENABLE_SANITIZER_UNDEFINED}
    ${cpp_startup_ENABLE_SANITIZER_THREAD}
    ${cpp_startup_ENABLE_SANITIZER_MEMORY})

  set_target_properties(cpp_startup_options PROPERTIES UNITY_BUILD ${cpp_startup_ENABLE_UNITY_BUILD})

  if(cpp_startup_ENABLE_PCH)
    target_precompile_headers(
      cpp_startup_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(cpp_startup_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    cpp_startup_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(cpp_startup_ENABLE_CLANG_TIDY)
    cpp_startup_enable_clang_tidy(cpp_startup_options ${cpp_startup_WARNINGS_AS_ERRORS})
  endif()

  if(cpp_startup_ENABLE_CPPCHECK)
    cpp_startup_enable_cppcheck(${cpp_startup_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(cpp_startup_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    cpp_startup_enable_coverage(cpp_startup_options)
  endif()

  if(cpp_startup_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(cpp_startup_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(cpp_startup_ENABLE_HARDENING AND NOT cpp_startup_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cpp_startup_ENABLE_SANITIZER_UNDEFINED
       OR cpp_startup_ENABLE_SANITIZER_ADDRESS
       OR cpp_startup_ENABLE_SANITIZER_THREAD
       OR cpp_startup_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    cpp_startup_enable_hardening(cpp_startup_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
