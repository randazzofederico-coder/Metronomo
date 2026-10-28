import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:native_audio_engine/live_mixer.dart';

import '../models/pattern_model.dart';
import '../models/session_model.dart';
import '../providers/settings_provider.dart';
import '../services/working_state_repository.dart';

class HomeMetronomeInstance {
  final int id;
  String? originalPatternId;
  bool isDirty;
  List<HomeMetronomePulse> pulses;
  double volume;
  bool isMuted;
  bool isSolo;
  String title;
  String structure;

  HomeMetronomeInstance({
    required this.id,
    required this.title,
    this.structure = "4",
    List<HomeMetronomePulse>? pulses,
    this.volume = 0.8,
    this.isMuted = false,
    this.isSolo = false,
    this.originalPatternId,
    this.isDirty = false,
  }) : pulses = pulses ?? _parseStructureInitial(structure); 

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'structure': structure,
    'pulses': pulses.map((p) => p.toJson()).toList(),
    'volume': volume,
    'isMuted': isMuted,
    'isSolo': isSolo,
    'originalPatternId': originalPatternId,
    'isDirty': isDirty,
  };

  factory HomeMetronomeInstance.fromJson(Map<String, dynamic> json) {
    return HomeMetronomeInstance(
      id: json['id'] as int,
      title: json['title'] as String,
      structure: json['structure'] as String? ?? '4',
      pulses: (json['pulses'] as List<dynamic>)
          .map((p) => HomeMetronomePulse.fromJson(p as Map<String, dynamic>))
          .toList(),
      volume: (json['volume'] as num?)?.toDouble() ?? 0.8,
      isMuted: json['isMuted'] as bool? ?? false,
      isSolo: json['isSolo'] as bool? ?? false,
      originalPatternId: json['originalPatternId'] as String?,
      isDirty: json['isDirty'] as bool? ?? false,
    );
  }

  static List<HomeMetronomePulse> _parseStructureInitial(String struct) {
      final String cleaned = struct.replaceAll(' ', '');
      if (cleaned.isEmpty) return List.generate(4, (index) => HomeMetronomePulse([index == 0 ? 1 : 3]));
      
      final List<String> parts = cleaned.split('+');
      final List<HomeMetronomePulse> newPulses = [];
      for (String part in parts) {
          int count = 1;
          int ratio = 0;  // 0 means "not specified" => default to count
          int subdivision = 1;
          
          String remainder = part;
          
          // Parse optional :ratio
          if (remainder.contains(':')) {
              final ratioParts = remainder.split(':');
              count = int.tryParse(ratioParts[0]) ?? 1;
              remainder = ratioParts.length > 1 ? ratioParts[1] : '';
              // remainder might be "2" or "2/6"
              if (remainder.contains('/')) {
                  final subParts = remainder.split('/');
                  ratio = int.tryParse(subParts[0]) ?? count;
                  subdivision = int.tryParse(subParts[1]) ?? 1;
              } else {
                  ratio = int.tryParse(remainder) ?? count;
              }
          } else if (remainder.contains('/')) {
              final subParts = remainder.split('/');
              count = int.tryParse(subParts[0]) ?? 1;
              if (subParts.length > 1) subdivision = int.tryParse(subParts[1]) ?? 1;
          } else {
              count = int.tryParse(remainder) ?? 1;
          }
          
          if (count <= 0) count = 1;
          if (subdivision <= 0) subdivision = 1;
          // Clamp to safe limits
          count = count.clamp(1, 32);
          subdivision = subdivision.clamp(1, 12);
          if (ratio > 0) ratio = ratio.clamp(1, 64);
          
          // durationRatio per pulse: if ratio specified, each pulse = ratio/count beats
          // otherwise each pulse = 1 beat
          double pulseDuration = (ratio > 0) ? ratio / count : 1.0;
          
          for (int i = 0; i < count; i++) {
              if (newPulses.length >= 64) break; // Total pulse cap
              List<int> subdivList = List.generate(subdivision, (s) => 3);
              if (i == 0) {
                  subdivList[0] = 1; // Primary pulse head
              } else {
                  subdivList[0] = 2; // Secondary pulse head
              }
              newPulses.add(HomeMetronomePulse(subdivList, pulseDuration));
          }
      }
      return newPulses;
  }
}

class MetronomeProvider with ChangeNotifier {
  final LiveMixer _liveMixer = LiveMixer();
  final WorkingStateRepository _workingStateRepo = WorkingStateRepository();
  Timer? _debounceSaveTimer;
  
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _bpm = 60;
  int get bpm => _bpm;
  
  final List<HomeMetronomeInstance> _instances = [];
  List<HomeMetronomeInstance> get instances => _instances;

  int _nextId = 1;

  final List<DateTime> _tapTimes = [];

  String? activeSessionId;
  String? activeSessionName;
  bool _isSessionDirty = false;
  bool get isSessionDirty => _isSessionDirty;

  bool _initialized = false;
  bool get initialized => _initialized;

  void markSessionDirty() {
    if (!_isSessionDirty) {
      _isSessionDirty = true;
      notifyListeners();
    }
    _scheduleDebouncedSave();
  }

  /// Schedules a debounced save of the working state.
  /// Waits 500ms after the last change before persisting.
  void _scheduleDebouncedSave() {
    _debounceSaveTimer?.cancel();
    _debounceSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _persistWorkingState();
    });
  }

  /// Persists current working state to SharedPreferences.
  Future<void> _persistWorkingState() async {
    final state = <String, dynamic>{
      'bpm': _bpm,
      'instances': _instances.map((i) => i.toJson()).toList(),
      'nextId': _nextId,
      'activeSessionId': activeSessionId,
      'activeSessionName': activeSessionName,
      'isSessionDirty': _isSessionDirty,
    };
    await _workingStateRepo.saveWorkingState(state);
  }

  /// Explicitly saves working state (called from lifecycle handler).
  Future<void> saveWorkingState() async {
    _debounceSaveTimer?.cancel();
    await _persistWorkingState();
  }

  /// Initializes the metronome from persisted working state, or sets up
  /// the default state (pattern "1" at 60 BPM) on first launch.
  Future<void> initializeWorkingState(SettingsProvider settings) async {
    if (_initialized) return;
    _initialized = true;

    final state = await _workingStateRepo.loadWorkingState();

    if (state != null) {
      // Restore persisted working state
      _bpm = state['bpm'] as int? ?? 60;
      _nextId = state['nextId'] as int? ?? 1;
      activeSessionId = state['activeSessionId'] as String?;
      activeSessionName = state['activeSessionName'] as String?;
      _isSessionDirty = state['isSessionDirty'] as bool? ?? false;

      final instancesList = state['instances'] as List<dynamic>?;
      if (instancesList != null && instancesList.isNotEmpty) {
        for (final instJson in instancesList) {
          final instance = HomeMetronomeInstance.fromJson(
              instJson as Map<String, dynamic>);
          _instances.add(instance);
          _addInstanceToEngine(instance);
        }
      } else {
        // Persisted state but no instances — add default
        _addDefaultInstance();
      }

      _liveMixer.setMetronomeConfig(_bpm);
    } else {
      // First launch — set up default state
      _addDefaultInstance();
    }

    notifyListeners();
  }

  /// Adds the default "1" pattern instance at current BPM.
  void _addDefaultInstance() {
    final instance = HomeMetronomeInstance(
      id: _nextId++,
      title: 'Patrón 1',
      structure: '1',
    );
    _instances.add(instance);
    _addInstanceToEngine(instance);
  }

  /// Clears everything and resets to the default state (pattern "1" at 60 BPM).
  void newSession() {
    stop();
    for (var inst in _instances) {
      _liveMixer.removeMetronomePattern(inst.id);
    }
    _instances.clear();
    activeSessionId = null;
    activeSessionName = null;
    _isSessionDirty = false;
    _bpm = 60;
    _liveMixer.setMetronomeConfig(_bpm);
    _addDefaultInstance();
    _scheduleDebouncedSave();
    notifyListeners();
  }

  MetronomeProvider() {
    _initEngine();
  }

  Future<void> _initEngine() async {
    if (kIsWeb) {
      try {
        await (_liveMixer as dynamic).init();
      } catch (e) {
        debugPrint("MetronomeProvider Web Initialization Error: $e");
      }
    }
    
    _liveMixer.setMetronomeSound(0, _generateClickSound(1000.0));
    _liveMixer.setMetronomeSound(1, _generateClickSound(600.0));
    _liveMixer.setMetronomeSound(2, _generateClickSound(800.0));
    _liveMixer.setMetronomeConfig(_bpm);
    _liveMixer.setMasterVolume(1.0);
    _liveMixer.setMetronomePreviewMode(true); // Always isolated preview mode
    _liveMixer.setRandomSilencePercent(0.0);
  }
  
  void addInstance({required String title, String structure = "4", List<HomeMetronomePulse>? pulses, String? originalPatternId, bool isDirty = false}) {
    final instance = HomeMetronomeInstance(id: _nextId++, title: title, structure: structure, pulses: pulses, originalPatternId: originalPatternId, isDirty: isDirty);
    _instances.add(instance);
    _addInstanceToEngine(instance);
    markSessionDirty(); // Session mixture changed
    notifyListeners();
  }
  
  void _addInstanceToEngine(HomeMetronomeInstance instance) {
    final flatPattern = <int>[];
    final subdivisions = <int>[];
    final durationRatios = <double>[];
    for (var pulse in instance.pulses) {
        subdivisions.add(pulse.subdivisions.length);
        flatPattern.addAll(pulse.subdivisions);
        durationRatios.add(pulse.durationRatio);
    }
    
    _liveMixer.addMetronomePattern(
        instance.id, 
        flatPattern,
        subdivisions,
        durationRatios,
        instance.volume, 
        instance.isMuted, 
        instance.isSolo
    );
  }
  
  void removeInstance(int id) {
    _instances.removeWhere((i) => i.id == id);
    _liveMixer.removeMetronomePattern(id);
    markSessionDirty(); // Session composition changed
    notifyListeners();
  }
  
  void updateInstancePulses(int id, List<HomeMetronomePulse> pulses) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.pulses = pulses;
     instance.isDirty = true;
     _syncInstanceToEngine(instance);
     markSessionDirty();
     notifyListeners();
  }

  void addPulse(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.pulses.add(HomeMetronomePulse([0])); // Add empty beat
     instance.isDirty = true;
     _syncInstanceToEngine(instance);
     markSessionDirty();
     notifyListeners();
  }

  void removePulse(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     if (instance.pulses.length > 1) {
         instance.pulses.removeLast();
         instance.isDirty = true;
         _syncInstanceToEngine(instance);
         markSessionDirty();
         notifyListeners();
     }
  }
  
  void updateInstanceStructure(int id, String structureString) {
      final String cleaned = structureString.replaceAll(' ', '');
      if (cleaned.isEmpty) return;

      final List<String> parts = cleaned.split('+');
      final List<HomeMetronomePulse> newPulses = [];

      for (String part in parts) {
          int count = 1;
          int ratio = 0;
          int subdivision = 1;
          
          String remainder = part;
          
          // Parse optional :ratio
          if (remainder.contains(':')) {
              final ratioParts = remainder.split(':');
              count = int.tryParse(ratioParts[0]) ?? 1;
              remainder = ratioParts.length > 1 ? ratioParts[1] : '';
              if (remainder.contains('/')) {
                  final subParts = remainder.split('/');
                  ratio = int.tryParse(subParts[0]) ?? count;
                  subdivision = int.tryParse(subParts[1]) ?? 1;
              } else {
                  ratio = int.tryParse(remainder) ?? count;
              }
          } else if (remainder.contains('/')) {
              final subParts = remainder.split('/');
              count = int.tryParse(subParts[0]) ?? 1;
              if (subParts.length > 1) subdivision = int.tryParse(subParts[1]) ?? 1;
          } else {
              count = int.tryParse(remainder) ?? 1;
          }
          
          if (count <= 0) count = 1;
          if (subdivision <= 0) subdivision = 1;
          // Clamp to safe limits
          count = count.clamp(1, 32);
          subdivision = subdivision.clamp(1, 12);
          if (ratio > 0) ratio = ratio.clamp(1, 64);

          double pulseDuration = (ratio > 0) ? ratio / count : 1.0;

          for (int i = 0; i < count; i++) {
              if (newPulses.length >= 64) break; // Total pulse cap
              List<int> subdivList = List.generate(subdivision, (s) => 3);
              if (i == 0) {
                  subdivList[0] = 1;
              } else {
                  subdivList[0] = 2;
              }
              newPulses.add(HomeMetronomePulse(subdivList, pulseDuration));
          }
      }

      final instance = _instances.firstWhere((i) => i.id == id);
      instance.structure = cleaned;
      instance.pulses = newPulses;
      instance.isDirty = true;
      _syncInstanceToEngine(instance);
      markSessionDirty();
      notifyListeners();
  }

  void renameInstance(int id, String newTitle) {
    final instance = _instances.firstWhere((i) => i.id == id);
    if (instance.title != newTitle) {
        instance.title = newTitle;
        instance.isDirty = true;
        markSessionDirty();
        notifyListeners();
    }
  }

  void markInstanceClean(int id, String newOriginalPatternId) {
    final instance = _instances.firstWhere((i) => i.id == id);
    instance.isDirty = false;
    instance.originalPatternId = newOriginalPatternId;
    notifyListeners();
  }
  
  void updateInstanceVolume(int id, double volume) {
     final instance = _instances.firstWhere((i) => i.id == id);
     if (instance.volume != volume) {
         instance.volume = volume;
         _syncInstanceToEngine(instance);
         markSessionDirty();
         notifyListeners();
     }
  }
  
  void toggleInstanceMute(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.isMuted = !instance.isMuted;
     _syncInstanceToEngine(instance);
     markSessionDirty();
     notifyListeners();
  }
  
  void toggleInstanceSolo(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.isSolo = !instance.isSolo;
     _syncInstanceToEngine(instance);
     markSessionDirty();
     notifyListeners();
  }
  
  void _syncInstanceToEngine(HomeMetronomeInstance instance) {
      final flatPattern = <int>[];
      final subdivisions = <int>[];
      final durationRatios = <double>[];
      for (var pulse in instance.pulses) {
          subdivisions.add(pulse.subdivisions.length);
          flatPattern.addAll(pulse.subdivisions);
          durationRatios.add(pulse.durationRatio);
      }
      
      _liveMixer.updateMetronomePattern(
         instance.id, 
         flatPattern, 
         subdivisions,
         durationRatios,
         instance.volume, 
         instance.isMuted, 
         instance.isSolo
      );
  }

  void setRandomSilencePercent(double percent) {
    _liveMixer.setRandomSilencePercent(percent);
    markSessionDirty();
  }

  void updateBPM(int newBpm) {
    if (_bpm != newBpm) {
        _bpm = newBpm.clamp(1, 999);
        _liveMixer.setMetronomeConfig(_bpm);
        markSessionDirty();
        notifyListeners();
    }
  }

  void tapTempo() {
    final now = DateTime.now();
    
    // Ignore stales: If it's been more than 2 seconds since the last tap, start fresh
    if (_tapTimes.isNotEmpty && now.difference(_tapTimes.last).inSeconds > 2) {
      _tapTimes.clear();
    }
    
    _tapTimes.add(now);
    
    if (_tapTimes.length > 4) {
      _tapTimes.removeAt(0);
    }
    
    if (_tapTimes.length >= 2) {
      final intervals = <int>[];
      for (int i = 1; i < _tapTimes.length; i++) {
        intervals.add(_tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds);
      }
      
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      if (avgInterval > 0) {
        int newBpm = (60000 / avgInterval).round();
        updateBPM(newBpm);
      }
    }
  }

  void togglePlay() {
    if (_isPlaying) {
      stop();
    } else {
      play();
    }
  }

  void play() {
    _isPlaying = true;
    _liveMixer.seek(0);
    _liveMixer.startPlayback();
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    _liveMixer.stopPlayback();
    _liveMixer.seek(0);
    notifyListeners();
  }

  void updateSoundSet(String setName) {
    if (setName == "Woodblock") {
      _liveMixer.setMetronomeSound(0, _generateWoodblockSound(1200.0));
      _liveMixer.setMetronomeSound(1, _generateWoodblockSound(800.0));
      _liveMixer.setMetronomeSound(2, _generateWoodblockSound(1000.0));
    } else if (setName == "Digital") {
      _liveMixer.setMetronomeSound(0, _generateDigitalSound(1500.0));
      _liveMixer.setMetronomeSound(1, _generateDigitalSound(800.0));
      _liveMixer.setMetronomeSound(2, _generateDigitalSound(1200.0));
    } else {
      _liveMixer.setMetronomeSound(0, _generateClickSound(1000.0));
      _liveMixer.setMetronomeSound(1, _generateClickSound(600.0));
      _liveMixer.setMetronomeSound(2, _generateClickSound(800.0));
    }
  }

  Float32List _generateClickSound(double freq) {
      final int sampleRate = 44100;
      final double durationFreq = 0.05; // 50ms click
      final int samples = (sampleRate * durationFreq).toInt();
      final Float32List buffer = Float32List(samples);
      
      for (int i = 0; i < samples; i++) {
          final double t = i / sampleRate;
          final double envelope = exp(-i / (samples * 0.2)); 
          buffer[i] = (sin(2 * pi * freq * t) * envelope * 0.5); 
      }
      return buffer;
  }

  Float32List _generateWoodblockSound(double freq) {
      final int sampleRate = 44100;
      final double durationFreq = 0.08; 
      final int samples = (sampleRate * durationFreq).toInt();
      final Float32List buffer = Float32List(samples);
      
      for (int i = 0; i < samples; i++) {
          final double t = i / sampleRate;
          // Fast decay for woodblock transient
          final double envelope = exp(-t * 80.0); 
          // Carrier + Modulator
          double val = sin(2 * pi * freq * t + 0.5 * sin(2 * pi * (freq * 1.5) * t));
          buffer[i] = val * envelope * 0.8; 
      }
      return buffer;
  }

  Float32List _generateDigitalSound(double freq) {
      final int sampleRate = 44100;
      final double durationFreq = 0.05; 
      final int samples = (sampleRate * durationFreq).toInt();
      final Float32List buffer = Float32List(samples);
      
      for (int i = 0; i < samples; i++) {
          final double t = i / sampleRate;
          final double envelope = exp(-i / (samples * 0.2)); 
          // Square wave logic for "Digital" sound
          double val = sin(2 * pi * freq * t) > 0 ? 0.5 : -0.5;
          buffer[i] = val * envelope * 0.5; 
      }
      return buffer;
  }

  // --- MACRO CYCLE MATH ---
  int _gcd(int a, int b) {
    while (b != 0) {
      int t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  int _lcm(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return ((a * b) / _gcd(a, b)).floor();
  }

  double _cycleDurationBeats(HomeMetronomeInstance instance) {
    double sum = 0.0;
    for (var pulse in instance.pulses) {
      sum += pulse.durationRatio;
    }
    return sum > 0 ? sum : 1.0;
  }

  int get macroCycleBeats {
    if (_instances.isEmpty) return 4;
    // Cycle duration per instance is always integer (sum of ratio values from parser)
    List<int> cycleLengths = _instances.map((i) => _cycleDurationBeats(i).round()).toList();
    return cycleLengths.fold(cycleLengths.first, (a, b) => _lcm(a, b)).clamp(1, 256);
  }

  double get currentMacroProgress {
    if (!_isPlaying && _liveMixer.getAtomicPosition() == 0) return 0.0;
    
    final int sampleRate = _liveMixer.getSampleRate();
    double framesPerBeat = (sampleRate.toDouble() * 60.0) / _bpm;
    int pos = _liveMixer.getAtomicPosition();
    double currentBeatInTotal = pos / framesPerBeat;
    
    int macroBeats = macroCycleBeats;
    double progress = (currentBeatInTotal % macroBeats) / macroBeats;
    
    return progress;
  }

  // ─────────────────────────────────────────────────────
  //  SESSION AND PATTERN EXPORT / IMPORT
  // ─────────────────────────────────────────────────────

  /// Loads a Pattern into the metronome as a new instance.
  void loadPattern(Pattern pattern) {
    int newId = _nextId++;
    final instance = HomeMetronomeInstance(
        id: newId, 
        title: pattern.name, 
        structure: pattern.structure, 
        pulses: pattern.pulses.map((p) => p.copyWith()).toList(),
        originalPatternId: pattern.id,
        isDirty: false,
    );
    _instances.add(instance);
    _addInstanceToEngine(instance);
    markSessionDirty();
    notifyListeners();
  }

  /// Creates a Pattern model from an existing instance to be saved.
  Pattern createPatternFromInstance(int id, {required String name, String description = ''}) {
    final instance = _instances.firstWhere((i) => i.id == id);
    return Pattern(
        id: instance.originalPatternId, // Re-use the existing ID to overwrite if available
        name: name,
        description: description,
        structure: instance.structure,
        pulses: instance.pulses.map((p) => p.copyWith()).toList(),
    );
  }

  void markSessionClean(String sessionId, String sessionName) {
    activeSessionId = sessionId;
    activeSessionName = sessionName;
    _isSessionDirty = false;
    _scheduleDebouncedSave();
    notifyListeners();
  }

  void clearSession() {
    newSession();
  }

  /// Starts a fresh, untitled session containing only [pattern].
  /// Used when opening a pattern received through a shared link.
  void newSessionWithPattern(Pattern pattern) {
    newSession();
    for (var inst in _instances) {
      _liveMixer.removeMetronomePattern(inst.id);
    }
    _instances.clear();
    loadPattern(pattern); // marks the new session dirty ("Sin Título *")
  }

  /// Clears current metronome and loads a full Session.
  Future<void> loadSession(
    Session session, 
    SettingsProvider settings, {
    required Future<Pattern?> Function(String patternId) getPatternById
  }) async {
    stop();
    // clear all instances efficiently without triggering listeners inside the loop
    for (var inst in _instances) {
        _liveMixer.removeMetronomePattern(inst.id);
    }
    _instances.clear();
    
    activeSessionId = session.id;
    activeSessionName = session.name;
    _isSessionDirty = false;
    
    updateBPM(session.globalBpm);
    settings.updateSound(session.soundSet);
    settings.updateSilence(session.randomSilencePercentage);
    updateSoundSet(session.soundSet);
    
    // Sort configurations by orderIndex
    final configs = List<SessionPatternConfig>.from(session.patternsConfig)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      
    for (var config in configs) {
       Pattern? pattern = await getPatternById(config.patternId);
       if (pattern != null) {
          int newId = _nextId++;
          final instance = HomeMetronomeInstance(
              id: newId, 
              title: pattern.name, 
              structure: pattern.structure, 
              pulses: pattern.pulses.map((p) => p.copyWith()).toList(),
              volume: config.volume,
              isMuted: config.isMuted,
              isSolo: config.isSolo,
              originalPatternId: config.patternId,
              isDirty: false,
          );
          _instances.add(instance);
          _addInstanceToEngine(instance);
       }
    }
    // We intentionally do not markSessionDirty here since we just loaded a clean session
    _scheduleDebouncedSave();
    notifyListeners();
  }

  /// Creates a Session model capturing the current state.
  Future<Session> createSession(
    String name, 
    String description, 
    SettingsProvider settings, {
    required Future<String> Function(HomeMetronomeInstance instance) ensurePatternSaved
  }) async {
     List<SessionPatternConfig> patternsConfig = [];
     for (int i = 0; i < _instances.length; i++) {
        final instance = _instances[i];
        String patternId = await ensurePatternSaved(instance);
        patternsConfig.add(SessionPatternConfig(
           patternId: patternId,
           volume: instance.volume,
           isMuted: instance.isMuted,
           isSolo: instance.isSolo,
           orderIndex: i,
        ));
     }
     
     return Session(
         name: name,
         description: description,
         globalBpm: _bpm,
         patternsConfig: patternsConfig,
         soundSet: settings.selectedSound,
         randomSilencePercentage: settings.randomSilencePercentage,
     );
  }

  @override
  void dispose() {
    _debounceSaveTimer?.cancel();
    _liveMixer.dispose();
    super.dispose();
  }
}
