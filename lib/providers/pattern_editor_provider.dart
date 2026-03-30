import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pattern_model.dart';
import '../services/pattern_repository.dart';

/// Manages the pattern editor keyboard state and the global pattern library.
///
/// Key rule: If the currently active/editing pattern is deleted,
/// the keyboard MUST close automatically and activeEditingPatternId resets to null.
class PatternEditorProvider extends ChangeNotifier {
  final PatternRepository _repository;

  PatternEditorProvider({PatternRepository? repository})
      : _repository = repository ?? PatternRepository();

  List<Pattern> _patterns = [];
  List<Pattern> get patterns => List.unmodifiable(_patterns);

  final Completer<void> _loadCompleter = Completer<void>();
  Future<void> get ensureLoaded => _loadCompleter.future;

  String? _activeEditingPatternId;
  String? get activeEditingPatternId => _activeEditingPatternId;

  bool _isKeyboardVisible = false;
  bool get isKeyboardVisible => _isKeyboardVisible;

  /// Returns the currently active pattern being edited, or null.
  Pattern? get activePattern {
    if (_activeEditingPatternId == null) return null;
    try {
      return _patterns.firstWhere((p) => p.id == _activeEditingPatternId);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────
  //  Initialization
  // ─────────────────────────────────────────────────────

  /// Loads patterns from persistent storage.
  Future<void> loadPatterns() async {
    _patterns = List<Pattern>.from(await _repository.loadPatterns());
    
    // Add default Chacarera patterns if library is entirely empty
    if (_patterns.isEmpty) {
      final p1 = Pattern(
        id: "default-chacarera-3-4",
        name: "3/4",
        structure: "3/2",
        pulses: [
          HomeMetronomePulse([0, 0]),
          HomeMetronomePulse([2, 0]),
          HomeMetronomePulse([2, 0]),
        ],
      );
      final p2 = Pattern(
        id: "default-chacarera-6-8",
        name: "6/8",
        structure: "2:3/3",
        pulses: [
          HomeMetronomePulse([1, 0, 0], 1.5),
          HomeMetronomePulse([1, 0, 0], 1.5),
        ],
      );
      _patterns.add(p1);
      _patterns.add(p2);
      await _repository.addPattern(p1);
      await _repository.addPattern(p2);
    }

    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────
  //  Keyboard Control
  // ─────────────────────────────────────────────────────

  /// Opens the pattern editor keyboard for a specific pattern.
  void openKeyboardFor(String patternId) {
    // Verify the pattern exists before opening
    final exists = _patterns.any((p) => p.id == patternId);
    if (!exists) return;

    _activeEditingPatternId = patternId;
    _isKeyboardVisible = true;
    notifyListeners();
  }

  /// Closes the pattern editor keyboard and resets active state.
  void closeKeyboard() {
    _activeEditingPatternId = null;
    _isKeyboardVisible = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────
  //  Pattern Library CRUD
  // ─────────────────────────────────────────────────────

  /// Adds a new pattern to the library.
  Future<void> addPattern(Pattern pattern) async {
    _patterns.add(pattern);
    await _repository.addPattern(pattern);
    notifyListeners();
  }

  /// Updates an existing pattern in the library.
  Future<void> updatePattern(Pattern updated) async {
    final index = _patterns.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _patterns[index] = updated.copyWith(updatedAt: DateTime.now());
      await _repository.updatePattern(_patterns[index]);
      notifyListeners();
    }
  }

  /// Deletes a pattern from the library.
  ///
  /// **STRICT RULE**: If the deleted pattern is the one currently being
  /// edited (activeEditingPatternId), the keyboard is automatically closed
  /// and the active state resets to null.
  Future<void> deletePattern(String patternId) async {
    _patterns.removeWhere((p) => p.id == patternId);
    await _repository.deletePattern(patternId);

    // ── Strict check: close keyboard if deleting the focused pattern ──
    if (_activeEditingPatternId == patternId) {
      _activeEditingPatternId = null;
      _isKeyboardVisible = false;
      // Single notifyListeners covers both removal and keyboard close
    }

    notifyListeners();
  }

  /// Retrieves a pattern by ID, or null if not found.
  Pattern? getPatternById(String id) {
    try {
      return _patterns.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Reorders patterns in the library (e.g., drag-and-drop).
  Future<void> reorderPatterns(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _patterns.removeAt(oldIndex);
    _patterns.insert(newIndex, item);
    await _repository.reorderPatterns(oldIndex, newIndex);
    notifyListeners();
  }
}
