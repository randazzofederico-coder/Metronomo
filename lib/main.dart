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
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MetronomeProvider()),
        ChangeNotifierProvider(create: (_) {
          final provider = SettingsProvider();
          provider.loadSettings();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
          final provider = PatternEditorProvider();
          provider.loadPatterns();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
          final provider = SessionProvider();
          provider.loadSessions();
          return provider;
        }),
        ChangeNotifierProvider(create: (context) {
          final provider = PlaylistProvider();
          // Legacy playlists (session references) are migrated to embedded
          // sessions: the session and pattern libraries must be loaded first.
          final sessions = context.read<SessionProvider>();
          final patterns = context.read<PatternEditorProvider>();
          provider.loadPlaylists(resolveSession: (id) async {
            await sessions.ensureLoaded;
            await patterns.ensureLoaded;
            return sessions.getSessionById(id)?.withEmbeddedPatterns(patterns.getPatternById);
          });
          return provider;
        }),
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
