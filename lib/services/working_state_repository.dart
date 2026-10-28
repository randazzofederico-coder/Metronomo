import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository for persisting the metronome's "working state" — the live
/// snapshot of whatever is on screen, even if it hasn't been saved as a
/// named session.  This survives app restarts.
class WorkingStateRepository {
  static const String _storageKey = 'working_state';

  /// Loads the previously persisted working state, or null if none exists.
  Future<Map<String, dynamic>?> loadWorkingState() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return null;

    try {
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Persists the current working state.
  Future<void> saveWorkingState(Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(state));
  }

  /// Removes the persisted working state.
  Future<void> clearWorkingState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
