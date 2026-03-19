import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_audio_engine_platform_interface.dart';

/// An implementation of [NativeAudioEnginePlatform] that uses method channels.
class MethodChannelNativeAudioEngine extends NativeAudioEnginePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('native_audio_engine');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
