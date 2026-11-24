import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../audio/click_synth.dart';
import '../models/pattern_model.dart';
import '../models/playlist_model.dart';
import '../models/session_model.dart';
import 'zip_builder.dart';

/// Standard MIDI File ticks per quarter note (960 PPQ).
const int kMidiPpq = 960;

/// Safety cap for session macro cycles (in quarter-note beats).
const int kMaxMacroCycleBeats = 2048;

/// How MIDI tracks map to MIDI channels.
enum MidiChannelMode {
  /// Every pattern outputs on MIDI Channel 10 (index 9) using General MIDI
  /// percussion notes mapped from its sound set.
  gmPercussion,

  /// Each pattern outputs on its own MIDI channel (Ch 1–9, 11–16, then 10)
  /// with Program Change, CC 7 volume, and fixed C5 / G4 / C4 pitches.
  multiChannel,
}

/// User-selected options for `.mid` / `.zip` export.
class MidiExportOptions {
  final int repetitions;
  final MidiChannelMode channelMode;

  const MidiExportOptions({
    this.repetitions = 1,
    this.channelMode = MidiChannelMode.gmPercussion,
  });
}

/// Pure-Dart Standard MIDI File (SMF Format 1) exporter for patterns,
/// polyrhythmic sessions, and playlists.
class MidiExportService {
  MidiExportService._();

  static const int _gmPercussionChannel = 9; // MIDI Channel 10 (0-indexed)

  /// General MIDI percussion note numbers `(accent, normal, soft)` per sound set.
  static const Map<String, (int, int, int)> gmPercussionNotes = {
    'Clásico': (76, 77, 37), // Hi Wood Block, Low Wood Block, Side Stick
    'Madera': (76, 77, 75), // Hi Wood Block, Low Wood Block, Claves
    'Claves': (75, 76, 77), // Claves, Hi Wood Block, Low Wood Block
    'Beep': (67, 68, 56), // High Agogo, Low Agogo, Cowbell
    'Hi-hat': (46, 44, 42), // Open Hi-Hat, Pedal Hi-Hat, Closed Hi-Hat
    'Bombo': (35, 36, 41), // Acoustic Bass Drum, Bass Drum 1, Low Floor Tom
    'Redoblante': (38, 40, 37), // Acoustic Snare, Electric Snare, Side Stick
  };

  /// General MIDI melodic program numbers (0-indexed) for multi-channel mode.
  static const Map<String, int> multiChannelPrograms = {
    'Clásico': 115, // Woodblock
    'Madera': 115, // Woodblock
    'Claves': 115, // Woodblock
    'Beep': 80, // Lead 1 (square)
    'Hi-hat': 118, // Synth Drum
    'Bombo': 116, // Taiko Drum
    'Redoblante': 117, // Melodic Tom
  };

  /// Fixed pitches `(accent, normal, soft)` for multi-channel mode.
  static const (int, int, int) multiChannelPitches = (72, 67, 60); // C5, G4, C4

  /// Assigns a 0-indexed MIDI channel for [trackIndex], skipping Ch 10 (index 9)
  /// until the first 15 melodic channels are filled.
  static int channelForTrackIndex(int trackIndex) {
    final mod = trackIndex % 16;
    if (mod < 9) return mod; // Ch 1..9
    if (mod < 15) return mod + 1; // Ch 11..16
    return _gmPercussionChannel; // Ch 10
  }

  static double _pulseDuration(HomeMetronomePulse pulse) =>
      pulse.durationRatio > 0 ? pulse.durationRatio : 1.0;

  /// Total duration of a single cycle of [pulses] in quarter-note beats.
  static double patternCycleBeats(List<HomeMetronomePulse> pulses) {
    if (pulses.isEmpty) return 1.0;
    var sum = 0.0;
    for (final p in pulses) {
      sum += _pulseDuration(p);
    }
    if (sum <= 0.0) return 1.0;
    final rounded = sum.roundToDouble();
    if ((sum - rounded).abs() < 1e-6) return rounded;
    return sum;
  }

  /// Least common cycle duration of all valid patterns in [session], in beats.
  static double sessionMacroCycleBeats(Session session) {
    final durations = <double>[
      for (final c in session.patternsConfig)
        if (c.pulses != null && c.pulses!.isNotEmpty) patternCycleBeats(c.pulses!),
    ];
    if (durations.isEmpty) return 4.0;

    final allInteger = durations.every((d) => (d - d.round()).abs() < 1e-6);
    if (allInteger) {
      var lcm = durations.first.round().clamp(1, kMaxMacroCycleBeats);
      for (var i = 1; i < durations.length; i++) {
        final next = durations[i].round().clamp(1, kMaxMacroCycleBeats);
        lcm = _lcm(lcm, next);
        if (lcm >= kMaxMacroCycleBeats) return kMaxMacroCycleBeats.toDouble();
      }
      return lcm.toDouble();
    }

    // Fractional fallback: scale by 60 (handles /2, /3, /4, /5, /6, /10, /12).
    const scale = 60;
    var lcmScaled = (durations.first * scale).round().clamp(1, kMaxMacroCycleBeats * scale);
    for (var i = 1; i < durations.length; i++) {
      final next = (durations[i] * scale).round().clamp(1, kMaxMacroCycleBeats * scale);
      lcmScaled = _lcm(lcmScaled, next);
      if (lcmScaled >= kMaxMacroCycleBeats * scale) {
        return kMaxMacroCycleBeats.toDouble();
      }
    }
    return lcmScaled / scale;
  }

  static int _gcd(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final t = y;
      y = x % y;
      x = t;
    }
    return x == 0 ? 1 : x;
  }

  static int _lcm(int a, int b) {
    if (a <= 0 || b <= 0) return 1;
    return (a ~/ _gcd(a, b)) * b;
  }

  /// Exports a single [Pattern] as an SMF Format 1 `.mid` byte array.
  static Uint8List exportPattern(
    Pattern pattern, {
    required int bpm,
    String soundSet = ClickSynth.defaultSoundSet,
    double volume = 1.0,
    MidiExportOptions options = const MidiExportOptions(),
  }) {
    final normalizedSet = ClickSynth.normalize(soundSet);
    final cycleBeats = patternCycleBeats(pattern.pulses);
    final spec = _TrackSpec(
      name: pattern.name,
      pulses: pattern.pulses,
      volume: volume.clamp(0.0, 1.5).toDouble(),
      soundSet: normalizedSet,
    );
    return _buildSmf(
      title: pattern.name,
      bpm: bpm,
      macroBeats: cycleBeats,
      tracks: [spec],
      options: options,
    );
  }

  /// Exports a [Session] as an SMF Format 1 `.mid` byte array.
  ///
  /// All patterns are exported regardless of active Mute/Solo states, and
  /// random silence is ignored so the exported MIDI is deterministic.
  static Uint8List exportSession(
    Session session, {
    MidiExportOptions options = const MidiExportOptions(),
  }) {
    final configs = List<SessionPatternConfig>.from(session.patternsConfig)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final sessionSound = ClickSynth.normalize(session.soundSet);
    final tracks = <_TrackSpec>[];
    for (var i = 0; i < configs.length; i++) {
      final c = configs[i];
      final pulses = c.pulses;
      if (pulses == null || pulses.isEmpty) continue;
      tracks.add(_TrackSpec(
        name: (c.name != null && c.name!.trim().isNotEmpty)
            ? c.name!
            : 'Pattern ${i + 1}',
        pulses: pulses,
        volume: c.volume.clamp(0.0, 1.5).toDouble(),
        soundSet: c.soundSet != null ? ClickSynth.normalize(c.soundSet) : sessionSound,
      ));
    }

    final macroBeats = sessionMacroCycleBeats(session);
    return _buildSmf(
      title: session.name,
      bpm: session.globalBpm,
      macroBeats: macroBeats,
      tracks: tracks,
      options: options,
    );
  }

  /// Exports a [Playlist] as a `.zip` archive containing one numbered `.mid`
  /// file per session in [resolvedSessions].
  static Uint8List exportPlaylistZip(
    Playlist playlist,
    List<Session> resolvedSessions, {
    MidiExportOptions options = const MidiExportOptions(),
    DateTime? timestamp,
  }) {
    final width = resolvedSessions.length >= 100 ? 3 : 2;
    final entries = <ZipEntry>[];
    for (var i = 0; i < resolvedSessions.length; i++) {
      final session = resolvedSessions[i];
      final indexLabel = (i + 1).toString().padLeft(width, '0');
      final safeName = sanitizeFileName(session.name, fallback: 'session_${i + 1}');
      final bpm = session.globalBpm.clamp(1, 999);
      final fileName = '$indexLabel - $safeName ($bpm BPM).mid';
      entries.add(ZipEntry(
        fileName,
        exportSession(session, options: options),
      ));
    }
    return buildZip(entries, timestamp: timestamp);
  }

  /// Strips filesystem-unsafe characters from [name] for `.mid` / `.zip` filenames.
  static String sanitizeFileName(String name, {String fallback = 'metronomo'}) {
    var sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ');
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
    sanitized = sanitized.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
    if (sanitized.isEmpty) return fallback;
    if (sanitized.length > 80) {
      sanitized = sanitized.substring(0, 80).trim();
    }
    return sanitized.isEmpty ? fallback : sanitized;
  }

  static Uint8List _buildSmf({
    required String title,
    required int bpm,
    required double macroBeats,
    required List<_TrackSpec> tracks,
    required MidiExportOptions options,
  }) {
    final reps = math.max(1, options.repetitions);
    final totalBeats = macroBeats * reps;
    final totalTicks = math.max(1, (totalBeats * kMidiPpq).round());
    final trackCount = 1 + tracks.length;

    final out = BytesBuilder(copy: false);

    // Header Chunk: MThd
    out.add(ascii.encode('MThd'));
    _writeUint32BE(out, 6);
    _writeUint16BE(out, 1); // Format 1 (multi-track synchronous)
    _writeUint16BE(out, trackCount);
    _writeUint16BE(out, kMidiPpq);

    // Track 0: Conductor (Title, Tempo, Time Signature, End of Track)
    final numerator = _resolveTimeSignatureNumerator(tracks);
    final conductorTrack = _buildConductorTrack(
      title: title,
      bpm: bpm,
      numerator: numerator,
      totalTicks: totalTicks,
    );
    _writeTrackChunk(out, conductorTrack);

    // Tracks 1..N: Pattern tracks
    for (var i = 0; i < tracks.length; i++) {
      final trackBytes = _buildPatternTrack(
        track: tracks[i],
        trackIndex: i,
        totalBeats: totalBeats,
        totalTicks: totalTicks,
        channelMode: options.channelMode,
      );
      _writeTrackChunk(out, trackBytes);
    }

    return out.takeBytes();
  }

  static int _resolveTimeSignatureNumerator(List<_TrackSpec> tracks) {
    if (tracks.isEmpty) return 4;
    final cycles = tracks.map((t) => patternCycleBeats(t.pulses)).toList();
    final first = cycles.first;
    final firstRound = first.round();
    final firstIsValidInt =
        (first - firstRound).abs() < 1e-6 && firstRound >= 1 && firstRound <= 32;

    if (cycles.length == 1) {
      return firstIsValidInt ? firstRound : 4;
    }

    final allMatchFirst = firstIsValidInt &&
        cycles.every((c) => (c - firstRound).abs() < 1e-6);
    if (allMatchFirst) return firstRound;
    return firstIsValidInt ? firstRound : 4;
  }

  static Uint8List _buildConductorTrack({
    required String title,
    required int bpm,
    required int numerator,
    required int totalTicks,
  }) {
    final events = <_MidiEvent>[];
    var seq = 0;

    final cleanTitle = _cleanMetaText(title);
    if (cleanTitle.isNotEmpty) {
      events.add(_MidiEvent.meta(0, 0, seq++, 0x03, utf8.encode(cleanTitle)));
    }

    // Set Tempo: microseconds per quarter note (clamped to 24-bit unsigned max).
    final clampedBpm = bpm.clamp(1, 999);
    final usPerQuarter = (60000000 / clampedBpm).round().clamp(1, 0xFFFFFF);
    events.add(_MidiEvent.meta(0, 0, seq++, 0x51, [
      (usPerQuarter >> 16) & 0xFF,
      (usPerQuarter >> 8) & 0xFF,
      usPerQuarter & 0xFF,
    ]));

    // Time Signature: nn / 4 (dd = 2 => 2^2 = 4), 24 MIDI clocks/click, 8 32nds/quarter.
    final nn = numerator.clamp(1, 32);
    events.add(_MidiEvent.meta(0, 0, seq++, 0x58, [nn, 0x02, 0x18, 0x08]));

    // End of Track at totalTicks.
    events.add(_MidiEvent.meta(totalTicks, 5, seq++, 0x2F, const []));

    return _encodeTrackEvents(events);
  }

  static Uint8List _buildPatternTrack({
    required _TrackSpec track,
    required int trackIndex,
    required double totalBeats,
    required int totalTicks,
    required MidiChannelMode channelMode,
  }) {
    final events = <_MidiEvent>[];
    var seq = 0;

    final channel = channelMode == MidiChannelMode.gmPercussion
        ? _gmPercussionChannel
        : channelForTrackIndex(trackIndex);

    final cleanName = _cleanMetaText(track.name);
    if (cleanName.isNotEmpty) {
      events.add(_MidiEvent.meta(0, 0, seq++, 0x03, utf8.encode(cleanName)));
    }

    if (channelMode == MidiChannelMode.multiChannel) {
      final program = multiChannelPrograms[track.soundSet] ?? 115;
      events.add(_MidiEvent.channel2(0, 1, seq++, 0xC0 | channel, program));
      final ccVol = (track.volume.clamp(0.0, 1.0) * 127).round().clamp(0, 127);
      events.add(_MidiEvent.channel3(0, 2, seq++, 0xB0 | channel, 7, ccVol));
    }

    final cycleBeats = patternCycleBeats(track.pulses);
    final numCycles = (totalBeats / cycleBeats).ceil();
    final notes = channelMode == MidiChannelMode.gmPercussion
        ? (gmPercussionNotes[track.soundSet] ?? gmPercussionNotes[ClickSynth.defaultSoundSet]!)
        : multiChannelPitches;

    for (var cycleIdx = 0; cycleIdx < numCycles; cycleIdx++) {
      final cycleStartBeat = cycleIdx * cycleBeats;
      var beatInCycle = 0.0;

      for (final pulse in track.pulses) {
        final pulseDur = _pulseDuration(pulse);
        final subCount = pulse.subdivisions.length;
        if (subCount > 0) {
          final subDur = pulseDur / subCount;
          for (var subIdx = 0; subIdx < subCount; subIdx++) {
            final eventStartBeat = cycleStartBeat + beatInCycle + subIdx * subDur;
            if (eventStartBeat >= totalBeats - 1e-9) break;

            final startTick = (eventStartBeat * kMidiPpq).round();
            if (startTick >= totalTicks) break;

            final type = pulse.subdivisions[subIdx];
            if (type >= 1 && type <= 3) {
              final eventVol = pulse.volumeAt(subIdx);
              final gain = channelMode == MidiChannelMode.gmPercussion
                  ? track.volume * eventVol
                  : eventVol;
              if (gain > 0.0) {
                final baseVel = switch (type) {
                  1 => 100,
                  2 => 85,
                  _ => 70,
                };
                final velocity = (baseVel * gain).round().clamp(1, 127);
                final note = switch (type) {
                  1 => notes.$1,
                  2 => notes.$2,
                  _ => notes.$3,
                };

                final nextTick = ((eventStartBeat + subDur) * kMidiPpq)
                    .round()
                    .clamp(startTick + 1, totalTicks);
                final durTicks = math
                    .min(((subDur * kMidiPpq) * 0.5).round(), kMidiPpq ~/ 4)
                    .clamp(1, nextTick - startTick);
                final endTick = startTick + durTicks;

                events.add(_MidiEvent.channel3(
                    startTick, 4, seq++, 0x90 | channel, note, velocity));
                events.add(_MidiEvent.channel3(
                    endTick, 3, seq++, 0x80 | channel, note, 0));
              }
            }
          }
        }
        beatInCycle += pulseDur;
      }
    }

    // End of Track pinned to totalTicks so trailing silences preserve the loop length.
    events.add(_MidiEvent.meta(totalTicks, 5, seq++, 0x2F, const []));

    return _encodeTrackEvents(events);
  }

  static Uint8List _encodeTrackEvents(List<_MidiEvent> events) {
    events.sort((a, b) {
      final tickCmp = a.tick.compareTo(b.tick);
      if (tickCmp != 0) return tickCmp;
      final prioCmp = a.priority.compareTo(b.priority);
      if (prioCmp != 0) return prioCmp;
      return a.seq.compareTo(b.seq);
    });

    final out = BytesBuilder(copy: false);
    var lastTick = 0;
    for (final ev in events) {
      final delta = math.max(0, ev.tick - lastTick);
      lastTick = ev.tick;
      _writeVlq(out, delta);
      out.add(ev.bytes);
    }
    return out.takeBytes();
  }

  static void _writeTrackChunk(BytesBuilder out, Uint8List trackBytes) {
    out.add(ascii.encode('MTrk'));
    _writeUint32BE(out, trackBytes.length);
    out.add(trackBytes);
  }

  static String _cleanMetaText(String text) =>
      text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  static void _writeUint32BE(BytesBuilder out, int value) {
    out.addByte((value >> 24) & 0xFF);
    out.addByte((value >> 16) & 0xFF);
    out.addByte((value >> 8) & 0xFF);
    out.addByte(value & 0xFF);
  }

  static void _writeUint16BE(BytesBuilder out, int value) {
    out.addByte((value >> 8) & 0xFF);
    out.addByte(value & 0xFF);
  }

  static void _writeVlq(BytesBuilder out, int value) {
    var v = value < 0 ? 0 : value;
    final reversed = <int>[v & 0x7F];
    v >>= 7;
    while (v > 0) {
      reversed.add((v & 0x7F) | 0x80);
      v >>= 7;
    }
    for (var i = reversed.length - 1; i >= 0; i--) {
      out.addByte(reversed[i]);
    }
  }
}

class _TrackSpec {
  final String name;
  final List<HomeMetronomePulse> pulses;
  final double volume;
  final String soundSet;

  const _TrackSpec({
    required this.name,
    required this.pulses,
    required this.volume,
    required this.soundSet,
  });
}

class _MidiEvent {
  final int tick;
  final int priority;
  final int seq;
  final List<int> bytes;

  const _MidiEvent(this.tick, this.priority, this.seq, this.bytes);

  factory _MidiEvent.meta(
    int tick,
    int priority,
    int seq,
    int metaType,
    List<int> data,
  ) {
    final builder = BytesBuilder(copy: false);
    builder.addByte(0xFF);
    builder.addByte(metaType);
    MidiExportService._writeVlq(builder, data.length);
    if (data.isNotEmpty) builder.add(data);
    return _MidiEvent(tick, priority, seq, builder.takeBytes());
  }

  factory _MidiEvent.channel2(
    int tick,
    int priority,
    int seq,
    int status,
    int data1,
  ) =>
      _MidiEvent(tick, priority, seq, [status, data1 & 0x7F]);

  factory _MidiEvent.channel3(
    int tick,
    int priority,
    int seq,
    int status,
    int data1,
    int data2,
  ) =>
      _MidiEvent(tick, priority, seq, [status, data1 & 0x7F, data2 & 0x7F]);
}
