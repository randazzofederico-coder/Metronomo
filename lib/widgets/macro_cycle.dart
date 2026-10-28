import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/theme/beat_colors.dart';

/// "CICLO MACRO": all patterns laid out over their least common cycle, with a
/// playhead. Only the playhead rebuilds at 60fps (via a [ValueNotifier]); the
/// cell matrix rebuilds when the metronome notifies changes.
class MacroCycle extends StatefulWidget {
  final MetronomeProvider metronome;

  /// Adds the editing gestures to the legend (tap / hold on cells).
  final bool showEditHints;

  const MacroCycle({super.key, required this.metronome, this.showEditHints = false});

  @override
  State<MacroCycle> createState() => _MacroCycleState();
}

class _MacroCycleState extends State<MacroCycle> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0.0);
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final newProgress = widget.metronome.currentMacroProgress;
      if (_progress.value != newProgress) _progress.value = newProgress;
      // Auto-stop ticker when playback stops (and snap the playhead).
      if (!widget.metronome.isPlaying) {
        _ticker.stop();
        _wasPlaying = false;
        _progress.value = widget.metronome.currentMacroProgress;
      }
    });
    if (widget.metronome.isPlaying) {
      _ticker.start();
      _wasPlaying = true;
    }
    widget.metronome.addListener(_onMetronomeChanged);
  }

  @override
  void didUpdateWidget(covariant MacroCycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metronome != widget.metronome) {
      oldWidget.metronome.removeListener(_onMetronomeChanged);
      widget.metronome.addListener(_onMetronomeChanged);
    }
  }

  void _onMetronomeChanged() {
    final isPlaying = widget.metronome.isPlaying;
    if (isPlaying && !_wasPlaying) {
      if (!_ticker.isActive) _ticker.start();
      _wasPlaying = true;
    } else if (!isPlaying && _wasPlaying) {
      if (_ticker.isActive) _ticker.stop();
      _wasPlaying = false;
      _progress.value = widget.metronome.currentMacroProgress;
    }
    // Rebuild the cell matrix only when instances/structure change (not per tick).
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.metronome.removeListener(_onMetronomeChanged);
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metronome = widget.metronome;
    if (metronome.instances.isEmpty) return const SizedBox.shrink();

    final int macroBeats = metronome.macroCycleBeats;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("CICLO MACRO",
                    style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10, letterSpacing: 2.0, fontWeight: FontWeight.bold)),
                Text("$macroBeats Pulsos",
                    style: TextStyle(color: AppColors.primary(context), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: metronome.instances
                          .map((instance) => _buildInstanceRow(context, instance, macroBeats))
                          .toList(),
                    ),
                    // Playhead — ONLY this rebuilds at 60fps.
                    ValueListenableBuilder<double>(
                      valueListenable: _progress,
                      builder: (context, progress, child) => Positioned(
                        left: constraints.maxWidth * progress,
                        top: -4,
                        bottom: 0,
                        child: child!,
                      ),
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: kIsWeb
                              ? null
                              : [BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 2),
            _BeatLegend(showEditHints: widget.showEditHints),
          ],
        ),
      ),
    );
  }

  /// One row: the instance's pattern repeated as many times as it fits in
  /// [macroBeats].
  Widget _buildInstanceRow(BuildContext context, HomeMetronomeInstance instance, int macroBeats) {
    double cycleDuration = 0.0;
    for (final p in instance.pulses) {
      cycleDuration += p.durationRatio;
    }
    if (cycleDuration <= 0) cycleDuration = instance.pulses.length.toDouble();
    final int repeats = (macroBeats / cycleDuration).round().clamp(1, 100);

    final cells = <Widget>[];
    for (int r = 0; r < repeats; r++) {
      for (final pulse in instance.pulses) {
        cells.add(
          Expanded(
            flex: (pulse.durationRatio * 100).round().clamp(1, 10000),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(pulse.subdivisions.length, (subIndex) {
                  final int type = pulse.subdivisions[subIndex];
                  final bool isHead = subIndex == 0;
                  final Color color = type == 0 ? AppColors.background(context) : BeatColors.of(context, type);
                  final Color edge = type == 0 ? AppColors.border(context) : color.withOpacity(0.8);
                  const transparent = BorderSide(color: Colors.transparent, width: 1);

                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(top: isHead ? 0 : 3),
                      decoration: BoxDecoration(
                        color: type == 0 ? color : AppColors.eventFill(color, pulse.volumeAt(subIndex), 0.4),
                        border: Border(
                          right: subIndex < pulse.subdivisions.length - 1
                              ? BorderSide(color: AppColors.background(context), width: 1.0)
                              : BorderSide(color: edge, width: 1),
                          top: isHead ? BorderSide(color: edge, width: 1) : transparent,
                          bottom: BorderSide(color: edge, width: 1),
                          left: isHead ? BorderSide(color: edge, width: 1) : transparent,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      height: 16,
      child: Row(children: cells),
    );
  }
}

/// Legend of the event types (color = type) plus, optionally, the gestures
/// that edit the cells — they're otherwise undiscoverable.
class _BeatLegend extends StatelessWidget {
  final bool showEditHints;

  const _BeatLegend({required this.showEditHints});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: AppColors.textSecondary(context), fontSize: 10);
    Widget swatch(int type, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: type == BeatColors.silence ? AppColors.background(context) : BeatColors.of(context, type).withOpacity(0.6),
                border: Border.all(
                  color: type == BeatColors.silence ? AppColors.border(context) : BeatColors.of(context, type),
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: style),
          ],
        );

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        swatch(BeatColors.accent, 'Acento'),
        swatch(BeatColors.normal, 'Normal'),
        swatch(BeatColors.soft, 'Suave'),
        swatch(BeatColors.silence, 'Silencio'),
        if (showEditHints)
          Text('· Tocá una celda para cambiarla · Mantené y arrastrá para el volumen', style: style),
      ],
    );
  }
}