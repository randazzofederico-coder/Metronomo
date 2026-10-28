import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/theme/beat_colors.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/providers/settings_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/widgets/formatted_structure.dart';
import 'package:metronomo_standalone/widgets/macro_cycle.dart';
import 'package:metronomo_standalone/widgets/mixer_strip.dart';
import 'package:metronomo_standalone/widgets/pattern_card.dart';
import 'package:metronomo_standalone/widgets/playback_clock.dart';
import 'package:metronomo_standalone/widgets/sequencer_grid.dart';
import 'package:metronomo_standalone/widgets/transport_bar.dart';
import 'package:metronomo_standalone/utils/space_play_shortcut.dart';

class PlaylistPlayerScreen extends StatefulWidget {
  final String playlistId;
  const PlaylistPlayerScreen({super.key, required this.playlistId});

  @override
  State<PlaylistPlayerScreen> createState() => _PlaylistPlayerScreenState();
}

class _PlaylistPlayerScreenState extends State<PlaylistPlayerScreen> with SpacePlayShortcut {
  late PageController _pageController;
  int _currentPage = 0;
  bool _editMode = false;

  // Saved state to restore on exit
  String? _savedSessionId;
  String? _savedSessionName;
  bool _savedDirty = false;
  int _savedBpm = 120;
  List<_SavedInstance> _savedInstances = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final metronome = context.read<MetronomeProvider>();
    // Save current metronome state
    _savedSessionId = metronome.activeSessionId;
    _savedSessionName = metronome.activeSessionName;
    _savedDirty = metronome.isSessionDirty;
    _savedBpm = metronome.bpm;
    _savedInstances = metronome.instances.map((i) => _SavedInstance(
      title: i.title, structure: i.structure,
      pulses: i.pulses.map((p) => p.copyWith()).toList(),
      volume: i.volume, isMuted: i.isMuted, isSolo: i.isSolo,
      originalPatternId: i.originalPatternId, isDirty: i.isDirty,
      soundSet: i.soundSet,
    )).toList();

    await _loadSession(0);
  }

  Future<void> _loadSession(int index) async {
    final playlist = context.read<PlaylistProvider>().getPlaylistById(widget.playlistId);
    if (playlist == null || index >= playlist.sessionIds.length) return;

    final sessionProvider = context.read<SessionProvider>();
    final patProvider = context.read<PatternEditorProvider>();
    final metronome = context.read<MetronomeProvider>();
    final settings = context.read<SettingsProvider>();

    final session = sessionProvider.getSessionById(playlist.sessionIds[index]);
    if (session == null) return;

    await metronome.loadSession(session, settings, getPatternById: (id) async {
      await patProvider.ensureLoaded;
      return patProvider.getPatternById(id);
    });
    metronome.play();
    if (mounted) setState(() => _currentPage = index);
  }

  void _restoreState() {
    final metronome = context.read<MetronomeProvider>();
    metronome.stop();
    metronome.clearSession();
    metronome.updateBPM(_savedBpm);

    for (var inst in _savedInstances) {
      metronome.addInstance(
        title: inst.title, structure: inst.structure,
        pulses: inst.pulses, originalPatternId: inst.originalPatternId,
        isDirty: inst.isDirty,
        soundSet: inst.soundSet,
      );
      // Restore volume/mute/solo
      final loaded = metronome.instances.last;
      if (inst.volume != loaded.volume) metronome.updateInstanceVolume(loaded.id, inst.volume);
      if (inst.isMuted != loaded.isMuted) metronome.toggleInstanceMute(loaded.id);
      if (inst.isSolo != loaded.isSolo) metronome.toggleInstanceSolo(loaded.id);
    }

    if (_savedSessionId != null) {
      metronome.markSessionClean(_savedSessionId!, _savedSessionName ?? '');
    }
    if (_savedDirty) metronome.markSessionDirty();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void onSpacePlayToggle() => context.read<MetronomeProvider>().togglePlay();

  @override
  Widget build(BuildContext context) {
    final playlist = context.watch<PlaylistProvider>().getPlaylistById(widget.playlistId);
    if (playlist == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        body: Center(child: Text("Playlist no encontrada", style: TextStyle(color: AppColors.textSecondary(context)))),
      );
    }
    final totalSessions = playlist.sessionIds.length;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          context.read<MetronomeProvider>().stop();
          _restoreState();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: AppColors.surface(context),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textSecondary(context)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Consumer<MetronomeProvider>(
            builder: (context, metronome, _) {
              final name = metronome.activeSessionName ?? playlist.name;
              final dirty = metronome.isSessionDirty;
              return Text(
                "$name${dirty ? ' *' : ''}",
                style: TextStyle(
                  letterSpacing: 1.5, fontSize: 16,
                  fontStyle: dirty ? FontStyle.italic : FontStyle.normal,
                  color: AppColors.textPrimary(context),
                ),
              );
            },
          ),
          actions: [
            // Edit mode toggle
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _editMode ? Icons.lock_open : Icons.lock_outline,
                  size: 16,
                  color: _editMode ? AppColors.primary(context) : AppColors.textSecondary(context),
                ),
                Switch(
                  value: _editMode,
                  onChanged: (v) => setState(() => _editMode = v),
                  activeColor: AppColors.primary(context),
                  inactiveThumbColor: AppColors.textSecondary(context),
                  inactiveTrackColor: AppColors.border(context),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool twoColumns = constraints.maxWidth >= _twoColumnBreakpoint;
              final pages = Column(
                children: [
                  // Session position indicator
                  _buildPositionIndicator(context, totalSessions),
                  // Main content with swipe. Swiping is disabled while playing so an
                  // accidental gesture on stage can't switch sessions and cut the
                  // audio; the arrows below still work.
                  Expanded(
                    child: Selector<MetronomeProvider, bool>(
                      selector: (_, m) => m.isPlaying,
                      builder: (context, isPlaying, _) => PageView.builder(
                        controller: _pageController,
                        physics: isPlaying ? const NeverScrollableScrollPhysics() : null,
                        itemCount: totalSessions,
                        onPageChanged: (page) async {
                          context.read<MetronomeProvider>().stop();
                          await _loadSession(page);
                        },
                        itemBuilder: (context, index) {
                          return _buildSessionPage(context, includeMacro: !twoColumns);
                        },
                      ),
                    ),
                  ),
                ],
              );

              if (!twoColumns) {
                return Column(
                  children: [
                    Expanded(child: pages),
                    // Bottom controls
                    _buildBottomControls(context),
                  ],
                );
              }

              // Wide screens: sessions on the left; macro cycle and transport
              // in a side panel (same layout as Tocar).
              final double panelWidth = (constraints.maxWidth * 0.36).clamp(340.0, 440.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: pages),
                  VerticalDivider(width: 1, color: AppColors.border(context)),
                  SizedBox(
                    width: panelWidth,
                    child: Column(
                      children: [
                        Expanded(
                          child: Consumer<MetronomeProvider>(
                            builder: (context, metronome, _) => ListView(
                              padding: const EdgeInsets.all(12),
                              children: [MacroCycle(metronome: metronome)],
                            ),
                          ),
                        ),
                        _buildBottomControls(context),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// From this width on, the player uses two columns (like Tocar).
  static const double _twoColumnBreakpoint = 840;

  Widget _buildPositionIndicator(BuildContext context, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: AppColors.surface(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final isActive = i == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: isActive ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary(context) : AppColors.border(context),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSessionPage(BuildContext context, {required bool includeMacro}) {
    return Consumer<MetronomeProvider>(
      builder: (context, metronome, _) {
        return PlaybackClock(
          metronome: metronome,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            children: [
              // Macro cycle visualizer (in the side panel on wide screens)
              if (includeMacro) ...[
                MacroCycle(metronome: metronome),
                const SizedBox(height: 8),
              ],
              // Pattern instances
              ...metronome.instances.map((instance) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildReadOnlyInstance(context, instance, metronome),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReadOnlyInstance(BuildContext context, HomeMetronomeInstance instance, MetronomeProvider metronome) {
    final index = metronome.instances.indexWhere((i) => i.id == instance.id);
    final accent = PatternColors.forIndex(index < 0 ? 0 : index);
    return PatternCard(
      accent: accent,
      title: Row(
        children: [
          Flexible(
            child: Text(
              instance.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontStyle: instance.isDirty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          if (instance.isDirty)
            Text(" *", style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
      structure: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.background(context).withOpacity(0.5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border(context).withOpacity(0.5)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: FormattedStructure(instance.structure),
        ),
      ),
      // Mixer (visible but only interactive in edit mode)
      mixer: Opacity(
        opacity: _editMode ? 1.0 : 0.5,
        child: IgnorePointer(
          ignoring: !_editMode,
          child: MixerStrip(
            volume: instance.volume,
            onVolumeChanged: (v) => metronome.updateInstanceVolume(instance.id, v),
            isMuted: instance.isMuted,
            onMuteToggle: () => metronome.toggleInstanceMute(instance.id),
            isSolo: instance.isSolo,
            onSoloToggle: () => metronome.toggleInstanceSolo(instance.id),
          ),
        ),
      ),
      sequencer: SequencerGrid(pulses: instance.pulses),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, metronome, _) {
        final total = context.read<PlaylistProvider>().getPlaylistById(widget.playlistId)?.sessionIds.length ?? 0;
        return TransportBar(
          isPlaying: metronome.isPlaying,
          bpm: metronome.bpm,
          onTogglePlay: metronome.togglePlay,
          onBpmChanged: metronome.updateBPM,
          bpmEnabled: _editMode,
          // Session navigation arrows
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _navArrow(
                context,
                icon: Icons.chevron_left,
                enabled: _currentPage > 0,
                onTap: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  "${_currentPage + 1}/$total",
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              _navArrow(
                context,
                icon: Icons.chevron_right,
                enabled: _currentPage < total - 1,
                onTap: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _navArrow(BuildContext context, {required IconData icon, required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled ? AppColors.primary(context).withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: enabled ? AppColors.primary(context) : AppColors.border(context),
            width: 1.5,
          ),
        ),
        child: Icon(icon, color: enabled ? AppColors.primary(context) : AppColors.border(context), size: 22),
      ),
    );
  }
}

class _SavedInstance {
  final String title;
  final String structure;
  final List<HomeMetronomePulse> pulses;
  final double volume;
  final bool isMuted;
  final bool isSolo;
  final String? originalPatternId;
  final bool isDirty;
  final String? soundSet;

  _SavedInstance({
    required this.title, required this.structure, required this.pulses,
    required this.volume, required this.isMuted, required this.isSolo,
    this.originalPatternId, required this.isDirty, this.soundSet,
  });
}

