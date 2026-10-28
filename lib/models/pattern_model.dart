import 'package:uuid/uuid.dart';

/// Represents a single pulse (subdivisions and duration) in a pattern.
///
/// [volumes] holds a per-subdivision gain aligned with [subdivisions]
/// (1.0 = 100%, range [minEventVolume]..[maxEventVolume]).
class HomeMetronomePulse {
  static const double minEventVolume = 0.0;
  static const double maxEventVolume = 1.5;

  List<int> subdivisions;
  List<double> volumes;
  double durationRatio;

  HomeMetronomePulse([List<int>? subdivisions, this.durationRatio = 1.0, List<double>? volumes])
      : subdivisions = subdivisions ?? [0],
        volumes = <double>[] {
    final src = volumes ?? const <double>[];
    this.volumes = List<double>.generate(
      this.subdivisions.length,
      (i) => i < src.length ? src[i].clamp(minEventVolume, maxEventVolume).toDouble() : 1.0,
    );
  }

  /// Volume of subdivision [index] (defaults to 1.0 if out of range).
  double volumeAt(int index) => index < volumes.length ? volumes[index] : 1.0;

  /// Keeps [volumes] aligned with [subdivisions] (new slots default to 100%).
  void syncVolumes() {
    if (volumes.length == subdivisions.length) return;
    volumes = List<double>.generate(subdivisions.length, (i) => volumeAt(i));
  }

  Map<String, dynamic> toJson() {
    syncVolumes();
    return {
      'subdivisions': subdivisions,
      'durationRatio': durationRatio,
      // Only persisted when customized, so untouched patterns keep the legacy format.
      if (volumes.any((v) => v != 1.0)) 'volumes': volumes,
    };
  }

  factory HomeMetronomePulse.fromJson(Map<String, dynamic> json) {
    return HomeMetronomePulse(
      List<int>.from(json['subdivisions'] ?? [0]),
      (json['durationRatio'] as num?)?.toDouble() ?? 1.0,
      (json['volumes'] as List<dynamic>?)?.map((v) => (v as num).toDouble()).toList(),
    );
  }

  HomeMetronomePulse copyWith({List<int>? subdivisions, double? durationRatio, List<double>? volumes}) {
    return HomeMetronomePulse(
      subdivisions ?? List<int>.from(this.subdivisions),
      durationRatio ?? this.durationRatio,
      volumes ?? List<double>.from(this.volumes),
    );
  }
}

/// Represents a rhythmic pattern that can be saved in the global Pattern Library.
///
/// Each pattern defines its structure, a sequence of pulses, 
/// and visual/organizational metadata.
class Pattern {
  final String id;
  final String name;
  final String description;
  final String structure; // e.g. "4", "3/2", "2:3/3"
  final List<HomeMetronomePulse> pulses;
  final String colorHex; // UI color for visual identification
  final List<String> tags; // user tags for filtering/search
  final DateTime createdAt;
  final DateTime updatedAt;

  Pattern({
    String? id,
    required this.name,
    this.description = '',
    this.structure = "4",
    List<HomeMetronomePulse>? pulses,
    this.colorHex = '#F98533',
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        pulses = pulses ?? [],
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Pattern copyWith({
    String? id,
    String? name,
    String? description,
    String? structure,
    List<HomeMetronomePulse>? pulses,
    String? colorHex,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Pattern(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      structure: structure ?? this.structure,
      pulses: pulses ?? this.pulses.map((p) => p.copyWith()).toList(),
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
        'structure': structure,
        'pulses': pulses.map((p) => p.toJson()).toList(),
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
      structure: json['structure'] as String? ?? '4',
      pulses: (json['pulses'] as List<dynamic>?)
              ?.map((p) => HomeMetronomePulse.fromJson(p as Map<String, dynamic>))
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
  String toString() => 'Pattern(id: $id, name: $name, structure: $structure)';
}
