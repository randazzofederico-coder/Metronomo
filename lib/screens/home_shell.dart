import 'package:flutter/material.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/screens/library_screen.dart';
import 'package:metronomo_standalone/screens/metronome_screen.dart';
import 'package:metronomo_standalone/screens/settings_screen.dart';

/// App shell: Tocar · Biblioteca · Ajustes.
///
/// Bottom [NavigationBar] on phones, [NavigationRail] from [railBreakpoint].
/// Tabs live in an [IndexedStack] so "Tocar" keeps its state (and keeps
/// handling shared links / lifecycle) while another tab is shown.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static const double railBreakpoint = 900;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const int _play = 0;
  static const int _library = 1;

  int _index = _play;
  final _metronomeKey = GlobalKey<MetronomeScreenState>();
  final _libraryKey = GlobalKey<LibraryScreenState>();

  void _select(int index) {
    if (index == _index) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _index = index);
  }

  void _openLibrarySessions() {
    _select(_library);
    _libraryKey.currentState?.showTab(0);
  }

  Future<void> _openSession(Session session) async {
    final opened = await _metronomeKey.currentState?.openSession(session) ?? false;
    if (opened && mounted) _select(_play);
  }

  void _addPattern(Pattern pattern) {
    _select(_play);
    _metronomeKey.currentState?.addPatternFromLibrary(pattern);
  }

  Future<void> _newSession() async {
    _select(_play);
    await _metronomeKey.currentState?.newSession();
  }

  static const _destinations = [
    (icon: Icons.graphic_eq_outlined, selected: Icons.graphic_eq_rounded, label: 'Tocar'),
    (icon: Icons.library_music_outlined, selected: Icons.library_music_rounded, label: 'Biblioteca'),
    (icon: Icons.settings_outlined, selected: Icons.settings_rounded, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final body = IndexedStack(
      index: _index,
      children: [
        MetronomeScreen(
          key: _metronomeKey,
          onOpenLibrary: _openLibrarySessions,
          onShowRequested: () => _select(_play),
        ),
        LibraryScreen(
          key: _libraryKey,
          onOpenSession: _openSession,
          onAddPattern: _addPattern,
          onNewSession: _newSession,
        ),
        const SettingsScreen(),
      ],
    );

    final wide = MediaQuery.sizeOf(context).width >= HomeShell.railBreakpoint;

    return PopScope(
      // Android back: from another tab, go back to "Tocar" instead of exiting.
      canPop: _index == _play,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(_play);
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: AppColors.surface(context),
                    indicatorColor: AppColors.primary(context).withOpacity(0.2),
                    selectedIconTheme: IconThemeData(color: AppColors.primary(context)),
                    unselectedIconTheme: IconThemeData(color: AppColors.textSecondary(context)),
                    selectedLabelTextStyle: TextStyle(color: AppColors.primary(context), fontWeight: FontWeight.bold),
                    unselectedLabelTextStyle: TextStyle(color: AppColors.textSecondary(context)),
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selected),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                  VerticalDivider(width: 1, color: AppColors.border(context)),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: _select,
                height: 64,
                backgroundColor: AppColors.surface(context),
                indicatorColor: AppColors.primary(context).withOpacity(0.2),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final d in _destinations)
                    NavigationDestination(
                      icon: Icon(d.icon, color: AppColors.textSecondary(context)),
                      selectedIcon: Icon(d.selected, color: AppColors.primary(context)),
                      label: d.label,
                    ),
                ],
              ),
      ),
    );
  }
}
