import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'native_audio_engine_method_channel.dart';

abstract class NativeAudioEnginePlatform extends PlatformInterface {
  /// Constructs a NativeAudioEnginePlatform.
  NativeAudioEnginePlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeAudioEnginePlatform _instance = MethodChannelNativeAudioEngine();

  /// The default instance of [NativeAudioEnginePlatform] to use.
  ///
  /// Defaults to [MethodChannelNativeAudioEngine].
  static NativeAudioEnginePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NativeAudioEnginePlatform] when
  /// they register themselves.
  static set instance(NativeAudioEnginePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
