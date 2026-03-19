cmake_minimum_required(VERSION 3.4.1)

project(native_audio_engine_plugin)

# --- AUDIO DSP OPTIMIZATIONS ---
# Enforce maximum optimization even during Flutter Debug builds.
# SoundTouch requires heavy math which starves the CPU without these flags.
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -ffast-math -fomit-frame-pointer")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -ffast-math -fomit-frame-pointer")
add_definitions(-DSOUNDTOUCH_FLOAT_SAMPLES=1)
# -------------------------------

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

add_library(native_audio_engine_plugin SHARED
    "${CMAKE_CURRENT_SOURCE_DIR}/../src/soundtouch_wrapper.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/../src/live_mixer.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/../src/Vocoder.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/../src/kiss_fft.c"
    ${SOUNDTOUCH_SOURCES}
)

include_directories(
    "${SOUNDTOUCH_ROOT}/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/../src"
)

find_library(log-lib log)

target_link_libraries(native_audio_engine_plugin ${log-lib})

target_compile_definitions(native_audio_engine_plugin PRIVATE ST_NO_EXCEPTION_HANDLING)
