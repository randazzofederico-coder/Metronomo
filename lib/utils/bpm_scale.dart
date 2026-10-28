/// Non-linear mapping between the tempo slider position [0.0, 1.0] and BPM
/// [1, 999]. The 30–250 BPM range (where most music lives) takes 70% of the
/// slider travel.
class BpmScale {
  BpmScale._();

  static const int minBpm = 1;
  static const int maxBpm = 999;

  /// Slider value [0.0, 1.0] → BPM.
  static int sliderToBpm(double val) {
    if (val <= 0.15) {
      return (1 + 29 * (val / 0.15)).round(); // 0.0 -> 1, 0.15 -> 30
    } else if (val <= 0.85) {
      return (30 + 220 * ((val - 0.15) / 0.70)).round(); // 0.15 -> 30, 0.85 -> 250
    } else {
      return (250 + 749 * ((val - 0.85) / 0.15)).round(); // 0.85 -> 250, 1.0 -> 999
    }
  }

  /// BPM → slider value, clamped to [0.0, 1.0].
  static double bpmToSlider(int bpm) {
    final double v;
    if (bpm <= 30) {
      v = 0.15 * ((bpm - 1) / 29.0);
    } else if (bpm <= 250) {
      v = 0.15 + 0.70 * ((bpm - 30) / 220.0);
    } else {
      v = 0.85 + 0.15 * ((bpm - 250) / 749.0);
    }
    return v.clamp(0.0, 1.0);
  }
}
