import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:metronomo_standalone/firebase_options.dart';
import 'package:metronomo_standalone/services/pwa_install_service.dart';
import 'package:metronomo_standalone/services/deep_link_service.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/providers/settings_provider.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/screens/metronome_screen.dart';
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
        ChangeNotifierProvider(create: (_) {
          final provider = PlaylistProvider();
          provider.loadPlaylists();
          return provider;
        }),
      ],
      child: MaterialApp(
        title: 'Metrónomo',
        themeMode: ThemeMode.dark,
        darkTheme: AppTheme.dark,
        home: const MetronomeScreen(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final settings = context.watch<SettingsProvider>();
          final data = MediaQuery.of(context);
          return MediaQuery(
            data: data.copyWith(
              textScaler: TextScaler.linear(settings.uiScale),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
