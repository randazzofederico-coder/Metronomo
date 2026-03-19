@echo off
echo.
echo ==========================================================
echo    Elongacion Musical - WebAssembly Audio Engine Build
echo ==========================================================
echo.

set "BASE_DIR=%~dp0"
set "SRC_DIR=%BASE_DIR%src"
set "OUT_DIR=%BASE_DIR%..\..\web"
set "SOUNDTOUCH_DIR=%SRC_DIR%\soundtouch\source\SoundTouch"
set "SOUNDTOUCH_INC=%SRC_DIR%\soundtouch\include"

REM Create output directory if it doesn't exist
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

REM Exported functions list (C API wrapper)
REM Note: The names must be prefixed with an underscore '_' when passed to emcc
set EXPORTED_FUNCTIONS="['_live_mixer_add_track', '_live_mixer_add_track_memory', '_live_mixer_add_track_pcm', '_live_mixer_free_waveform_data', '_live_mixer_set_master_mute', '_live_mixer_set_master_solo', '_live_mixer_set_metronome_config', '_live_mixer_set_metronome_sound', '_live_mixer_add_metronome_pattern', '_live_mixer_update_metronome_pattern', '_live_mixer_remove_metronome_pattern', '_live_mixer_clear_metronome_patterns', '_live_mixer_set_metronome_preview_mode', '_malloc', '_free', '_live_mixer_create', '_live_mixer_destroy', '_live_mixer_remove_track', '_live_mixer_set_volume', '_live_mixer_set_master_volume', '_live_mixer_set_pan', '_live_mixer_set_mute', '_live_mixer_set_solo', '_live_mixer_set_loop', '_live_mixer_seek', '_live_mixer_get_position', '_live_mixer_process', '_live_mixer_start', '_live_mixer_stop', '_live_mixer_get_atomic_position', '_live_mixer_set_speed', '_live_mixer_set_soundtouch_setting']"

REM Exported runtime methods needed for memory manipulation from JS
set EXPORTED_RUNTIME_METHODS="['ccall', 'cwrap', 'setValue', 'getValue', 'HEAPU8', 'HEAP32', 'HEAPF32', 'HEAPF64', 'allocateUTF8']"

echo Compiling C++ files to WebAssembly...
echo.

REM Hardcoded path based on your PowerShell output
set EMSDK_PATH=C:\dev\emsdk
set EMSCRIPTEN_PYTHON=%EMSDK_PATH%\python\3.13.3_64bit\python.exe
set EMCC_PY=%EMSDK_PATH%\upstream\emscripten\emcc.py

call "%EMSCRIPTEN_PYTHON%" "%EMCC_PY%" ^
    "%SRC_DIR%\live_mixer.cpp" ^
    "%SRC_DIR%\soundtouch_wrapper.cpp" ^
    "%SOUNDTOUCH_DIR%\AAFilter.cpp" ^
    "%SOUNDTOUCH_DIR%\BPMDetect.cpp" ^
    "%SOUNDTOUCH_DIR%\cpu_detect_x86.cpp" ^
    "%SOUNDTOUCH_DIR%\FIFOSampleBuffer.cpp" ^
    "%SOUNDTOUCH_DIR%\FIRFilter.cpp" ^
    "%SOUNDTOUCH_DIR%\InterpolateCubic.cpp" ^
    "%SOUNDTOUCH_DIR%\InterpolateLinear.cpp" ^
    "%SOUNDTOUCH_DIR%\InterpolateShannon.cpp" ^
    "%SOUNDTOUCH_DIR%\PeakFinder.cpp" ^
    "%SOUNDTOUCH_DIR%\RateTransposer.cpp" ^
    "%SOUNDTOUCH_DIR%\SoundTouch.cpp" ^
    "%SOUNDTOUCH_DIR%\TDStretch.cpp" ^
    -I"%SRC_DIR%" ^
    -I"%SOUNDTOUCH_DIR%" ^
    -I"%SOUNDTOUCH_INC%" ^
    -O3 ^
    -s WASM=1 ^
    -s EXPORTED_FUNCTIONS=%EXPORTED_FUNCTIONS% ^
    -s EXPORTED_RUNTIME_METHODS=%EXPORTED_RUNTIME_METHODS% ^
    -s ALLOW_MEMORY_GROWTH=1 ^
    -s MAXIMUM_MEMORY=1073741824 ^
    -s USE_PTHREADS=0 ^
    -s MODULARIZE=1 ^
    -s EXPORT_NAME="LiveMixerModule" ^
    -DMINIAUDIO_IMPLEMENTATION ^
    -o "%OUT_DIR%\live_mixer.js"

REM Inject globalThis export so it is visible inside the isolated AudioWorkletGlobalScope
echo globalThis.LiveMixerModule = LiveMixerModule; >> "%OUT_DIR%\live_mixer.js"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Emscripten compilation failed.
    echo Ensure you have activated the Emscripten SDK environment.
    exit /b %ERRORLEVEL%
)

echo.
echo [SUCCESS] Build complete!
echo Output files:
echo   - %OUT_DIR%\live_mixer.js
echo   - %OUT_DIR%\live_mixer.wasm
echo.
