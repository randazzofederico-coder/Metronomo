import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/version_check_service.dart';

/// Full-screen blocking UI shown when the app version is below the minimum.
///
/// - On **web / PWA**: shows a brief "Descargando actualización…" animation
///   and then reloads the page automatically.
/// - On **mobile / desktop**: shows the update info and a button that opens
///   the corresponding store listing.
class UpdateRequiredScreen extends StatefulWidget {
  final VersionCheckResult result;

  const UpdateRequiredScreen({super.key, required this.result});

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // On web, auto-trigger the reload after a brief delay so the user sees
    // the loading animation.
    if (kIsWeb) {
      _triggerWebUpdate();
    }
  }

  Future<void> _triggerWebUpdate() async {
    setState(() => _isUpdating = true);
    // Brief pause so the progress indicator is visible.
    await Future.delayed(const Duration(seconds: 1));
    await VersionCheckService().triggerWebUpdate();
    // If we're still alive (reload didn't happen), keep the spinner.
  }

  Future<void> _openStore() async {
    // Android Play Store URL. When you publish to iOS/macOS, add their URLs.
    const androidUrl =
        'https://play.google.com/store/apps/details?id=ar.com.federicorandazzo.metronomo';
    // TODO: Add iOS App Store URL when available
    // const iosUrl = 'https://apps.apple.com/app/id...';

    final uri = Uri.parse(androidUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Constants matching Metrónomo's palette (no BuildContext-dependent
    // colors because this screen is outside the themed MaterialApp).
    const background = Color(0xFF1E1A17);
    const surface = Color(0xFF2C2621);
    const primary = Color(0xFFF98533);
    const textPrimary = Color(0xFFF2EBE5);
    const textSecondary = Color(0xFFBCAAA4);

    final message = widget.result.updateMessage ??
        'Hay una nueva versión disponible.\nActualizá para seguir usando Metrónomo.';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon ──
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: primary,
                    size: 44,
                  ),
                ),

                const SizedBox(height: 28),

                // ── Title ──
                const Text(
                  'Actualización Necesaria',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Message ──
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Version info ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'v${widget.result.currentVersion}',
                        style: const TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: primary, size: 18),
                      ),
                      Text(
                        'v${widget.result.minVersion}',
                        style: const TextStyle(
                          color: primary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Action area ──
                if (kIsWeb || _isUpdating)
                  // Web: auto-updating with progress indicator
                  const Column(
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: primary,
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Descargando actualización…',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                else
                  // Mobile/desktop: button to open the store
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openStore,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text(
                        'Actualizar',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
