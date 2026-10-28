import 'dart:math' as math;
import 'dart:typed_data';

/// Procedural synthesizer for the metronome click sounds.
///
/// Every sound set provides three variants that map to the engine slots:
///   * slot 0 → event type 1 (red, accent)
///   * slot 1 → event type 2 (cyan, pulse)
///   * slot 2 → event type 3 (green, subdivision)
///
/// Design goals (see the sound research notes):
///   * Energy in the 1.5–4 kHz band, where both the ear and phone speakers are most efficient.
///   * A short noise transient for a precise attack.
///   * Soft saturation to raise loudness (RMS) without raising the peak.
///   * Every buffer normalized to −1 dBFS; the engine's soft limiter handles overlaps / >100% events.
class ClickSynth {
  ClickSynth(this.sampleRate);

  final int sampleRate;

  /// Sound set ids, in the order they are shown to the user.
  static const List<String> soundSets = [
    'Clásico',
    'Madera',
    'Claves',
    'Beep',
    'Hi-hat',
    'Bombo',
    'Redoblante',
  ];

  static const String defaultSoundSet = 'Clásico';

  /// Maps legacy names (persisted in prefs / sessions / shared links) to the current ids.
  static String normalize(String? name) {
    switch (name) {
      case null:
      case 'Default':
        return 'Clásico';
      case 'Woodblock':
        return 'Madera';
      case 'Digital':
        return 'Beep';
    }
    return soundSets.contains(name) ? name : defaultSoundSet;
  }

  /// Returns the 3 buffers (slot 0, 1, 2) for the given sound set.
  List<Float32List> buildSet(String name) {
    switch (normalize(name)) {
      case 'Madera':
        return [_madera(1600), _madera(850), _madera(1150)];
      case 'Claves':
        return [_claves(3000), _claves(1900), _claves(2400)];
      case 'Beep':
        return [_beep(2000), _beep(1000), _beep(1500)];
      case 'Hi-hat':
        // abierto / semiabierto / cerrado
        return [_hihat(0.30, 0.90), _hihat(0.09, 0.35), _hihat(0.018, 0.08)];
      case 'Bombo':
        // grave / medio / agudo
        return [_bombo(50), _bombo(70), _bombo(100)];
      case 'Redoblante':
        // con bordona / sin bordona / aro
        return [_redoblante(true), _redoblante(false), _aro()];
      case 'Clásico':
      default:
        // agudo / grave / medio (same layout as the original default set)
        return [_clasico(2500), _clasico(1500), _clasico(1900)];
    }
  }

  // ───────────────────────────────────────────────────────────── tonal sets

  Float32List _clasico(double f0) {
    final n = _len(0.06);
    final x = Float64List(n);
    final tr = _noiseBurst(n, 1.5, 2500, seed: 1);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final body = math.sin(2 * math.pi * f0 * t) * math.exp(-t / 0.025) +
          0.4 * math.sin(2 * math.pi * f0 * 2.01 * t) * math.exp(-t / 0.012);
      x[i] = body * _attack(t, 0.5) + 1.2 * tr[i];
    }
    return _finish(x, drive: 2.5);
  }

  Float32List _madera(double f0) {
    const modes = [
      [1.0, 1.0, 0.030],
      [2.71, 0.55, 0.014],
      [5.40, 0.30, 0.007],
    ];
    final n = _len(0.09);
    final x = Float64List(n);
    final tr = _noiseBurst(n, 1.0, 2000, seed: 2);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var v = 0.0;
      for (final m in modes) {
        v += m[1] * math.sin(2 * math.pi * f0 * m[0] * t) * math.exp(-t / m[2]);
      }
      x[i] = v * _attack(t, 0.3) + 0.5 * tr[i];
    }
    return _finish(x, drive: 2.0);
  }

  Float32List _claves(double f0) {
    final n = _len(0.10);
    final x = Float64List(n);
    final tr = _noiseBurst(n, 0.8, 4000, seed: 3);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final v = math.sin(2 * math.pi * f0 * t) * math.exp(-t / 0.040) +
          0.25 * math.sin(2 * math.pi * f0 * 3.93 * t) * math.exp(-t / 0.010);
      x[i] = v * _attack(t, 0.3) + 0.4 * tr[i];
    }
    return _finish(x, drive: 3.0);
  }

  Float32List _beep(double f0) {
    const dur = 0.07;
    final n = _len(dur);
    final x = Float64List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var v = 0.0;
      for (final k in const [1, 3, 5, 7]) {
        v += math.sin(2 * math.pi * f0 * k * t) / k;
      }
      final release = ((dur - t) / 0.015).clamp(0.0, 1.0);
      x[i] = v * _attack(t, 1.0) * release;
    }
    return _finish(x, drive: 1.5);
  }

  // ───────────────────────────────────────────────────────────── drums

  /// TR-808 style hi-hat: 6 inharmonic square oscillators + noise, band-passed high.
  Float32List _hihat(double decay, double length) {
    const freqs = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0];
    final n = _len(length);
    var metal = Float64List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var v = 0.0;
      for (var k = 0; k < freqs.length; k++) {
        v += math.sin(2 * math.pi * freqs[k] * 1.7 * t + k) >= 0 ? 1.0 : -1.0;
      }
      metal[i] = v;
    }
    metal = _biquad(_biquad(metal, _Filter.bandPass, 10000, 1.0), _Filter.highPass, 7000, 0.707);
    final nz = _biquad(_noise(n, seed: 10), _Filter.highPass, 6000, 0.707);
    final x = Float64List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final tail = ((length - t) / 0.01).clamp(0.0, 1.0);
      x[i] = (metal[i] + 0.6 * nz[i]) * math.exp(-t / decay) * tail * _attack(t, 0.2);
    }
    return _finish(x, drive: 1.5);
  }

  /// Kick: pitch-swept sine + high "beater" transient. The high drive generates harmonics
  /// so the low end is still perceived on phone speakers that can't reproduce 50–100 Hz.
  Float32List _bombo(double fEnd) {
    const length = 0.35;
    final n = _len(length);
    final beater = _biquad(_noise(n, seed: 20), _Filter.bandPass, 3500, 0.8);
    final x = Float64List(n);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final f = fEnd + fEnd * 2.5 * math.exp(-t / 0.025);
      phase += 2 * math.pi * f / sampleRate;
      final body = math.sin(phase) * math.exp(-t / 0.18);
      final tail = ((length - t) / 0.02).clamp(0.0, 1.0);
      x[i] = (body + 0.9 * beater[i] * math.exp(-t / 0.003)) * tail * _attack(t, 0.3);
    }
    return _finish(x, drive: 4.0);
  }

  Float32List _redoblante(bool bordona) {
    const length = 0.30;
    final n = _len(length);
    final stick = _noiseBurst(n, 2.0, 2000, seed: 30);
    final snares = bordona
        ? _biquad(_biquad(_noise(n, seed: 31), _Filter.highPass, 1800, 0.707), _Filter.lowPass, 9000, 0.707)
        : null;
    final x = Float64List(n);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      phase += 2 * math.pi * 190 * (1 + 0.25 * math.exp(-t / 0.01)) / sampleRate;
      final body = math.sin(phase) * math.exp(-t / 0.05) +
          0.6 * math.sin(2 * math.pi * 330 * t) * math.exp(-t / 0.035) +
          0.3 * math.sin(2 * math.pi * 510 * t) * math.exp(-t / 0.02);
      final v = bordona
          ? 0.8 * body + 1.3 * snares![i] * math.exp(-t / 0.075) + 0.6 * stick[i]
          : body + 0.4 * stick[i]; // head only: more tonal, tom-like
      final tail = ((length - t) / 0.02).clamp(0.0, 1.0);
      x[i] = v * tail * _attack(t, 0.3);
    }
    return _finish(x, drive: 2.5);
  }

  /// Rim click / cross-stick: dry, woody click.
  Float32List _aro() {
    const modes = [
      [520.0, 0.6, 0.020],
      [1650.0, 1.0, 0.012],
      [2750.0, 0.6, 0.006],
    ];
    final n = _len(0.08);
    final click = _biquad(_noise(n, seed: 40), _Filter.bandPass, 2000, 1.5);
    final x = Float64List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var v = 0.0;
      for (final m in modes) {
        v += m[1] * math.sin(2 * math.pi * m[0] * t) * math.exp(-t / m[2]);
      }
      x[i] = (v + 0.9 * click[i] * math.exp(-t / 0.004)) * _attack(t, 0.2);
    }
    return _finish(x, drive: 2.5);
  }

  // ───────────────────────────────────────────────────────────── DSP helpers

  int _len(double seconds) => (sampleRate * seconds).round();

  /// Short linear attack ramp to avoid DC "pops".
  static double _attack(double t, double ms) => (t / (ms / 1000.0)).clamp(0.0, 1.0);

  /// Deterministic gaussian noise (Box–Muller), so every launch produces identical sounds.
  Float64List _noise(int n, {required int seed}) {
    final rng = math.Random(seed);
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      final u1 = 1.0 - rng.nextDouble();
      final u2 = rng.nextDouble();
      out[i] = math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2);
    }
    return out;
  }

  /// High-passed noise with an exponential decay of [ms] milliseconds.
  Float64List _noiseBurst(int n, double ms, double hp, {required int seed}) {
    final nz = _biquad(_noise(n, seed: seed), _Filter.highPass, hp, 0.707);
    for (var i = 0; i < n; i++) {
      nz[i] *= math.exp(-(i / sampleRate) / (ms / 1000.0));
    }
    return nz;
  }

  /// RBJ cookbook biquad.
  Float64List _biquad(Float64List x, _Filter kind, double f0, double q) {
    final w0 = 2 * math.pi * f0 / sampleRate;
    final alpha = math.sin(w0) / (2 * q);
    final c = math.cos(w0);
    double b0, b1, b2;
    switch (kind) {
      case _Filter.highPass:
        b0 = (1 + c) / 2;
        b1 = -(1 + c);
        b2 = (1 + c) / 2;
      case _Filter.lowPass:
        b0 = (1 - c) / 2;
        b1 = 1 - c;
        b2 = (1 - c) / 2;
      case _Filter.bandPass:
        b0 = alpha;
        b1 = 0;
        b2 = -alpha;
    }
    final a0 = 1 + alpha;
    final a1 = -2 * c / a0;
    final a2 = (1 - alpha) / a0;
    b0 /= a0;
    b1 /= a0;
    b2 /= a0;
    final y = Float64List(x.length);
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    for (var i = 0; i < x.length; i++) {
      final xi = x[i];
      final yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1;
      x1 = xi;
      y2 = y1;
      y1 = yi;
      y[i] = yi;
    }
    return y;
  }

  static double _tanh(double x) {
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  /// Normalize → soft saturation (tanh) → normalize to −1 dBFS.
  static Float32List _finish(Float64List x, {required double drive}) {
    var peak = 0.0;
    for (final v in x) {
      peak = math.max(peak, v.abs());
    }
    final out = Float32List(x.length);
    if (peak == 0) return out;
    final norm = _tanh(drive);
    var peak2 = 0.0;
    final tmp = Float64List(x.length);
    for (var i = 0; i < x.length; i++) {
      tmp[i] = _tanh(drive * x[i] / peak) / norm;
      peak2 = math.max(peak2, tmp[i].abs());
    }
    final target = math.pow(10, -1 / 20) / peak2; // −1 dBFS
    for (var i = 0; i < x.length; i++) {
      out[i] = tmp[i] * target;
    }
    return out;
  }
}

enum _Filter { highPass, lowPass, bandPass }
