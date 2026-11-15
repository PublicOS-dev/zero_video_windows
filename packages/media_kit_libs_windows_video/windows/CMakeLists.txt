# Hard fork of package:media_kit_libs_windows_video (MIT, Hitesh Kumar Saini).
# See ../README.md for why this fork exists and what changed.
#
# Two deltas vs upstream:
#   1. The native archives are VENDORED under binaries/ and verified with SHA-256.
#      Upstream downloads them from GitHub at build time and pins with MD5.
#   2. Extraction runs at CONFIGURE time, not build time. Upstream extracts via an
#      add_custom_target with no dependency edge to media_kit_video's compile step,
#      so the mpv headers can be consumed before they exist.

cmake_minimum_required(VERSION 3.14)

# Read by package:media_kit_video. The plugin whose CMakeLists sets this MUST be
# configured before media_kit_video's; Flutter adds plugin subdirectories in
# ALPHABETICAL order, so this package's name has to keep sorting before
# "media_kit_video". That is the reason the fork keeps the upstream package name.
option(MEDIA_KIT_LIBS_AVAILABLE "package:media_kit libraries are available." ON)

set(PROJECT_NAME "media_kit_libs_windows_video")
project(${PROJECT_NAME} LANGUAGES CXX)

# Deal with MSVC incompatiblity
add_compile_definitions(_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR)

# ------------------------------------------------------------------------------

set(VENDOR_DIR "${CMAKE_CURRENT_SOURCE_DIR}/binaries")

function(verify_sha256 file expected)
  if(NOT EXISTS "${file}")
    message(FATAL_ERROR "Vendored archive is missing: ${file}")
  endif()

  file(SHA256 "${file}" actual)

  if(NOT actual STREQUAL expected)
    message(
      FATAL_ERROR
      "Integrity check FAILED for ${file}\n"
      "  expected: ${expected}\n"
      "  actual:   ${actual}"
    )
  endif()
endfunction()

function(check_directory_exists_and_not_empty dir result_var)
  if(EXISTS "${dir}")
    file(GLOB dir_contents "${dir}/*")

    if(dir_contents)
      set(${result_var} TRUE PARENT_SCOPE)
    else()
      set(${result_var} FALSE PARENT_SCOPE)
    endif()
  else()
    set(${result_var} FALSE PARENT_SCOPE)
  endif()
endfunction()

function(extract_archive archive destination)
  file(MAKE_DIRECTORY "${destination}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar xf "${archive}"
    WORKING_DIRECTORY "${destination}"
    RESULT_VARIABLE extract_result
  )

  if(NOT extract_result EQUAL 0)
    message(FATAL_ERROR "Failed to extract ${archive} into ${destination}.")
  endif()
endfunction()

# ------------------------------------------------------------------------------
# libmpv — mpv v0.36.0-403-g652a1dd907, built LGPL (mpv -Dgpl=false; FFmpeg
# --disable-gpl --disable-nonfree --enable-version3). Sourced from the (now
# archived) media-kit/libmpv-win32-video-build release 2023-09-24.

set(LIBMPV_ARCHIVE "${VENDOR_DIR}/libmpv.7z")
set(LIBMPV_SHA256 "dce982222d7a23e4a1c6f0fb6cc39f6e899a6714624b95ea49cff6558ee97572")
set(LIBMPV_SRC "${CMAKE_BINARY_DIR}/libmpv")

verify_sha256("${LIBMPV_ARCHIVE}" "${LIBMPV_SHA256}")
check_directory_exists_and_not_empty("${LIBMPV_SRC}" LIBMPV_SRC_VALID)

if(NOT LIBMPV_SRC_VALID)
  message(STATUS "Extracting vendored libmpv...")
  extract_archive("${LIBMPV_ARCHIVE}" "${LIBMPV_SRC}")

  # The archive ships headers at include/mpv/*.h, but media_kit_video includes
  # them unqualified (#include <client.h>). Flatten include/mpv -> include.
  file(GLOB LIBMPV_HEADERS "${LIBMPV_SRC}/include/mpv/*.h")

  if(NOT LIBMPV_HEADERS)
    message(FATAL_ERROR "No mpv headers found under ${LIBMPV_SRC}/include/mpv.")
  endif()

  file(COPY ${LIBMPV_HEADERS} DESTINATION "${LIBMPV_SRC}/include.flat")
  file(REMOVE_RECURSE "${LIBMPV_SRC}/include")
  file(RENAME "${LIBMPV_SRC}/include.flat" "${LIBMPV_SRC}/include")
endif()

# ------------------------------------------------------------------------------
# ANGLE — OpenGL ES over Direct3D. media_kit_video renders libmpv's GL output
# through this into a Flutter texture.

set(ANGLE_ARCHIVE "${VENDOR_DIR}/ANGLE.7z")
set(ANGLE_SHA256 "cc5911bb15d596fd5a2b362613ad35b7093b427117269a7359054a65746a5f9a")
set(ANGLE_SRC "${CMAKE_BINARY_DIR}/ANGLE")

verify_sha256("${ANGLE_ARCHIVE}" "${ANGLE_SHA256}")
check_directory_exists_and_not_empty("${ANGLE_SRC}" ANGLE_SRC_VALID)

if(NOT ANGLE_SRC_VALID)
  message(STATUS "Extracting vendored ANGLE...")
  extract_archive("${ANGLE_ARCHIVE}" "${ANGLE_SRC}")
endif()

# ------------------------------------------------------------------------------

set(PLUGIN_NAME "media_kit_libs_windows_video_plugin")

add_library(
  ${PLUGIN_NAME} SHARED
  "include/media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h"
  "media_kit_libs_windows_video_plugin_c_api.cpp"
)

apply_standard_settings(${PLUGIN_NAME})

set_target_properties(
  ${PLUGIN_NAME}
  PROPERTIES
  CXX_VISIBILITY_PRESET
  hidden
)
target_compile_definitions(
  ${PLUGIN_NAME}
  PRIVATE
  FLUTTER_PLUGIN_IMPL
)

target_include_directories(
  ${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_link_libraries(
  ${PLUGIN_NAME}
  PRIVATE
  flutter
  flutter_wrapper_plugin
)

# Copied next to the .exe by Flutter's windows build.
set(
  media_kit_libs_windows_video_bundled_libraries
  "${LIBMPV_SRC}/libmpv-2.dll"
  "${ANGLE_SRC}/d3dcompiler_47.dll"
  "${ANGLE_SRC}/libEGL.dll"
  "${ANGLE_SRC}/libGLESv2.dll"
  "${ANGLE_SRC}/vk_swiftshader.dll"
  "${ANGLE_SRC}/vulkan-1.dll"
  "${ANGLE_SRC}/zlib.dll"
  PARENT_SCOPE
)
