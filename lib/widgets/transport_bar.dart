import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LengthLimitingTextInputFormatter;
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/utils/bpm_scale.dart';

/// Fixed bottom bar: Play/Stop, BPM display with ±1/±5 steppers and tempo
/// slider, and a [trailing] slot (TAP button, playlist navigation...).
class TransportBar extends StatelessWidget {
  final bool isPlaying;
  final int bpm;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onBpmChanged;

  /// When false the BPM controls are dimmed and ignore input (read-only mode).
  final bool bpmEnabled;
  final Widget? trailing;

  const TransportBar({
    super.key,
    required this.isPlaying,
    required this.bpm,
    required this.onTogglePlay,
    required this.onBpmChanged,
    this.bpmEnabled = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      // Precision control: excluded from the global UI scale.
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          border: Border(top: BorderSide(color: AppColors.border(context))),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            PlayStopButton(isPlaying: isPlaying, onTap: onTogglePlay),
            Expanded(
              child: IgnorePointer(
                ignoring: !bpmEnabled,
                child: Opacity(
                  opacity: bpmEnabled ? 1.0 : 0.7,
                  child: _buildBpmControls(context),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }

  Widget _buildBpmControls(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepper(context, -5),
              _stepper(context, -1),
              Tooltip(
                message: 'Tocá para escribir el tempo',
                child: Semantics(
                  button: true,
                  label: 'Tempo $bpm BPM. Tocá para escribirlo',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _editBpm(context),
                    child: Container(
                      width: 80,
                      alignment: Alignment.center,
                      child: Text(
                        "$bpm",
                        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              _stepper(context, 1),
              _stepper(context, 5),
            ],
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.primary(context),
            inactiveTrackColor: AppColors.border(context),
            thumbColor: AppColors.primary(context),
            overlayColor: AppColors.primary(context).withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: BpmScale.bpmToSlider(bpm),
            onChanged: (val) => onBpmChanged(BpmScale.sliderToBpm(val)),
          ),
        ),
      ],
    );
  }

  Widget _stepper(BuildContext context, int delta) {
    return _RepeatStepButton(
      label: delta > 0 ? '+$delta' : '$delta',
      semanticLabel: '${delta > 0 ? 'Subir' : 'Bajar'} ${delta.abs()} BPM (mantené para repetir)',
      onStep: () => onBpmChanged(bpm + delta),
    );
  }

  /// Dialog to type an exact tempo.
  Future<void> _editBpm(BuildContext context) async {
    final controller = TextEditingController(text: '$bpm');
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) {
        void submit() {
          final v = int.tryParse(controller.text.trim());
          if (v == null) return;
          Navigator.pop(ctx, v.clamp(BpmScale.minBpm, BpmScale.maxBpm));
        }

        return AlertDialog(
          title: const Text('Tempo'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textPrimary(ctx), fontSize: 32, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              suffixText: 'BPM',
              helperText: '${BpmScale.minBpm}–${BpmScale.maxBpm}',
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary(ctx))),
            ),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary(ctx))),
            ),
            TextButton(
              onPressed: submit,
              child: Text('OK', style: TextStyle(color: AppColors.primary(ctx), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (value != null) onBpmChanged(value);
  }
}

/// BPM stepper: tap = one step; hold = repeats (accelerating).
/// The hit area is at least 44×44 even though the label is small.
class _RepeatStepButton extends StatefulWidget {
  final String label;
  final String semanticLabel;
  final VoidCallback onStep;

  const _RepeatStepButton({required this.label, required this.semanticLabel, required this.onStep});

  @override
  State<_RepeatStepButton> createState() => _RepeatStepButtonState();
}

class _RepeatStepButtonState extends State<_RepeatStepButton> {
  Timer? _timer;
  int _repeats = 0;

  void _startRepeat() {
    _repeats = 0;
    _schedule(const Duration(milliseconds: 350));
  }

  void _schedule(Duration delay) {
    _timer = Timer(delay, () {
      if (!mounted) return;
      widget.onStep(); // reads the latest widget (current bpm)
      _repeats++;
      _schedule(Duration(milliseconds: _repeats < 5 ? 120 : 60));
    });
  }

  void _stopRepeat() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onStep,
        onLongPressStart: (_) {
          widget.onStep();
          _startRepeat();
        },
        onLongPressEnd: (_) => _stopRepeat(),
        onLongPressCancel: _stopRepeat,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.label,
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round Play/Stop button.
class PlayStopButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const PlayStopButton({super.key, required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isPlaying ? AppColors.accentRed(context) : AppColors.primary(context);
    return Semantics(
      button: true,
      label: isPlaying ? 'Detener' : 'Reproducir',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: kIsWeb
                ? null
                : [BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Icon(isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

/// "TAP" tempo button.
class TapTempoButton extends StatelessWidget {
  final VoidCallback onTap;

  const TapTempoButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tap tempo',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceHighlight(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border(context), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, color: AppColors.textPrimary(context), size: 20),
              const SizedBox(height: 1),
              Text(
                "TAP",
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 8,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
