import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
              Container(
                width: 80,
                alignment: Alignment.center,
                child: Text(
                  "$bpm",
                  style: TextStyle(color: AppColors.textPrimary(context), fontSize: 36, fontWeight: FontWeight.bold),
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
    final label = delta > 0 ? '+$delta' : '$delta';
    return Semantics(
      button: true,
      label: '${delta > 0 ? 'Subir' : 'Bajar'} ${delta.abs()} BPM',
      child: GestureDetector(
        onTap: () => onBpmChanged(bpm + delta),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16, fontWeight: FontWeight.bold),
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
