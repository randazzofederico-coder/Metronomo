import 'dart:async';
import 'dart:math';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/pattern_model.dart';
import '../models/session_model.dart';

// Conditional import: web reads/cleans the browser URL, stub is a no-op.
import 'deep_link_stub.dart'
    if (dart.library.js_interop) 'deep_link_web.dart';

/// Service that manages sharing patterns and sessions via clean deep links.
///
/// Workflow:
///  **Export** — serialises the data to Firestore under a short random ID,
///               then shares the URL `…/metronomo/?share=<id>`.
///  **Import (Web)** — on app start, checks the URL for `?share=` via JS interop.
///  **Import (Native)** — listens for incoming App Links via `app_links` package.
///
/// Documents in `shared_links` include an `expiresAt` timestamp set to 30 days
/// from creation. A Firestore TTL Policy on that field auto-deletes expired docs.
class DeepLinkService {
  // Singleton -----------------------------------------------------------------
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;
  DeepLinkService._();

  // Configuration -------------------------------------------------------------
  static const String _baseUrl =
      'https://federicorandazzo.com.ar/metronomo/';
  static const String _collection = 'shared_links';
  static const int _ttlDays = 30;

  // Native link listener ------------------------------------------------------
  StreamSubscription<Uri>? _linkSub;

  /// Share ID captured at app startup (before any screen mounts).
  /// This avoids timing issues where the auth gate consumes the intent
  /// before MetronomeScreen can read it.
  String? _pendingShareId;

  /// Call from main.dart BEFORE runApp() to capture the initial deep link.
  Future<void> captureInitialLink() async {
    if (kIsWeb) return; // Web uses JS interop (checkForShareParam)
    try {
      final appLinks = AppLinks();
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        _pendingShareId = initialUri.queryParameters['share'];
      }
    } catch (e) {
      debugPrint('DeepLinkService.captureInitialLink error: $e');
    }
  }

  /// Returns and clears the pending share ID (if any).
  /// This ensures the import only happens once.
  String? consumePendingShareId() {
    final id = _pendingShareId;
    _pendingShareId = null;
    return id;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Generates a short random alphanumeric ID for use as Firestore doc ID.
  String _generateShortId([int length = 8]) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Converts a human-readable name into a URL-safe slug.
  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }

  /// Builds the Firestore document payload with a 30-day TTL.
  Map<String, dynamic> _buildPayload({
    required String type,
    required String name,
    required Map<String, dynamic> data,
    List<Map<String, dynamic>>? patterns,
  }) {
    final payload = <String, dynamic>{
      'type': type,
      'name': name,
      'data': data,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: _ttlDays)),
      ),
    };
    if (patterns != null) {
      payload['patterns'] = patterns;
    }
    return payload;
  }

  // ── Export (share) ─────────────────────────────────────────────────────────

  /// Shares a single [Pattern] via deep link.
  Future<void> sharePattern(Pattern pattern) async {
    final shareId = _generateShortId();

    await FirebaseFirestore.instance.collection(_collection).doc(shareId).set(
      _buildPayload(
        type: 'pattern',
        name: pattern.name,
        data: pattern.toJson(),
      ),
    );

    // Lazy cleanup: delete a few expired links while we're at it
    _cleanupExpiredLinks();

    final slug = _slugify(pattern.name);
    final url = '${_baseUrl}?share=$shareId&name=$slug';

    await _shareUrl(url, 'Patrón de Metrónomo: ${pattern.name}');
  }

  /// Shares a [Session] together with all its referenced [Pattern]s.
  Future<void> shareSession(
    Session session,
    List<Pattern> patterns,
  ) async {
    final shareId = _generateShortId();

    await FirebaseFirestore.instance.collection(_collection).doc(shareId).set(
      _buildPayload(
        type: 'session',
        name: session.name,
        data: session.toJson(),
        patterns: patterns.map((p) => p.toJson()).toList(),
      ),
    );

    // Lazy cleanup: delete a few expired links while we're at it
    _cleanupExpiredLinks();

    final slug = _slugify(session.name);
    final url = '${_baseUrl}?share=$shareId&name=$slug';

    await _shareUrl(url, 'Sesión de Metrónomo: ${session.name}');
  }

  /// Invokes the platform share sheet, falling back to clipboard.
  Future<void> _shareUrl(String url, String subject) async {
    try {
      await Share.share(url, subject: subject);
    } catch (_) {
      // Fallback: copy to clipboard (desktop web browsers may not support
      // the Web Share API).
      await Clipboard.setData(ClipboardData(text: url));
    }
  }

  // ── Import (receive) ──────────────────────────────────────────────────────

  /// Returns the share ID embedded in the current browser URL, or `null`.
  /// Works only on Web (uses JS interop).
  String? checkForShareParam() {
    if (!kIsWeb) return null;
    return getShareParamFromUrl();
  }

  /// Initialises native deep link listening (Android/iOS).
  /// Call once from the main screen's `initState`.
  ///
  /// [onShareReceived] is invoked with the share ID whenever a deep link
  /// is opened — both on cold start and when the app is already running.
  Future<void> initNativeLinks({
    required Future<void> Function(String shareId) onShareReceived,
  }) async {
    if (kIsWeb) return; // Web uses JS interop in checkForShareParam()

    final appLinks = AppLinks();

    // 1. Cold start: check if the app was launched via a deep link
    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        final shareId = initialUri.queryParameters['share'];
        if (shareId != null && shareId.isNotEmpty) {
          await onShareReceived(shareId);
        }
      }
    } catch (e) {
      debugPrint('DeepLinkService.initNativeLinks initial link error: $e');
    }

    // 2. Warm resume: listen for links while app is open
    _linkSub?.cancel();
    _linkSub = appLinks.uriLinkStream.listen((uri) {
      final shareId = uri.queryParameters['share'];
      if (shareId != null && shareId.isNotEmpty) {
        onShareReceived(shareId);
      }
    });
  }

  /// Fetches the shared payload from Firestore.
  /// If the document has expired (expiresAt in the past), deletes it and returns null.
  Future<Map<String, dynamic>?> fetchSharedData(String shareId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(shareId)
          .get();
      if (!doc.exists) return null;

      final data = doc.data()!;

      // Check TTL: if expiresAt exists and is in the past, treat as expired
      final expiresAt = data['expiresAt'] as Timestamp?;
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        // Clean up the expired document
        doc.reference.delete();
        return null;
      }

      // Renew TTL: each download extends the expiration by another 30 days
      doc.reference.update({
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: _ttlDays)),
        ),
      });

      return data;
    } catch (e) {
      debugPrint('DeepLinkService.fetchSharedData error: $e');
      return null;
    }
  }

  /// Deletes up to 10 expired documents from shared_links.
  /// Runs in the background (fire-and-forget) to avoid blocking the UI.
  void _cleanupExpiredLinks() async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final expired = await FirebaseFirestore.instance
          .collection(_collection)
          .where('expiresAt', isLessThan: now)
          .limit(10)
          .get();

      for (var doc in expired.docs) {
        doc.reference.delete();
      }

      if (expired.docs.isNotEmpty) {
        debugPrint('DeepLinkService: cleaned ${expired.docs.length} expired links');
      }
    } catch (e) {
      // Silently fail — cleanup is best-effort
      debugPrint('DeepLinkService._cleanupExpiredLinks error: $e');
    }
  }

  /// Strips the `?share=…` params from the browser URL bar.
  void cleanUrl() {
    if (kIsWeb) {
      cleanShareParamFromUrl();
    }
  }

  /// Cancels native link listener. Call from dispose if needed.
  void dispose() {
    _linkSub?.cancel();
    _linkSub = null;
  }
}
