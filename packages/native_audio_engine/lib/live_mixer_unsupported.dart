import 'audio_track_info.dart';
import 'dart:typed_data';

class LiveMixer {
  LiveMixer();

  void dispose() {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  AudioTrackInfo? addTrack(String id, String filePath) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  AudioTrackInfo? addTrackMemory(String id, Uint8List data) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void removeTrack(String id) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setVolume(String id, double volume) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setMasterVolume(double volume) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setMasterMute(bool muted) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setMasterSolo(bool solo) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setPan(String id, double pan) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setMute(String id, bool muted) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setSolo(String id, bool solo) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setLoop(int startSample, int endSample, bool enabled) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void seek(int positionSample) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  int getPosition() {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }
  
  List<double> process(int frames) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }
  
  void startPlayback() {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }
  
  void stopPlayback() {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }
  
  int getAtomicPosition() {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }
  
  void setSpeed(double speed) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }
  
  void setSoundTouchSetting(int settingId, int value) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setMetronomeConfig(int bpm) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setMetronomeSound(int type, Float32List data) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void addMetronomePattern(int id, List<int>? flatPattern, List<int>? subdivisions, List<double>? durationRatios, double vol, bool mute, bool solo) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void updateMetronomePattern(int id, List<int>? flatPattern, List<int>? subdivisions, List<double>? durationRatios, double vol, bool mute, bool solo) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void removeMetronomePattern(int id) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void clearMetronomePatterns() {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }

  void setMetronomePreviewMode(bool enabled) {
    throw UnsupportedError('Native audio engine is not supported on this platform.');
  }
}
