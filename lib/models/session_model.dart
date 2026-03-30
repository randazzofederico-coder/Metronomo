import 'package:uuid/uuid.dart';

/// Configuration for a single pattern within a session.
///
/// Each pattern in a session has its own independent volume, mute and solo states,
/// plus an order index for arranging the sequence.
class SessionPatternConfig {
  final String patternId;
  final double volume;
  final bool isMuted;
  final bool isSolo;
  final int orderIndex;

  SessionPatternConfig({
    required this.patternId,
    this.volume = 1.0,
    this.isMuted = false,
    this.isSolo = false,
    this.orderIndex = 0,
  });

  SessionPatternConfig copyWith({
    String? patternId,
    double? volume,
    bool? isMuted,
    bool? isSolo,
    int? orderIndex,
  }) {
    return SessionPatternConfig(
      patternId: patternId ?? this.patternId,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, dynamic> toJson() => {
    'patternId': patternId,
    'volume': volume,
    'isMuted': isMuted,
    'isSolo': isSolo,
    'orderIndex': orderIndex,
  };

  factory SessionPatternConfig.fromJson(Map<String, dynamic> json) {
    return SessionPatternConfig(
      patternId: json['patternId'] as String,
      volume: (json['volume'] as num).toDouble(),
      isMuted: json['isMuted'] as bool? ?? false,
      isSolo: json['isSolo'] as bool? ?? false,
      orderIndex: json['orderIndex'] as int? ?? 0,
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
      isTrainingEnabled: isTrainingEnabled ?? this.isTrainingEnabled,
      trainingConfig: trainingConfig ?? this.trainingConfig.copyWith(),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'globalBpm': globalBpm,
    'patternsConfig': patternsConfig.map((p) => p.toJson()).toList(),
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
