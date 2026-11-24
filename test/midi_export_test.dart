import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:metronomo_standalone/audio/click_synth.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/playlist_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/services/midi_export_service.dart';

class _NoteEvent {
  final int tick;
  final int channel;
  final int note;
  final int velocity;
  final bool isOn;

  const _NoteEvent({
    required this.tick,
    required this.channel,
    required this.note,
    required this.velocity,
    required this.isOn,
  });
}

class _CcEvent {
  final int tick;
  final int channel;
  final int controller;
  final int value;

  const _CcEvent(this.tick, this.channel, this.controller, this.value);
}

class _ProgramEvent {
  final int tick;
  final int channel;
  final int program;

  const _ProgramEvent(this.tick, this.channel, this.program);
}

class _ParsedTrack {
  String? name;
  int? tempoUsPerQuarter;
  (int, int, int, int)? timeSignature;
  int? endOfTrackTick;
  final List<_ProgramEvent> programChanges = [];
  final List<_CcEvent> controlChanges = [];
  final List<_NoteEvent> notes = [];

  List<_NoteEvent> get noteOns => notes.where((n) => n.isOn).toList();
  List<_NoteEvent> get noteOffs => notes.where((n) => !n.isOn).toList();
}

class _ParsedMidi {
  final int format;
  final int trackCount;
  final int division;
  final List<_ParsedTrack> tracks;

  const _ParsedMidi({
    required this.format,
    required this.trackCount,
    required this.division,
    required this.tracks,
  });
}

_ParsedMidi _parseMidi(Uint8List bytes) {
  final bd = ByteData.sublistView(bytes);
  expect(ascii.decode(bytes.sublist(0, 4)), 'MThd');
  final headerLen = bd.getUint32(4, Endian.big);
  expect(headerLen, 6);
  final format = bd.getUint16(8, Endian.big);
  final trackCount = bd.getUint16(10, Endian.big);
  final division = bd.getUint16(12, Endian.big);

  var offset = 14;
  final tracks = <_ParsedTrack>[];

  for (var t = 0; t < trackCount; t++) {
    expect(ascii.decode(bytes.sublist(offset, offset + 4)), 'MTrk');
    final chunkLen = bd.getUint32(offset + 4, Endian.big);
    offset += 8;
    final chunkEnd = offset + chunkLen;
    expect(chunkEnd, lessThanOrEqualTo(bytes.length));

    final track = _ParsedTrack();
    var tick = 0;
    var cursor = offset;

    int readVlq() {
      var val = 0;
      while (true) {
        final b = bytes[cursor++];
        val = (val << 7) | (b & 0x7F);
        if ((b & 0x80) == 0) break;
      }
      return val;
    }

    while (cursor < chunkEnd) {
      tick += readVlq();
      final status = bytes[cursor++];
      if (status == 0xFF) {
        final metaType = bytes[cursor++];
        final len = readVlq();
        final data = bytes.sublist(cursor, cursor + len);
        cursor += len;
        if (metaType == 0x03) {
          track.name = utf8.decode(data);
        } else if (metaType == 0x51 && len == 3) {
          track.tempoUsPerQuarter =
              (data[0] << 16) | (data[1] << 8) | data[2];
        } else if (metaType == 0x58 && len == 4) {
          track.timeSignature = (data[0], data[1], data[2], data[3]);
        } else if (metaType == 0x2F) {
          track.endOfTrackTick = tick;
        }
      } else {
        final type = status & 0xF0;
        final channel = status & 0x0F;
        if (type == 0x90) {
          final note = bytes[cursor++];
          final vel = bytes[cursor++];
          track.notes.add(_NoteEvent(
            tick: tick,
            channel: channel,
            note: note,
            velocity: vel,
            isOn: vel > 0,
          ));
        } else if (type == 0x80) {
          final note = bytes[cursor++];
          final vel = bytes[cursor++];
          track.notes.add(_NoteEvent(
            tick: tick,
            channel: channel,
            note: note,
            velocity: vel,
            isOn: false,
          ));
        } else if (type == 0xB0) {
          final cc = bytes[cursor++];
          final val = bytes[cursor++];
          track.controlChanges.add(_CcEvent(tick, channel, cc, val));
        } else if (type == 0xC0) {
          final prog = bytes[cursor++];
          track.programChanges.add(_ProgramEvent(tick, channel, prog));
        } else {
          fail('Unexpected MIDI status byte 0x${status.toRadixString(16)}');
        }
      }
    }

    expect(cursor, chunkEnd, reason: 'Track $t length mismatch');
    expect(track.endOfTrackTick, isNotNull, reason: 'Missing End of Track');
    tracks.add(track);
    offset = chunkEnd;
  }

  expect(offset, bytes.length, reason: 'Trailing bytes after MIDI tracks');
  return _ParsedMidi(
    format: format,
    trackCount: trackCount,
    division: division,
    tracks: tracks,
  );
}

void main() {
  group('MidiExportService', () {
    test('exports simple 4-beat pattern with exact ticks and End-of-Track', () {
      final pattern = Pattern(
        name: 'Basic 4',
        structure: '4',
        pulses: [
          HomeMetronomePulse([1]),
          HomeMetronomePulse([2]),
          HomeMetronomePulse([2]),
          HomeMetronomePulse([2]),
        ],
      );

      final midi = _parseMidi(
        MidiExportService.exportPattern(pattern, bpm: 120),
      );

      expect(midi.format, 1);
      expect(midi.trackCount, 2);
      expect(midi.division, 960);

      final conductor = midi.tracks[0];
      expect(conductor.name, 'Basic 4');
      expect(conductor.tempoUsPerQuarter, 500000); // 120 BPM
      expect(conductor.timeSignature, (4, 2, 0x18, 0x08));
      expect(conductor.endOfTrackTick, 3840);

      final track = midi.tracks[1];
      expect(track.name, 'Basic 4');
      expect(track.endOfTrackTick, 3840);
      expect(track.controlChanges, isEmpty); // No CC 7 in GM percussion mode
      expect(track.noteOns.map((e) => e.tick).toList(), [0, 960, 1920, 2880]);
      expect(track.noteOns.every((e) => e.channel == 9), isTrue);
      // Clásico GM mapping: (76, 77, 37)
      expect(track.noteOns.map((e) => e.note).toList(), [76, 77, 77, 77]);
      expect(track.noteOns.map((e) => e.velocity).toList(), [100, 85, 85, 85]);
      expect(track.noteOffs, hasLength(4));
    });

    test('preserves full cycle length when trailing pulses are silences', () {
      final pattern = Pattern(
        name: 'Half Silent',
        structure: '4',
        pulses: [
          HomeMetronomePulse([1]),
          HomeMetronomePulse([2]),
          HomeMetronomePulse([0]),
          HomeMetronomePulse([0]),
        ],
      );

      final midi = _parseMidi(
        MidiExportService.exportPattern(pattern, bpm: 100),
      );

      expect(midi.tracks[1].noteOns.map((n) => n.tick).toList(), [0, 960]);
      expect(midi.tracks[1].endOfTrackTick, 3840);
      expect(midi.tracks[0].endOfTrackTick, 3840);
    });

    test('handles tuplets and subdivisions accurately without cumulative drift',
        () {
      // 2:3/3 => 2 pulses of 1.5 beats, 3 subdivisions each (0.5 beat = 480 ticks)
      final twoAgainstThree = Pattern(
        name: '6/8',
        structure: '2:3/3',
        pulses: [
          HomeMetronomePulse([1, 3, 3], 1.5),
          HomeMetronomePulse([2, 3, 3], 1.5),
        ],
      );
      final m1 = _parseMidi(
        MidiExportService.exportPattern(twoAgainstThree, bpm: 120),
      );
      expect(
        m1.tracks[1].noteOns.map((n) => n.tick).toList(),
        [0, 480, 960, 1440, 1920, 2400],
      );
      expect(m1.tracks[1].endOfTrackTick, 2880);
      expect(m1.tracks[0].timeSignature?.$1, 3);

      // 3:2/2 => 3 pulses of 2/3 beats (total 2.0 beats), 2 subdivisions (1/3 beat = 320 ticks)
      final triplets = Pattern(
        name: 'Triplets',
        structure: '3:2/2',
        pulses: [
          HomeMetronomePulse([1, 3], 2 / 3),
          HomeMetronomePulse([2, 3], 2 / 3),
          HomeMetronomePulse([2, 3], 2 / 3),
        ],
      );
      final m2 = _parseMidi(
        MidiExportService.exportPattern(triplets, bpm: 120),
      );
      expect(
        m2.tracks[1].noteOns.map((n) => n.tick).toList(),
        [0, 320, 640, 960, 1280, 1600],
      );
      expect(m2.tracks[1].endOfTrackTick, 1920);

      // 5:4/4 => 5 pulses of 0.8 beats (total 4.0 beats), 4 subdivisions (0.2 beat = 192 ticks)
      final quintuplets = Pattern(
        name: 'Quintuplet',
        structure: '5:4/4',
        pulses: List.generate(
          5,
          (i) => HomeMetronomePulse([i == 0 ? 1 : 2, 3, 3, 3], 0.8),
        ),
      );
      final m3 = _parseMidi(
        MidiExportService.exportPattern(quintuplets, bpm: 120),
      );
      expect(
        m3.tracks[1].noteOns.map((n) => n.tick).toList(),
        List.generate(20, (i) => i * 192),
      );
      expect(m3.tracks[1].endOfTrackTick, 3840);

      // 7:4 repeated 4 times => each cycle starts at exact multiples of 3840 ticks
      final septuplets = Pattern(
        name: 'Septuplet',
        structure: '7:4',
        pulses: List.generate(
          7,
          (i) => HomeMetronomePulse([i == 0 ? 1 : 2], 4 / 7),
        ),
      );
      final m4 = _parseMidi(
        MidiExportService.exportPattern(
          septuplets,
          bpm: 120,
          options: const MidiExportOptions(repetitions: 4),
        ),
      );
      final ons = m4.tracks[1].noteOns;
      expect(ons, hasLength(28));
      expect(ons[0].tick, 0);
      expect(ons[7].tick, 3840);
      expect(ons[14].tick, 7680);
      expect(ons[21].tick, 11520);
      expect(m4.tracks[1].endOfTrackTick, 15360);
    });

    test('computes polyrhythmic session macro cycle and scales with repetitions',
        () {
      // 3/4 (3 beats) vs 6/8 (2:3/3 = 3 beats) -> macro cycle = 3 beats
      final sameLengthSession = Session(
        name: 'Birritmia',
        globalBpm: 90,
        patternsConfig: [
          SessionPatternConfig(
            patternId: 'p1',
            name: '3/4',
            structure: '3',
            pulses: [
              HomeMetronomePulse([1]),
              HomeMetronomePulse([2]),
              HomeMetronomePulse([2]),
            ],
            orderIndex: 0,
          ),
          SessionPatternConfig(
            patternId: 'p2',
            name: '6/8',
            structure: '2:3/3',
            pulses: [
              HomeMetronomePulse([1, 3, 3], 1.5),
              HomeMetronomePulse([2, 3, 3], 1.5),
            ],
            orderIndex: 1,
          ),
        ],
      );
      expect(MidiExportService.sessionMacroCycleBeats(sameLengthSession), 3.0);

      // 3 vs 4 -> macro cycle = 12 beats (11520 ticks)
      final polySession = Session(
        name: '3 contra 4',
        globalBpm: 120,
        patternsConfig: [
          SessionPatternConfig(
            patternId: 'p1',
            name: 'Three',
            structure: '3',
            pulses: [
              HomeMetronomePulse([1]),
              HomeMetronomePulse([2]),
              HomeMetronomePulse([2]),
            ],
            orderIndex: 0,
          ),
          SessionPatternConfig(
            patternId: 'p2',
            name: 'Four',
            structure: '4',
            pulses: [
              HomeMetronomePulse([1]),
              HomeMetronomePulse([2]),
              HomeMetronomePulse([2]),
              HomeMetronomePulse([2]),
            ],
            orderIndex: 1,
          ),
        ],
      );

      final midi1x = _parseMidi(MidiExportService.exportSession(polySession));
      expect(midi1x.trackCount, 3);
      expect(midi1x.tracks[1].noteOns, hasLength(12)); // 4 cycles of 3
      expect(midi1x.tracks[2].noteOns, hasLength(12)); // 3 cycles of 4
      expect(midi1x.tracks[1].endOfTrackTick, 11520);
      expect(midi1x.tracks[2].endOfTrackTick, 11520);

      final midi4x = _parseMidi(
        MidiExportService.exportSession(
          polySession,
          options: const MidiExportOptions(repetitions: 4),
        ),
      );
      expect(midi4x.tracks[1].noteOns, hasLength(48));
      expect(midi4x.tracks[2].noteOns, hasLength(48));
      expect(midi4x.tracks[1].endOfTrackTick, 11520 * 4);
      expect(midi4x.tracks[2].endOfTrackTick, 11520 * 4);
    });

    test('GM percussion mode maps all 7 sound sets and scales velocity', () {
      const expectedNotes = {
        'Clásico': [76, 77, 37],
        'Madera': [76, 77, 75],
        'Claves': [75, 76, 77],
        'Beep': [67, 68, 56],
        'Hi-hat': [46, 44, 42],
        'Bombo': [35, 36, 41],
        'Redoblante': [38, 40, 37],
      };

      for (final soundSet in ClickSynth.soundSets) {
        final pat = Pattern(
          name: soundSet,
          structure: '1/3',
          pulses: [
            HomeMetronomePulse([1, 2, 3], 1.0, [1.5, 1.0, 0.5]),
          ],
        );
        final midi = _parseMidi(
          MidiExportService.exportPattern(
            pat,
            bpm: 120,
            soundSet: soundSet,
            volume: 0.5,
          ),
        );
        final ons = midi.tracks[1].noteOns;
        expect(ons.every((n) => n.channel == 9), isTrue);
        expect(ons.map((n) => n.note).toList(), expectedNotes[soundSet]);
        // Base velocities [100, 85, 70] * (0.5 * [1.5, 1.0, 0.5]) -> [75, 43, 18]
        expect(ons.map((n) => n.velocity).toList(), [75, 43, 18]);
      }
    });

    test('multi-channel mode assigns channels skipping Ch 10, CC7, and PC', () {
      final configs = <SessionPatternConfig>[];
      for (var i = 0; i < 17; i++) {
        configs.add(
          SessionPatternConfig(
            patternId: 'p$i',
            name: 'Pat $i',
            structure: '1',
            pulses: [
              HomeMetronomePulse([1, 2, 3], 1.0, [1.0, 1.0, 1.0]),
            ],
            volume: i == 0 ? 0.5 : (i == 1 ? 0.0 : 1.0),
            soundSet: i == 0 ? 'Bombo' : (i == 1 ? 'Beep' : 'Hi-hat'),
            orderIndex: i,
          ),
        );
      }
      final session = Session(
        name: 'Many Channels',
        globalBpm: 120,
        patternsConfig: configs,
      );

      final midi = _parseMidi(
        MidiExportService.exportSession(
          session,
          options: const MidiExportOptions(
            channelMode: MidiChannelMode.multiChannel,
          ),
        ),
      );
      expect(midi.trackCount, 18);

      final expectedChannels = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, // Ch 1..9
        10, 11, 12, 13, 14, 15, // Ch 11..16
        9, // Ch 10 as 16th channel
        0, // wraps at 17th track
      ];
      for (var i = 0; i < 17; i++) {
        final track = midi.tracks[i + 1];
        final ch = expectedChannels[i];
        expect(track.programChanges.single.channel, ch);
        expect(track.controlChanges.single.controller, 7);
        expect(track.controlChanges.single.channel, ch);
        expect(track.noteOns.every((n) => n.channel == ch), isTrue);
        expect(track.noteOns.map((n) => n.note).toList(), [72, 67, 60]);
      }

      // Track 0: Bombo -> program 116, vol 0.5 -> CC7 = 64
      expect(midi.tracks[1].programChanges.single.program, 116);
      expect(midi.tracks[1].controlChanges.single.value, 64);

      // Track 1: Beep -> program 80, vol 0.0 -> CC7 = 0, still keeps notes!
      expect(midi.tracks[2].programChanges.single.program, 80);
      expect(midi.tracks[2].controlChanges.single.value, 0);
      expect(midi.tracks[2].noteOns, hasLength(3));
    });

    test('session export ignores Mute, Solo, and random silence percentage', () {
      final session = Session(
        name: 'Mixed',
        globalBpm: 110,
        randomSilencePercentage: 85.0,
        patternsConfig: [
          SessionPatternConfig(
            patternId: 'p1',
            name: 'Muted Track',
            structure: '2',
            pulses: [HomeMetronomePulse([1]), HomeMetronomePulse([2])],
            isMuted: true,
            isSolo: false,
            orderIndex: 0,
          ),
          SessionPatternConfig(
            patternId: 'p2',
            name: 'Solo Track',
            structure: '2',
            pulses: [HomeMetronomePulse([1]), HomeMetronomePulse([2])],
            isMuted: false,
            isSolo: true,
            orderIndex: 1,
          ),
        ],
      );

      final midi = _parseMidi(MidiExportService.exportSession(session));
      expect(midi.trackCount, 3);
      expect(midi.tracks[1].name, 'Muted Track');
      expect(midi.tracks[1].noteOns, hasLength(2));
      expect(midi.tracks[2].name, 'Solo Track');
      expect(midi.tracks[2].noteOns, hasLength(2));
    });

    test('clamps Set Tempo cleanly across extreme BPM values (1..999)', () {
      final pat = Pattern(
        name: 'Tempo Test',
        structure: '1',
        pulses: [HomeMetronomePulse([1])],
      );

      final bpm1 = _parseMidi(MidiExportService.exportPattern(pat, bpm: 1));
      expect(bpm1.tracks[0].tempoUsPerQuarter, 0xFFFFFF);

      final bpm60 = _parseMidi(MidiExportService.exportPattern(pat, bpm: 60));
      expect(bpm60.tracks[0].tempoUsPerQuarter, 1000000);

      final bpm999 = _parseMidi(MidiExportService.exportPattern(pat, bpm: 999));
      expect(bpm999.tracks[0].tempoUsPerQuarter, 60060);
    });

    test('exportPlaylistZip creates numbered .mid files for every session', () {
      final s1 = Session(
        name: 'Intro / Count',
        globalBpm: 80,
        patternsConfig: [
          SessionPatternConfig(
            patternId: 'a',
            name: 'Pulse',
            structure: '4',
            pulses: [
              HomeMetronomePulse([1]),
              HomeMetronomePulse([2]),
              HomeMetronomePulse([2]),
              HomeMetronomePulse([2]),
            ],
            orderIndex: 0,
          ),
        ],
      );
      final s2 = Session(
        name: 'Chacarera',
        globalBpm: 132,
        patternsConfig: [
          SessionPatternConfig(
            patternId: 'b',
            name: 'Bombo',
            structure: '3',
            pulses: [
              HomeMetronomePulse([1]),
              HomeMetronomePulse([2]),
              HomeMetronomePulse([2]),
            ],
            orderIndex: 0,
          ),
        ],
      );
      final playlist = Playlist(
        name: 'Show En Vivo',
        items: [
          PlaylistItem(sourceSessionId: s1.id, session: s1),
          PlaylistItem(sourceSessionId: s2.id, session: s2),
          // Repeat s1 to verify unique numbering handles duplicate names
          PlaylistItem(sourceSessionId: s1.id, session: s1),
        ],
      );

      final zipBytes = MidiExportService.exportPlaylistZip(
        playlist,
        [s1, s2, s1],
        options: const MidiExportOptions(repetitions: 2),
      );

      // Verify EOCD count and filenames from Central Directory
      final bd = ByteData.sublistView(zipBytes);
      final eocdOffset = zipBytes.length - 22;
      expect(bd.getUint32(eocdOffset, Endian.little), 0x06054b50);
      expect(bd.getUint16(eocdOffset + 10, Endian.little), 3);

      final cdStart = bd.getUint32(eocdOffset + 16, Endian.little);
      var cursor = cdStart;
      final names = <String>[];
      final lfhOffsets = <int>[];
      final sizes = <int>[];
      for (var i = 0; i < 3; i++) {
        expect(bd.getUint32(cursor, Endian.little), 0x02014b50);
        final size = bd.getUint32(cursor + 20, Endian.little);
        final nameLen = bd.getUint16(cursor + 28, Endian.little);
        final extraLen = bd.getUint16(cursor + 30, Endian.little);
        final commentLen = bd.getUint16(cursor + 32, Endian.little);
        final lfhOffset = bd.getUint32(cursor + 42, Endian.little);
        names.add(utf8.decode(zipBytes.sublist(cursor + 46, cursor + 46 + nameLen)));
        lfhOffsets.add(lfhOffset);
        sizes.add(size);
        cursor += 46 + nameLen + extraLen + commentLen;
      }

      expect(names, [
        '01 - Intro Count (80 BPM).mid',
        '02 - Chacarera (132 BPM).mid',
        '03 - Intro Count (80 BPM).mid',
      ]);

      // Parse the second .mid directly out of the ZIP payload
      final lfh2NameLen = bd.getUint16(lfhOffsets[1] + 26, Endian.little);
      final lfh2ExtraLen = bd.getUint16(lfhOffsets[1] + 28, Endian.little);
      final data2Start = lfhOffsets[1] + 30 + lfh2NameLen + lfh2ExtraLen;
      final mid2 = _parseMidi(zipBytes.sublist(data2Start, data2Start + sizes[1]));
      expect(mid2.tracks[0].tempoUsPerQuarter, (60000000 / 132).round());
      expect(mid2.tracks[1].noteOns, hasLength(6)); // 3 beats * 2 repetitions
    });
  });
}
