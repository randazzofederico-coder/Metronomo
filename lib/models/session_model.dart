import 'package:uuid/uuid.dart';

import 'pattern_model.dart';

/// Configuration for a single pattern within a session.
///
/// Each pattern in a session has its own independent volume, mute and solo states,
/// an optional sound set, plus an order index for arranging the sequence.
///
/// The session **embeds** the pattern itself ([name], [structure], [pulses]),
/// so it doesn't depend on the pattern library: deleting or editing a library
/// pattern never changes a saved session. [patternId] is a stable id for the
/// pattern inside the session; if a library pattern has the same id, saving
/// the pattern to the library updates that one.
///
/// Legacy sessions (before embedding) only have [patternId]: they are resolved
/// against the library and migrated (see [Session.withEmbeddedPatterns]).
class SessionPatternConfig {
  final String patternId;
  final double volume;
  final bool isMuted;
  final bool isSolo;
  final int orderIndex;

  /// Sound set used by this pattern (see `ClickSynth.soundSets`).
  /// `null` = follows the session's global sound set.
  final String? soundSet;

  /// Embedded pattern data (null in legacy sessions).
  final String? name;
  final String? structure;
  final List<HomeMetronomePulse>? pulses;

  SessionPatternConfig({
    required this.patternId,
    this.volume = 1.0,
    this.isMuted = false,
    this.isSolo = false,
    this.orderIndex = 0,
    this.soundSet,
    this.name,
    this.structure,
    this.pulses,
  });

  /// True if the pattern data is stored in the session itself.
  bool get hasEmbeddedPattern => structure != null && pulses != null;

  /// The embedded pattern as a [Pattern] (id = [patternId]), or null for
  /// legacy configs.
  Pattern? get embeddedPattern => hasEmbeddedPattern
      ? Pattern(
          id: patternId,
          name: name ?? 'Patrón',
          structure: structure!,
          pulses: pulses!.map((p) => p.copyWith()).toList(),
        )
      : null;

  /// Returns a copy with [pattern] embedded (keeps [patternId]).
  SessionPatternConfig embedding(Pattern pattern) => copyWith(
        name: pattern.name,
        structure: pattern.structure,
        pulses: pattern.pulses.map((p) => p.copyWith()).toList(),
      );

  static const Object _unset = Object();

  /// Pass `soundSet: null` explicitly to reset the pattern to the session's sound.
  SessionPatternConfig copyWith({
    String? patternId,
    double? volume,
    bool? isMuted,
    bool? isSolo,
    int? orderIndex,
    Object? soundSet = _unset,
    String? name,
    String? structure,
    List<HomeMetronomePulse>? pulses,
  }) {
    return SessionPatternConfig(
      patternId: patternId ?? this.patternId,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
      orderIndex: orderIndex ?? this.orderIndex,
      soundSet: identical(soundSet, _unset) ? this.soundSet : soundSet as String?,
      name: name ?? this.name,
      structure: structure ?? this.structure,
      pulses: pulses ?? this.pulses?.map((p) => p.copyWith()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'patternId': patternId,
    'volume': volume,
    'isMuted': isMuted,
    'isSolo': isSolo,
    'orderIndex': orderIndex,
    // Only persisted when overridden, so untouched sessions keep the legacy format.
    if (soundSet != null) 'soundSet': soundSet,
    if (name != null) 'name': name,
    if (structure != null) 'structure': structure,
    if (pulses != null) 'pulses': pulses!.map((p) => p.toJson()).toList(),
  };

  factory SessionPatternConfig.fromJson(Map<String, dynamic> json) {
    return SessionPatternConfig(
      patternId: json['patternId'] as String,
      volume: (json['volume'] as num).toDouble(),
      isMuted: json['isMuted'] as bool? ?? false,
      isSolo: json['isSolo'] as bool? ?? false,
      orderIndex: json['orderIndex'] as int? ?? 0,
      soundSet: json['soundSet'] as String?,
      name: json['name'] as String?,
      structure: json['structure'] as String?,
      pulses: (json['pulses'] as List<dynamic>?)
          ?.map((p) => HomeMetronomePulse.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionPatternConfig &&
          runtimeType == other.runtimeType &&
          patternId == other.patternId &&
          orderIndex == other.orderIndex;

  @override
  int get hashCode => patternId.hashCode ^ orderIndex.hashCode;
}

/// Training configuration embedded inside a session.
class TrainingConfig {
  final int startBpm;
  final int endBpm;
  final int bpmIncrement;
  final int intervalSeconds; // seconds between each BPM increase

  const TrainingConfig({
    this.startBpm = 60,
    this.endBpm = 120,
    this.bpmIncrement = 5,
    this.intervalSeconds = 60,
  });

  TrainingConfig copyWith({
    int? startBpm,
    int? endBpm,
    int? bpmIncrement,
    int? intervalSeconds,
  }) {
    return TrainingConfig(
      startBpm: startBpm ?? this.startBpm,
      endBpm: endBpm ?? this.endBpm,
      bpmIncrement: bpmIncrement ?? this.bpmIncrement,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'startBpm': startBpm,
    'endBpm': endBpm,
    'bpmIncrement': bpmIncrement,
    'intervalSeconds': intervalSeconds,
  };

  factory TrainingConfig.fromJson(Map<String, dynamic> json) {
    return TrainingConfig(
      startBpm: json['startBpm'] as int? ?? 60,
      endBpm: json['endBpm'] as int? ?? 120,
      bpmIncrement: json['bpmIncrement'] as int? ?? 5,
      intervalSeconds: json['intervalSeconds'] as int? ?? 60,
    );
  }
}

/// Represents a session: an ordered collection of patterns with independent
/// mix configurations and optional training parameters.
class Session {
  final String id;
  final String name;
  final String description;
  final int globalBpm;
  final List<SessionPatternConfig> patternsConfig;
  final String soundSet;
  final double randomSilencePercentage;
  final bool isTrainingEnabled;
  final TrainingConfig trainingConfig;
  final DateTime createdAt;
  final DateTime updatedAt;

  Session({
    String? id,
    required this.name,
    this.description = '',
    required this.globalBpm,
    required this.patternsConfig,
    this.soundSet = 'Default',
    this.randomSilencePercentage = 0.0,
    this.isTrainingEnabled = false,
    TrainingConfig? trainingConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        trainingConfig = trainingConfig ?? const TrainingConfig(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Session copyWith({
    String? id,
    String? name,
    String? description,
    int? globalBpm,
    List<SessionPatternConfig>? patternsConfig,
    String? soundSet,
    double? randomSilencePercentage,
    bool? isTrainingEnabled,
    TrainingConfig? trainingConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      globalBpm: globalBpm ?? this.globalBpm,
      patternsConfig: patternsConfig ??
          this.patternsConfig.map((p) => p.copyWith()).toList(),
      soundSet: soundSet ?? this.soundSet,
      randomSilencePercentage: randomSilencePercentage ?? this.randomSilencePercentage,
      isTrainingEnabled: isTrainingEnabled ?? this.isTrainingEnabled,
      trainingConfig: trainingConfig ?? this.trainingConfig.copyWith(),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// True if some pattern still depends on the library (legacy format).
  bool get needsEmbedding => patternsConfig.any((c) => !c.hasEmbeddedPattern);

  /// Returns a copy where every legacy config gets its pattern embedded,
  /// resolved through [lookup] (usually the library). Configs whose pattern
  /// can't be found are kept as they are.
  Session withEmbeddedPatterns(Pattern? Function(String patternId) lookup) {
    if (!needsEmbedding) return this;
    return copyWith(
      updatedAt: updatedAt,
      patternsConfig: patternsConfig.map((c) {
        if (c.hasEmbeddedPattern) return c.copyWith();
        final pattern = lookup(c.patternId);
        return pattern == null ? c.copyWith() : c.embedding(pattern);
      }).toList(),
    );
  }

  /// The session's patterns as [Pattern] objects (one per distinct id).
  ///
  /// Shared links still include them in the bundle's `patterns` list so that
  /// older app versions (that resolve sessions through the library) can open
  /// links created by newer versions.
  List<Pattern> get embeddedPatterns {
    final seen = <String>{};
    return [
      for (final c in patternsConfig)
        if (seen.add(c.patternId) && c.embeddedPattern != null) c.embeddedPattern!,
    ];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'globalBpm': globalBpm,
    'patternsConfig': patternsConfig.map((p) => p.toJson()).toList(),
    'soundSet': soundSet,
    'randomSilencePercentage': randomSilencePercentage,
    'isTrainingEnabled': isTrainingEnabled,
    'trainingConfig': trainingConfig.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      globalBpm: json['globalBpm'] as int,
      patternsConfig: (json['patternsConfig'] as List)
          .map((p) => SessionPatternConfig.fromJson(p as Map<String, dynamic>))
          .toList(),
      soundSet: json['soundSet'] as String? ?? 'Default',
      randomSilencePercentage: (json['randomSilencePercentage'] as num?)?.toDouble() ?? 0.0,
      isTrainingEnabled: json['isTrainingEnabled'] as bool? ?? false,
      trainingConfig: json['trainingConfig'] != null
          ? TrainingConfig.fromJson(json['trainingConfig'] as Map<String, dynamic>)
          : const TrainingConfig(),
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
      other is Session && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Session(id: $id, name: $name, patterns: ${patternsConfig.length})';
}
