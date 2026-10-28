import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Conditional imports for web-only reload logic
import 'version_check_stub.dart'
    if (dart.library.js_interop) 'version_check_web.dart';

/// Result of a version check.
class VersionCheckResult {
  final bool updateRequired;
  final String currentVersion;
  final String minVersion;
  final String? updateMessage;

  const VersionCheckResult({
    required this.updateRequired,
    required this.currentVersion,
    required this.minVersion,
    this.updateMessage,
  });
}

/// Cross-platform service that checks whether the app is running the minimum
/// required version. Version info is fetched from Firebase Remote Config.
///
/// On web, if an update is needed the page is automatically reloaded so the
/// browser downloads the latest build. On mobile, a blocking screen is shown
/// directing the user to the appropriate store.
class VersionCheckService {
  static final VersionCheckService _instance = VersionCheckService._();
  factory VersionCheckService() => _instance;
  VersionCheckService._();

  late final FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;

  /// Initialize Remote Config with sensible defaults.
  Future<void> initialize() async {
    if (_initialized) return;

    _remoteConfig = FirebaseRemoteConfig.instance;

    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      // In production the minimum interval prevents excessive fetches.
      // During development you can lower this.
      minimumFetchInterval: const Duration(hours: 1),
    ));

    // Default values (used when Remote Config has no server value yet).
    await _remoteConfig.setDefaults(const {
      'metronomo_min_version': '1.0.0',
      'metronomo_force_update_message': '',
    });

    _initialized = true;
  }

  /// Fetch the latest config from Firebase and compare versions.
  ///
  /// Returns a [VersionCheckResult] indicating whether an update is required.
  /// Failures are swallowed – if we can't reach Remote Config we assume the
  /// current version is fine (so the app doesn't break offline).
  Future<VersionCheckResult> checkForUpdate() async {
    if (!_initialized) await initialize();

    // Current app version from pubspec.yaml (embedded at build time).
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version; // e.g. "1.3.0"

    try {
      // Fetch & activate remote values.
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      // Network error, timeout, etc. — don't block the user.
      debugPrint('VersionCheckService: Remote Config fetch failed: $e');
      return VersionCheckResult(
        updateRequired: false,
        currentVersion: currentVersion,
        minVersion: _remoteConfig.getString('metronomo_min_version'),
      );
    }

    final minVersion = _remoteConfig.getString('metronomo_min_version');
    final forceMessage = _remoteConfig.getString('metronomo_force_update_message');

    final needsUpdate = _isVersionLessThan(currentVersion, minVersion);

    return VersionCheckResult(
      updateRequired: needsUpdate,
      currentVersion: currentVersion,
      minVersion: minVersion,
      updateMessage: forceMessage.isNotEmpty ? forceMessage : null,
    );
  }

  /// Semantic version comparison: returns `true` when [current] < [minimum].
  bool _isVersionLessThan(String current, String minimum) {
    final currentParts = _parseVersion(current);
    final minimumParts = _parseVersion(minimum);

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < minimumParts[i]) return true;
      if (currentParts[i] > minimumParts[i]) return false;
    }
    return false; // equal
  }

  /// Parse "major.minor.patch" into a 3-element list.
  List<int> _parseVersion(String version) {
    final parts = version.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.sublist(0, 3);
  }

  // ─────────────────────────────────────────────────────
  //  Platform-specific update triggers
  // ─────────────────────────────────────────────────────

  /// On web: clears caches and reloads the page so the browser fetches the
  /// latest build.  On other platforms this is a no-op (the update screen
  /// handles redirection to the store).
  Future<void> triggerWebUpdate() async {
    if (kIsWeb) {
      await performWebReload();
    }
  }
}
