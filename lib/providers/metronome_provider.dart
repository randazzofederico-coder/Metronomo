import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:native_audio_engine/live_mixer.dart';

class HomeMetronomePulse {
  List<int> subdivisions;
  double durationRatio;
  HomeMetronomePulse([List<int>? subdivisions, this.durationRatio = 1.0]) : subdivisions = subdivisions ?? [0];
}

class HomeMetronomeInstance {
  final int id;
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
  }) : pulses = pulses ?? _parseStructureInitial(structure); 

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
          
          // durationRatio per pulse: if ratio specified, each pulse = ratio/count beats
          // otherwise each pulse = 1 beat
          double pulseDuration = (ratio > 0) ? ratio / count : 1.0;
          
          for (int i = 0; i < count; i++) {
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
  
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _bpm = 120;
  int get bpm => _bpm;
  
  final List<HomeMetronomeInstance> _instances = [];
  List<HomeMetronomeInstance> get instances => _instances;

  int _nextId = 1;

  final List<DateTime> _tapTimes = [];

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
    
    // Add defaults: Birritmia (3/4 vs 6/8)
    // Patrón 1: 3/2 — 3 pulses, each subdivided in 2 = [0,0, 2,0, 2,0]
    addInstance(
      title: "3/4",
      structure: "3/2",
      pulses: [
        HomeMetronomePulse([0, 0]),  // Beat 1: silent
        HomeMetronomePulse([2, 0]),  // Beat 2: secondary accent + silent
        HomeMetronomePulse([2, 0]),  // Beat 3: secondary accent + silent
      ],
    );
    // Patrón 2: 2:3/3 — 2 pulses in time of 3, each subdivided in 3 = [1,0,0, 1,0,0]
    addInstance(
      title: "6/8",
      structure: "2:3/3",
      pulses: [
        HomeMetronomePulse([1, 0, 0], 1.5),  // Beat 1: primary accent + 2 silent (spans 1.5 beats)
        HomeMetronomePulse([1, 0, 0], 1.5),  // Beat 2: primary accent + 2 silent (spans 1.5 beats)
      ],
    );
  }
  
  void addInstance({required String title, String structure = "4", List<HomeMetronomePulse>? pulses}) {
    final instance = HomeMetronomeInstance(id: _nextId++, title: title, structure: structure, pulses: pulses);
    _instances.add(instance);
    
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
    notifyListeners();
  }
  
  void removeInstance(int id) {
    _instances.removeWhere((i) => i.id == id);
    _liveMixer.removeMetronomePattern(id);
    notifyListeners();
  }
  
  void updateInstancePulses(int id, List<HomeMetronomePulse> pulses) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.pulses = pulses;
     _syncInstanceToEngine(instance);
     notifyListeners();
  }

  void addPulse(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.pulses.add(HomeMetronomePulse([0])); // Add empty beat
     _syncInstanceToEngine(instance);
     notifyListeners();
  }

  void removePulse(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     if (instance.pulses.length > 1) {
         instance.pulses.removeLast();
         _syncInstanceToEngine(instance);
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

          double pulseDuration = (ratio > 0) ? ratio / count : 1.0;

          for (int i = 0; i < count; i++) {
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
      _syncInstanceToEngine(instance);
      notifyListeners();
  }
  
  void updateInstanceVolume(int id, double volume) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.volume = volume;
     _syncInstanceToEngine(instance);
     notifyListeners();
  }
  
  void toggleInstanceMute(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.isMuted = !instance.isMuted;
     _syncInstanceToEngine(instance);
     notifyListeners();
  }
  
  void toggleInstanceSolo(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.isSolo = !instance.isSolo;
     _syncInstanceToEngine(instance);
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

  void updateBPM(int newBpm) {
    _bpm = newBpm.clamp(1, 999);
    _liveMixer.setMetronomeConfig(_bpm);
    notifyListeners();
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
    return cycleLengths.fold(cycleLengths.first, (a, b) => _lcm(a, b));
  }

  double get currentMacroProgress {
    if (!_isPlaying && _liveMixer.getAtomicPosition() == 0) return 0.0;
    
    double framesPerBeat = (44100.0 * 60.0) / _bpm;
    int pos = _liveMixer.getAtomicPosition();
    double currentBeatInTotal = pos / framesPerBeat;
    
    int macroBeats = macroCycleBeats;
    double progress = (currentBeatInTotal % macroBeats) / macroBeats;
    
    return progress;
  }

  @override
  void dispose() {
    _liveMixer.dispose();
    super.dispose();
  }
}
