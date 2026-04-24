import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/permission_cache.dart';

/// Manages all application-level settings with automatic persistence.
///
/// Covers: sound selection, random silences, background playback,
/// screen wake lock, timer, training session, and UI scale.
class SettingsProvider extends ChangeNotifier {
  static const String _prefKeySound = 'settings_sound';
  static const String _prefKeySilence = 'settings_silence';
  static const String _prefKeyBackground = 'settings_background';
  static const String _prefKeyScreenOn = 'settings_screen_on';
  static const String _prefKeyTimer = 'settings_timer';
  static const String _prefKeyTrainingActive = 'settings_training_active';
  static const String _prefKeyTrainingStartBpm = 'settings_training_start_bpm';
  static const String _prefKeyTrainingEndBpm = 'settings_training_end_bpm';
  static const String _prefKeyTrainingIncrement = 'settings_training_increment';
  static const String _prefKeyTrainingInterval = 'settings_training_interval';
  static const String _prefKeyTrainingRepetitions = 'settings_training_reps';
  static const String _prefKeyUiScale = 'settings_ui_scale';

  // ─────────────────────────────────────────────────────
  //  Available Options
  // ─────────────────────────────────────────────────────

  static const List<String> availableSounds = [
    'Default',
    'Woodblock',
    'Digital',
  ];

  // ─────────────────────────────────────────────────────
  //  State
  // ─────────────────────────────────────────────────────

  String _selectedSound = 'Default';
  String get selectedSound => _selectedSound;

  double _randomSilencePercentage = 0.0;
  double get randomSilencePercentage => _randomSilencePercentage;

  bool _backgroundPlayback = true;
  bool get backgroundPlayback => _backgroundPlayback;

  bool _keepScreenOn = true;
  bool get keepScreenOn => _keepScreenOn;

  int _timerDurationMinutes = 0;
  int get timerDurationMinutes => _timerDurationMinutes;

  bool _isTrainingSessionActive = false;
  bool get isTrainingSessionActive => _isTrainingSessionActive;

  int _trainingStartBpm = 60;
  int get trainingStartBpm => _trainingStartBpm;

  int _trainingEndBpm = 120;
  int get trainingEndBpm => _trainingEndBpm;

  int _trainingBpmIncrement = 5;
  int get trainingBpmIncrement => _trainingBpmIncrement;

  int _trainingIntervalSeconds = 60;
  int get trainingIntervalSeconds => _trainingIntervalSeconds;

  int _trainingRepetitions = 1;
  int get trainingRepetitions => _trainingRepetitions;

  double _uiScale = 1.0;
  double get uiScale => _uiScale;

  // ─────────────────────────────────────────────────────
  //  Persistence
  // ─────────────────────────────────────────────────────

  /// Loads all settings from SharedPreferences.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedSound = prefs.getString(_prefKeySound) ?? 'Default';
    _selectedSound = availableSounds.contains(savedSound) ? savedSound : 'Default';
    _randomSilencePercentage = prefs.getDouble(_prefKeySilence) ?? 0.0;
    _backgroundPlayback = prefs.getBool(_prefKeyBackground) ?? true;
    _keepScreenOn = prefs.getBool(_prefKeyScreenOn) ?? true;
    _timerDurationMinutes = prefs.getInt(_prefKeyTimer) ?? 0;
    _isTrainingSessionActive = prefs.getBool(_prefKeyTrainingActive) ?? false;
    _trainingStartBpm = prefs.getInt(_prefKeyTrainingStartBpm) ?? 60;
    _trainingEndBpm = prefs.getInt(_prefKeyTrainingEndBpm) ?? 120;
    _trainingBpmIncrement = prefs.getInt(_prefKeyTrainingIncrement) ?? 5;
    _trainingIntervalSeconds = prefs.getInt(_prefKeyTrainingInterval) ?? 60;
    _trainingRepetitions = prefs.getInt(_prefKeyTrainingRepetitions) ?? 1;
    _uiScale = prefs.getDouble(_prefKeyUiScale) ?? 1.0;

    if (_keepScreenOn) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    notifyListeners();
  }

  /// Saves all settings to SharedPreferences.
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeySound, _selectedSound);
    await prefs.setDouble(_prefKeySilence, _randomSilencePercentage);
    await prefs.setBool(_prefKeyBackground, _backgroundPlayback);
    await prefs.setBool(_prefKeyScreenOn, _keepScreenOn);
    await prefs.setInt(_prefKeyTimer, _timerDurationMinutes);
    await prefs.setBool(_prefKeyTrainingActive, _isTrainingSessionActive);
    await prefs.setInt(_prefKeyTrainingStartBpm, _trainingStartBpm);
    await prefs.setInt(_prefKeyTrainingEndBpm, _trainingEndBpm);
    await prefs.setInt(_prefKeyTrainingIncrement, _trainingBpmIncrement);
    await prefs.setInt(_prefKeyTrainingInterval, _trainingIntervalSeconds);
    await prefs.setInt(_prefKeyTrainingRepetitions, _trainingRepetitions);
    await prefs.setDouble(_prefKeyUiScale, _uiScale);
  }

  // ─────────────────────────────────────────────────────
  //  Mutators (with auto-save)
  // ─────────────────────────────────────────────────────

  void updateSound(String sound) {
    _selectedSound = sound;
    notifyListeners();
    _saveSettings();
  }

  void updateSilence(double percent) {
    _randomSilencePercentage = percent.clamp(0.0, 100.0);
    notifyListeners();
    _saveSettings();
  }

  void toggleBackgroundPlayback(bool value) {
    _backgroundPlayback = value;
    notifyListeners();
    _saveSettings();
  }

  void toggleKeepScreenOn(bool value) {
    _keepScreenOn = value;
    notifyListeners();
    WakelockPlus.toggle(enable: value);
    _saveSettings();
  }

  void updateTimer(int minutes) {
    _timerDurationMinutes = minutes.clamp(0, 480);
    notifyListeners();
    _saveSettings();
  }

  void toggleTrainingSession(bool value) {
    _isTrainingSessionActive = value;
    notifyListeners();
    _saveSettings();
  }

  void updateTrainingBpm(int start, int end) {
    _trainingStartBpm = start.clamp(20, 400);
    _trainingEndBpm = end.clamp(20, 400);
    notifyListeners();
    _saveSettings();
  }

  void updateTrainingIncrement(int increment) {
    _trainingBpmIncrement = increment.clamp(1, 50);
    notifyListeners();
    _saveSettings();
  }

  void updateTrainingInterval(int seconds) {
    _trainingIntervalSeconds = seconds.clamp(5, 600);
    notifyListeners();
    _saveSettings();
  }

  void updateTrainingRepetitions(int repetitions) {
    _trainingRepetitions = repetitions.clamp(1, 100);
    notifyListeners();
    _saveSettings();
  }

  void updateUiScale(double scale) {
    _uiScale = scale.clamp(0.8, 1.5);
    notifyListeners();
    _saveSettings();
  }

  // ─────────────────────────────────────────────────────
  //  Permission Cache — Offline Access
  // ─────────────────────────────────────────────────────

  static const String _keyPermHasAccess = 'perm_has_access';
  static const String _keyPermHasProfile = 'perm_has_profile';
  static const String _keyPermRol = 'perm_rol';
  static const String _keyPermTrialActive = 'perm_trial_active';
  static const String _keyPermTrialDaysLeft = 'perm_trial_days_left';
  static const String _keyPermTrialExpired = 'perm_trial_expired';
  static const String _keyPermTrialUsed = 'perm_trial_used';
  static const String _keyPermLastVerified = 'perm_last_verified';

  /// Save the result of a successful Firestore permission check.
  Future<void> savePermissionCache({
    required bool hasAccess,
    required bool hasProfile,
    required String rol,
    required bool trialActive,
    required int trialDaysLeft,
    required bool trialExpired,
    required bool trialUsed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPermHasAccess, hasAccess);
    await prefs.setBool(_keyPermHasProfile, hasProfile);
    await prefs.setString(_keyPermRol, rol);
    await prefs.setBool(_keyPermTrialActive, trialActive);
    await prefs.setInt(_keyPermTrialDaysLeft, trialDaysLeft);
    await prefs.setBool(_keyPermTrialExpired, trialExpired);
    await prefs.setBool(_keyPermTrialUsed, trialUsed);
    await prefs.setString(
      _keyPermLastVerified,
      DateTime.now().toIso8601String(),
    );
  }

  /// Load the cached permission state. Returns null if no cache exists.
  Future<PermissionCache?> loadPermissionCacheAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVerifiedStr = prefs.getString(_keyPermLastVerified);
    if (lastVerifiedStr == null) return null;

    return PermissionCache(
      hasAccess: prefs.getBool(_keyPermHasAccess) ?? false,
      hasProfile: prefs.getBool(_keyPermHasProfile) ?? false,
      rol: prefs.getString(_keyPermRol) ?? 'pendiente',
      trialActive: prefs.getBool(_keyPermTrialActive) ?? false,
      trialDaysLeft: prefs.getInt(_keyPermTrialDaysLeft) ?? 0,
      trialExpired: prefs.getBool(_keyPermTrialExpired) ?? false,
      trialUsed: prefs.getBool(_keyPermTrialUsed) ?? false,
      lastVerified: DateTime.parse(lastVerifiedStr),
    );
  }

  /// Clear the permission cache (used on logout).
  Future<void> clearPermissionCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPermHasAccess);
    await prefs.remove(_keyPermHasProfile);
    await prefs.remove(_keyPermRol);
    await prefs.remove(_keyPermTrialActive);
    await prefs.remove(_keyPermTrialDaysLeft);
    await prefs.remove(_keyPermTrialExpired);
    await prefs.remove(_keyPermTrialUsed);
    await prefs.remove(_keyPermLastVerified);
  }
}
