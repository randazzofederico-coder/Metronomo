class AudioTrackInfo {
  final List<double> peakData;
  final int peakDataLength;
  final int channels;
  final int sampleRate;
  final int totalFrames;
  final int error;

  AudioTrackInfo({
    required this.peakData,
    required this.peakDataLength,
    required this.channels,
    required this.sampleRate,
    required this.totalFrames,
    required this.error,
  });
}
