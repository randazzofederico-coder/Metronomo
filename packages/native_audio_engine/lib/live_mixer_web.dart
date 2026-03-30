import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:async';
import 'audio_track_info.dart';

@JS('LiveMixerModule')
external JSPromise<JSAny?> modulePromise();

@JS('AudioContext')
external JSFunction? get _audioContextConstructor;
@JS('webkitAudioContext')
external JSFunction? get _webkitAudioContextConstructor;

JSObject _createAudioContext() {
  if (_audioContextConstructor != null) return _audioContextConstructor!.callAsConstructor();
  if (_webkitAudioContextConstructor != null) return _webkitAudioContextConstructor!.callAsConstructor();
  throw UnsupportedError('AudioContext not supported.');
}

extension type AudioBuffer._(JSObject _) implements JSObject {
  external int get length;
  external int get numberOfChannels;
  external int get sampleRate;
  external JSFloat32Array getChannelData(int channel);
}

extension type AudioProcessingEvent._(JSObject _) implements JSObject {
  external AudioBuffer get outputBuffer;
}

extension type AudioWorkletNode._(JSObject _) implements JSObject {
  factory AudioWorkletNode(AudioContext context, String name, [JSObject? options]) {
    return _audioWorkletNodeConstructor.callAsConstructor<AudioWorkletNode>(context, name.toJS, options);
  }
  external JSObject get port;
  external void connect(JSObject destination);
  external void disconnect();
}

@JS('AudioWorkletNode')
external JSFunction get _audioWorkletNodeConstructor;

extension type AudioWorklet._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> addModule(JSString moduleUrl);
}

extension type AudioContext._(JSObject _) implements JSObject {
  factory AudioContext() => AudioContext._(_createAudioContext());
  external JSPromise<JSAny?> decodeAudioData(JSObject audioData);
  external AudioWorklet get audioWorklet;
}

@JS('fetch')
external JSPromise<JSAny?> _fetch(JSString url);

extension type Response._(JSObject _) implements JSObject {
  external bool get ok;
  external JSPromise<JSAny?> arrayBuffer();
}



class LiveMixer {
  bool isReady = false;
  bool _isDisposed = false;

  AudioContext? _audioContext;
  JSObject? _scriptNode;
  
  static AudioContext? _decodeCtx;

  int _currentPos = 0;
  int _currentAtomicPos = 0;
  
  int _nextReqId = 1;
  final Map<int, Completer<AudioTrackInfo?>> _trackCompleters = {};

  LiveMixer();

  Future<void> init() async {
    _audioContext = AudioContext();
    await _initAudioWorklet();
    isReady = true;
  }

  Future<void> _initAudioWorklet() async {
      try {
          // 1. Fetch WASM binary as ArrayBuffer
          final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
          final fetchPromise = _fetch('live_mixer.wasm?v=2_$cacheBuster'.toJS);
          final responseDynamic = await fetchPromise.toDart;
          final response = responseDynamic as Response;
          if (!response.ok) {
              throw Exception("Failed to fetch live_mixer.wasm");
          }
          final arrayBufferPromise = response.arrayBuffer();
          final wasmBinary = await arrayBufferPromise.toDart as JSObject;

          // 2. Load WASM Module wrapper and AudioWorklet processor script
          final worklet = _audioContext!.audioWorklet;
          await worklet.addModule('live_mixer.js?v=$cacheBuster'.toJS).toDart;
          await worklet.addModule('audio_worklet_processor.js?v=$cacheBuster'.toJS).toDart;
          
          final options = {'outputChannelCount': [2]}.jsify() as JSObject;
          final node = AudioWorkletNode(_audioContext!, 'live-mixer-worklet', options);
          _scriptNode = node;
          
          node.connect(_audioContext!.getProperty('destination'.toJS) as JSObject);
          
          final port = node.port;
          

          
          // 3. Setup message listener from Worklet
          port.setProperty('onmessage'.toJS, ((JSObject eventObj) {
              final data = eventObj.getProperty('data'.toJS) as JSObject;
              final type = data.getProperty('type'.toJS).dartify() as String?;
              
              if (type == 'state') {
                  _currentPos = (data.getProperty('position'.toJS).dartify() as num?)?.toInt() ?? 0;
                  _currentAtomicPos = (data.getProperty('atomicPosition'.toJS).dartify() as num?)?.toInt() ?? 0;
              } else if (type == 'trackAdded') {
                 final reqId = (data.getProperty('reqId'.toJS).dartify() as num?)?.toInt() ?? 0;
                 final error = (data.getProperty('error'.toJS).dartify() as num?)?.toInt() ?? 0;
                 final completer = _trackCompleters.remove(reqId);
                 
                 if (completer != null) {
                     if (error != 0) {
                         completer.complete(null);
                     } else {
                         final peakDataLength = (data.getProperty('peakDataLength'.toJS).dartify() as num?)?.toInt() ?? 0;
                         final channels = (data.getProperty('channels'.toJS).dartify() as num?)?.toInt() ?? 2;
                         final sampleRate = (data.getProperty('sampleRate'.toJS).dartify() as num?)?.toInt() ?? 44100;
                         final totalFrames = (data.getProperty('totalFrames'.toJS).dartify() as num?)?.toInt() ?? 0;
                         
                         List<double> peaks = [];
                         if (peakDataLength > 0) {
                             final peaksArray = (data.getProperty('peaks'.toJS) as JSFloat32Array).toDart;
                             peaks.addAll(peaksArray);
                         }
                         
                         completer.complete(AudioTrackInfo(
                            peakData: peaks,
                            peakDataLength: peakDataLength,
                            channels: channels,
                            sampleRate: sampleRate,
                            totalFrames: totalFrames,
                            error: error,
                         ));
                     }
                 }
              }
          }).toJS);
          
          // 4. Send init message
          final initMsg = JSObject();
          initMsg.setProperty('type'.toJS, 'init'.toJS);
          initMsg.setProperty('wasmBinary'.toJS, wasmBinary);
          
          port.callMethod('postMessage'.toJS, initMsg);
          
      } catch (e) {
          print("Failed to initialize AudioWorklet: $e");
      }
  }

  void dispose() {
    if (!_isDisposed && isReady) {
      if (_scriptNode != null) {
          final port = _scriptNode!.getProperty('port'.toJS) as JSObject;
          final msg = JSObject();
          msg.setProperty('type'.toJS, 'cmd'.toJS);
          msg.setProperty('cmd'.toJS, 'dispose'.toJS);
          port.callMethod('postMessage'.toJS, msg);
          _scriptNode!.callMethod('disconnect'.toJS);
          _scriptNode = null;
      }
      _isDisposed = true;
    }
  }

  void _postCmd(JSObject msg) {
      if (_scriptNode != null) {
          final port = _scriptNode!.getProperty('port'.toJS) as JSObject;
          msg.setProperty('type'.toJS, 'cmd'.toJS);
          port.callMethod('postMessage'.toJS, msg);
      }
  }

  AudioTrackInfo? addTrack(String id, String filePath) {
    throw UnsupportedError('Loading from file path is not supported on Web. Use addTrackMemory.');
  }

  Future<AudioTrackInfo?> addTrackMemory(String id, Uint8List data) async {
    if (_isDisposed || !isReady) return null;
    
    final exactBytes = Uint8List.fromList(data);
    _decodeCtx ??= AudioContext();
    final promise = _decodeCtx!.decodeAudioData(exactBytes.buffer.toJS);
    final decodedDynamic = await promise.toDart;
    final audioBuffer = decodedDynamic as AudioBuffer;
    
    int channels = audioBuffer.numberOfChannels;
    int length = audioBuffer.length;
    int sampleRate = audioBuffer.sampleRate;
    
    Float32List interleaved = Float32List(length * channels);
    for (int c = 0; c < channels; c++) {
      final channelData = audioBuffer.getChannelData(c).toDart;
      for (int i = 0; i < length; i++) {
        interleaved[i * channels + c] = channelData[i];
      }
    }
    
    final reqId = _nextReqId++;
    final completer = Completer<AudioTrackInfo?>();
    _trackCompleters[reqId] = completer;

    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'addTrackMemory'.toJS);
    msg.setProperty('reqId'.toJS, reqId.toJS);
    msg.setProperty('id'.toJS, id.toJS);
    msg.setProperty('pcm'.toJS, interleaved.toJS);
    msg.setProperty('length'.toJS, length.toJS);
    msg.setProperty('channels'.toJS, channels.toJS);
    msg.setProperty('sampleRate'.toJS, sampleRate.toJS);
    _postCmd(msg);
    
    return completer.future;
  }

  void removeTrack(String id) {
    if (_isDisposed || !isReady) return;
    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'removeTrack'.toJS);
    msg.setProperty('id'.toJS, id.toJS);
    _postCmd(msg);
  }

  void setVolume(String id, double volume) {
    if (_isDisposed || !isReady) return;
    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'setVolume'.toJS);
    msg.setProperty('id'.toJS, id.toJS);
    msg.setProperty('volume'.toJS, volume.toJS);
    _postCmd(msg);
  }

  void setPan(String id, double pan) {
    if (_isDisposed || !isReady) return;
    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'setPan'.toJS);
    msg.setProperty('id'.toJS, id.toJS);
    msg.setProperty('pan'.toJS, pan.toJS);
    _postCmd(msg);
  }

  void setMute(String id, bool muted) {
    if (_isDisposed || !isReady) return;
    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'setMute'.toJS);
    msg.setProperty('id'.toJS, id.toJS);
    msg.setProperty('muted'.toJS, muted.toJS);
    _postCmd(msg);
  }

  void setSolo(String id, bool solo) {
    if (_isDisposed || !isReady) return;
    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'setSolo'.toJS);
    msg.setProperty('id'.toJS, id.toJS);
    msg.setProperty('solo'.toJS, solo.toJS);
    _postCmd(msg);
  }

  void setMasterVolume(double volume) {
    if (_isDisposed || !isReady) return;
    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'setMasterVolume'.toJS);
    msg.setProperty('volume'.toJS, volume.toJS);
    _postCmd(msg);
  }

  void setMasterMute(bool muted) {
    if (_isDisposed || !isReady) return;
    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'setMasterMute'.toJS);
    msg.setProperty('muted'.toJS, muted.toJS);
    _postCmd(msg);
  }

  void setMasterSolo(bool solo) {
    if (_isDisposed || !isReady) return;
    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'setMasterSolo'.toJS);
    msg.setProperty('solo'.toJS, solo.toJS);
    _postCmd(msg);
  }

  void startPlayback() {
     if (_isDisposed || !isReady) return;     
     try {
         if (_audioContext!.getProperty('state'.toJS).dartify() != 'running') {
             _audioContext!.callMethod('resume'.toJS);
         }
     } catch (e) {
         print("AudioContext resume error: $e");
     }
     
     if (_scriptNode != null) {
        final port = _scriptNode!.getProperty('port'.toJS) as JSObject;
        final msg = JSObject();
        msg.setProperty('type'.toJS, 'start'.toJS);
        port.callMethod('postMessage'.toJS, msg);
     }
  }

  void stopPlayback() {
     if (_isDisposed || !isReady) return;
     if (_scriptNode != null) {
        final port = _scriptNode!.getProperty('port'.toJS) as JSObject;
        final msg = JSObject();
        msg.setProperty('type'.toJS, 'stop'.toJS);
        port.callMethod('postMessage'.toJS, msg);
     }
  }
  
  void setLoop(int startSample, int endSample, bool enabled) {
    if (_isDisposed || !isReady) return;
    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'setLoop'.toJS);
    msg.setProperty('startSample'.toJS, startSample.toJS);
    msg.setProperty('endSample'.toJS, endSample.toJS);
    msg.setProperty('enabled'.toJS, enabled.toJS);
    _postCmd(msg);
  }

  void seek(int positionSample) {
    if (_isDisposed || !isReady) return;
    final msg = JSObject();
    msg.setProperty('cmd'.toJS, 'seek'.toJS);
    msg.setProperty('positionSample'.toJS, positionSample.toJS);
    _postCmd(msg);
  }
  
  int getPosition() {
     return _currentPos;
  }

  int getAtomicPosition() {
     return _currentAtomicPos;
  }
  
  void setSpeed(double speed) {
     if (_isDisposed || !isReady) return;
     final msg = JSObject();
     msg.setProperty('cmd'.toJS, 'setSpeed'.toJS);
     msg.setProperty('speed'.toJS, speed.toJS);
     _postCmd(msg);
  }

  void setSoundTouchSetting(int settingId, int value) {
     if (_isDisposed || !isReady) return;
     final msg = JSObject();
     msg.setProperty('cmd'.toJS, 'setSoundTouchSetting'.toJS);
     msg.setProperty('settingId'.toJS, settingId.toJS);
     msg.setProperty('value'.toJS, value.toJS);
     _postCmd(msg);
  }

  void setRandomSilencePercent(double percent) {
     // Web: handled in JS audioWorklet or ignored
  }

  void setMetronomeConfig(int bpm) {
     if (_isDisposed || !isReady) return;
     final msg = JSObject();
     msg.setProperty('cmd'.toJS, 'setMetronomeConfig'.toJS);
     msg.setProperty('bpm'.toJS, bpm.toJS);
     _postCmd(msg);
  }

  void setMetronomeSound(int type, Float32List data) {
     if (_isDisposed || !isReady) return;
     final msg = JSObject();
     msg.setProperty('cmd'.toJS, 'setMetronomeSound'.toJS);
     msg.setProperty('trackType'.toJS, type.toJS);
     msg.setProperty('data'.toJS, data.toJS);
     _postCmd(msg);
  }

  void addMetronomePattern(int id, List<int>? flatPattern, List<int>? subdivisions, List<double>? durationRatios, double vol, bool mute, bool solo) {
     if (_isDisposed || !isReady) return;
     final msg = JSObject();
     msg.setProperty('cmd'.toJS, 'addMetronomePattern'.toJS);
     msg.setProperty('id'.toJS, id.toJS);
     if (flatPattern != null) msg.setProperty('flatPattern'.toJS, Int32List.fromList(flatPattern).toJS);
     if (subdivisions != null) msg.setProperty('subdivisions'.toJS, Int32List.fromList(subdivisions).toJS);
     if (durationRatios != null) msg.setProperty('durationRatios'.toJS, Float64List.fromList(durationRatios).toJS);
     msg.setProperty('vol'.toJS, vol.toJS);
     msg.setProperty('mute'.toJS, mute.toJS);
     msg.setProperty('solo'.toJS, solo.toJS);
     _postCmd(msg);
  }

  void updateMetronomePattern(int id, List<int>? flatPattern, List<int>? subdivisions, List<double>? durationRatios, double vol, bool mute, bool solo) {
     if (_isDisposed || !isReady) return;
     final msg = JSObject();
     msg.setProperty('cmd'.toJS, 'updateMetronomePattern'.toJS);
     msg.setProperty('id'.toJS, id.toJS);
     if (flatPattern != null) msg.setProperty('flatPattern'.toJS, Int32List.fromList(flatPattern).toJS);
     if (subdivisions != null) msg.setProperty('subdivisions'.toJS, Int32List.fromList(subdivisions).toJS);
     if (durationRatios != null) msg.setProperty('durationRatios'.toJS, Float64List.fromList(durationRatios).toJS);
     msg.setProperty('vol'.toJS, vol.toJS);
     msg.setProperty('mute'.toJS, mute.toJS);
     msg.setProperty('solo'.toJS, solo.toJS);
     _postCmd(msg);
  }

  void removeMetronomePattern(int id) {
     if (_isDisposed || !isReady) return;
     final msg = JSObject();
     msg.setProperty('cmd'.toJS, 'removeMetronomePattern'.toJS);
     msg.setProperty('id'.toJS, id.toJS);
     _postCmd(msg);
  }

  void clearMetronomePatterns() {
     if (_isDisposed || !isReady) return;
     final msg = JSObject();
     msg.setProperty('cmd'.toJS, 'clearMetronomePatterns'.toJS);
     _postCmd(msg);
  }

  void setMetronomePreviewMode(bool enabled) {
     if (_isDisposed || !isReady) return;
     final msg = JSObject();
     msg.setProperty('cmd'.toJS, 'setMetronomePreviewMode'.toJS);
     msg.setProperty('enabled'.toJS, enabled.toJS);
     _postCmd(msg);
  }
}

