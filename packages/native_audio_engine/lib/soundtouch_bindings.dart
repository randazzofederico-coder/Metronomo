import 'dart:ffi';
import 'dart:io';


// Type definitions
typedef SoundTouchCreateC = Pointer<Void> Function();
typedef SoundTouchCreateDart = Pointer<Void> Function();

typedef SoundTouchDestroyC = Void Function(Pointer<Void>);
typedef SoundTouchDestroyDart = void Function(Pointer<Void>);

typedef SoundTouchSetTempoC = Void Function(Pointer<Void>, Float);
typedef SoundTouchSetTempoDart = void Function(Pointer<Void>, double);

typedef SoundTouchSetPitchC = Void Function(Pointer<Void>, Float);
typedef SoundTouchSetPitchDart = void Function(Pointer<Void>, double);

typedef SoundTouchSetRateC = Void Function(Pointer<Void>, Float);
typedef SoundTouchSetRateDart = void Function(Pointer<Void>, double);

typedef SoundTouchSetChannelsC = Void Function(Pointer<Void>, Int32);
typedef SoundTouchSetChannelsDart = void Function(Pointer<Void>, int);

typedef SoundTouchSetSampleRateC = Void Function(Pointer<Void>, Int32);
typedef SoundTouchSetSampleRateDart = void Function(Pointer<Void>, int);

typedef SoundTouchPutSamplesC = Void Function(Pointer<Void>, Pointer<Float>, Int32);
typedef SoundTouchPutSamplesDart = void Function(Pointer<Void>, Pointer<Float>, int);

typedef SoundTouchReceiveSamplesC = Int32 Function(Pointer<Void>, Pointer<Float>, Int32);
typedef SoundTouchReceiveSamplesDart = int Function(Pointer<Void>, Pointer<Float>, int);

typedef SoundTouchFlushC = Void Function(Pointer<Void>);
typedef SoundTouchFlushDart = void Function(Pointer<Void>);

typedef SoundTouchClearC = Void Function(Pointer<Void>);
typedef SoundTouchClearDart = void Function(Pointer<Void>);

typedef SoundTouchNumSamplesC = Int32 Function(Pointer<Void>);
typedef SoundTouchNumSamplesDart = int Function(Pointer<Void>);

class SoundTouchBindings {
  late DynamicLibrary _lib;
  
  late SoundTouchCreateDart _create;
  late SoundTouchDestroyDart _destroy;
  late SoundTouchSetTempoDart _setTempo;
  late SoundTouchSetPitchDart _setPitch;
  late SoundTouchSetRateDart _setRate;
  late SoundTouchSetChannelsDart _setChannels;
  late SoundTouchSetSampleRateDart _setSampleRate;
  late SoundTouchPutSamplesDart _putSamples;
  late SoundTouchReceiveSamplesDart _receiveSamples;
  late SoundTouchFlushDart _flush;
  late SoundTouchClearDart _clear;
  late SoundTouchNumSamplesDart _numSamples;

  SoundTouchBindings() {
    if (Platform.isWindows) {
      _lib = DynamicLibrary.open('native_audio_engine_plugin.dll');
    } else if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libnative_audio_engine_plugin.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process(); // Static link on iOS
    } else if (Platform.isMacOS) {
      _lib = DynamicLibrary.open('native_audio_engine_plugin.framework/native_audio_engine_plugin');
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    _create = _lib.lookupFunction<SoundTouchCreateC, SoundTouchCreateDart>('soundtouch_create');
    _destroy = _lib.lookupFunction<SoundTouchDestroyC, SoundTouchDestroyDart>('soundtouch_destroy');
    _setTempo = _lib.lookupFunction<SoundTouchSetTempoC, SoundTouchSetTempoDart>('soundtouch_setTempo');
    _setPitch = _lib.lookupFunction<SoundTouchSetPitchC, SoundTouchSetPitchDart>('soundtouch_setPitch');
    _setRate = _lib.lookupFunction<SoundTouchSetRateC, SoundTouchSetRateDart>('soundtouch_setRate');
    _setChannels = _lib.lookupFunction<SoundTouchSetChannelsC, SoundTouchSetChannelsDart>('soundtouch_setChannels');
    _setSampleRate = _lib.lookupFunction<SoundTouchSetSampleRateC, SoundTouchSetSampleRateDart>('soundtouch_setSampleRate');
    _putSamples = _lib.lookupFunction<SoundTouchPutSamplesC, SoundTouchPutSamplesDart>('soundtouch_putSamples');
    _receiveSamples = _lib.lookupFunction<SoundTouchReceiveSamplesC, SoundTouchReceiveSamplesDart>('soundtouch_receiveSamples');
    _flush = _lib.lookupFunction<SoundTouchFlushC, SoundTouchFlushDart>('soundtouch_flush');
    _clear = _lib.lookupFunction<SoundTouchClearC, SoundTouchClearDart>('soundtouch_clear');
    _numSamples = _lib.lookupFunction<SoundTouchNumSamplesC, SoundTouchNumSamplesDart>('soundtouch_numSamples');
  }

  Pointer<Void> create() => _create();
  void destroy(Pointer<Void> handle) => _destroy(handle);
  void setTempo(Pointer<Void> handle, double tempo) => _setTempo(handle, tempo);
  void setPitch(Pointer<Void> handle, double pitch) => _setPitch(handle, pitch);
  void setRate(Pointer<Void> handle, double rate) => _setRate(handle, rate);
  void setChannels(Pointer<Void> handle, int channels) => _setChannels(handle, channels);
  void setSampleRate(Pointer<Void> handle, int sampleRate) => _setSampleRate(handle, sampleRate);
  void putSamples(Pointer<Void> handle, Pointer<Float> samples, int numSamples) => _putSamples(handle, samples, numSamples);
  int receiveSamples(Pointer<Void> handle, Pointer<Float> output, int maxSamples) => _receiveSamples(handle, output, maxSamples);
  void flush(Pointer<Void> handle) => _flush(handle);
  void clear(Pointer<Void> handle) => _clear(handle);
  int numSamples(Pointer<Void> handle) => _numSamples(handle);
}
