import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:metronomo_standalone/firebase_options.dart';
import 'package:metronomo_standalone/services/pwa_install_service.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/providers/settings_provider.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize PWA install prompt capture (web only, no-op on other platforms)
  PwaInstallService().initialize();

  // Lock orientation to portrait on mobile only (not supported on web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(const MyApp());
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
      ],
      child: MaterialApp(
        title: 'Metrónomo',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1E1A17),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFF98533),
            onPrimary: Colors.white,
            secondary: Color(0xFFE55353),
            onSecondary: Colors.white,
            error: Color(0xFFD32F2F),
            onError: Colors.white,
            surface: Color(0xFF2C2621),
            onSurface: Color(0xFFF2EBE5),
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2C2621),
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Color(0xFFF2EBE5),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        home: const AuthGate(),
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
