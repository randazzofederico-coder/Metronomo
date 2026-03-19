import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'soundtouch_bindings.dart';

class SoundTouchProcessor {
  final SoundTouchBindings _bindings = SoundTouchBindings();
  late Pointer<Void> _handle;
  bool _isDisposed = false;

  SoundTouchProcessor() {
    _handle = _bindings.create();
  }

  void dispose() {
    if (!_isDisposed) {
      _bindings.destroy(_handle);
      _isDisposed = true;
    }
  }

  void setTempo(double tempo) { // 1.0 is normal speed
    _bindings.setTempo(_handle, tempo);
  }

  void setPitch(double pitch) { // 1.0 is normal pitch
    _bindings.setPitch(_handle, pitch);
  }

  void setRate(double rate) { // 1.0 is normal rate
    _bindings.setRate(_handle, rate);
  }
  
  void setChannels(int channels) {
    _bindings.setChannels(_handle, channels);
  }

  void setSampleRate(int sampleRate) {
    _bindings.setSampleRate(_handle, sampleRate);
  }
  
  void clear() {
    _bindings.clear(_handle);
  }

  /// Processes a chunk of interleaved float samples.
  /// [input] is the input samples (interleaved if stereo).
  /// [bufferSize] is the number of samples *per channel* (or total? SoundTouch uses total samples usually if not specified, but putSamples usually takes nSamples per channel?)
  /// CHECK: SoundTouch::putSamples(const SAMPLETYPE *samples, uint nSamples)
  /// "nSamples: Number of sample frames to put." -> Frames. So if stereo, 2 floats = 1 frame.
  /// 
  /// Returns a list of processed interleaved float samples.
  List<double> process(List<double> input, int channels) {
    if (input.isEmpty) return [];

    int inputFrames = input.length ~/ channels;
    
    // Allocate input buffer
    final inputPointer = calloc<Float>(input.length);
    for (int i = 0; i < input.length; i++) {
      inputPointer[i] = input[i];
    }

    _bindings.putSamples(_handle, inputPointer, inputFrames);
    calloc.free(inputPointer);

    // Receive samples
    // We don't know exactly how many samples correspond to input, depends on tempo.
    // We'll peek or just fetch with a reasonable buffer.
    // SoundTouch::numSamples() returns number of available output samples.
    
    // It's safer to loop receiveSamples until empty?
    List<double> output = [];
    
    // Request a chunk
    // Max buffer size?
    const int maxFrames = 4096;
    final outputPointer = calloc<Float>(maxFrames * channels);

    while (true) {
        int receivedFrames = _bindings.receiveSamples(_handle, outputPointer, maxFrames);
        if (receivedFrames <= 0) break;
        
        for (int i = 0; i < receivedFrames * channels; i++) {
           output.add(outputPointer[i]);
        }
        
        // If we filled the buffer, maybe there is more?
        if (receivedFrames < maxFrames) break; 
    }
    
    calloc.free(outputPointer);
    return output;
  }
}
