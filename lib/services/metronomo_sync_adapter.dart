import 'package:fede_apps_core/fede_apps_core.dart' show LibrarySync, SyncAdapter, SyncFields, SyncState, SyncStatus;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import '../providers/pattern_editor_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/session_provider.dart';

/// Connects the three libraries (patterns, sessions, playlists) to the cloud
/// sync of fede_apps_core ([LibrarySync], `users/{uid}/appData/metronomo`).
///
/// Uses the **same provider instances** as the UI, so whatever arrives from
/// the cloud shows up immediately.
///
/// * [readAll]: every item, tombstones included, as full JSON.
/// * [applyRemote]: stored exactly as given (no rev/updatedAt/dev stamping),
///   never calls [LibrarySync.notifyLocalChange]. [collections] is ordered
///   patterns → sessions → playlists, which is the order [LibrarySync]
///   applies them within one sync (sessions before the playlists that link
///   to them).
/// * A remote session delete runs the same before-delete hooks as a local
///   delete (playlists refresh their snapshot first): see
///   [SessionProvider.applyRemote].
/// * Session open in "Tocar" ([onSessionRenamed]): a remote rename updates
///   the title, like a local rename; the working state (patterns, tempo) is
///   never touched by a remote update. A remote delete behaves like a local
///   delete: nothing changes on screen, and saving falls back to "save as"
///   because the session is no longer in the library.
class MetronomoSyncAdapter implements SyncAdapter {
  MetronomoSyncAdapter({
    required this.patterns,
    required this.sessions,
    required this.playlists,
    this.onSessionRenamed,
  });

  static const patternsCollection = 'patterns';
  static const sessionsCollection = 'sessions';
  static const playlistsCollection = 'playlists';

  final PatternEditorProvider patterns;
  final SessionProvider sessions;
  final PlaylistProvider playlists;

  /// Called when a remote update renamed a session (set by `main.dart` to
  /// `MetronomeProvider.onSessionRenamed`).
  void Function(String sessionId, String newName)? onSessionRenamed;

  static const _uuid = Uuid();

  @override
  String get appId => 'metronomo';

  @override
  List<String> get collections => const [patternsCollection, sessionsCollection, playlistsCollection];

  @override
  Future<List<Map<String, dynamic>>> readAll(String collection) async {
    switch (collection) {
      case patternsCollection:
        return _withoutPristineSeeds(await patterns.exportForSync());
      case sessionsCollection:
        return _withoutPristineSeeds(await sessions.exportForSync());
      case playlistsCollection:
        return playlists.exportForSync();
    }
    return const [];
  }

  /// Default items seeded on first launch (ids `default-…`) are only synced
  /// once the user changes or deletes them (rev ≥ 2). Every install seeds
  /// them with the same ids but its own `createdAt` / language, and on a
  /// first login (no base) both sides count as changed: syncing untouched
  /// seeds would create "(otro dispositivo)" copies, or revive a default the
  /// user deleted on another device. Left out, a cloud version (edited on
  /// another device) still replaces the local seed.
  static bool isPristineSeed(Map<String, dynamic> item) {
    final id = item[SyncFields.id];
    return id is String &&
        id.startsWith('default-') &&
        SyncFields.readRev(item) == 1 &&
        !SyncFields.readDeleted(item);
  }

  static List<Map<String, dynamic>> _withoutPristineSeeds(List<Map<String, dynamic>> items) =>
      [for (final i in items) if (!isPristineSeed(i)) i];

  @override
  Future<void> applyRemote(
    String collection, {
    required List<Map<String, dynamic>> upserts,
    required List<String> removals,
  }) async {
    switch (collection) {
      case patternsCollection:
        await patterns.applyRemote(upserts: upserts, removals: removals);
      case sessionsCollection:
        final renamed = <String, String>{};
        for (final u in upserts) {
          final id = u[SyncFields.id];
          final name = u['name'];
          if (id is! String || name is! String || SyncFields.readDeleted(u)) continue;
          final current = sessions.getSessionById(id);
          if (current != null && current.name != name) renamed[id] = name;
        }
        await sessions.applyRemote(upserts: upserts, removals: removals);
        renamed.forEach((id, name) => onSessionRenamed?.call(id, name));
      case playlistsCollection:
        await playlists.applyRemote(upserts: upserts, removals: removals);
    }
  }

  /// New id, name "… (otro dispositivo)" / "… (other device)" (app language),
  /// data unchanged (playlists keep their items as they are). The package
  /// sets rev, updatedAt, dev and clears the tombstone.
  @override
  Map<String, dynamic> conflictCopy(String collection, Map<String, dynamic> item) {
    final name = item['name'];
    return {
      ...item,
      SyncFields.id: _uuid.v4(),
      'name': L10n.current.syncConflictCopyName(name is String ? name : ''),
    };
  }

  // ── Tombstone purge ──────────────────────────────────────────────────────

  VoidCallback? _purgeListener;

  /// After every successful sync, purges the expired tombstones that are now
  /// synced (the purge on load can't, for an account, until the sync state
  /// is known: see [LibrarySync.canPurgeLocally]).
  void purgeAfterSyncs(LibrarySync sync) {
    if (_purgeListener != null) return;
    DateTime? last = sync.status.value.lastSyncedAt;
    void listener() {
      final SyncStatus s = sync.status.value;
      if (s.state != SyncState.idle || s.lastSyncedAt == null || s.lastSyncedAt == last) return;
      last = s.lastSyncedAt;
      patterns.purgeExpired();
      sessions.purgeExpired();
      playlists.purgeExpired();
    }

    _purgeListener = listener;
    sync.status.addListener(listener);
  }
}
