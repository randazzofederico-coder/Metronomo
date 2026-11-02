import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/playlist_model.dart';
import '../models/session_model.dart';
import '../models/synced_item.dart';
import '../services/playlist_repository.dart';
import 'pattern_editor_provider.dart';
import 'session_provider.dart';

/// Resolves a library session (with its patterns embedded) for the legacy
/// playlist migration. Returns null if it doesn't exist (or was deleted).
typedef PlaylistSessionResolver = Future<Session?> Function(String sessionId);

/// Synchronous lookup of an **active** library session (with its patterns
/// embedded), or null if it doesn't exist / was deleted / isn't loaded yet.
typedef LibrarySessionLookup = Session? Function(String sessionId);

/// Manages the playlist library state for the UI.
///
/// Hybrid model (see [PlaylistItem]): each item links to a library session
/// ([PlaylistItem.sourceSessionId], the source of truth) and keeps a fallback
/// snapshot. Use [resolveSession] / [resolvedSessions] for what to play, show
/// or share; [isInLibrary] tells whether the item is using its snapshot.
///
/// [playlists] and [getPlaylistById] only see active (non-deleted) playlists;
/// deletions are tombstones (see [PlaylistRepository]).
class PlaylistProvider extends ChangeNotifier {
  final PlaylistRepository _repository;

  PlaylistProvider({PlaylistRepository? repository, LibrarySessionLookup? librarySession})
      : _repository = repository ?? PlaylistRepository(),
        _librarySession = librarySession;

  static const _uuid = Uuid();

  LibrarySessionLookup? _librarySession;
  PlaylistSessionResolver? _attachedResolver;
  final List<VoidCallback> _detach = [];

  /// Connects the playlists to the session library (done once in `main.dart`):
  ///  * items resolve to the library version of their session;
  ///  * before a library session is deleted, the playlists refresh their
  ///    snapshot of it (so they keep playing exactly the same);
  ///  * library changes notify this provider's listeners (the playlist
  ///    screens show the library version);
  ///  * [loadPlaylists] migrates legacy playlists through the library.
  void attachLibrary({required SessionProvider sessions, required PatternEditorProvider patterns}) {
    _librarySession = (id) => sessions.getSessionById(id)?.withEmbeddedPatterns(patterns.getPatternById);
    _attachedResolver = (id) async {
      await sessions.ensureLoaded;
      await patterns.ensureLoaded;
      return _librarySession!(id);
    };
    sessions.addBeforeDeleteHook(
      (session) => refreshSnapshotsFor(session.withEmbeddedPatterns(patterns.getPatternById)),
    );
    sessions.addListener(notifyListeners);
    patterns.addListener(notifyListeners);
    _detach.add(() {
      sessions.removeListener(notifyListeners);
      patterns.removeListener(notifyListeners);
    });
  }

  @override
  void dispose() {
    for (final d in _detach) {
      d();
    }
    super.dispose();
  }

  /// Active playlists (what the UI shows).
  List<Playlist> get playlists => _repository.active;

  /// Every playlist including tombstones (internal: persistence/sync/tests).
  List<Playlist> get allPlaylists => _repository.all;

  final Completer<void> _loadCompleter = Completer<void>();

  /// Completes after loading **and** migrating legacy playlists.
  Future<void> get ensureLoaded => _loadCompleter.future;

  // ── Resolution (hybrid model) ────────────────────────────────────────────

  /// The active library session linked by [item] (patterns embedded), or
  /// null if it's not in the library.
  Session? librarySessionFor(PlaylistItem item) {
    final id = item.sourceSessionId;
    if (id == null) return null;
    return _librarySession?.call(id);
  }

  /// True if [item] is linked to an active library session (editable there).
  bool isInLibrary(PlaylistItem item) => librarySessionFor(item) != null;

  /// What [item] plays/shows/shares: the library session if it's active,
  /// otherwise the item's snapshot.
  Session resolveSession(PlaylistItem item) => librarySessionFor(item) ?? item.session;

  /// [resolveSession] for every item of [playlist], in order.
  List<Session> resolvedSessions(Playlist playlist) =>
      [for (final item in playlist.items) resolveSession(item)];

  static String _content(Session s) {
    final json = stripSyncFields(s.toJson())..remove('id');
    return jsonEncode(json);
  }

  /// [item] with its snapshot updated to [library] (keeps the snapshot id).
  /// Returns the same instance if nothing changed.
  static PlaylistItem _withSnapshot(PlaylistItem item, Session library) {
    if (_content(item.session) == _content(library)) return item;
    return item.copyWith(session: library.asEmbeddedCopy(id: item.session.id));
  }

  /// Opportunistic refresh: every item linked to an active library session
  /// gets an up-to-date snapshot. Only applied when the playlist is being
  /// stored anyway (no extra revs).
  Playlist _withFreshSnapshots(Playlist playlist) {
    if (_librarySession == null) return playlist;
    var changed = false;
    final items = [
      for (final item in playlist.items)
        () {
          final library = librarySessionFor(item);
          if (library == null) return item;
          final refreshed = _withSnapshot(item, library);
          if (!identical(refreshed, item)) changed = true;
          return refreshed;
        }(),
    ];
    return changed ? playlist.copyWith(items: items, updatedAt: playlist.updatedAt) : playlist;
  }

  // ── Loading / migration ──────────────────────────────────────────────────

  /// Loads playlists from persistent storage (purging expired tombstones).
  ///
  /// Legacy playlists (only `sessionIds`) are migrated here with
  /// [resolveSession] (default: the library attached with [attachLibrary]),
  /// which must wait for the session (and pattern) library to be loaded: each
  /// id becomes a [PlaylistItem] linked to it (with a snapshot); ids that
  /// can't be resolved are skipped. Migrated playlists are persisted once
  /// (rev + 1). Without a resolver, legacy playlists are kept untouched (and
  /// keep their `sessionIds` on disk) until a later load can migrate them.
  ///
  /// Playlists already in the item format need nothing: their items keep
  /// [PlaylistItem.sourceSessionId] (the link) and their embedded copy, which
  /// is now just the snapshot. Re-running is idempotent.
  Future<void> loadPlaylists({PlaylistSessionResolver? resolveSession}) async {
    await _repository.load();
    resolveSession ??= _attachedResolver;

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

  // ── Playlist CRUD ────────────────────────────────────────────────────────

  /// Adds a new playlist to the library (rev 1).
  Future<void> addPlaylist(Playlist playlist) async {
    await _loadCompleter.future;
    await _repository.create(_withFreshSnapshots(playlist));
    notifyListeners();
  }

  /// Updates an existing playlist in the library (rev + 1).
  Future<void> updatePlaylist(Playlist updated) async {
    await _loadCompleter.future;
    if (await _repository.update(_withFreshSnapshots(updated)) != null) notifyListeners();
  }

  /// Deletes a playlist from the library (tombstone).
  /// Returns the removed playlist and its position (for [restorePlaylist]).
  Future<(Playlist, int)?> deletePlaylist(String playlistId) async {
    await _loadCompleter.future;
    final removed = await _repository.delete(playlistId);
    if (removed != null) notifyListeners();
    return removed;
  }

  /// Undo of [deletePlaylist]: revives [playlist] exactly as it was (data,
  /// `updatedAt`) at its position.
  Future<void> restorePlaylist(Playlist playlist, int index) async {
    await _loadCompleter.future;
    if (await _repository.restore(playlist, index) != null) notifyListeners();
  }

  /// Retrieves an active playlist by ID, or null if not found / deleted.
  Playlist? getPlaylistById(String id) => _repository.byId(id);

  Future<void> _mutate(String playlistId, Playlist Function(Playlist p) change) async {
    await _loadCompleter.future;
    if (await _repository.mutate(playlistId, (p) => _withFreshSnapshots(change(p))) != null) {
      notifyListeners();
    }
  }

  // ── Items ────────────────────────────────────────────────────────────────

  /// Adds [librarySession] at the end of the playlist: an item linked to it
  /// with a snapshot (the same session may be added several times). Pass it
  /// with its patterns embedded (see [Session.withEmbeddedPatterns]).
  Future<PlaylistItem?> addSessionToPlaylist(String playlistId, Session librarySession) async {
    final item = PlaylistItem.fromLibrary(librarySession);
    await _mutate(playlistId, (p) => p.copyWith(items: [...p.items, item]));
    return getPlaylistById(playlistId) == null ? null : item;
  }

  /// Removes the item at [itemIndex]. Returns it plus the playlist as it was
  /// before (for [undoItemRemoval]).
  Future<(PlaylistItem, Playlist)?> removeItemFromPlaylist(String playlistId, int itemIndex) async {
    final playlist = getPlaylistById(playlistId);
    if (playlist == null || itemIndex < 0 || itemIndex >= playlist.items.length) return null;
    final removed = playlist.items[itemIndex];
    await _mutate(playlistId, (p) => p.copyWith(items: List.of(p.items)..removeAt(itemIndex)));
    return (removed, playlist);
  }

  /// Undo of [removeItemFromPlaylist]: see [revertPlaylist].
  Future<void> undoItemRemoval(Playlist previous) => revertPlaylist(previous);

  /// "Go back in time" for a playlist that is still active: restores
  /// [previous] exactly (name, description, items and their order,
  /// `updatedAt`), with rev + 1 internally. Items that still exist keep their
  /// current (fresher) snapshot.
  Future<void> revertPlaylist(Playlist previous) async {
    await _loadCompleter.future;
    final current = getPlaylistById(previous.id);
    if (current == null) return;
    final currentItems = {for (final i in current.items) i.id: i};
    final reverted = previous.copyWith(
      items: [for (final i in previous.items) currentItems[i.id] ?? i],
      updatedAt: previous.updatedAt,
    );
    await _repository.restoreSnapshot(reverted);
    notifyListeners();
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

  /// Links item [itemId] to the library session [sessionId] (e.g. after
  /// "Restaurar en la biblioteca" of an item that had no link). rev + 1.
  Future<void> linkItemToLibrary(String playlistId, String itemId, String sessionId) async {
    final playlist = getPlaylistById(playlistId);
    if (playlist == null) return;
    final item = playlist.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null || item.sourceSessionId == sessionId) return;
    await _mutate(playlistId, (p) => p.copyWith(items: [
          for (final i in p.items)
            if (i.id == itemId) i.copyWith(sourceSessionId: sessionId) else i,
        ]));
  }

  /// Called right before [librarySession] is deleted from the library: every
  /// item linked to it gets its snapshot updated to this latest version, so
  /// the playlists keep playing exactly the same (rev + 1 of each affected
  /// playlist; its `updatedAt` is kept, since nothing visible changed).
  Future<void> refreshSnapshotsFor(Session librarySession) async {
    await _loadCompleter.future;
    var changed = false;
    for (final playlist in _repository.active) {
      if (!playlist.items.any((i) => i.sourceSessionId == librarySession.id)) continue;
      var touched = false;
      final items = [
        for (final item in playlist.items)
          if (item.sourceSessionId == librarySession.id)
            () {
              final refreshed = _withSnapshot(item, librarySession);
              if (!identical(refreshed, item)) touched = true;
              return refreshed;
            }()
          else
            item,
      ];
      if (!touched) continue;
      await _repository.update(
        playlist.copyWith(items: items, updatedAt: playlist.updatedAt),
        keepUpdatedAt: true,
      );
      changed = true;
    }
    if (changed) notifyListeners();
  }
}
