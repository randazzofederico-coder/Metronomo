import 'dart:async';
import 'package:flutter/material.dart';
import 'package:metronomo_standalone/l10n/l10n.dart';
import '../models/pattern_model.dart';
import '../models/session_model.dart';
import '../services/session_repository.dart';

/// Manages the session library state for the UI.
///
/// [sessions] and [getSessionById] only see active (non-deleted) sessions;
/// deletions are tombstones (see [SessionRepository]). [allSessions]
/// (tombstones included) is for internal use only.
class SessionProvider extends ChangeNotifier {
  final SessionRepository _repository;

  SessionProvider({SessionRepository? repository})
      : _repository = repository ?? SessionRepository();

  /// Active sessions (what the UI shows).
  List<Session> get sessions => _repository.active;

  /// Every session including tombstones (internal: persistence/sync/tests).
  List<Session> get allSessions => _repository.all;

  final Completer<void> _loadCompleter = Completer<void>();
  Future<void> get ensureLoaded => _loadCompleter.future;

  /// Loads sessions from persistent storage (purging expired tombstones).
  Future<void> loadSessions() async {
    await _repository.load();

    // Add default Chacarera session if the library has never had anything
    // (a library with only tombstones means the user deleted them).
    if (_repository.all.isEmpty) {
      final chacareraSession = Session(
        id: "default-session-chacarera",
        name: "Chacarera",
        description: L10n.current.sessionDefaultDescription,
        globalBpm: 120,
        patternsConfig: [
          SessionPatternConfig(patternId: "default-chacarera-3-4", volume: 0.8, orderIndex: 0),
          SessionPatternConfig(patternId: "default-chacarera-6-8", volume: 0.8, orderIndex: 1),
        ]
      );
      await _repository.create(chacareraSession);
    }

    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
    notifyListeners();
  }

  /// Adds a new session to the library (rev 1).
  Future<void> addSession(Session session) async {
    await _loadCompleter.future;
    await _repository.create(session);
    notifyListeners();
  }

  /// Updates an existing session in the library (rev + 1).
  Future<void> updateSession(Session updated) async {
    await _loadCompleter.future;
    if (await _repository.update(updated) != null) notifyListeners();
  }

  /// Undo of an overwrite: puts [previous] back exactly as it was (data and
  /// `updatedAt`; rev + 1 internally), keeping its position.
  Future<void> revertSession(Session previous) async {
    await _loadCompleter.future;
    await _repository.restoreSnapshot(previous);
    notifyListeners();
  }

  final List<Future<void> Function(Session session)> _beforeDeleteHooks = [];

  /// Registers [hook], awaited with the current (active) session right before
  /// it's deleted. Used by playlists to refresh their fallback snapshot.
  void addBeforeDeleteHook(Future<void> Function(Session session) hook) =>
      _beforeDeleteHooks.add(hook);

  /// Deletes a session from the library (tombstone).
  /// Returns the removed session and its position (for [restoreSession]).
  ///
  /// Playlists keep working: before deleting, the before-delete hooks let
  /// them refresh their snapshot of this session (see [addBeforeDeleteHook]).
  Future<(Session, int)?> deleteSession(String sessionId) async {
    await _loadCompleter.future;
    final current = getSessionById(sessionId);
    if (current == null) return null;
    for (final hook in List.of(_beforeDeleteHooks)) {
      await hook(current);
    }
    final removed = await _repository.delete(sessionId);
    if (removed != null) notifyListeners();
    return removed;
  }

  /// Undo of [deleteSession]: revives [session] exactly as it was (data,
  /// `updatedAt`) at its position.
  Future<void> restoreSession(Session session, int index) async {
    await _loadCompleter.future;
    if (await _repository.restore(session, index) != null) notifyListeners();
  }

  /// "Restaurar en la biblioteca" from a playlist: puts [snapshot] (a
  /// playlist's fallback copy) back in the library under [id].
  ///
  /// * Already active → returned as is (nothing changes).
  /// * Tombstone still there → revived in place with the snapshot data
  ///   (same id, rev + 1).
  /// * Otherwise → created with that id (rev 1).
  ///
  /// The snapshot's own `createdAt`/`updatedAt` are kept in both cases.
  Future<Session> restoreFromSnapshot(Session snapshot, {required String id}) async {
    await _loadCompleter.future;
    final existing = getSessionById(id);
    if (existing != null) return existing;
    final copy = snapshot.asEmbeddedCopy(id: id);
    final Session stored;
    if (_repository.all.any((s) => s.id == id)) {
      stored = await _repository.restoreSnapshot(copy);
    } else {
      stored = await _repository.create(copy, keepUpdatedAt: true);
    }
    notifyListeners();
    return stored;
  }

  /// Retrieves an active session by ID, or null if not found / deleted.
  Session? getSessionById(String id) => _repository.byId(id);

  /// One-time migration: embeds library patterns into legacy sessions so they
  /// no longer depend on the pattern library. Idempotent. Returns how many
  /// sessions were migrated.
  Future<int> embedMissingPatterns(Pattern? Function(String patternId) lookup) async {
    await _loadCompleter.future;
    var migrated = 0;
    for (final session in sessions) {
      if (!session.needsEmbedding) continue;
      final updated = session.withEmbeddedPatterns(lookup);
      if (updated.needsEmbedding && updated.patternsConfig.every((c) => !c.hasEmbeddedPattern)) {
        continue; // nothing could be resolved
      }
      await _repository.update(updated);
      migrated++;
    }
    if (migrated > 0) notifyListeners();
    return migrated;
  }
}
