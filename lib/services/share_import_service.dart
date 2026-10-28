import 'package:uuid/uuid.dart';

import '../models/pattern_model.dart';
import '../models/playlist_model.dart';
import '../models/session_model.dart';
import '../providers/pattern_editor_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/session_provider.dart';
import 'deep_link_service.dart';

/// Result of importing a [SharedBundle] into the local libraries.
class ShareImportResult {
  final SharedType type;
  final String name;

  /// Local ID of the main entity (pattern / session / playlist).
  final String localId;

  /// True if nothing new was added (link opened before, or own content).
  final bool alreadyInLibrary;

  final int patternCount;
  final int sessionCount;

  const ShareImportResult({
    required this.type,
    required this.name,
    required this.localId,
    required this.alreadyInLibrary,
    this.patternCount = 0,
    this.sessionCount = 0,
  });
}

/// Imports shared bundles into the local pattern/session/playlist libraries.
///
/// ID strategy (idempotent, no extra storage needed):
///  * If the original ID already exists locally, the entity is the user's own
///    (they opened their own link) → reuse it.
///  * Otherwise the local ID is a UUID v5 derived from `shareId + originalId`,
///    so opening the same link again maps to the same local entities and
///    nothing is duplicated. If the user deleted them, they're re-created.
class ShareImportService {
  final PatternEditorProvider patterns;
  final SessionProvider sessions;
  final PlaylistProvider playlists;

  ShareImportService({
    required this.patterns,
    required this.sessions,
    required this.playlists,
  });

  static const _uuid = Uuid();

  String _derivedId(String shareId, String originalId) =>
      _uuid.v5(Namespace.url.value, 'metronomo-share:$shareId:$originalId');

  Future<ShareImportResult> import(SharedBundle bundle) async {
    await Future.wait([
      patterns.ensureLoaded,
      sessions.ensureLoaded,
      playlists.ensureLoaded,
    ]);

    final patternIdMap = <String, String>{};
    final sessionIdMap = <String, String>{};
    var addedSomething = false;

    // ── Patterns ──
    final patternJsons = bundle.type == SharedType.pattern
        ? [bundle.data]
        : bundle.patterns;
    for (final json in patternJsons) {
      final pattern = Pattern.fromJson(json);
      if (patterns.getPatternById(pattern.id) != null) {
        patternIdMap[pattern.id] = pattern.id;
        continue;
      }
      final localId = _derivedId(bundle.shareId, pattern.id);
      patternIdMap[pattern.id] = localId;
      if (patterns.getPatternById(localId) == null) {
        await patterns.addPattern(pattern.copyWith(id: localId));
        addedSomething = true;
      }
    }

    // ── Sessions ──
    final sessionJsons = bundle.type == SharedType.session
        ? [bundle.data]
        : bundle.sessions;
    for (final json in sessionJsons) {
      final session = Session.fromJson(json);
      if (sessions.getSessionById(session.id) != null) {
        sessionIdMap[session.id] = session.id;
        continue;
      }
      final localId = _derivedId(bundle.shareId, session.id);
      sessionIdMap[session.id] = localId;
      if (sessions.getSessionById(localId) == null) {
        final configs = session.patternsConfig
            .map((c) => c.copyWith(
                patternId: patternIdMap[c.patternId] ?? c.patternId))
            .toList();
        await sessions.addSession(
            session.copyWith(id: localId, patternsConfig: configs));
        addedSomething = true;
      }
    }

    // ── Main entity ID ──
    final String localId;
    switch (bundle.type) {
      case SharedType.pattern:
        localId = patternIdMap.values.first;
      case SharedType.session:
        localId = sessionIdMap.values.first;
      case SharedType.playlist:
        final playlist = Playlist.fromJson(bundle.data);
        if (playlists.getPlaylistById(playlist.id) != null) {
          localId = playlist.id;
        } else {
          localId = _derivedId(bundle.shareId, playlist.id);
          if (playlists.getPlaylistById(localId) == null) {
            await playlists.addPlaylist(playlist.copyWith(
              id: localId,
              sessionIds: playlist.sessionIds
                  .map((id) => sessionIdMap[id] ?? id)
                  .toList(),
            ));
            addedSomething = true;
          }
        }
    }

    return ShareImportResult(
      type: bundle.type,
      name: bundle.name,
      localId: localId,
      alreadyInLibrary: !addedSomething,
      patternCount: patternJsons.length,
      sessionCount: sessionJsons.length,
    );
  }
}
