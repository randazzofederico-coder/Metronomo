import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pattern_model.dart';

/// Repository service for managing the global Pattern Library.
///
/// Provides CRUD operations with automatic persistence to SharedPreferences.
class PatternRepository {
  static const String _storageKey = 'pattern_library';

  List<Pattern> _patterns = [];
  List<Pattern> get patterns => List.unmodifiable(_patterns);

  /// Loads all patterns from persistent storage.
  Future<List<Pattern>> loadPatterns() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
        _patterns = jsonList
            .map((item) => Pattern.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _patterns = [];
      }
    } else {
      _patterns = [];
    }

    return List.unmodifiable(_patterns);
  }

  /// Saves all patterns to persistent storage.
  Future<void> _savePatterns() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_patterns.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Adds a new pattern and persists.
  Future<void> addPattern(Pattern pattern) async {
    _patterns.add(pattern);
    await _savePatterns();
  }

  /// Updates an existing pattern by ID and persists.
  Future<void> updatePattern(Pattern updated) async {
    final index = _patterns.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _patterns[index] = updated.copyWith(updatedAt: DateTime.now());
      await _savePatterns();
    }
  }

  /// Deletes a pattern by ID and persists.
  Future<void> deletePattern(String id) async {
    _patterns.removeWhere((p) => p.id == id);
    await _savePatterns();
  }

  /// Retrieves a pattern by ID, or null if not found.
  Pattern? getPatternById(String id) {
    try {
      return _patterns.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Reorders patterns by moving an item from [oldIndex] to [newIndex].
  Future<void> reorderPatterns(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _patterns.removeAt(oldIndex);
    _patterns.insert(newIndex, item);
    await _savePatterns();
  }
}
