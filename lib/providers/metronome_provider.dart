import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:native_audio_engine/live_mixer.dart';
import 'package:uuid/uuid.dart';

import '../audio/click_synth.dart';
import '../models/pattern_model.dart';
import '../models/session_model.dart';
import '../providers/settings_provider.dart';
import '../services/working_state_repository.dart';

const _uuid = Uuid();

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

  /// Sound set override for this pattern (see [ClickSynth.soundSets]).
  /// `null` = follows the global sound set.
  String? soundSet;

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
    this.soundSet,
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
    'soundSet': soundSet,
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
      soundSet: json['soundSet'] == null ? null : ClickSynth.normalize(json['soundSet'] as String),
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

  /// Currently loaded click sound set (see [ClickSynth.soundSets]).
  /// Used by every pattern without its own sound override.
  String _currentSoundSet = ClickSynth.defaultSoundSet;
  String get currentSoundSet => _currentSoundSet;

  /// Engine sound banks already loaded (bank index = index in [ClickSynth.soundSets]).
  final Set<int> _loadedSoundBanks = {};

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
    
    _loadedSoundBanks.clear(); // anything sent before the engine was ready was dropped
    updateSoundSet(_currentSoundSet);
    // Instances restored/created while the engine was still initializing
    // (e.g. the working state loaded at startup on web) were dropped too:
    // register them again. Remove first in case some did make it.
    for (final inst in _instances) {
      _liveMixer.removeMetronomePattern(inst.id);
      _addInstanceToEngine(inst); // also applies the instance sound
    }
    _liveMixer.setMetronomeConfig(_bpm);
    _liveMixer.setMasterVolume(1.0);
    _liveMixer.setMetronomePreviewMode(true); // Always isolated preview mode
    _liveMixer.setRandomSilencePercent(0.0);
  }
  
  void addInstance({required String title, String structure = "4", List<HomeMetronomePulse>? pulses, String? originalPatternId, bool isDirty = false, String? soundSet}) {
    final instance = HomeMetronomeInstance(id: _nextId++, title: title, structure: structure, pulses: pulses, originalPatternId: originalPatternId, isDirty: isDirty, soundSet: soundSet);
    _instances.add(instance);
    _addInstanceToEngine(instance);
    markSessionDirty(); // Session mixture changed
    notifyListeners();
  }
  
  void _addInstanceToEngine(HomeMetronomeInstance instance) {
    final flat = _flattenPulses(instance.pulses);
    _liveMixer.addMetronomePattern(
        instance.id, 
        flat.pattern,
        flat.subdivisions,
        flat.durationRatios,
        instance.volume, 
        instance.isMuted, 
        instance.isSolo,
        eventVolumes: flat.volumes,
    );
    _applyInstanceSound(instance);
  }

  /// Flattens pulses into the parallel arrays expected by the audio engine.
  static ({List<int> pattern, List<int> subdivisions, List<double> durationRatios, List<double> volumes}) _flattenPulses(List<HomeMetronomePulse> pulses) {
    final pattern = <int>[];
    final subdivisions = <int>[];
    final durationRatios = <double>[];
    final volumes = <double>[];
    for (final pulse in pulses) {
      pulse.syncVolumes();
      subdivisions.add(pulse.subdivisions.length);
      pattern.addAll(pulse.subdivisions);
      volumes.addAll(pulse.volumes);
      durationRatios.add(pulse.durationRatio);
    }
    return (pattern: pattern, subdivisions: subdivisions, durationRatios: durationRatios, volumes: volumes);
  }
  
  void removeInstance(int id) {
    _instances.removeWhere((i) => i.id == id);
    _liveMixer.removeMetronomePattern(id);
    markSessionDirty(); // Session composition changed
    notifyListeners();
  }

  /// Re-inserts a previously removed [instance] at [index] (undo of
  /// [removeInstance]). Keeps its original id.
  void restoreInstance(HomeMetronomeInstance instance, int index) {
    if (_instances.any((i) => i.id == instance.id)) return;
    _instances.insert(index.clamp(0, _instances.length), instance);
    _addInstanceToEngine(instance);
    markSessionDirty();
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

      final List<HomeMetronomePulse> newPulses = HomeMetronomeInstance._parseStructureInitial(cleaned);

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
      final flat = _flattenPulses(instance.pulses);
      _liveMixer.updateMetronomePattern(
         instance.id, 
         flat.pattern, 
         flat.subdivisions,
         flat.durationRatios,
         instance.volume, 
         instance.isMuted, 
         instance.isSolo,
         eventVolumes: flat.volumes,
      );
  }

  /// Sets the volume (0.0–1.5, i.e. 0–150%) of a single event of a pattern.
  void updateEventVolume(int id, int pulseIndex, int subIndex, double volume) {
      final instance = _instances.firstWhere((i) => i.id == id);
      final pulse = instance.pulses[pulseIndex];
      pulse.syncVolumes();
      final clamped = volume.clamp(HomeMetronomePulse.minEventVolume, HomeMetronomePulse.maxEventVolume).toDouble();
      if (pulse.volumes[subIndex] == clamped) return;
      pulse.volumes[subIndex] = clamped;
      instance.isDirty = true;
      _syncInstanceToEngine(instance);
      markSessionDirty();
      notifyListeners();
  }

  /// Sets the random-silence percentage in the engine. [markDirty] is false
  /// when just syncing a stored value (startup, loading a session).
  void setRandomSilencePercent(double percent, {bool markDirty = true}) {
    _liveMixer.setRandomSilencePercent(percent);
    if (markDirty) markSessionDirty();
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

  /// Sets the global sound set (used by every pattern without its own override).
  void updateSoundSet(String setName) {
    _currentSoundSet = ClickSynth.normalize(setName);
    _ensureSoundBank(_currentSoundSet);
    for (final inst in _instances) {
      if (inst.soundSet == null) _applyInstanceSound(inst);
    }
    notifyListeners();
  }

  /// Sound set actually heard for [instance] (its override or the global one).
  String effectiveSoundSet(HomeMetronomeInstance instance) =>
      ClickSynth.normalize(instance.soundSet ?? _currentSoundSet);

  /// Assigns a sound set to a single pattern. `null` = follow the global sound set.
  void updateInstanceSoundSet(int id, String? setName) {
    final instance = _instances.firstWhere((i) => i.id == id);
    final normalized = setName == null ? null : ClickSynth.normalize(setName);
    if (instance.soundSet == normalized) return;
    instance.soundSet = normalized;
    _applyInstanceSound(instance);
    markSessionDirty();
    notifyListeners();
  }

  /// Makes sure the engine bank for [setName] is loaded and returns its index.
  /// Bank index = position in [ClickSynth.soundSets] (always < the engine's 16 banks).
  int _ensureSoundBank(String setName) {
    final name = ClickSynth.normalize(setName);
    final bank = ClickSynth.soundSets.indexOf(name);
    if (_loadedSoundBanks.add(bank)) {
      // Generate at the engine's real sample rate (e.g. 48 kHz on most web AudioContexts)
      final buffers = ClickSynth(_liveMixer.getSampleRate()).buildSet(name);
      for (var slot = 0; slot < buffers.length; slot++) {
        _liveMixer.setMetronomeBankSound(bank, slot, buffers[slot]);
      }
    }
    return bank;
  }

  /// Routes [instance] to the engine bank of its effective sound set.
  void _applyInstanceSound(HomeMetronomeInstance instance) {
    final bank = _ensureSoundBank(effectiveSoundSet(instance));
    _liveMixer.setMetronomePatternSoundBank(instance.id, bank);
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

  /// Playback position in beats since play started, or -1 when stopped.
  /// Used to highlight the event currently sounding in each pattern.
  double get currentBeatPosition {
    if (!_isPlaying) return -1;
    final int sampleRate = _liveMixer.getSampleRate();
    if (sampleRate <= 0 || _bpm <= 0) return -1;
    final double framesPerBeat = (sampleRate.toDouble() * 60.0) / _bpm;
    return _liveMixer.getAtomicPosition() / framesPerBeat;
  }

  /// Inserts a copy of the instance right after it (new pattern, not linked
  /// to the library).
  void duplicateInstance(int id) {
    final index = _instances.indexWhere((i) => i.id == id);
    if (index < 0) return;
    final src = _instances[index];
    final copy = HomeMetronomeInstance(
      id: _nextId++,
      title: '${src.title} (copia)',
      structure: src.structure,
      pulses: src.pulses.map((p) => p.copyWith()).toList(),
      volume: src.volume,
      isMuted: src.isMuted,
      isSolo: false,
      isDirty: true,
      soundSet: src.soundSet,
    );
    _instances.insert(index + 1, copy);
    _addInstanceToEngine(copy);
    markSessionDirty();
    notifyListeners();
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

  /// The library renamed a session: keep the title in sync if it's the open one.
  void onSessionRenamed(String sessionId, String newName) {
    if (activeSessionId != sessionId) return;
    activeSessionName = newName;
    _scheduleDebouncedSave();
    notifyListeners();
  }

  /// Marks the session as saved. Pattern dirty flags are cleared too: the
  /// session now holds their changes.
  void markSessionClean(String sessionId, String sessionName) {
    activeSessionId = sessionId;
    activeSessionName = sessionName;
    _isSessionDirty = false;
    for (final inst in _instances) {
      inst.isDirty = false;
    }
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

    // Apply the session's tempo/sound/silence without marking it dirty.
    _bpm = session.globalBpm.clamp(1, 999);
    _liveMixer.setMetronomeConfig(_bpm);
    settings.updateSound(session.soundSet);
    settings.updateSilence(session.randomSilencePercentage);
    updateSoundSet(session.soundSet);
    setRandomSilencePercent(session.randomSilencePercentage, markDirty: false);
    _isSessionDirty = false;
    
    // Sort configurations by orderIndex
    final configs = List<SessionPatternConfig>.from(session.patternsConfig)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      
    for (var config in configs) {
       // Embedded pattern (current format) or library lookup (legacy sessions).
       final Pattern? pattern = config.embeddedPattern ?? await getPatternById(config.patternId);
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
              soundSet: config.soundSet == null ? null : ClickSynth.normalize(config.soundSet),
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
  ///
  /// Patterns are embedded in the session (the library is not touched).
  /// Instances without a stable id get one, so the same pattern keeps its id
  /// across saves and "save to library" can link to it.
  /// Doesn't change dirty flags: see [markSessionClean].
  Session createSession(
    String name, 
    String description, 
    SettingsProvider settings,
  ) {
     List<SessionPatternConfig> patternsConfig = [];
     for (int i = 0; i < _instances.length; i++) {
        final instance = _instances[i];
        instance.originalPatternId ??= _uuid.v4();
        patternsConfig.add(SessionPatternConfig(
           patternId: instance.originalPatternId!,
           volume: instance.volume,
           isMuted: instance.isMuted,
           isSolo: instance.isSolo,
           orderIndex: i,
           soundSet: instance.soundSet,
           name: instance.title,
           structure: instance.structure,
           pulses: instance.pulses.map((p) => p.copyWith()).toList(),
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
