# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "native_audio_engine")
project(${PROJECT_NAME} LANGUAGES CXX C)

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "native_audio_engine_plugin")

# SoundTouch Configuration
set(SOUNDTOUCH_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../src/soundtouch")
set(SOUNDTOUCH_SOURCES
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/AAFilter.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/BPMDetect.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/cpu_detect_x86.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/FIFOSampleBuffer.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/FIRFilter.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/InterpolateCubic.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/InterpolateLinear.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/InterpolateShannon.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/mmx_optimized.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/PeakFinder.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/RateTransposer.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/SoundTouch.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/sse_optimized.cpp"
  "${SOUNDTOUCH_ROOT}/source/SoundTouch/TDStretch.cpp"
)

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "native_audio_engine_plugin.cpp"
  "native_audio_engine_plugin.h"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/soundtouch_wrapper.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/live_mixer.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/Vocoder.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src/kiss_fft.c"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
# We also include SoundTouch sources here.
add_library(${PLUGIN_NAME} SHARED
  "include/native_audio_engine/native_audio_engine_plugin_c_api.h"
  "native_audio_engine_plugin_c_api.cpp"
  ${PLUGIN_SOURCES}
  ${SOUNDTOUCH_SOURCES}
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL ST_NO_EXCEPTION_HANDLING)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

# Add SoundTouch includes
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${SOUNDTOUCH_ROOT}/include"
  "${CMAKE_CURRENT_SOURCE_DIR}/../src"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

if(WIN32)
  target_link_libraries(${PLUGIN_NAME} PRIVATE mfreadwrite mfplat mfuuid ole32)
endif()

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(native_audio_engine_bundled_libraries
  ""
  PARENT_SCOPE
)

# === Tests ===
# These unit tests can be run from a terminal after building the example, or
# from Visual Studio after opening the generated solution file.
if (${include_${PROJECT_NAME}_tests})
# ... (omitted for brevity, assume unchanged or disabled for now)
endif()

