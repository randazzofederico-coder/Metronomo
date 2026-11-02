import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fede_apps_core/fede_apps_core.dart' show EcosystemPrompts, EcosystemSection, FedeApp;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/pwa_install_service.dart';
import '../providers/settings_provider.dart';
import '../providers/metronome_provider.dart';
import '../constants/app_colors.dart';
import 'package:metronomo_standalone/l10n/l10n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.promptOnOpen = true});

  /// Whether to (maybe) show the "other apps" suggestion right after the
  /// screen opens. The Settings tab in [HomeShell] lives in an IndexedStack
  /// and is built at startup, so it passes `false` and triggers the
  /// suggestion itself when the tab is selected.
  final bool promptOnOpen;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening Settings is a "quiet moment": the shared package may suggest
    // the other apps (it decides on its own; usually does nothing).
    if (widget.promptOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          EcosystemPrompts.maybeShowAppsPrompt(context, currentApp: FedeApp.metronomo);
        }
      });
    }
    // Load persisted settings on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = context.read<SettingsProvider>();
      await settings.loadSettings();
      // Sync current silence value to the engine (not a user edit: the
      // session must not become dirty — this screen is built at startup).
      if (mounted) {
        final metronome = context.read<MetronomeProvider>();
        metronome.setRandomSilencePercent(settings.randomSilencePercentage, markDirty: false);
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
        // Same name as its tab in the bottom bar.
        title: Text(context.l10n.settingsTitle, style: TextStyle(letterSpacing: 2.0)),
        backgroundColor: AppColors.surface(context),
      ),
      // On wide screens keep the settings at a readable width.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _buildList(context, controller),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, SettingsProvider controller) {
    return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // ── Language ──
          _buildLanguageSection(context, controller),

          const SizedBox(height: 12),

          // ── Playback & Screen ──
          _buildSectionCard(
            context,
            icon: Icons.settings_rounded,
            title: context.l10n.settingsPlaybackTitle,
            child: Column(
              children: [
                _buildSwitchTile(
                  context,
                  title: context.l10n.settingsBackgroundPlaybackTitle,
                  subtitle: context.l10n.settingsBackgroundPlaybackSubtitle,
                  icon: Icons.headphones_rounded,
                  value: controller.backgroundPlayback,
                  onChanged: (val) => controller.toggleBackgroundPlayback(val),
                ),
                Divider(color: AppColors.border(context), height: 1),
                _buildSwitchTile(
                  context,
                  title: context.l10n.settingsKeepScreenOnTitle,
                  subtitle: context.l10n.settingsKeepScreenOnSubtitle,
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
            title: context.l10n.settingsSoundSetTitle,
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
                        child: Text(soundSetLabel(context.l10n, sound)),
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
            title: context.l10n.settingsRandomSilenceTitle,
            subtitle: context.l10n.settingsRandomSilenceSubtitle,
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
            title: context.l10n.settingsUiScaleTitle,
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

          // ── Comunidad / Foro ──
          _buildForumSection(context),
          const SizedBox(height: 12),

          // ── Más apps (fede_apps_core) ──
          _buildMoreAppsSection(context),
          const SizedBox(height: 12),

          // ── Acerca de ──
          _buildAboutSection(context),
          const SizedBox(height: 24),
        ],
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


  Widget _buildPwaInstallSection(BuildContext context) {
    final pwaService = PwaInstallService();

    return _buildSectionCard(
      context,
      icon: Icons.install_mobile_rounded,
      title: context.l10n.settingsInstallTitle,
      subtitle: context.l10n.settingsInstallSubtitle,
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
                          context.l10n.settingsInstalledTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentGreen(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.settingsInstalledMessage,
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
                      context.l10n.settingsInstallPrompt,
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
                        label: Text(context.l10n.settingsInstallButton, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
                    context.l10n.settingsInstallManualIntro,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
                  ),
                  const SizedBox(height: 10),
                  _buildInstallStep(context, Icons.phone_android, 'Chrome (Android)',
                      context.l10n.settingsInstallStepChromeAndroid),
                  _buildInstallStep(context, Icons.desktop_windows, 'Chrome (PC)',
                      context.l10n.settingsInstallStepChromePc),
                  _buildInstallStep(context, Icons.phone_iphone, 'Safari (iOS)',
                      context.l10n.settingsInstallStepSafariIos),
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

  Widget _buildLanguageSection(BuildContext context, SettingsProvider controller) {
    return _buildSectionCard(
      context,
      icon: Icons.translate_rounded,
      title: context.l10n.settingsLanguageTitle,
      subtitle: context.l10n.settingsLanguageSubtitle,
      child: DropdownButtonFormField<String?>(
        value: controller.languageCode,
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
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(context.l10n.languageSystem),
          ),
          DropdownMenuItem<String?>(
            value: 'es',
            child: Text(context.l10n.languageSpanish),
          ),
          DropdownMenuItem<String?>(
            value: 'en',
            child: Text(context.l10n.languageEnglish),
          ),
        ],
        onChanged: (val) => controller.updateLanguage(val),
      ),
    );
  }

  Widget _buildForumSection(BuildContext context) {
    return _buildSectionCard(
      context,
      icon: Icons.forum_rounded,
      title: context.l10n.settingsForumTitle,
      subtitle: context.l10n.settingsForumSubtitle,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final uri = Uri.parse('https://federicorandazzo.com.ar/foro/');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(
            context.l10n.settingsForumButton,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary(context),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreAppsSection(BuildContext context) {
    return _buildSectionCard(
      context,
      icon: Icons.apps_rounded,
      title: context.l10n.settingsMoreAppsTitle,
      // Tiles flush with the card content, like the switch tiles above.
      // The website tile is hidden: "Acerca de" already links to the site.
      child: const ListTileTheme(
        contentPadding: EdgeInsets.zero,
        child: EcosystemSection(
          currentApp: FedeApp.metronomo,
          showHeader: false,
          showSite: false,
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildSectionCard(
      context,
      icon: Icons.info_outline_rounded,
      title: context.l10n.settingsAboutTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.appTitle,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.settingsAboutDevelopedBy,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse('https://federicorandazzo.com.ar/apps/');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.language_rounded),
              label: Text(
                context.l10n.settingsAboutVisitWebsite,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

