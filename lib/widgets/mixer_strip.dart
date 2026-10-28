import 'package:flutter/material.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/widgets/knob_control.dart';

/// Compact per-pattern mixer: volume knob, Mute and Solo, plus an optional
/// [trailing] widget (e.g. the sound selector).
class MixerStrip extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final bool isMuted;
  final VoidCallback onMuteToggle;
  final bool isSolo;
  final VoidCallback onSoloToggle;
  final Widget? trailing;

  const MixerStrip({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    required this.isMuted,
    required this.onMuteToggle,
    required this.isSolo,
    required this.onSoloToggle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 36,
          child: KnobControl(
            value: volume,
            onChanged: onVolumeChanged,
            min: 0,
            max: 1,
            label: 'VOL',
            labelColor: volume > 0 ? AppColors.accentGreen(context) : AppColors.accentRed(context),
            size: 28,
          ),
        ),
        const SizedBox(width: 8),
        ToggleChipButton(
          label: 'M',
          tooltip: 'Silenciar',
          active: isMuted,
          activeColor: AppColors.accentRed(context),
          activeTextColor: Colors.white,
          onTap: onMuteToggle,
        ),
        ToggleChipButton(
          label: 'S',
          tooltip: 'Solo',
          active: isSolo,
          activeColor: AppColors.primary(context),
          activeTextColor: Colors.black,
          onTap: onSoloToggle,
        ),
        if (trailing != null) ...[
          const SizedBox(width: 2),
          trailing!,
        ],
      ],
    );
  }
}

/// Small square toggle (Mute / Solo style).
class ToggleChipButton extends StatelessWidget {
  final String label;
  final String? tooltip;
  final bool active;
  final Color activeColor;
  final Color activeTextColor;
  final VoidCallback onTap;

  const ToggleChipButton({
    super.key,
    required this.label,
    this.tooltip,
    required this.active,
    required this.activeColor,
    required this.activeTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Visual chip stays 32×26; the hit area is 40×40.
    final Widget chip = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: 32,
            height: 26,
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border(context)),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: active ? activeTextColor : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
    final Widget semantic = Semantics(button: true, toggled: active, label: tooltip ?? label, child: chip);
    return tooltip == null ? semantic : Tooltip(message: tooltip!, child: semantic);
  }
}
