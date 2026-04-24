import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/providers/settings_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/widgets/knob_control.dart';

class PlaylistPlayerScreen extends StatefulWidget {
  final String playlistId;
  const PlaylistPlayerScreen({super.key, required this.playlistId});

  @override
  State<PlaylistPlayerScreen> createState() => _PlaylistPlayerScreenState();
}

class _PlaylistPlayerScreenState extends State<PlaylistPlayerScreen> {
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

  int _sliderToBpm(double val) {
    if (val <= 0.15) return (1 + 29 * (val / 0.15)).round();
    if (val <= 0.85) return (30 + 220 * ((val - 0.15) / 0.70)).round();
    return (250 + 749 * ((val - 0.85) / 0.15)).round();
  }

  double _bpmToSlider(int bpm) {
    if (bpm <= 30) return 0.15 * ((bpm - 1) / 29.0);
    if (bpm <= 250) return 0.15 + 0.70 * ((bpm - 30) / 220.0);
    return 0.85 + 0.15 * ((bpm - 250) / 749.0);
  }

  Color _getColorForType(BuildContext context, int type) {
    switch (type) {
      case 1: return AppColors.accentRed(context);
      case 2: return AppColors.accentCyan(context);
      case 3: return AppColors.accentGreen(context);
      default: return AppColors.surfaceHighlight(context);
    }
  }

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
                  color: _editMode ? AppColors.accentCyan(context) : AppColors.textSecondary(context),
                ),
                Switch(
                  value: _editMode,
                  onChanged: (v) => setState(() => _editMode = v),
                  activeColor: AppColors.accentCyan(context),
                  inactiveThumbColor: AppColors.textSecondary(context),
                  inactiveTrackColor: AppColors.border(context),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Session position indicator
              _buildPositionIndicator(context, totalSessions),
              // Main content with swipe
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: totalSessions,
                  onPageChanged: (page) async {
                    context.read<MetronomeProvider>().stop();
                    await _loadSession(page);
                  },
                  itemBuilder: (context, index) {
                    return _buildSessionPage(context);
                  },
                ),
              ),
              // Bottom controls
              _buildBottomControls(context),
            ],
          ),
        ),
      ),
    );
  }

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
              color: isActive ? AppColors.accentCyan(context) : AppColors.border(context),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSessionPage(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, metronome, _) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          children: [
            // Macro cycle visualizer
            _PlayerMacroCycle(metronome: metronome),
            const SizedBox(height: 8),
            // Pattern instances
            ...metronome.instances.map((instance) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildReadOnlyInstance(context, instance, metronome),
            )),
          ],
        );
      },
    );
  }

  Widget _buildReadOnlyInstance(BuildContext context, HomeMetronomeInstance instance, MetronomeProvider metronome) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + structure
            Row(
              children: [
                Expanded(
                  child: Text(
                    instance.title,
                    style: TextStyle(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontStyle: instance.isDirty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                if (instance.isDirty)
                  Text(" *", style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background(context).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border(context).withOpacity(0.5)),
                  ),
                  child: Text(
                    instance.structure,
                    style: TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Sequencer cells
            _buildSequencerCells(context, instance),
            const SizedBox(height: 6),
            // Controls row (visible but only interactive in edit mode)
            _buildInstanceControls(context, instance, metronome),
          ],
        ),
      ),
    );
  }

  Widget _buildSequencerCells(BuildContext context, HomeMetronomeInstance instance) {
    return LayoutBuilder(builder: (context, constraints) {
      int items = instance.pulses.length;
      int rows = 1;
      if (items > 0 && constraints.maxWidth / items < 45.0) rows = 2;
      if (items > 16) rows = 3;
      int itemsPerRow = (items / rows).ceil();

      List<Widget> rowWidgets = [];
      for (int r = 0; r < rows; r++) {
        int start = r * itemsPerRow;
        int end = (start + itemsPerRow).clamp(0, items);
        if (start >= items) break;

        List<Widget> cells = [];
        for (int i = start; i < end; i++) {
          final pulse = instance.pulses[i];
          cells.add(Expanded(
            flex: (pulse.durationRatio * 100).round().clamp(1, 10000),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              height: rows == 1 ? 42 : 36,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border(context), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(pulse.subdivisions.length, (subIndex) {
                    int type = pulse.subdivisions[subIndex];
                    bool isHead = subIndex == 0;
                    return Expanded(child: Container(
                      margin: EdgeInsets.only(top: isHead ? 0 : 8),
                      decoration: BoxDecoration(
                        color: type == 0 ? AppColors.background(context) : _getColorForType(context, type).withOpacity(0.2),
                        border: Border(
                          right: subIndex < pulse.subdivisions.length - 1
                              ? BorderSide(color: AppColors.background(context), width: 3)
                              : BorderSide.none,
                          top: isHead ? BorderSide.none : BorderSide(color: AppColors.border(context).withOpacity(0.5), width: 1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: subIndex == 0
                          ? Text('${i + 1}', style: TextStyle(
                              color: type == 0 ? AppColors.textSecondary(context) : AppColors.textPrimary(context),
                              fontWeight: FontWeight.bold, fontSize: rows == 1 ? 16 : 12))
                          : null,
                    ));
                  }),
                ),
              ),
            ),
          ));
        }
        while (cells.length < itemsPerRow) cells.add(const Expanded(child: SizedBox.shrink()));
        rowWidgets.add(Row(children: cells));
      }
      return Column(children: rowWidgets);
    });
  }

  Widget _buildInstanceControls(BuildContext context, HomeMetronomeInstance instance, MetronomeProvider metronome) {
    final opacity = _editMode ? 1.0 : 0.5;
    return Opacity(
      opacity: opacity,
      child: IgnorePointer(
        ignoring: !_editMode,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 36,
              child: KnobControl(
                value: instance.volume,
                onChanged: (v) => metronome.updateInstanceVolume(instance.id, v),
                min: 0, max: 1, label: 'VOL',
                labelColor: instance.volume > 0 ? AppColors.accentGreen(context) : AppColors.accentRed(context),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => metronome.toggleInstanceMute(instance.id),
              child: Container(
                width: 32, height: 26,
                decoration: BoxDecoration(
                  color: instance.isMuted ? AppColors.accentRed(context) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border(context)),
                ),
                alignment: Alignment.center,
                child: Text('M', style: TextStyle(color: instance.isMuted ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => metronome.toggleInstanceSolo(instance.id),
              child: Container(
                width: 32, height: 26,
                decoration: BoxDecoration(
                  color: instance.isSolo ? AppColors.accentCyan(context) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border(context)),
                ),
                alignment: Alignment.center,
                child: Text('S', style: TextStyle(color: instance.isSolo ? Colors.black : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Consumer<MetronomeProvider>(
      builder: (context, metronome, _) {
        final isPlaying = metronome.isPlaying;
        final currentBpm = metronome.bpm;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border(top: BorderSide(color: AppColors.border(context))),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -4))],
            ),
            child: Row(
              children: [
                // Play/Stop
                GestureDetector(
                  onTap: () => metronome.togglePlay(),
                  child: Container(
                    height: 48, width: 48,
                    decoration: BoxDecoration(
                      color: isPlaying ? AppColors.accentRed(context) : AppColors.accentCyan(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 28),
                  ),
                ),
                // BPM display
                Expanded(
                  child: IgnorePointer(
                    ignoring: !_editMode,
                    child: Opacity(
                      opacity: _editMode ? 1.0 : 0.7,
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _bpmButton(context, "-5", () => metronome.updateBPM(currentBpm - 5)),
                                _bpmButton(context, "-1", () => metronome.updateBPM(currentBpm - 1)),
                                Container(
                                  width: 80, alignment: Alignment.center,
                                  child: Text("$currentBpm", style: TextStyle(
                                    color: AppColors.textPrimary(context), fontSize: 36, fontWeight: FontWeight.bold)),
                                ),
                                _bpmButton(context, "+1", () => metronome.updateBPM(currentBpm + 1)),
                                _bpmButton(context, "+5", () => metronome.updateBPM(currentBpm + 5)),
                              ],
                            ),
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              activeTrackColor: AppColors.accentCyan(context),
                              inactiveTrackColor: AppColors.border(context),
                              thumbColor: AppColors.accentCyan(context),
                              overlayColor: AppColors.accentCyan(context).withOpacity(0.2),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            ),
                            child: Slider(
                              value: _bpmToSlider(currentBpm).clamp(0.0, 1.0),
                              onChanged: (val) => metronome.updateBPM(_sliderToBpm(val)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Swipe hint
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe, color: AppColors.textSecondary(context).withOpacity(0.5), size: 20),
                    Text("${_currentPage + 1}/${context.read<PlaylistProvider>().getPlaylistById(widget.playlistId)?.sessionIds.length ?? 0}",
                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bpmButton(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16, fontWeight: FontWeight.bold)),
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

  _SavedInstance({
    required this.title, required this.structure, required this.pulses,
    required this.volume, required this.isMuted, required this.isSolo,
    this.originalPatternId, required this.isDirty,
  });
}

// Macro cycle visualizer for the player (reused pattern from metronome_screen)
class _PlayerMacroCycle extends StatefulWidget {
  final MetronomeProvider metronome;
  const _PlayerMacroCycle({required this.metronome});

  @override
  State<_PlayerMacroCycle> createState() => _PlayerMacroCycleState();
}

class _PlayerMacroCycleState extends State<_PlayerMacroCycle> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final ValueNotifier<double> _progress = ValueNotifier(0.0);
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final p = widget.metronome.currentMacroProgress;
      if (_progress.value != p) _progress.value = p;
      if (!widget.metronome.isPlaying) {
        _ticker.stop();
        _wasPlaying = false;
        _progress.value = widget.metronome.currentMacroProgress;
      }
    });
    if (widget.metronome.isPlaying) { _ticker.start(); _wasPlaying = true; }
    widget.metronome.addListener(_onChanged);
  }

  void _onChanged() {
    if (widget.metronome.isPlaying && !_wasPlaying) {
      if (!_ticker.isActive) _ticker.start();
      _wasPlaying = true;
    } else if (!widget.metronome.isPlaying && _wasPlaying) {
      if (_ticker.isActive) _ticker.stop();
      _wasPlaying = false;
      _progress.value = widget.metronome.currentMacroProgress;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.metronome.removeListener(_onChanged);
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  Color _colorForType(BuildContext ctx, int t) {
    switch (t) { case 1: return AppColors.accentRed(ctx); case 2: return AppColors.accentCyan(ctx); case 3: return AppColors.accentGreen(ctx); default: return AppColors.surfaceHighlight(ctx); }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.metronome.instances.isEmpty) return const SizedBox.shrink();
    int macroBeats = widget.metronome.macroCycleBeats;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border(context))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("CICLO MACRO", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10, letterSpacing: 2.0, fontWeight: FontWeight.bold)),
            Text("$macroBeats Pulsos", style: TextStyle(color: AppColors.accentCyan(context), fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            return Stack(clipBehavior: Clip.none, children: [
              Column(children: widget.metronome.instances.map((instance) {
                double cycleDur = 0.0;
                for (var p in instance.pulses) cycleDur += p.durationRatio;
                if (cycleDur <= 0) cycleDur = instance.pulses.length.toDouble();
                int repeats = (macroBeats / cycleDur).round().clamp(1, 100);
                List<Widget> cells = [];
                for (int r = 0; r < repeats; r++) {
                  for (var pulse in instance.pulses) {
                    cells.add(Expanded(
                      flex: (pulse.durationRatio * 100).round().clamp(1, 10000),
                      child: Container(margin: const EdgeInsets.symmetric(horizontal: 1), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(pulse.subdivisions.length, (si) {
                        int type = pulse.subdivisions[si];
                        bool isHead = si == 0;
                        Color color = type == 0 ? AppColors.background(context) : _colorForType(context, type);
                        return Expanded(child: Container(
                          margin: EdgeInsets.only(top: isHead ? 0 : 3),
                          decoration: BoxDecoration(
                            color: type == 0 ? color : color.withOpacity(0.4),
                            border: Border(
                              right: si < pulse.subdivisions.length - 1 ? BorderSide(color: AppColors.background(context), width: 1.0) : BorderSide(color: type == 0 ? AppColors.border(context) : color.withOpacity(0.8), width: 1),
                              top: isHead ? BorderSide(color: type == 0 ? AppColors.border(context) : color.withOpacity(0.8), width: 1) : const BorderSide(color: Colors.transparent, width: 1),
                              bottom: BorderSide(color: type == 0 ? AppColors.border(context) : color.withOpacity(0.8), width: 1),
                              left: isHead ? BorderSide(color: type == 0 ? AppColors.border(context) : color.withOpacity(0.8), width: 1) : const BorderSide(color: Colors.transparent, width: 1),
                            ),
                          ),
                        ));
                      }))),
                    ));
                  }
                }
                return Container(margin: const EdgeInsets.only(bottom: 6), height: 16, child: Row(children: cells));
              }).toList()),
              ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (ctx, progress, child) => Positioned(left: constraints.maxWidth * progress, top: -4, bottom: 0, child: child!),
                child: Container(width: 2, decoration: BoxDecoration(color: Colors.white, boxShadow: kIsWeb ? null : [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)])),
              ),
            ]);
          }),
        ]),
      ),
    );
  }
}
