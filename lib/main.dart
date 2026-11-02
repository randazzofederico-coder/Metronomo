import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fede_apps_core/fede_apps_core.dart';

import 'package:metronomo_standalone/firebase_options.dart';
import 'package:metronomo_standalone/l10n/l10n.dart';
import 'package:metronomo_standalone/services/pwa_install_service.dart';
import 'package:metronomo_standalone/services/deep_link_service.dart';
import 'package:metronomo_standalone/services/metronomo_sync_adapter.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/providers/settings_provider.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/screens/home_shell.dart';
import 'package:metronomo_standalone/theme/app_theme.dart';
import 'package:metronomo_standalone/services/version_check_service.dart';
import 'package:metronomo_standalone/widgets/update_required_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize PWA install prompt capture (web only, no-op on other platforms)
  PwaInstallService().initialize();

  // Capture initial deep link BEFORE runApp to avoid timing issues with auth gate
  await DeepLinkService().captureInitialLink();

  // Lock orientation to portrait on mobile only (not supported on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // ── Version Check ──
  // Compare the running version against the minimum required version
  // stored in Firebase Remote Config. If outdated, show a blocking update
  // screen instead of the main app.
  final versionService = VersionCheckService();
  await versionService.initialize();
  final versionResult = await versionService.checkForUpdate();

  // Local usage tracking (fede_apps_core). Must never block startup.
  try {
    await UsageTracker.instance.init();
  } catch (e) {
    debugPrint('UsageTracker init failed: $e');
  }

  if (versionResult.updateRequired) {
    runApp(UpdateRequiredScreen(result: versionResult));
  } else {
    // Libraries are created here (not inside MultiProvider) so the cloud sync
    // works on the very same instances the UI uses.
    final libraries = AppLibraries.create();
    runApp(MyApp(libraries: libraries));
    // Load after the first frame: the default library items use the app
    // language (L10n.current is set by the MaterialApp builder).
    WidgetsBinding.instance.addPostFrameCallback((_) => libraries.load());
    unawaited(libraries.startSync());
  }
}

/// The three libraries (patterns, sessions, playlists) shared by the UI and
/// the cloud sync ([MetronomoSyncAdapter]).
class AppLibraries {
  AppLibraries._(this.patterns, this.sessions, this.playlists)
      : adapter = MetronomoSyncAdapter(patterns: patterns, sessions: sessions, playlists: playlists);

  final PatternEditorProvider patterns;
  final SessionProvider sessions;
  final PlaylistProvider playlists;
  final MetronomoSyncAdapter adapter;

  /// Creates the libraries (not loaded yet: see [load]).
  factory AppLibraries.create() {
    final patterns = PatternEditorProvider();
    final sessions = SessionProvider();
    // Playlists are connected to the session library before any session can
    // be deleted (they refresh their snapshot first). Hybrid playlists: items
    // resolve to the library session (source of truth) and fall back to their
    // snapshot. Legacy playlists (session references) are migrated once
    // sessions and patterns are loaded.
    final playlists = PlaylistProvider()..attachLibrary(sessions: sessions, patterns: patterns);
    return AppLibraries._(patterns, sessions, playlists);
  }

  /// Loads the libraries (and migrates legacy playlists).
  void load() {
    patterns.loadPatterns();
    sessions.loadSessions();
    playlists.loadPlaylists();
  }

  /// Starts the cloud sync once loading and migration are done (the first
  /// sync reads the libraries). Never blocks nor breaks the app.
  Future<void> startSync() async {
    try {
      await Future.wait([patterns.ensureLoaded, sessions.ensureLoaded, playlists.ensureLoaded]);
      adapter.purgeAfterSyncs(LibrarySync.instance);
      await LibrarySync.instance.configure(adapter);
    } catch (e) {
      debugPrint('LibrarySync configure failed: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.libraries});

  final AppLibraries libraries;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final metronome = MetronomeProvider();
          // A remote rename of the open session updates its title.
          libraries.adapter.onSessionRenamed = metronome.onSessionRenamed;
          return metronome;
        }),
        ChangeNotifierProvider(create: (_) {
          final provider = SettingsProvider();
          provider.loadSettings();
          return provider;
        }),
        ChangeNotifierProvider.value(value: libraries.patterns),
        ChangeNotifierProvider.value(value: libraries.sessions),
        ChangeNotifierProvider.value(value: libraries.playlists),
      ],
      child: Builder(
        builder: (context) {
          final locale = context.select<SettingsProvider, Locale?>((s) => s.locale);
          return MaterialApp(
            onGenerateTitle: (context) => context.l10n.appTitle,
            locale: locale,
            supportedLocales: kSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            localeListResolutionCallback: (deviceLocales, _) => resolveAppLocale(deviceLocales),
            themeMode: ThemeMode.dark,
            darkTheme: AppTheme.dark,
            home: const HomeShell(),
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              // Keep the context-free accessor in sync with the active locale.
              L10n.current = context.l10n;
              final settings = context.watch<SettingsProvider>();
              final data = MediaQuery.of(context);
              return MediaQuery(
                data: data.copyWith(
                  textScaler: TextScaler.linear(settings.uiScale),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
