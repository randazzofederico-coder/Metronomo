import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/pwa_install_service.dart';
import '../providers/settings_provider.dart';
import '../providers/metronome_provider.dart';
import '../constants/app_colors.dart';
import '../models/permission_cache.dart';

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

          // ── PWA Install (only on web) ──
          if (kIsWeb) ...[
            _buildPwaInstallSection(context),
            const SizedBox(height: 12),
          ],

          // ── Session & Logout ──
          _buildSessionSection(context),
          const SizedBox(height: 12),
          _buildLogoutButton(context),
          const SizedBox(height: 8),
          _buildDeleteAccountButton(context),
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

  Widget _buildPwaInstallSection(BuildContext context) {
    final pwaService = PwaInstallService();

    return _buildSectionCard(
      context,
      icon: Icons.install_mobile_rounded,
      title: 'Instalar Aplicación',
      subtitle: 'Instalá el metrónomo en tu dispositivo',
      child: ValueListenableBuilder<bool>(
        valueListenable: pwaService.isInstalled,
        builder: (context, isInstalled, _) {
          if (isInstalled) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentGreen(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentGreen(context).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.accentGreen(context), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Instalada',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGreen(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Estás usando la versión instalada del Metrónomo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return ValueListenableBuilder<bool>(
            valueListenable: pwaService.canInstall,
            builder: (context, canInstall, _) {
              if (canInstall) {
                return Column(
                  children: [
                    Text(
                      'Instalá el Metrónomo en tu dispositivo para acceso rápido y uso sin conexión.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await pwaService.promptInstall();
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Instalar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary(context),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Manual install instructions
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Podés instalar esta app desde el menú de tu navegador:',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
                  ),
                  const SizedBox(height: 10),
                  _buildInstallStep(context, Icons.phone_android, 'Chrome (Android)',
                      'Menú ⋮ → "Instalar aplicación" o "Añadir a pantalla de inicio"'),
                  _buildInstallStep(context, Icons.desktop_windows, 'Chrome (PC)',
                      'Icono de instalación en la barra de direcciones o Menú ⋮ → "Instalar app"'),
                  _buildInstallStep(context, Icons.phone_iphone, 'Safari (iOS)',
                      'Tocar el botón Compartir → "Agregar a pantalla de inicio"'),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInstallStep(BuildContext context, IconData icon, String label, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary(context)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                  ),
                  TextSpan(
                    text: detail,
                    style: TextStyle(color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSection(BuildContext context) {
    final settings = context.read<SettingsProvider>();

    return FutureBuilder<PermissionCache?>(
      future: settings.loadPermissionCacheAsync(),
      builder: (context, snapshot) {
        final cache = snapshot.data;

        String lastDateText = 'Nunca verificada';
        String daysText = 'Sin datos';
        Color daysColor = AppColors.textSecondary(context);
        IconData daysIcon = Icons.help_outline;

        if (cache != null) {
          // Manual date formatting (avoids DateFormat locale crash)
          final d = cache.lastVerified;
          const meses = [
            'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
            'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
          ];
          lastDateText = '${d.day} de ${meses[d.month - 1]} de ${d.year}';

          final days = cache.daysUntilExpiry;
          if (days > 5) {
            daysText = '$days días restantes';
            daysColor = AppColors.accentGreen(context);
            daysIcon = Icons.check_circle_outline;
          } else if (days > 0) {
            daysText = '$days ${days == 1 ? 'día' : 'días'} restantes';
            daysColor = AppColors.warning(context);
            daysIcon = Icons.warning_amber_rounded;
          } else {
            daysText = 'Verificación requerida';
            daysColor = AppColors.error(context);
            daysIcon = Icons.error_outline;
          }
        }

        return _buildSectionCard(
          context,
          icon: Icons.shield_outlined,
          title: 'Sesión',
          child: Column(
            children: [
              _buildInfoRow(
                context,
                icon: Icons.calendar_today_outlined,
                label: 'Última verificación online',
                value: lastDateText,
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                icon: daysIcon,
                label: 'Próxima verificación requerida',
                value: daysText,
                valueColor: daysColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutConfirmation(context),
        icon: Icon(Icons.logout_rounded, size: 18, color: AppColors.error(context)),
        label: Text(
          'Cerrar sesión',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.error(context),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.error(context).withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Cerrar sesión?',
          style: TextStyle(color: AppColors.textPrimary(context)),
        ),
        content: Text(
          'Tus patrones y sesiones guardados localmente no se borrarán. '
          'Solo se cerrará la sesión de tu cuenta.',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Cerrar sesión',
              style: TextStyle(color: AppColors.error(context), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final settings = context.read<SettingsProvider>();
      await settings.clearPermissionCache();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Widget _buildDeleteAccountButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showDeleteAccountConfirmation(context),
        icon: Icon(Icons.delete_forever, size: 18, color: Colors.red),
        label: Text(
          'Eliminar cuenta',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Eliminar cuenta',
          style: TextStyle(color: AppColors.textPrimary(context)),
        ),
        content: Text(
          '¿Estás seguro que deseas eliminar tu cuenta de forma permanente?\n\n'
          'Esta acción no se puede deshacer y perderás todos tus datos asociados a esta cuenta.',
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).delete();
        await user.delete();
      }
      if (mounted) {
        final settings = context.read<SettingsProvider>();
        await settings.clearPermissionCache();
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por seguridad, debes volver a iniciar sesión antes de eliminar tu cuenta.'),
            duration: Duration(seconds: 5),
          ),
        );
        final settings = context.read<SettingsProvider>();
        await settings.clearPermissionCache();
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: ${e.message}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      }
    }
  }
}

