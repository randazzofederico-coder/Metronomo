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
///
/// Playlists (hybrid model): their sessions are added to the session library
/// (deterministic ids from the sender's library id, so re-imports don't
/// duplicate; sessions the user already has are reused) and each imported
/// item links to its library session, with a snapshot as fallback. If the
/// playlist was already imported, nothing is touched. Older links (playlist
/// with `sessionIds` + flat `sessions` list) are converted the same way.
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
    // Only a shared *pattern* goes to the pattern library. Patterns that come
    // with a session/playlist are embedded in their sessions instead (the
    // flat list exists for links created by older versions).
    final patternJsons = bundle.type == SharedType.pattern
        ? [bundle.data]
        : bundle.patterns;
    final bundlePatterns = <String, Pattern>{};
    for (final json in patternJsons) {
      final pattern = Pattern.fromJson(json);
      bundlePatterns[pattern.id] = pattern;
      if (patterns.getPatternById(pattern.id) != null) {
        patternIdMap[pattern.id] = pattern.id;
        continue;
      }
      final localId = _derivedId(bundle.shareId, pattern.id);
      patternIdMap[pattern.id] = localId;
      if (bundle.type == SharedType.pattern && patterns.getPatternById(localId) == null) {
        await patterns.addPattern(pattern.copyWith(id: localId));
        addedSomething = true;
      }
    }

    // ── Sessions ──
    // A shared *session* goes to the session library here; the sessions of a
    // shared playlist are added below, when the playlist is created.
    Session localCopy(Session session, String id) {
      // Embed patterns from the bundle (links from older versions only have
      // ids), then remap ids.
      final configs = session
          .withEmbeddedPatterns((pid) => bundlePatterns[pid])
          .patternsConfig
          .map((c) => c.copyWith(patternId: patternIdMap[c.patternId] ?? c.patternId))
          .toList();
      return session.copyWith(id: id, patternsConfig: configs);
    }

    final sessionJsons = bundle.type == SharedType.session
        ? [bundle.data]
        : const <Map<String, dynamic>>[];
    for (final json in sessionJsons) {
      final session = Session.fromJson(json);
      if (sessions.getSessionById(session.id) != null) {
        sessionIdMap[session.id] = session.id;
        continue;
      }
      final localId = _derivedId(bundle.shareId, session.id);
      sessionIdMap[session.id] = localId;
      if (sessions.getSessionById(localId) == null) {
        await sessions.addSession(localCopy(session, localId));
        addedSomething = true;
      }
    }

    // ── Main entity ID ──
    final String localId;
    var sessionCount = sessionJsons.length;
    switch (bundle.type) {
      case SharedType.pattern:
        localId = patternIdMap.values.first;
      case SharedType.session:
        localId = sessionIdMap.values.first;
      case SharedType.playlist:
        final playlist = Playlist.fromJson(bundle.data);
        // Current links: `items` with embedded sessions. Older links: only
        // `sessionIds`, resolved against the bundle's flat `sessions` list.
        final List<PlaylistItem> remoteItems;
        if (playlist.needsMigration) {
          final bundleSessions = {
            for (final json in bundle.sessions)
              (json['id'] as String?) ?? '': Session.fromJson(json),
          };
          remoteItems = [
            for (var i = 0; i < playlist.legacySessionIds.length; i++)
              if (bundleSessions[playlist.legacySessionIds[i]] != null)
                PlaylistItem(
                  id: 'legacy:$i:${playlist.legacySessionIds[i]}',
                  session: bundleSessions[playlist.legacySessionIds[i]]!,
                ),
          ];
        } else {
          remoteItems = playlist.items;
        }
        sessionCount = remoteItems.length;

        if (playlists.getPlaylistById(playlist.id) != null) {
          localId = playlist.id;
        } else {
          localId = _derivedId(bundle.shareId, playlist.id);
          if (playlists.getPlaylistById(localId) == null) {
            // Hybrid playlists: each session goes to the session library
            // (deduplicated by its original library id, same derivation as
            // shared sessions and as older versions) and the item links to it
            // with a snapshot.
            final items = <PlaylistItem>[];
            for (final item in remoteItems) {
              final originalId = item.sourceSessionId ?? item.session.id;
              final String librarySessionId;
              if (sessions.getSessionById(originalId) != null) {
                librarySessionId = originalId; // own content: reuse
              } else {
                librarySessionId = sessionIdMap[originalId] ?? _derivedId(bundle.shareId, originalId);
                if (sessions.getSessionById(librarySessionId) == null) {
                  await sessions.addSession(localCopy(item.session, librarySessionId));
                }
              }
              sessionIdMap[originalId] = librarySessionId;
              items.add(PlaylistItem(
                id: _derivedId(bundle.shareId, 'item:${item.id}'),
                sourceSessionId: librarySessionId,
                session: localCopy(
                  item.session,
                  _derivedId(bundle.shareId, 'item-session:${item.id}:${item.session.id}'),
                ),
              ));
            }
            await playlists.addPlaylist(playlist.copyWith(
              id: localId,
              items: items,
              legacySessionIds: const [],
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
      sessionCount: sessionCount,
    );
  }
}
