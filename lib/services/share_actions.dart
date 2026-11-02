import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/playlist_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
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
  final sessionProvider = context.read<SessionProvider>();
  final patProvider = context.read<PatternEditorProvider>();
  showShareSheet(
    context,
    heading: context.l10n.shareHeadingPlaylist,
    subtitle: context.l10n.shareSubtitlePlaylist(playlist.name, playlist.sessionIds.length),
    createLink: () async {
      await sessionProvider.ensureLoaded;
      await patProvider.ensureLoaded;

      // Resolve sessions (with embedded patterns; legacy ones via the
      // library). The flat pattern list is still sent for older versions.
      final sessions = <Session>[];
      final allPatterns = <Pattern>[];
      final seenPatternIds = <String>{};

      for (final sessionId in playlist.sessionIds) {
        final stored = sessionProvider.getSessionById(sessionId);
        if (stored != null) {
          final session = stored.withEmbeddedPatterns(patProvider.getPatternById);
          sessions.add(session);
          for (final pat in session.embeddedPatterns) {
            if (seenPatternIds.add(pat.id)) allPatterns.add(pat);
          }
        }
      }

      return DeepLinkService().createPlaylistLink(playlist, sessions, allPatterns);
    },
  );
}
