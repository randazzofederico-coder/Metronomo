import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/pattern_model.dart';
import '../models/playlist_model.dart';
import '../models/session_model.dart';

// Conditional import: web reads/cleans the browser URL, stub is a no-op.
import 'deep_link_stub.dart'
    if (dart.library.js_interop) 'deep_link_web.dart';

/// Kind of content carried by a shared link.
enum SharedType { pattern, session, playlist }

/// A ready-to-share link produced by [DeepLinkService].
class SharedLink {
  final String id;
  final String url;

  /// Human title, e.g. "Sesión: Chacarera".
  final String title;

  /// Full message to send (includes the URL).
  final String message;

  const SharedLink({
    required this.id,
    required this.url,
    required this.title,
    required this.message,
  });
}

/// Decoded content of a shared link, independent of storage format.
class SharedBundle {
  final String shareId;
  final SharedType type;
  final String name;

  /// Main entity JSON (pattern / session / playlist).
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> patterns;
  final List<Map<String, dynamic>> sessions;

  const SharedBundle({
    required this.shareId,
    required this.type,
    required this.name,
    required this.data,
    this.patterns = const [],
    this.sessions = const [],
  });
}

/// User-facing error raised while creating a share link.
class ShareException implements Exception {
  final String message;
  const ShareException(this.message);
  @override
  String toString() => message;
}

/// Service that manages sharing patterns, sessions and playlists via deep links.
///
/// Workflow:
///  **Export** — signs in (anonymously if needed), serialises the bundle and
///               stores it in Firestore under a *content-addressed* short ID
///               (same content + same author ⇒ same link, no duplicate docs).
///               URL: `…/metronomo/?share=<id>&name=<slug>`.
///  **Import (Web)** — on app start, checks the URL for `?share=` via JS interop.
///  **Import (Native)** — listens for App Links via the `app_links` package.
///
/// Document schema (v2) in `shared_links/{id}`:
/// ```
/// v: 2, type, name, ownerUid, summary{patterns,sessions,bpm},
/// payload: "<JSON string {data, patterns, sessions}>",
/// createdAt, expiresAt
/// ```
/// The payload is stored as a JSON string so it is format-stable across
/// platforms (no int/double drift on web) and trivially readable by the
/// website/forum. Legacy v1 docs (nested `data/patterns/sessions`) are still
/// readable.
///
/// Firebase project is on the Spark plan (no TTL policies), so expired docs
/// are removed lazily by the client: up to 10 on each link creation, and any
/// expired link that gets opened. Rules only allow deleting expired docs.
class DeepLinkService {
  // Singleton -----------------------------------------------------------------
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;
  DeepLinkService._();

  // Configuration -------------------------------------------------------------
  static const String _baseUrl = 'https://federicorandazzo.com.ar/metronomo/';
  static const String _collection = 'shared_links';
  static const int _ttlDays = 30;
  static const int _schemaVersion = 2;

  // Native link listener ------------------------------------------------------
  StreamSubscription<Uri>? _linkSub;

  /// Share ID captured at app startup (before any screen mounts).
  String? _pendingShareId;

  /// Share IDs already dispatched during this app run. `app_links` may deliver
  /// the same initial link through several paths (getInitialLink + stream).
  final Set<String> _dispatched = {};

  /// Call from main.dart BEFORE runApp() to capture the initial deep link.
  Future<void> captureInitialLink() async {
    if (kIsWeb) {
      _pendingShareId = getShareParamFromUrl();
      if (_pendingShareId != null) cleanShareParamFromUrl();
      return;
    }
    try {
      final initialUri = await AppLinks().getInitialLink();
      if (initialUri != null) {
        _pendingShareId = _extractShareId(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService.captureInitialLink error: $e');
    }
  }

  /// Returns and clears the pending share ID (if any) — only once.
  String? consumePendingShareId() {
    final id = _pendingShareId;
    _pendingShareId = null;
    if (id == null || id.isEmpty || !_dispatched.add(id)) return null;
    return id;
  }

  /// Listens for links arriving while the app runs:
  ///  * Native: App Links via `app_links`.
  ///  * Web (installed PWA): `launchQueue` when the window is reused.
  /// Already-dispatched IDs are ignored so a link is imported once.
  void listenIncomingLinks(void Function(String shareId) onShareReceived) {
    if (kIsWeb) {
      listenWebLaunchQueue((id) {
        if (id.isNotEmpty && _dispatched.add(id)) onShareReceived(id);
      });
      return;
    }
    _linkSub?.cancel();
    _linkSub = AppLinks().uriLinkStream.listen((uri) {
      final id = _extractShareId(uri);
      if (id != null && _dispatched.add(id)) onShareReceived(id);
    });
  }

  String? _extractShareId(Uri uri) {
    final id = uri.queryParameters['share'];
    return (id == null || id.isEmpty) ? null : id;
  }

  /// Whether a native share sheet is available (Web Share API on web).
  bool get canNativeShare => kIsWeb ? webCanShare() : true;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Ensures there is a Firebase user (anonymous if none). The anonymous
  /// account can later be upgraded with `linkWithCredential`, keeping the
  /// same uid so links remain attributed to the user.
  Future<User> _ensureUser() async {
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    if (current != null) return current;
    try {
      final cred = await auth.signInAnonymously();
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      debugPrint('DeepLinkService anonymous sign-in failed: ${e.code}');
      throw const ShareException(
          'No se pudo conectar con el servidor para crear el link.');
    }
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
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  /// Canonicalises JSON for hashing: sorted keys, volatile fields removed.
  Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {
        for (final k in keys)
          if (k != 'createdAt' && k != 'updatedAt') k: _canonical(value[k]),
      };
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  /// Short content-addressed ID (10 chars, base36) from SHA-256.
  String _contentId(String ownerUid, Map<String, dynamic> payload) {
    final canonical = jsonEncode(_canonical({'o': ownerUid, 'p': payload}));
    final bytes = sha256.convert(utf8.encode(canonical)).bytes;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(10, (i) => chars[bytes[i] % chars.length]).join();
  }

  Timestamp _newExpiry() =>
      Timestamp.fromDate(DateTime.now().add(const Duration(days: _ttlDays)));

  /// Stores [payload] (or reuses an identical existing doc) and returns the link.
  Future<SharedLink> _createLink({
    required SharedType type,
    required String name,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> summary,
    required String title,
    required String message,
  }) async {
    final user = await _ensureUser();
    final shareId = _contentId(user.uid, payload);
    final ref = FirebaseFirestore.instance.collection(_collection).doc(shareId);

    try {
      final existing = await ref.get();
      if (existing.exists) {
        // Same content already shared by this user: just extend its life.
        unawaited(ref.update({'expiresAt': _newExpiry()}).catchError((_) {}));
      } else {
        await ref.set({
          'v': _schemaVersion,
          'type': type.name,
          'name': name,
          'ownerUid': user.uid,
          'summary': summary,
          'payload': jsonEncode(payload),
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': _newExpiry(),
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('DeepLinkService._createLink ${e.code}: ${e.message}');
      throw ShareException(e.code == 'permission-denied'
          ? 'El servidor rechazó el link (permisos).'
          : 'No se pudo crear el link. Revisá tu conexión.');
    }

    final url = '$_baseUrl?share=$shareId&name=${_slugify(name)}';

    // Lazy cleanup of expired links (Spark plan has no TTL policies).
    unawaited(_cleanupExpiredLinks());

    return SharedLink(
      id: shareId,
      url: url,
      title: title,
      message: '$message\n$url',
    );
  }

  // ── Export (share) ─────────────────────────────────────────────────────────

  /// Creates a link for a single [Pattern].
  Future<SharedLink> createPatternLink(Pattern pattern) {
    return _createLink(
      type: SharedType.pattern,
      name: pattern.name,
      payload: {'data': pattern.toJson()},
      summary: {'patterns': 1, 'structure': pattern.structure},
      title: 'Patrón: ${pattern.name}',
      message: '🎵 Te comparto el patrón «${pattern.name}» (${pattern.structure}) en Metrónomo:',
    );
  }

  /// Creates a link for a [Session] bundled with its [Pattern]s.
  Future<SharedLink> createSessionLink(Session session, List<Pattern> patterns) {
    return _createLink(
      type: SharedType.session,
      name: session.name,
      payload: {
        'data': session.toJson(),
        'patterns': patterns.map((p) => p.toJson()).toList(),
      },
      summary: {'patterns': patterns.length, 'bpm': session.globalBpm},
      title: 'Sesión: ${session.name}',
      message:
          '🎵 Te comparto la sesión «${session.name}» (${session.globalBpm} BPM · ${patterns.length} patrones) en Metrónomo:',
    );
  }

  /// Creates a link for a [Playlist] bundled with its [Session]s and [Pattern]s.
  Future<SharedLink> createPlaylistLink(
    Playlist playlist,
    List<Session> sessions,
    List<Pattern> patterns,
  ) {
    return _createLink(
      type: SharedType.playlist,
      name: playlist.name,
      payload: {
        'data': playlist.toJson(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'patterns': patterns.map((p) => p.toJson()).toList(),
      },
      summary: {'sessions': sessions.length, 'patterns': patterns.length},
      title: 'Playlist: ${playlist.name}',
      message:
          '🎵 Te comparto la playlist «${playlist.name}» (${sessions.length} sesiones) en Metrónomo:',
    );
  }

  // ── Import (receive) ──────────────────────────────────────────────────────

  /// Fetches and decodes a shared link. Returns `null` if missing/expired.
  Future<SharedBundle?> fetchSharedBundle(String shareId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(shareId)
          .get();
      if (!doc.exists) return null;
      final raw = doc.data()!;

      final expiresAt = raw['expiresAt'];
      if (expiresAt is Timestamp && expiresAt.toDate().isBefore(DateTime.now())) {
        // Expired: delete it (rules allow deleting only expired docs).
        unawaited(doc.reference.delete().catchError((_) {}));
        return null;
      }

      // Renew TTL (best-effort; rules allow touching only `expiresAt`).
      unawaited(doc.reference
          .update({'expiresAt': _newExpiry()})
          .catchError((e) => debugPrint('TTL renew skipped: $e')));

      final type = SharedType.values
          .where((t) => t.name == raw['type'])
          .firstOrNull;
      if (type == null) return null;

      // v2: JSON string payload. v1 (legacy): nested maps at top level.
      final Map<String, dynamic> body = raw['payload'] is String
          ? jsonDecode(raw['payload'] as String) as Map<String, dynamic>
          : raw;

      List<Map<String, dynamic>> list(Object? v) => (v as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      return SharedBundle(
        shareId: shareId,
        type: type,
        name: raw['name'] as String? ?? '',
        data: Map<String, dynamic>.from(body['data'] as Map),
        patterns: list(body['patterns']),
        sessions: list(body['sessions']),
      );
    } catch (e) {
      debugPrint('DeepLinkService.fetchSharedBundle error: $e');
      return null;
    }
  }

  /// Deletes up to 10 expired links (best-effort, fire-and-forget).
  ///
  /// Security rules only allow listing/deleting docs whose `expiresAt` is in
  /// the past, so the query uses a 1-hour safety margin against clock skew
  /// (rules compare against server time).
  Future<void> _cleanupExpiredLinks() async {
    try {
      final cutoff = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1)));
      final expired = await FirebaseFirestore.instance
          .collection(_collection)
          .where('expiresAt', isLessThan: cutoff)
          .limit(10)
          .get();
      for (final doc in expired.docs) {
        unawaited(doc.reference.delete().catchError((_) {}));
      }
      if (expired.docs.isNotEmpty) {
        debugPrint('DeepLinkService: cleaned ${expired.docs.length} expired links');
      }
    } catch (e) {
      debugPrint('DeepLinkService._cleanupExpiredLinks skipped: $e');
    }
  }

  /// Cancels native link listener.
  void dispose() {
    _linkSub?.cancel();
    _linkSub = null;
  }
}
