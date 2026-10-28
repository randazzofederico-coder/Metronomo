import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';

/// Drives a single [Ticker] while the metronome plays and exposes the
/// playback position (in beats, -1 when stopped) to its subtree.
///
/// Widgets that need the position (e.g. [SequencerGrid] highlighting) read it
/// with [PlaybackClock.of] and listen to the returned [ValueListenable], so
/// only they rebuild — never the whole screen.
class PlaybackClock extends StatefulWidget {
  final MetronomeProvider metronome;
  final Widget child;

  const PlaybackClock({super.key, required this.metronome, required this.child});

  /// Beat position notifier of the nearest clock, or null if there's none.
  static ValueListenable<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PlaybackClockScope>()?.position;

  @override
  State<PlaybackClock> createState() => _PlaybackClockState();
}

class _PlaybackClockState extends State<PlaybackClock> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _position = ValueNotifier<double>(-1);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _position.value = widget.metronome.currentBeatPosition);
    widget.metronome.addListener(_sync);
    _sync();
  }

  @override
  void didUpdateWidget(covariant PlaybackClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metronome != widget.metronome) {
      oldWidget.metronome.removeListener(_sync);
      widget.metronome.addListener(_sync);
      _sync();
    }
  }

  void _sync() {
    final playing = widget.metronome.isPlaying;
    if (playing && !_ticker.isActive) {
      _ticker.start();
    } else if (!playing && _ticker.isActive) {
      _ticker.stop();
      _position.value = -1;
    }
  }

  @override
  void dispose() {
    widget.metronome.removeListener(_sync);
    _ticker.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PlaybackClockScope(position: _position, child: widget.child);
}

class _PlaybackClockScope extends InheritedWidget {
  final ValueListenable<double> position;

  const _PlaybackClockScope({required this.position, required super.child});

  @override
  bool updateShouldNotify(_PlaybackClockScope oldWidget) => oldWidget.position != position;
}
