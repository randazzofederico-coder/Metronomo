import 'dart:ffi';
import 'dart:typed_data';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Type definitions
typedef LiveMixerCreateC = Pointer<Void> Function();
typedef LiveMixerCreateDart = Pointer<Void> Function();

typedef LiveMixerDestroyC = Void Function(Pointer<Void>);
typedef LiveMixerDestroyDart = void Function(Pointer<Void>);

typedef LiveMixerAddTrackC = Pointer<WaveformData> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef LiveMixerAddTrackDart = Pointer<WaveformData> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef LiveMixerAddTrackMemoryC = Pointer<WaveformData> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, IntPtr);
typedef LiveMixerAddTrackMemoryDart = Pointer<WaveformData> Function(Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int);

typedef LiveMixerRemoveTrackC = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef LiveMixerRemoveTrackDart = void Function(Pointer<Void>, Pointer<Utf8>);

typedef LiveMixerSetVolumeC = Void Function(Pointer<Void>, Pointer<Utf8>, Float);
typedef LiveMixerSetVolumeDart = void Function(Pointer<Void>, Pointer<Utf8>, double);

typedef LiveMixerSetMasterVolumeC = Void Function(Pointer<Void>, Float);
typedef LiveMixerSetMasterVolumeDart = void Function(Pointer<Void>, double);

typedef LiveMixerSetMasterMuteC = Void Function(Pointer<Void>, Bool);
typedef LiveMixerSetMasterMuteDart = void Function(Pointer<Void>, bool);

typedef LiveMixerSetMasterSoloC = Void Function(Pointer<Void>, Bool);
typedef LiveMixerSetMasterSoloDart = void Function(Pointer<Void>, bool);

typedef LiveMixerSetPanC = Void Function(Pointer<Void>, Pointer<Utf8>, Float);
typedef LiveMixerSetPanDart = void Function(Pointer<Void>, Pointer<Utf8>, double);

typedef LiveMixerSetMuteC = Void Function(Pointer<Void>, Pointer<Utf8>, Bool);
typedef LiveMixerSetMuteDart = void Function(Pointer<Void>, Pointer<Utf8>, bool);

typedef LiveMixerSetSoloC = Void Function(Pointer<Void>, Pointer<Utf8>, Bool);
typedef LiveMixerSetSoloDart = void Function(Pointer<Void>, Pointer<Utf8>, bool);

typedef LiveMixerSetLoopC = Void Function(Pointer<Void>, Double, Double, Bool);
typedef LiveMixerSetLoopDart = void Function(Pointer<Void>, double, double, bool);

typedef LiveMixerSeekC = Void Function(Pointer<Void>, Double);
typedef LiveMixerSeekDart = void Function(Pointer<Void>, double);

typedef LiveMixerGetPositionC = Double Function(Pointer<Void>);
typedef LiveMixerGetPositionDart = double Function(Pointer<Void>);

typedef LiveMixerProcessC = Int32 Function(Pointer<Void>, Pointer<Float>, Int32);
typedef LiveMixerProcessDart = int Function(Pointer<Void>, Pointer<Float>, int);

// --- METRONOME ---
typedef LiveMixerSetRandomSilencePercentC = Void Function(Pointer<Void>, Float);
typedef LiveMixerSetRandomSilencePercentDart = void Function(Pointer<Void>, double);

typedef LiveMixerSetMetronomeConfigC = Void Function(Pointer<Void>, Int32);
typedef LiveMixerSetMetronomeConfigDart = void Function(Pointer<Void>, int);

typedef LiveMixerSetMetronomeSoundC = Void Function(Pointer<Void>, Int32, Pointer<Float>, Int32);
typedef LiveMixerSetMetronomeSoundDart = void Function(Pointer<Void>, int, Pointer<Float>, int);

typedef LiveMixerAddMetronomePatternC = Void Function(Pointer<Void>, Int32, Pointer<Int32>, Pointer<Int32>, Pointer<Double>, Int32, Float, Bool, Bool);
typedef LiveMixerAddMetronomePatternDart = void Function(Pointer<Void>, int, Pointer<Int32>, Pointer<Int32>, Pointer<Double>, int, double, bool, bool);

typedef LiveMixerUpdateMetronomePatternC = Void Function(Pointer<Void>, Int32, Pointer<Int32>, Pointer<Int32>, Pointer<Double>, Int32, Float, Bool, Bool);
typedef LiveMixerUpdateMetronomePatternDart = void Function(Pointer<Void>, int, Pointer<Int32>, Pointer<Int32>, Pointer<Double>, int, double, bool, bool);

typedef LiveMixerRemoveMetronomePatternC = Void Function(Pointer<Void>, Int32);
typedef LiveMixerRemoveMetronomePatternDart = void Function(Pointer<Void>, int);

typedef LiveMixerClearMetronomePatternsC = Void Function(Pointer<Void>);
typedef LiveMixerClearMetronomePatternsDart = void Function(Pointer<Void>);

typedef LiveMixerSetMetronomePreviewModeC = Void Function(Pointer<Void>, Bool);
typedef LiveMixerSetMetronomePreviewModeDart = void Function(Pointer<Void>, bool);

// --- ZERO-COPY DEFS ---
final class WaveformData extends Struct {
  external Pointer<Float> peakData;
  @Int32() external int peakDataLength;
  @Int32() external int channels;
  @Int32() external int sampleRate;
  @Uint64() external int totalFrames;
  @Int32() external int error;
}

typedef LiveMixerFreeWaveformDataC = Void Function(Pointer<WaveformData>);
typedef LiveMixerFreeWaveformDataDart = void Function(Pointer<WaveformData>);

class LiveMixerBindings {
  late DynamicLibrary _lib;
  
  late LiveMixerCreateDart _create;
  late LiveMixerDestroyDart _destroy;
  late LiveMixerAddTrackDart _addTrack;
  late LiveMixerAddTrackMemoryDart _addTrackMemory;
  late LiveMixerRemoveTrackDart _removeTrack;
  late LiveMixerSetVolumeDart _setVolume;
  late LiveMixerSetMasterVolumeDart _setMasterVolume;
  late LiveMixerSetMasterMuteDart _setMasterMute;
  late LiveMixerSetMasterSoloDart _setMasterSolo;
  late LiveMixerSetPanDart _setPan;
  late LiveMixerSetMuteDart _setMute;
  late LiveMixerSetSoloDart _setSolo;
  late LiveMixerSetLoopDart _setLoop;
  late LiveMixerSeekDart _seek;
  late LiveMixerGetPositionDart _getPosition;
  late LiveMixerProcessDart _process;

  LiveMixerBindings() {
      if (Platform.isWindows) {
        _lib = DynamicLibrary.open('native_audio_engine_plugin.dll');
      } else if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libnative_audio_engine_plugin.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process(); 
      } else if (Platform.isMacOS) {
        _lib = DynamicLibrary.open('native_audio_engine_plugin.framework/native_audio_engine_plugin');
      } else {
        // Fallback or throw?
        // Try linking to process for Linux/etc if loaded implicitly
        try {
             _lib = DynamicLibrary.process();
        } catch (_) {
             throw UnsupportedError('Unsupported platform or library not found');
        }
      }

      _create = _lib.lookupFunction<LiveMixerCreateC, LiveMixerCreateDart>('live_mixer_create');
      _destroy = _lib.lookupFunction<LiveMixerDestroyC, LiveMixerDestroyDart>('live_mixer_destroy');
      _addTrack = _lib.lookupFunction<LiveMixerAddTrackC, LiveMixerAddTrackDart>('live_mixer_add_track');
      _addTrackMemory = _lib.lookupFunction<LiveMixerAddTrackMemoryC, LiveMixerAddTrackMemoryDart>('live_mixer_add_track_memory');
      _removeTrack = _lib.lookupFunction<LiveMixerRemoveTrackC, LiveMixerRemoveTrackDart>('live_mixer_remove_track');
      _setVolume = _lib.lookupFunction<LiveMixerSetVolumeC, LiveMixerSetVolumeDart>('live_mixer_set_volume');
      _setMasterVolume = _lib.lookupFunction<LiveMixerSetMasterVolumeC, LiveMixerSetMasterVolumeDart>('live_mixer_set_master_volume');
      _setMasterMute = _lib.lookupFunction<LiveMixerSetMasterMuteC, LiveMixerSetMasterMuteDart>('live_mixer_set_master_mute');
      _setMasterSolo = _lib.lookupFunction<LiveMixerSetMasterSoloC, LiveMixerSetMasterSoloDart>('live_mixer_set_master_solo');
      _setPan = _lib.lookupFunction<LiveMixerSetPanC, LiveMixerSetPanDart>('live_mixer_set_pan');
      _setMute = _lib.lookupFunction<LiveMixerSetMuteC, LiveMixerSetMuteDart>('live_mixer_set_mute');
      _setSolo = _lib.lookupFunction<LiveMixerSetSoloC, LiveMixerSetSoloDart>('live_mixer_set_solo');
      _setLoop = _lib.lookupFunction<LiveMixerSetLoopC, LiveMixerSetLoopDart>('live_mixer_set_loop');
      _seek = _lib.lookupFunction<LiveMixerSeekC, LiveMixerSeekDart>('live_mixer_seek');
      _getPosition = _lib.lookupFunction<LiveMixerGetPositionC, LiveMixerGetPositionDart>('live_mixer_get_position');
      _process = _lib.lookupFunction<LiveMixerProcessC, LiveMixerProcessDart>('live_mixer_process');
  }

  void freeWaveformData(Pointer<WaveformData> dataPtr) {
      final func = _lib.lookupFunction<LiveMixerFreeWaveformDataC, LiveMixerFreeWaveformDataDart>('live_mixer_free_waveform_data');
      func(dataPtr);
  }

  Pointer<Void> create() => _create();
  void destroy(Pointer<Void> handle) => _destroy(handle);
  
  Pointer<WaveformData> addTrack(Pointer<Void> mixer, String id, String filePath) {
      final idPtr = id.toNativeUtf8();
      final pathPtr = filePath.toNativeUtf8();
      
      final result = _addTrack(mixer, idPtr, pathPtr);
      
      calloc.free(pathPtr);
      calloc.free(idPtr);
      return result;
  }

  Pointer<WaveformData> addTrackMemory(Pointer<Void> mixer, String id, Uint8List data) {
      final idPtr = id.toNativeUtf8();
      
      // Allocate memory for the data
      final dataPtr = calloc<Uint8>(data.length);
      final dataList = dataPtr.asTypedList(data.length);
      dataList.setAll(0, data);
      
      final result = _addTrackMemory(mixer, idPtr, dataPtr, data.length);
      
      calloc.free(dataPtr);
      calloc.free(idPtr);
      return result;
  }
  
  void removeTrack(Pointer<Void> mixer, String id) {
      final idPtr = id.toNativeUtf8();
      _removeTrack(mixer, idPtr);
      calloc.free(idPtr);
  }

  void setVolume(Pointer<Void> mixer, String id, double volume) {
      final idPtr = id.toNativeUtf8();
      _setVolume(mixer, idPtr, volume);
      calloc.free(idPtr);
  }
  
  void setMasterVolume(Pointer<Void> mixer, double volume) {
      _setMasterVolume(mixer, volume);
  }
  
  void setMasterMute(Pointer<Void> mixer, bool muted) {
      _setMasterMute(mixer, muted);
  }
  
  void setMasterSolo(Pointer<Void> mixer, bool solo) {
      _setMasterSolo(mixer, solo);
  }
  
  void setPan(Pointer<Void> mixer, String id, double pan) {
      final idPtr = id.toNativeUtf8();
      _setPan(mixer, idPtr, pan);
      calloc.free(idPtr);
  }

  void setMute(Pointer<Void> mixer, String id, bool muted) {
      final idPtr = id.toNativeUtf8();
      _setMute(mixer, idPtr, muted);
      calloc.free(idPtr);
  }

  void setSolo(Pointer<Void> mixer, String id, bool solo) {
      final idPtr = id.toNativeUtf8();
      _setSolo(mixer, idPtr, solo);
      calloc.free(idPtr);
  }

  void setLoop(Pointer<Void> mixer, double start, double end, bool enabled) {
      _setLoop(mixer, start, end, enabled);
  }
  
  void seek(Pointer<Void> mixer, double position) {
      _seek(mixer, position);
  }

  double getPosition(Pointer<Void> mixer) {
      return _getPosition(mixer);
  }

  // Returns number of frames provided in output (which should be pre-allocated).
  int process(Pointer<Void> mixer, Pointer<Float> output, int frames) {
      return _process(mixer, output, frames);
  }
  
  // --- NATIVE OUTPUT BINDINGS ---
  late final _start = _lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('live_mixer_start');
  late final _stop = _lib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('live_mixer_stop');
  late final _getAtomicPosition = _lib.lookupFunction<Double Function(Pointer<Void>), double Function(Pointer<Void>)>('live_mixer_get_atomic_position');
  late final _setSpeed = _lib.lookupFunction<Void Function(Pointer<Void>, Float), void Function(Pointer<Void>, double)>('live_mixer_set_speed');
  late final _setSoundTouchSetting = _lib.lookupFunction<Void Function(Pointer<Void>, Int32, Int32), void Function(Pointer<Void>, int, int)>('live_mixer_set_soundtouch_setting');
  
  // Method caches for metronome
  late final _setRandomSilencePercent = _lib.lookupFunction<LiveMixerSetRandomSilencePercentC, LiveMixerSetRandomSilencePercentDart>('live_mixer_set_random_silence_percent');
  late final _setMetronomeConfig = _lib.lookupFunction<LiveMixerSetMetronomeConfigC, LiveMixerSetMetronomeConfigDart>('live_mixer_set_metronome_config');
  late final _setMetronomeSound = _lib.lookupFunction<LiveMixerSetMetronomeSoundC, LiveMixerSetMetronomeSoundDart>('live_mixer_set_metronome_sound');
  late final _addMetronomePattern = _lib.lookupFunction<LiveMixerAddMetronomePatternC, LiveMixerAddMetronomePatternDart>('live_mixer_add_metronome_pattern');
  late final _updateMetronomePattern = _lib.lookupFunction<LiveMixerUpdateMetronomePatternC, LiveMixerUpdateMetronomePatternDart>('live_mixer_update_metronome_pattern');
  late final _removeMetronomePattern = _lib.lookupFunction<LiveMixerRemoveMetronomePatternC, LiveMixerRemoveMetronomePatternDart>('live_mixer_remove_metronome_pattern');
  late final _clearMetronomePatterns = _lib.lookupFunction<LiveMixerClearMetronomePatternsC, LiveMixerClearMetronomePatternsDart>('live_mixer_clear_metronome_patterns');
  late final _setMetronomePreviewMode = _lib.lookupFunction<LiveMixerSetMetronomePreviewModeC, LiveMixerSetMetronomePreviewModeDart>('live_mixer_set_metronome_preview_mode');

  void start(Pointer<Void> mixer) => _start(mixer);
  void stop(Pointer<Void> mixer) => _stop(mixer);
  double getAtomicPosition(Pointer<Void> mixer) => _getAtomicPosition(mixer);
  void setSpeed(Pointer<Void> mixer, double speed) => _setSpeed(mixer, speed);
  void setSoundTouchSetting(Pointer<Void> mixer, int settingId, int value) => _setSoundTouchSetting(mixer, settingId, value);

  void setRandomSilencePercent(Pointer<Void> mixer, double percent) => _setRandomSilencePercent(mixer, percent);
  void setMetronomeConfig(Pointer<Void> mixer, int bpm) => _setMetronomeConfig(mixer, bpm);
  
  void setMetronomeSound(Pointer<Void> mixer, int type, Float32List data) {
      final ptr = calloc<Float>(data.length);
      final list = ptr.asTypedList(data.length); 
      list.setAll(0, data); 
      
      _setMetronomeSound(mixer, type, ptr, data.length);
      calloc.free(ptr);
  }

  void addMetronomePattern(Pointer<Void> mixer, int id, List<int>? flatPattern, List<int>? subdivisions, List<double>? durationRatios, double vol, bool mute, bool solo) {
      Pointer<Int32> flatPtr = nullptr;
      if (flatPattern != null && flatPattern.isNotEmpty) {
          flatPtr = calloc<Int32>(flatPattern.length);
          flatPtr.asTypedList(flatPattern.length).setAll(0, flatPattern);
      }
      Pointer<Int32> subPtr = nullptr;
      int numPulses = 0;
      if (subdivisions != null && subdivisions.isNotEmpty) {
          numPulses = subdivisions.length;
          subPtr = calloc<Int32>(numPulses);
          subPtr.asTypedList(numPulses).setAll(0, subdivisions);
      }
      Pointer<Double> durPtr = nullptr;
      if (durationRatios != null && durationRatios.isNotEmpty) {
          durPtr = calloc<Double>(durationRatios.length);
          durPtr.asTypedList(durationRatios.length).setAll(0, durationRatios);
      }
      
      _addMetronomePattern(mixer, id, flatPtr, subPtr, durPtr, numPulses, vol, mute, solo);
      
      if (flatPtr != nullptr) calloc.free(flatPtr);
      if (subPtr != nullptr) calloc.free(subPtr);
      if (durPtr != nullptr) calloc.free(durPtr);
  }

  void updateMetronomePattern(Pointer<Void> mixer, int id, List<int>? flatPattern, List<int>? subdivisions, List<double>? durationRatios, double vol, bool mute, bool solo) {
      Pointer<Int32> flatPtr = nullptr;
      if (flatPattern != null && flatPattern.isNotEmpty) {
          flatPtr = calloc<Int32>(flatPattern.length);
          flatPtr.asTypedList(flatPattern.length).setAll(0, flatPattern);
      }
      Pointer<Int32> subPtr = nullptr;
      int numPulses = 0;
      if (subdivisions != null && subdivisions.isNotEmpty) {
          numPulses = subdivisions.length;
          subPtr = calloc<Int32>(numPulses);
          subPtr.asTypedList(numPulses).setAll(0, subdivisions);
      }
      Pointer<Double> durPtr = nullptr;
      if (durationRatios != null && durationRatios.isNotEmpty) {
          durPtr = calloc<Double>(durationRatios.length);
          durPtr.asTypedList(durationRatios.length).setAll(0, durationRatios);
      }
      
      _updateMetronomePattern(mixer, id, flatPtr, subPtr, durPtr, numPulses, vol, mute, solo);
      
      if (flatPtr != nullptr) calloc.free(flatPtr);
      if (subPtr != nullptr) calloc.free(subPtr);
      if (durPtr != nullptr) calloc.free(durPtr);
  }

  void removeMetronomePattern(Pointer<Void> mixer, int id) => _removeMetronomePattern(mixer, id);
  void clearMetronomePatterns(Pointer<Void> mixer) => _clearMetronomePatterns(mixer);
  
  void setMetronomePreviewMode(Pointer<Void> mixer, bool enabled) => _setMetronomePreviewMode(mixer, enabled);
}
