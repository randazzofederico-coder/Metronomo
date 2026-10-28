import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pattern_model.dart';
import '../models/session_model.dart';
import '../services/session_repository.dart';

/// Manages the session library state for the UI.
class SessionProvider extends ChangeNotifier {
  final SessionRepository _repository;

  SessionProvider({SessionRepository? repository})
      : _repository = repository ?? SessionRepository();

  List<Session> _sessions = [];
  List<Session> get sessions => List.unmodifiable(_sessions);

  final Completer<void> _loadCompleter = Completer<void>();
  Future<void> get ensureLoaded => _loadCompleter.future;

  /// Loads sessions from persistent storage.
  Future<void> loadSessions() async {
    _sessions = List<Session>.from(await _repository.loadSessions());
    
    // Add default Chacarera session if library is entirely empty
    if (_sessions.isEmpty) {
      final chacareraSession = Session(
        id: "default-session-chacarera",
        name: "Chacarera",
        description: "Sesión por defecto con birritmia de 3/4 y 6/8",
        globalBpm: 120,
        patternsConfig: [
          SessionPatternConfig(patternId: "default-chacarera-3-4", volume: 0.8, orderIndex: 0),
          SessionPatternConfig(patternId: "default-chacarera-6-8", volume: 0.8, orderIndex: 1),
        ]
      );
      _sessions.add(chacareraSession);
      await _repository.addSession(chacareraSession);
    }

    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
    notifyListeners();
  }

  /// Adds a new session to the library.
  Future<void> addSession(Session session) async {
    await _loadCompleter.future;
    _sessions.add(session);
    await _repository.addSession(session);
    notifyListeners();
  }

  /// Updates an existing session in the library.
  Future<void> updateSession(Session updated) async {
    await _loadCompleter.future;
    final index = _sessions.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _sessions[index] = updated.copyWith(updatedAt: DateTime.now());
      await _repository.updateSession(_sessions[index]);
      notifyListeners();
    }
  }

  /// Deletes a session from the library.
  /// Returns the removed session and its position (for [restoreSession]).
  Future<(Session, int)?> deleteSession(String sessionId) async {
    await _loadCompleter.future;
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return null;
    final removed = _sessions.removeAt(index);
    await _repository.deleteSession(sessionId);
    notifyListeners();
    return (removed, index);
  }

  /// Undo of [deleteSession]: re-inserts [session] at [index].
  Future<void> restoreSession(Session session, int index) async {
    await _loadCompleter.future;
    if (getSessionById(session.id) != null) return;
    _sessions.insert(index.clamp(0, _sessions.length), session);
    await _repository.insertSession(index, session);
    notifyListeners();
  }

  /// Retrieves a session by ID, or null if not found.
  Session? getSessionById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// One-time migration: embeds library patterns into legacy sessions so they
  /// no longer depend on the pattern library. Idempotent. Returns how many
  /// sessions were migrated.
  Future<int> embedMissingPatterns(Pattern? Function(String patternId) lookup) async {
    await _loadCompleter.future;
    var migrated = 0;
    for (var i = 0; i < _sessions.length; i++) {
      final session = _sessions[i];
      if (!session.needsEmbedding) continue;
      final updated = session.withEmbeddedPatterns(lookup);
      if (updated.needsEmbedding && updated.patternsConfig.every((c) => !c.hasEmbeddedPattern)) {
        continue; // nothing could be resolved
      }
      _sessions[i] = updated;
      await _repository.updateSession(updated);
      migrated++;
    }
    if (migrated > 0) notifyListeners();
    return migrated;
  }
}
