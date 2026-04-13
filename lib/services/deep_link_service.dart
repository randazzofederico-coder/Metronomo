import 'dart:math';
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
///  **Import** — on app start, checks the URL for `?share=`, fetches the
///               Firestore document and returns the parsed data.
class DeepLinkService {
  // Singleton -----------------------------------------------------------------
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;
  DeepLinkService._();

  // Configuration -------------------------------------------------------------
  static const String _baseUrl =
      'https://federicorandazzo.com.ar/metronomo/';
  static const String _collection = 'shared_links';

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

  // ── Export (share) ─────────────────────────────────────────────────────────

  /// Shares a single [Pattern] via deep link.
  Future<void> sharePattern(Pattern pattern) async {
    final shareId = _generateShortId();

    await FirebaseFirestore.instance.collection(_collection).doc(shareId).set({
      'type': 'pattern',
      'name': pattern.name,
      'data': pattern.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    });

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

    await FirebaseFirestore.instance.collection(_collection).doc(shareId).set({
      'type': 'session',
      'name': session.name,
      'data': session.toJson(),
      'patterns': patterns.map((p) => p.toJson()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });

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

  /// Returns the share ID embedded in the current URL, or `null`.
  String? checkForShareParam() {
    if (!kIsWeb) return null;
    return getShareParamFromUrl();
  }

  /// Fetches the shared payload from Firestore.
  Future<Map<String, dynamic>?> fetchSharedData(String shareId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(shareId)
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('DeepLinkService.fetchSharedData error: $e');
      return null;
    }
  }

  /// Strips the `?share=…` params from the browser URL bar.
  void cleanUrl() {
    if (kIsWeb) {
      cleanShareParamFromUrl();
    }
  }
}
