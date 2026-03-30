import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/metronome_provider.dart';
import '../constants/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Load persisted settings on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = context.read<SettingsProvider>();
      await settings.loadSettings();
      // Sync current silence value to the engine
      if (mounted) {
        final metronome = context.read<MetronomeProvider>();
        metronome.setRandomSilencePercent(settings.randomSilencePercentage);
        metronome.updateSoundSet(settings.selectedSound);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: AppColors.surface(context),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // ── Playback & Screen ──
          _buildSectionCard(
            context,
            icon: Icons.settings_rounded,
            title: 'Reproducción',
            child: Column(
              children: [
                _buildSwitchTile(
                  context,
                  title: 'Reproducción en segundo plano',
                  subtitle: 'El metrónomo sigue sonando al minimizar la app',
                  icon: Icons.headphones_rounded,
                  value: controller.backgroundPlayback,
                  onChanged: (val) => controller.toggleBackgroundPlayback(val),
                ),
                Divider(color: AppColors.border(context), height: 1),
                _buildSwitchTile(
                  context,
                  title: 'Mantener pantalla encendida',
                  subtitle: 'Evita que el dispositivo se bloquee automáticamente',
                  icon: Icons.brightness_high_rounded,
                  value: controller.keepScreenOn,
                  onChanged: (val) => controller.toggleKeepScreenOn(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Sound Selection ──
          _buildSectionCard(
            context,
            icon: Icons.music_note_rounded,
            title: 'Set de Sonidos',
            child: DropdownButtonFormField<String>(
              value: controller.selectedSound,
              dropdownColor: AppColors.surface(context),
              style: TextStyle(color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border(context)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: SettingsProvider.availableSounds
                  .map((sound) => DropdownMenuItem(
                        value: sound,
                        child: Text(sound),
                      ))
                  .toList(),
              onChanged: (val) {
                controller.updateSound(val!);
                context.read<MetronomeProvider>().updateSoundSet(val);
              },
            ),
          ),

          const SizedBox(height: 12),

          // ── Random Silence ──
          _buildSectionCard(
            context,
            icon: Icons.volume_off_rounded,
            title: 'Silencios al Azar',
            subtitle: 'Porcentaje de beats que se silencian aleatoriamente',
            child: Column(
              children: [
                Slider(
                  value: controller.randomSilencePercentage,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: AppColors.primary(context),
                  inactiveColor: AppColors.border(context),
                  label: '${controller.randomSilencePercentage.toInt()}%',
                  onChanged: (val) {
                    controller.updateSilence(val);
                    context.read<MetronomeProvider>().setRandomSilencePercent(val);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0%', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                    Text(
                      '${controller.randomSilencePercentage.toInt()}%',
                      style: TextStyle(
                        color: AppColors.primary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('100%', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── UI Scale ──
          _buildSectionCard(
            context,
            icon: Icons.zoom_in_rounded,
            title: 'Tamaño de la Interfaz',
            child: Column(
              children: [
                Slider(
                  value: controller.uiScale,
                  min: 0.8,
                  max: 1.5,
                  divisions: 7,
                  activeColor: AppColors.primary(context),
                  inactiveColor: AppColors.border(context),
                  label: '${(controller.uiScale * 100).toInt()}%',
                  onChanged: (val) => controller.updateUiScale(val),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('80%', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                    Text(
                      '${(controller.uiScale * 100).toInt()}%',
                      style: TextStyle(
                        color: AppColors.primary(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text('150%', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  //  Reusable Widgets
  // ─────────────────────────────────────────────────────

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary(context), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary(context), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                subtitle,
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 11),
              ),
            )
          : null,
      value: value,
      activeTrackColor: AppColors.primary(context),
      onChanged: onChanged,
    );
  }

  Widget _buildNumericField(
    BuildContext context, {
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary(context), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: AppColors.surfaceHighlight(context),
      ),
      onChanged: (val) {
        final parsed = int.tryParse(val);
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}
