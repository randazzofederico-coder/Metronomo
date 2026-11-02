import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist_model.dart';
import '../models/session_model.dart';
import '../services/playlist_repository.dart';

/// Resolves a library session (with its patterns embedded) for the legacy
/// playlist migration. Returns null if it doesn't exist (or was deleted).
typedef PlaylistSessionResolver = Future<Session?> Function(String sessionId);

/// Manages the playlist library state for the UI.
///
/// Playlists are self-contained: each [PlaylistItem] holds a full copy of a
/// session, so the session library can change without affecting them.
/// [playlists] and [getPlaylistById] only see active (non-deleted) playlists;
/// deletions are tombstones (see [PlaylistRepository]).
class PlaylistProvider extends ChangeNotifier {
  final PlaylistRepository _repository;

  PlaylistProvider({PlaylistRepository? repository})
      : _repository = repository ?? PlaylistRepository();

  static const _uuid = Uuid();

  /// Active playlists (what the UI shows).
  List<Playlist> get playlists => _repository.active;

  /// Every playlist including tombstones (internal: persistence/sync/tests).
  List<Playlist> get allPlaylists => _repository.all;

  final Completer<void> _loadCompleter = Completer<void>();

  /// Completes after loading **and** migrating legacy playlists.
  Future<void> get ensureLoaded => _loadCompleter.future;

  /// Loads playlists from persistent storage (purging expired tombstones).
  ///
  /// Legacy playlists (only `sessionIds`) are migrated here with
  /// [resolveSession], which must wait for the session (and pattern) library
  /// to be loaded: each id is embedded as a [PlaylistItem]; ids that can't be
  /// resolved are skipped. Migrated playlists are persisted once (rev + 1).
  /// Without a resolver, legacy playlists are kept untouched (and keep their
  /// `sessionIds` on disk) until a later load can migrate them.
  Future<void> loadPlaylists({PlaylistSessionResolver? resolveSession}) async {
    await _repository.load();

    if (resolveSession != null) {
      for (final playlist in _repository.all) {
        // Tombstones stay as they are (hidden, purged later).
        if (!playlist.needsMigration || playlist.deleted) continue;
        final items = <PlaylistItem>[];
        for (var i = 0; i < playlist.legacySessionIds.length; i++) {
          final sessionId = playlist.legacySessionIds[i];
          final session = await resolveSession(sessionId);
          if (session == null) continue; // missing / deleted: skip
          items.add(PlaylistItem.fromLibrary(
            session,
            // Deterministic ids: migrating the same data twice (or on two
            // devices) yields the same items.
            id: _uuid.v5(Namespace.url.value, 'metronomo-playlist-item:${playlist.id}:$i:$sessionId'),
            sessionId: _uuid.v5(Namespace.url.value, 'metronomo-playlist-session:${playlist.id}:$i:$sessionId'),
          ));
        }
        final migrated = playlist.copyWith(
          items: [...playlist.items, ...items],
          legacySessionIds: const [],
        );
        await _repository.update(migrated);
      }
    }

    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
    notifyListeners();
  }

  /// Adds a new playlist to the library (rev 1).
  Future<void> addPlaylist(Playlist playlist) async {
    await _loadCompleter.future;
    await _repository.create(playlist);
    notifyListeners();
  }

  /// Updates an existing playlist in the library (rev + 1).
  Future<void> updatePlaylist(Playlist updated) async {
    await _loadCompleter.future;
    if (await _repository.update(updated) != null) notifyListeners();
  }

  /// Deletes a playlist from the library (tombstone).
  /// Returns the removed playlist and its position (for [restorePlaylist]).
  Future<(Playlist, int)?> deletePlaylist(String playlistId) async {
    await _loadCompleter.future;
    final removed = await _repository.delete(playlistId);
    if (removed != null) notifyListeners();
    return removed;
  }

  /// Undo of [deletePlaylist]: revives [playlist] at its position.
  Future<void> restorePlaylist(Playlist playlist, int index) async {
    await _loadCompleter.future;
    if (await _repository.restore(playlist, index) != null) notifyListeners();
  }

  /// Retrieves an active playlist by ID, or null if not found / deleted.
  Playlist? getPlaylistById(String id) => _repository.byId(id);

  Future<void> _mutate(String playlistId, Playlist Function(Playlist p) change) async {
    await _loadCompleter.future;
    if (await _repository.mutate(playlistId, change) != null) notifyListeners();
  }

  /// Adds a **copy** of [librarySession] at the end of the playlist (the same
  /// session may be added several times). Pass it with its patterns embedded
  /// (see [Session.withEmbeddedPatterns]).
  Future<PlaylistItem?> addSessionToPlaylist(String playlistId, Session librarySession) async {
    final item = PlaylistItem.fromLibrary(librarySession);
    await _mutate(playlistId, (p) => p.copyWith(items: [...p.items, item]));
    return getPlaylistById(playlistId) == null ? null : item;
  }

  /// Removes the item at [itemIndex]. Returns it (for [insertItemInPlaylist]).
  Future<PlaylistItem?> removeItemFromPlaylist(String playlistId, int itemIndex) async {
    final playlist = getPlaylistById(playlistId);
    if (playlist == null || itemIndex < 0 || itemIndex >= playlist.items.length) return null;
    final removed = playlist.items[itemIndex];
    await _mutate(playlistId, (p) => p.copyWith(items: List.of(p.items)..removeAt(itemIndex)));
    return removed;
  }

  /// Inserts [item] at [itemIndex] (undo of [removeItemFromPlaylist]).
  Future<void> insertItemInPlaylist(String playlistId, int itemIndex, PlaylistItem item) async {
    final playlist = getPlaylistById(playlistId);
    if (playlist == null || playlist.items.any((i) => i.id == item.id)) return;
    await _mutate(
      playlistId,
      (p) => p.copyWith(items: List.of(p.items)..insert(itemIndex.clamp(0, p.items.length), item)),
    );
  }

  /// Reorders items within a playlist (rev + 1).
  Future<void> reorderItemsInPlaylist(String playlistId, int oldIndex, int newIndex) async {
    final playlist = getPlaylistById(playlistId);
    if (playlist == null || oldIndex < 0 || oldIndex >= playlist.items.length) return;
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    await _mutate(playlistId, (p) {
      final items = List.of(p.items);
      final item = items.removeAt(oldIndex);
      items.insert(newIndex.clamp(0, items.length), item);
      return p.copyWith(items: items);
    });
  }

  /// Replaces the embedded session of item [itemId] (the playlist's own copy;
  /// the session library is never touched). rev + 1 of the playlist.
  Future<void> updateItemSession(String playlistId, String itemId, Session session) async {
    await _mutate(playlistId, (p) => p.copyWith(items: [
          for (final i in p.items)
            if (i.id == itemId) i.copyWith(session: session.asEmbeddedCopy(id: i.session.id)) else i,
        ]));
  }
}
