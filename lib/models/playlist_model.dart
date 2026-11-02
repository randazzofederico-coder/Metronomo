import 'package:fede_apps_core/fede_apps_core.dart' show SyncFields;
import 'package:uuid/uuid.dart';

import 'session_model.dart';
import 'synced_item.dart';

/// One entry of a playlist (hybrid model): a **link** to a library session
/// plus a fallback **snapshot** of it.
///
/// * [id] is unique within the playlist, so the same session can appear
///   several times.
/// * [sourceSessionId] links the item to a library session, which is the
///   source of truth: while it's active, the playlist plays/shows/shares the
///   library version (see [PlaylistProvider.resolveSession]), so editing the
///   session in the library is reflected in every playlist that contains it.
/// * [session] is the snapshot: a deep copy with its **own** id (see
///   [Session.asEmbeddedCopy]) and no sync metadata. It's only used when the
///   library session is gone (deleted, or never in this library), so the
///   playlist keeps playing exactly what it was. It's refreshed when the item
///   is added, when the source session is deleted and opportunistically when
///   the playlist itself changes — not on every library edit.
class PlaylistItem {
  final String id;
  final String? sourceSessionId;
  final Session session;

  PlaylistItem({String? id, this.sourceSessionId, required this.session})
      : id = id ?? const Uuid().v4();

  /// Links [librarySession] in a new item, with a snapshot of it (new item
  /// id, new snapshot id). Pass a session that already has its patterns
  /// embedded (see [Session.withEmbeddedPatterns]).
  factory PlaylistItem.fromLibrary(Session librarySession, {String? id, String? sessionId}) =>
      PlaylistItem(
        id: id,
        sourceSessionId: librarySession.id,
        session: librarySession.asEmbeddedCopy(id: sessionId),
      );

  PlaylistItem copyWith({String? id, String? sourceSessionId, Session? session}) => PlaylistItem(
        id: id ?? this.id,
        sourceSessionId: sourceSessionId ?? this.sourceSessionId,
        session: session ?? this.session.copyWith(updatedAt: this.session.updatedAt),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (sourceSessionId != null) 'sourceSessionId': sourceSessionId,
        'session': stripSyncFields(session.toJson()),
      };

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    final session = Session.fromJson(Map<String, dynamic>.from(json['session'] as Map));
    return PlaylistItem(
      id: json['id'] as String?,
      sourceSessionId: json['sourceSessionId'] as String?,
      // Embedded copies never carry sync metadata.
      session: session.asEmbeddedCopy(id: session.id),
    );
  }
}

/// Represents a playlist: an ordered list of [items], each one linked to a
/// library session with a fallback snapshot (see [PlaylistItem]), so the
/// playlist follows library edits but never breaks if a session is deleted.
///
/// Legacy playlists (before items) only stored `sessionIds` (references to
/// the session library). They are read into [legacySessionIds] and migrated by
/// [PlaylistProvider.loadPlaylists]; while not migrated, they are written back
/// as they were so nothing is lost.
class Playlist implements SyncedItem<Playlist> {
  @override
  final String id;
  final String name;
  final String description;
  final List<PlaylistItem> items;

  /// Legacy references (old format). Empty once migrated.
  final List<String> legacySessionIds;

  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  final int rev;
  @override
  final bool deleted;
  @override
  final DateTime? deletedAt;
  @override
  final String? device;

  Playlist({
    String? id,
    required this.name,
    this.description = '',
    List<PlaylistItem>? items,
    List<String>? legacySessionIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.rev = 1,
    this.deleted = false,
    this.deletedAt,
    this.device,
  })  : id = id ?? const Uuid().v4(),
        items = items ?? [],
        legacySessionIds = legacySessionIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// True if it still references the session library (old format).
  bool get needsMigration => legacySessionIds.isNotEmpty;

  /// The snapshots, in order (fallback copies; for what the user sees use
  /// [PlaylistProvider.resolvedSessions]).
  List<Session> get sessions => [for (final item in items) item.session];

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    List<PlaylistItem>? items,
    List<String>? legacySessionIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      items: items ?? List<PlaylistItem>.from(this.items),
      legacySessionIds: legacySessionIds ?? List<String>.from(this.legacySessionIds),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      rev: rev,
      deleted: deleted,
      deletedAt: deletedAt,
      device: device,
    );
  }

  @override
  Playlist withSync({
    required int rev,
    required bool deleted,
    DateTime? deletedAt,
    String? device,
    required DateTime updatedAt,
  }) =>
      Playlist(
        id: id,
        name: name,
        description: description,
        items: List<PlaylistItem>.from(items),
        legacySessionIds: List<String>.from(legacySessionIds),
        createdAt: createdAt,
        updatedAt: updatedAt,
        rev: rev,
        deleted: deleted,
        deletedAt: deletedAt,
        device: device,
      );

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'items': items.map((i) => i.toJson()).toList(),
      // Kept only until migrated (never lose old references).
      if (legacySessionIds.isNotEmpty) 'sessionIds': legacySessionIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
    SyncFields.write(json, rev: rev, deleted: deleted, deletedAt: deletedAt, device: device);
    return json;
  }

  /// Reads both formats: `items` (current) and `sessionIds` (legacy). If both
  /// are present, `items` wins.
  factory Playlist.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .map((e) => PlaylistItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <PlaylistItem>[];
    final legacy = rawItems is List
        ? <String>[]
        : (json['sessionIds'] as List<dynamic>?)?.cast<String>().toList() ?? <String>[];
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      items: items,
      legacySessionIds: legacy,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      rev: SyncFields.readRev(json),
      deleted: SyncFields.readDeleted(json),
      deletedAt: SyncFields.readDeletedAt(json),
      device: SyncFields.readDevice(json),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Playlist(id: $id, name: $name, items: ${items.length})';
}
