import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';

/// Repository service for managing saved Sessions.
///
/// Provides CRUD operations with automatic persistence to SharedPreferences.
class SessionRepository {
  static const String _storageKey = 'session_library';

  List<Session> _sessions = [];
  List<Session> get sessions => List.unmodifiable(_sessions);

  /// Loads all sessions from persistent storage.
  Future<List<Session>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
        _sessions = jsonList
            .map((item) => Session.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _sessions = [];
      }
    } else {
      _sessions = [];
    }

    return List.unmodifiable(_sessions);
  }

  /// Saves all sessions to persistent storage.
  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Adds a new session and persists.
  Future<void> addSession(Session session) async {
    _sessions.add(session);
    await _saveSessions();
  }

  /// Updates an existing session by ID and persists.
  Future<void> updateSession(Session updated) async {
    final index = _sessions.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _sessions[index] = updated.copyWith(updatedAt: DateTime.now());
      await _saveSessions();
    }
  }

  /// Deletes a session by ID and persists.
  Future<void> deleteSession(String id) async {
    _sessions.removeWhere((s) => s.id == id);
    await _saveSessions();
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
