import 'dart:async';
import 'package:flutter/material.dart';
import '../models/pattern_model.dart';
import '../services/pattern_repository.dart';

/// Manages the pattern editor keyboard state and the global pattern library.
///
/// Key rule: If the currently active/editing pattern is deleted,
/// the keyboard MUST close automatically and activeEditingPatternId resets to null.
///
/// [patterns] and [getPatternById] only see active (non-deleted) patterns;
/// deletions are tombstones (see [PatternRepository]).
class PatternEditorProvider extends ChangeNotifier {
  final PatternRepository _repository;

  PatternEditorProvider({PatternRepository? repository})
      : _repository = repository ?? PatternRepository();

  /// Active patterns (what the UI shows).
  List<Pattern> get patterns => _repository.active;

  /// Every pattern including tombstones (internal: persistence/sync/tests).
  List<Pattern> get allPatterns => _repository.all;

  final Completer<void> _loadCompleter = Completer<void>();
  Future<void> get ensureLoaded => _loadCompleter.future;

  String? _activeEditingPatternId;
  String? get activeEditingPatternId => _activeEditingPatternId;

  bool _isKeyboardVisible = false;
  bool get isKeyboardVisible => _isKeyboardVisible;

  /// Returns the currently active pattern being edited, or null.
  Pattern? get activePattern {
    if (_activeEditingPatternId == null) return null;
    return getPatternById(_activeEditingPatternId!);
  }

  // ─────────────────────────────────────────────────────
  //  Initialization
  // ─────────────────────────────────────────────────────

  /// Loads patterns from persistent storage (purging expired tombstones).
  Future<void> loadPatterns() async {
    await _repository.load();

    // Add default Chacarera patterns if the library has never had anything
    // (a library with only tombstones means the user deleted them).
    if (_repository.all.isEmpty) {
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
      await _repository.create(p1);
      await _repository.create(p2);
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
    final exists = getPatternById(patternId) != null;
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

  /// Adds a new pattern to the library (rev 1; re-creating a deleted id
  /// revives its tombstone with rev + 1).
  Future<void> addPattern(Pattern pattern) async {
    await _loadCompleter.future;
    await _repository.create(pattern);
    notifyListeners();
  }

  /// Updates an existing pattern in the library (rev + 1).
  Future<void> updatePattern(Pattern updated) async {
    await _loadCompleter.future;
    if (await _repository.update(updated) != null) notifyListeners();
  }

  /// Updates the pattern if its id is already in the library, otherwise adds
  /// it (a deleted pattern with the same id is revived, never duplicated).
  Future<void> upsertPattern(Pattern pattern) async {
    await _loadCompleter.future;
    if (getPatternById(pattern.id) != null) {
      await updatePattern(pattern);
    } else {
      await addPattern(pattern);
    }
  }

  /// Deletes a pattern from the library (tombstone).
  ///
  /// **STRICT RULE**: If the deleted pattern is the one currently being
  /// edited (activeEditingPatternId), the keyboard is automatically closed
  /// and the active state resets to null.
  Future<(Pattern, int)?> deletePattern(String patternId) async {
    await _loadCompleter.future;
    final removed = await _repository.delete(patternId);
    if (removed == null) return null;

    // ── Strict check: close keyboard if deleting the focused pattern ──
    if (_activeEditingPatternId == patternId) {
      _activeEditingPatternId = null;
      _isKeyboardVisible = false;
      // Single notifyListeners covers both removal and keyboard close
    }

    notifyListeners();
    return removed;
  }

  /// Undo of [deletePattern]: revives [pattern] at its position.
  Future<void> restorePattern(Pattern pattern, int index) async {
    await _loadCompleter.future;
    if (await _repository.restore(pattern, index) != null) notifyListeners();
  }

  /// Retrieves an active pattern by ID, or null if not found / deleted.
  Pattern? getPatternById(String id) => _repository.byId(id);

  /// Reorders patterns in the library (e.g., drag-and-drop). Local order
  /// only: doesn't change the patterns' rev.
  Future<void> reorderPatterns(int oldIndex, int newIndex) async {
    await _loadCompleter.future;
    if (oldIndex < newIndex) newIndex -= 1;
    await _repository.reorder(oldIndex, newIndex);
    notifyListeners();
  }
}
