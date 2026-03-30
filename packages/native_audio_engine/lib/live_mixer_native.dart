import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'live_mixer_bindings.dart';
import 'audio_track_info.dart';

class LiveMixer {
  final LiveMixerBindings _bindings = LiveMixerBindings();
  late Pointer<Void> _handle;
  bool _isDisposed = false;

  LiveMixer() {
    _handle = _bindings.create();
  }

  void dispose() {
    if (!_isDisposed) {
      _bindings.destroy(_handle);
      _isDisposed = true;
    }
  }

  AudioTrackInfo? addTrack(String id, String filePath) {
    if (_isDisposed) return null;
    final wavePtr = _bindings.addTrack(_handle, id, filePath);
    return _extractAndFreeWaveformData(wavePtr);
  }

  AudioTrackInfo? addTrackMemory(String id, Uint8List data) {
    if (_isDisposed) return null;
    // We didn't add the addTrackMemory binding in live_mixer_bindings.dart yet. 
    // Need to do that too. Assuming it returns pointer.
    return _extractAndFreeWaveformData(null); // Will fix next
  }

  AudioTrackInfo? _extractAndFreeWaveformData(Pointer<WaveformData>? wavePtr) {
    if (wavePtr == null || wavePtr == nullptr || wavePtr.ref.error != 0) {
       if (wavePtr != null && wavePtr != nullptr) freeWaveformData(wavePtr);
       return null;
    }
    
    final decoded = wavePtr.ref;
    final channels = decoded.channels;
    
    // Extract points
    List<double> peaks = [];
    if (decoded.peakData != nullptr) {
       for (int i = 0; i < decoded.peakDataLength; i++) {
           peaks.add(decoded.peakData[i]);
       }
    }
    
    final info = AudioTrackInfo(
      peakData: peaks,
      peakDataLength: decoded.peakDataLength,
      channels: channels,
      sampleRate: decoded.sampleRate,
      totalFrames: decoded.totalFrames,
      error: decoded.error,
    );
    
    freeWaveformData(wavePtr);
    return info;
  }

  void freeWaveformData(Pointer<WaveformData> dataPtr) {
    _bindings.freeWaveformData(dataPtr);
  }

  void removeTrack(String id) {
    if (_isDisposed) return;
    _bindings.removeTrack(_handle, id);
  }

  void setVolume(String id, double volume) {
    if (_isDisposed) return;
    _bindings.setVolume(_handle, id, volume);
  }

  void setMasterVolume(double volume) {
    if (_isDisposed) return;
    _bindings.setMasterVolume(_handle, volume);
  }

  void setMasterMute(bool muted) {
    if (_isDisposed) return;
    _bindings.setMasterMute(_handle, muted);
  }

  void setMasterSolo(bool solo) {
    if (_isDisposed) return;
    _bindings.setMasterSolo(_handle, solo);
  }

  void setPan(String id, double pan) {
    if (_isDisposed) return;
    _bindings.setPan(_handle, id, pan);
  }

  void setMute(String id, bool muted) {
    if (_isDisposed) return;
    _bindings.setMute(_handle, id, muted);
  }

  void setSolo(String id, bool solo) {
    if (_isDisposed) return;
    _bindings.setSolo(_handle, id, solo);
  }

  void setLoop(int startSample, int endSample, bool enabled) {
    if (_isDisposed) return;
    _bindings.setLoop(_handle, startSample.toDouble(), endSample.toDouble(), enabled);
  }

  void seek(int positionSample) {
    if (_isDisposed) return;
    _bindings.seek(_handle, positionSample.toDouble());
  }

  int getPosition() {
    if (_isDisposed) return 0;
    return _bindings.getPosition(_handle).toInt();
  }
  
  /// Process audio.
  /// [frames] is number of stereo frames to request.
  /// Returns a List<double> of interleaved samples (length = frames * 2).
  List<double> process(int frames) {
      if (_isDisposed) return List.filled(frames * 2, 0.0);
      
      final outputPtr = calloc<Float>(frames * 2);
      
      int filled = _bindings.process(_handle, outputPtr, frames);
      
      List<double> result = List<double>.filled(frames * 2, 0.0);
      for (int i = 0; i < frames * 2; i++) {
          result[i] = outputPtr[i];
      }
      
      calloc.free(outputPtr);
      return result;
  }
  
  // Method to allow filling an existing buffer if we want to avoid allocation thrashing?
  // Current Stream implementation in Dart usually yields new lists anyway.
  
  // --- NATIVE OUTPUT CONTROL ---
  void startPlayback() {
     if (_isDisposed) return;
     _bindings.start(_handle);
  }
  
  void stopPlayback() {
     if (_isDisposed) return;
     _bindings.stop(_handle);
  }
  
  int getAtomicPosition() {
     if (_isDisposed) return 0;
     return _bindings.getAtomicPosition(_handle).toInt();
  }
  
  void setSpeed(double speed) {
     if (_isDisposed) return;
     _bindings.setSpeed(_handle, speed);
  }
  
  void setSoundTouchSetting(int settingId, int value) {
     if (_isDisposed) return;
     _bindings.setSoundTouchSetting(_handle, settingId, value);
  }

  void setRandomSilencePercent(double percent) {
     if (_isDisposed) return;
     _bindings.setRandomSilencePercent(_handle, percent);
  }

  // --- METRONOME ---
  void setMetronomeConfig(int bpm) {
     if (_isDisposed) return;
     _bindings.setMetronomeConfig(_handle, bpm);
  }

  void setMetronomeSound(int type, Float32List data) {
     if (_isDisposed) return;
     _bindings.setMetronomeSound(_handle, type, data);
  }

  void addMetronomePattern(int id, List<int>? flatPattern, List<int>? subdivisions, List<double>? durationRatios, double vol, bool mute, bool solo) {
      if (_isDisposed) return;
      _bindings.addMetronomePattern(_handle, id, flatPattern, subdivisions, durationRatios, vol, mute, solo);
  }

  void updateMetronomePattern(int id, List<int>? flatPattern, List<int>? subdivisions, List<double>? durationRatios, double vol, bool mute, bool solo) {
      if (_isDisposed) return;
      _bindings.updateMetronomePattern(_handle, id, flatPattern, subdivisions, durationRatios, vol, mute, solo);
  }

  void removeMetronomePattern(int id) {
      if (_isDisposed) return;
      _bindings.removeMetronomePattern(_handle, id);
  }

  void clearMetronomePatterns() {
      if (_isDisposed) return;
      _bindings.clearMetronomePatterns(_handle);
  }

  void setMetronomePreviewMode(bool enabled) {
      if (_isDisposed) return;
      _bindings.setMetronomePreviewMode(_handle, enabled);
  }
}
