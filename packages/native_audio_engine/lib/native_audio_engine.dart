
import 'native_audio_engine_platform_interface.dart';

class NativeAudioEngine {
  Future<String?> getPlatformVersion() {
    return NativeAudioEnginePlatform.instance.getPlatformVersion();
  }
}
