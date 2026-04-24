import 'package:uuid/uuid.dart';

/// Represents a playlist: an ordered collection of session IDs
/// that can be played back sequentially.
class Playlist {
  final String id;
  final String name;
  final String description;
  final List<String> sessionIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  Playlist({
    String? id,
    required this.name,
    this.description = '',
    List<String>? sessionIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        sessionIds = sessionIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? sessionIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sessionIds: sessionIds ?? List<String>.from(this.sessionIds),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'sessionIds': sessionIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      sessionIds: (json['sessionIds'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Playlist(id: $id, name: $name, sessions: ${sessionIds.length})';
}
