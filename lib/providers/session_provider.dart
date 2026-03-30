import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../services/session_repository.dart';

/// Manages the session library state for the UI.
class SessionProvider extends ChangeNotifier {
  final SessionRepository _repository;

  SessionProvider({SessionRepository? repository})
      : _repository = repository ?? SessionRepository();

  List<Session> _sessions = [];
  List<Session> get sessions => List.unmodifiable(_sessions);

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
    
    notifyListeners();
  }

  /// Adds a new session to the library.
  Future<void> addSession(Session session) async {
    _sessions.add(session);
    await _repository.addSession(session);
    notifyListeners();
  }

  /// Updates an existing session in the library.
  Future<void> updateSession(Session updated) async {
    final index = _sessions.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _sessions[index] = updated.copyWith(updatedAt: DateTime.now());
      await _repository.updateSession(_sessions[index]);
      notifyListeners();
    }
  }

  /// Deletes a session from the library.
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    await _repository.deleteSession(sessionId);
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
}
