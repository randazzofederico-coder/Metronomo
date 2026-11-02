import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/playlist_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/services/deep_link_service.dart';
import 'package:metronomo_standalone/widgets/share_sheet.dart';
import 'package:metronomo_standalone/l10n/l10n.dart';

/// Share flows used from several screens (Tocar, Biblioteca).

void sharePattern(BuildContext context, Pattern pattern) {
  showShareSheet(
    context,
    heading: context.l10n.shareHeadingPattern,
    subtitle: context.l10n.shareSubtitlePattern(pattern.name, pattern.structure),
    createLink: () => DeepLinkService().createPatternLink(pattern),
  );
}

void shareSession(BuildContext context, Session session) {
  final patProvider = context.read<PatternEditorProvider>();
  showShareSheet(
    context,
    heading: context.l10n.shareHeadingSession,
    subtitle: context.l10n.shareSubtitleSession(
        session.name, session.globalBpm, session.patternsConfig.length),
    createLink: () async {
      // Patterns are embedded in the session; legacy sessions fall back to
      // the library. The list is still sent for older app versions.
      await patProvider.ensureLoaded;
      final embedded = session.withEmbeddedPatterns(patProvider.getPatternById);
      return DeepLinkService().createSessionLink(embedded, embedded.embeddedPatterns);
    },
  );
}

void sharePlaylist(BuildContext context, Playlist playlist) {
  final patProvider = context.read<PatternEditorProvider>();
  showShareSheet(
    context,
    heading: context.l10n.shareHeadingPlaylist,
    subtitle: context.l10n.shareSubtitlePlaylist(playlist.name, playlist.items.length),
    createLink: () async {
      await patProvider.ensureLoaded;

      // The playlist is self-contained (embedded sessions with embedded
      // patterns; very old copies fall back to the library). The flat
      // session/pattern lists are still sent for older app versions.
      final items = <PlaylistItem>[];
      final allPatterns = <Pattern>[];
      final seenPatternIds = <String>{};

      for (final item in playlist.items) {
        final session = item.session.withEmbeddedPatterns(patProvider.getPatternById);
        items.add(item.copyWith(session: session));
        for (final pat in session.embeddedPatterns) {
          if (seenPatternIds.add(pat.id)) allPatterns.add(pat);
        }
      }

      return DeepLinkService().createPlaylistLink(playlist.copyWith(items: items), allPatterns);
    },
  );
}
