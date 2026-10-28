import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/playlist_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/services/deep_link_service.dart';
import 'package:metronomo_standalone/widgets/share_sheet.dart';

/// Share flows used from several screens (Tocar, Biblioteca).

void sharePattern(BuildContext context, Pattern pattern) {
  showShareSheet(
    context,
    heading: 'Compartir patrón',
    subtitle: '«${pattern.name}» · ${pattern.structure}',
    createLink: () => DeepLinkService().createPatternLink(pattern),
  );
}

void shareSession(BuildContext context, Session session) {
  final patProvider = context.read<PatternEditorProvider>();
  showShareSheet(
    context,
    heading: 'Compartir sesión',
    subtitle: '«${session.name}» · ${session.globalBpm} BPM · ${session.patternsConfig.length} patrones',
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
    heading: 'Compartir playlist',
    subtitle: '«${playlist.name}» · ${playlist.sessionIds.length} sesiones',
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
