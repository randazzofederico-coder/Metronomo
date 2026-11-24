import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:metronomo_standalone/l10n/l10n.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/playlist_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/services/midi_export_service.dart';
import 'package:metronomo_standalone/utils/bpm_scale.dart';
import 'package:metronomo_standalone/widgets/midi_export_sheet.dart';

/// MIDI export flows used from Tocar, Biblioteca, and Playlists.

void exportPatternMidi(
  BuildContext context,
  Pattern pattern, {
  int? initialBpm,
  String? soundSet,
}) {
  final metronome = context.read<MetronomeProvider>();
  final bpm = (initialBpm ?? metronome.bpm)
      .clamp(BpmScale.minBpm, BpmScale.maxBpm);
  final effectiveSoundSet = soundSet ?? metronome.currentSoundSet;
  final fileName =
      '${MidiExportService.sanitizeFileName(pattern.name, fallback: 'pattern')}.mid';

  showMidiExportSheet(
    context,
    heading: context.l10n.midiExportTitlePattern,
    subtitle: context.l10n.shareSubtitlePattern(pattern.name, pattern.structure),
    fileName: fileName,
    isZip: false,
    initialBpm: bpm,
    singleCycleBeats: MidiExportService.patternCycleBeats(pattern.pulses),
    analyticsType: 'pattern',
    buildBytes: (options, selectedBpm) => MidiExportService.exportPattern(
      pattern,
      bpm: selectedBpm,
      soundSet: effectiveSoundSet,
      options: options,
    ),
  );
}

Future<void> exportSessionMidi(BuildContext context, Session session) async {
  final patProvider = context.read<PatternEditorProvider>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;

  await patProvider.ensureLoaded;
  if (!context.mounted) return;

  final embedded = session.withEmbeddedPatterns(patProvider.getPatternById);
  final validCount = embedded.patternsConfig
      .where((c) => c.pulses != null && c.pulses!.isNotEmpty)
      .length;
  if (validCount == 0) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.midiExportSessionEmpty)),
    );
    return;
  }

  final fileName =
      '${MidiExportService.sanitizeFileName(embedded.name, fallback: 'session')}.mid';

  await showMidiExportSheet(
    context,
    heading: l10n.midiExportTitleSession,
    subtitle: l10n.shareSubtitleSession(
      embedded.name,
      embedded.globalBpm,
      validCount,
    ),
    fileName: fileName,
    isZip: false,
    fixedBpm: embedded.globalBpm,
    singleCycleBeats: MidiExportService.sessionMacroCycleBeats(embedded),
    analyticsType: 'session',
    buildBytes: (options, _) => MidiExportService.exportSession(
      embedded,
      options: options,
    ),
  );
}

Future<void> exportPlaylistMidi(BuildContext context, Playlist playlist) async {
  final patProvider = context.read<PatternEditorProvider>();
  final playlistProvider = context.read<PlaylistProvider>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;

  if (playlist.items.isEmpty) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.midiExportPlaylistEmpty)),
    );
    return;
  }

  await patProvider.ensureLoaded;
  if (!context.mounted) return;

  final resolvedSessions = <Session>[
    for (final item in playlist.items)
      playlistProvider
          .resolveSession(item)
          .withEmbeddedPatterns(patProvider.getPatternById),
  ];
  final fileName =
      '${MidiExportService.sanitizeFileName(playlist.name, fallback: 'playlist')}.zip';

  await showMidiExportSheet(
    context,
    heading: l10n.midiExportTitlePlaylist,
    subtitle: l10n.midiExportSubtitlePlaylist(
      playlist.name,
      resolvedSessions.length,
    ),
    fileName: fileName,
    isZip: true,
    sessionCount: resolvedSessions.length,
    analyticsType: 'playlist',
    buildBytes: (options, _) => MidiExportService.exportPlaylistZip(
      playlist,
      resolvedSessions,
      options: options,
    ),
  );
}
