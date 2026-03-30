import 'package:uuid/uuid.dart';

/// Represents a single subdivision configuration within a beat.
class SubdivisionConfig {
  final int count;
  final int accentLevel; // 0=silent, 1=primary, 2=secondary, 3=ghost

  const SubdivisionConfig({
    this.count = 1,
    this.accentLevel = 3,
  });

  SubdivisionConfig copyWith({int? count, int? accentLevel}) {
    return SubdivisionConfig(
      count: count ?? this.count,
      accentLevel: accentLevel ?? this.accentLevel,
    );
  }

  Map<String, dynamic> toJson() => {
    'count': count,
    'accentLevel': accentLevel,
  };

  factory SubdivisionConfig.fromJson(Map<String, dynamic> json) {
    return SubdivisionConfig(
      count: json['count'] as int? ?? 1,
      accentLevel: json['accentLevel'] as int? ?? 3,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubdivisionConfig &&
          runtimeType == other.runtimeType &&
          count == other.count &&
          accentLevel == other.accentLevel;

  @override
  int get hashCode => count.hashCode ^ accentLevel.hashCode;
}

/// Represents a rhythmic pattern that can be saved in the global Pattern Library.
///
/// Each pattern defines a time signature, a sequence of beat steps (accent levels),
/// optional subdivision configurations, and visual/organizational metadata.
class Pattern {
  final String id;
  final String name;
  final String description;
  final int beats;
  final List<int> steps; // accent levels per beat: 0=silent, 1=primary, 2=secondary, 3=ghost
  final String timeSignature; // e.g. "4/4", "3/4", "6/8"
  final List<SubdivisionConfig> subdivisions;
  final String colorHex; // UI color for visual identification
  final List<String> tags; // user tags for filtering/search
  final DateTime createdAt;
  final DateTime updatedAt;

  Pattern({
    String? id,
    required this.name,
    this.description = '',
    required this.beats,
    required this.steps,
    this.timeSignature = '4/4',
    List<SubdivisionConfig>? subdivisions,
    this.colorHex = '#F98533',
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        subdivisions = subdivisions ?? [],
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Pattern copyWith({
    String? id,
    String? name,
    String? description,
    int? beats,
    List<int>? steps,
    String? timeSignature,
    List<SubdivisionConfig>? subdivisions,
    String? colorHex,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Pattern(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      beats: beats ?? this.beats,
      steps: steps ?? List<int>.from(this.steps),
      timeSignature: timeSignature ?? this.timeSignature,
      subdivisions: subdivisions ?? this.subdivisions.map((s) => s.copyWith()).toList(),
      colorHex: colorHex ?? this.colorHex,
      tags: tags ?? List<String>.from(this.tags),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'beats': beats,
    'steps': steps,
    'timeSignature': timeSignature,
    'subdivisions': subdivisions.map((s) => s.toJson()).toList(),
    'colorHex': colorHex,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Pattern.fromJson(Map<String, dynamic> json) {
    return Pattern(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      beats: json['beats'] as int,
      steps: List<int>.from(json['steps']),
      timeSignature: json['timeSignature'] as String? ?? '4/4',
      subdivisions: (json['subdivisions'] as List<dynamic>?)
              ?.map((s) => SubdivisionConfig.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      colorHex: json['colorHex'] as String? ?? '#F98533',
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
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
      other is Pattern && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Pattern(id: $id, name: $name, beats: $beats, timeSignature: $timeSignature)';
}
