import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/screens/settings_screen.dart';
import 'package:metronomo_standalone/widgets/knob_control.dart';
import 'package:flutter/scheduler.dart';
import 'package:metronomo_standalone/providers/settings_provider.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> with WidgetsBindingObserver {
  // Focus management for custom keyboard
  int? _activePatternIdForKeyboard;
  final Map<int, TextEditingController> _structureControllers = {};
  bool _wasPlayingBeforeBackground = false;
  
  // Map Slider Value [0.0, 1.0] to BPM [1, 999]
  int _sliderToBpm(double val) {
    if (val <= 0.15) {
      return (1 + 29 * (val / 0.15)).round(); // 0.0 -> 1, 0.15 -> 30
    } else if (val <= 0.85) {
      return (30 + 220 * ((val - 0.15) / 0.70)).round(); // 0.15 -> 30, 0.85 -> 250
    } else {
      return (250 + 749 * ((val - 0.85) / 0.15)).round(); // 0.85 -> 250, 1.0 -> 999
    }
  }

  // Map BPM [1, 999] to Slider Value [0.0, 1.0]
  double _bpmToSlider(int bpm) {
    if (bpm <= 30) {
      return 0.15 * ((bpm - 1) / 29.0);
    } else if (bpm <= 250) {
      return 0.15 + 0.70 * ((bpm - 30) / 220.0);
    } else {
      return 0.85 + 0.15 * ((bpm - 250) / 749.0);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    
    final metronome = context.read<MetronomeProvider>();
    final settings = context.read<SettingsProvider>();

    if (state == AppLifecycleState.paused) {
      // App going to background
      if (!settings.backgroundPlayback && metronome.isPlaying) {
        _wasPlayingBeforeBackground = true;
        metronome.stop();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App returning to foreground
      if (_wasPlayingBeforeBackground) {
        _wasPlayingBeforeBackground = false;
        metronome.play();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (var controller in _structureControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('METRÓNOMO', style: TextStyle(letterSpacing: 2.0)),
        backgroundColor: AppColors.surface(context),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: AppColors.textSecondary(context)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Dismiss custom keyboard when tapping outside
            if (_activePatternIdForKeyboard != null) {
              setState(() {
                _activePatternIdForKeyboard = null;
              });
            }
          },
          child: Consumer<MetronomeProvider>(
            builder: (context, metronome, child) {
              return Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          children: [
                            _MacroCycleVisualizer(metronome: metronome),
                            const SizedBox(height: 8),
                            
                            // Dynamic Instances
                            ...metronome.instances.map((instance) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildMetronomeInstance(
                                  context: context,
                                  instance: instance,
                                  onStructureChange: (newStructure) => metronome.updateInstanceStructure(instance.id, newStructure),
                                  onPulseSubdivisionChange: (pulseIndex, subIndex, newType) {
                                      final newPulses = List<HomeMetronomePulse>.from(instance.pulses);
                                      newPulses[pulseIndex].subdivisions[subIndex] = newType;
                                      metronome.updateInstancePulses(instance.id, newPulses);
                                  },
                                  onVolChanged: (val) => metronome.updateInstanceVolume(instance.id, val),
                                  onMuteToggle: () => metronome.toggleInstanceMute(instance.id),
                                  onSoloToggle: () => metronome.toggleInstanceSolo(instance.id),
                                   onRemove: () {
                                     // STRICT RULE: Close keyboard if deleting the active pattern
                                     if (_activePatternIdForKeyboard == instance.id) {
                                       setState(() {
                                         _activePatternIdForKeyboard = null;
                                       });
                                     }
                                     _structureControllers.remove(instance.id);
                                     metronome.removeInstance(instance.id);
                                   },
                                ),
                              );
                            }).toList(),
                            
                            // Add Pattern Button
                            ElevatedButton.icon(
                              onPressed: () {
                                metronome.addInstance(title: "Patrón ${metronome.instances.length + 1}");
                              },
                              icon: const Icon(Icons.add),
                              label: const Text("AÑADIR PATRÓN"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surfaceHighlight(context),
                                foregroundColor: AppColors.textPrimary(context),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: AppColors.border(context)),
                                ),
                              ),
                            ),
                            SizedBox(height: _activePatternIdForKeyboard != null ? 300 : 80), // Pad bottom for keyboard
                          ],
                        ),
                        
                        // Custom Keyboard Overlay
                        if (_activePatternIdForKeyboard != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _buildCustomKeyboard(
                               context: context,
                               instanceId: _activePatternIdForKeyboard!,
                               controller: _structureControllers[_activePatternIdForKeyboard!]!,
                               onSubmit: (val) {
                                   metronome.updateInstanceStructure(_activePatternIdForKeyboard!, val);
                                   setState(() {
                                       _activePatternIdForKeyboard = null;
                                   });
                               },
                               onUpdateLive: (val) {
                                   // Force local UI redraw so the user sees the '+' immediately
                                   setState(() {});
                                   
                                   if (val.isNotEmpty && !val.endsWith('+')) { 
                                       metronome.updateInstanceStructure(_activePatternIdForKeyboard!, val);
                                   }
                               }
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Fixed bottom controls bar
                  _buildGlobalControls(context, metronome),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalControls(BuildContext context, MetronomeProvider metronome) {
    final bool isPlaying = metronome.isPlaying;
    final currentBpm = metronome.bpm;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(top: BorderSide(color: AppColors.border(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Play/Stop Button
          GestureDetector(
            onTap: () => metronome.togglePlay(),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: isPlaying ? AppColors.accentRed(context) : AppColors.accentCyan(context),
                shape: BoxShape.circle,
                boxShadow: kIsWeb ? null : [
                  BoxShadow(
                    color: (isPlaying ? AppColors.accentRed(context) : AppColors.accentCyan(context)).withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          
          // BPM Display and Adjust
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       GestureDetector(
                         onTap: () => metronome.updateBPM(currentBpm - 5),
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           child: Text(
                             "-5",
                             style: TextStyle(
                               color: AppColors.textSecondary(context),
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                       ),
                       GestureDetector(
                         onTap: () => metronome.updateBPM(currentBpm - 1),
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           child: Text(
                             "-1",
                             style: TextStyle(
                               color: AppColors.textSecondary(context),
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                       ),
                       Container(
                         width: 80,
                         alignment: Alignment.center,
                         child: Text(
                           "$currentBpm",
                           style: TextStyle(
                             color: AppColors.textPrimary(context),
                             fontSize: 36,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                       ),
                       GestureDetector(
                         onTap: () => metronome.updateBPM(currentBpm + 1),
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           child: Text(
                             "+1",
                             style: TextStyle(
                               color: AppColors.textSecondary(context),
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                       ),
                       GestureDetector(
                         onTap: () => metronome.updateBPM(currentBpm + 5),
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           child: Text(
                             "+5",
                             style: TextStyle(
                               color: AppColors.textSecondary(context),
                               fontSize: 16,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                       ),
                    ],
                  ),
                ),
                // Tempo Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: AppColors.accentCyan(context),
                    inactiveTrackColor: AppColors.border(context),
                    thumbColor: AppColors.accentCyan(context),
                    overlayColor: AppColors.accentCyan(context).withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: _bpmToSlider(currentBpm).clamp(0.0, 1.0),
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) => metronome.updateBPM(_sliderToBpm(val)),
                  ),
                )
              ],
            ),
          ),
          
          // Tap Tempo Button
          GestureDetector(
            onTap: () => metronome.tapTempo(),
            child: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border(context), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.touch_app, color: AppColors.textPrimary(context), size: 20),
                   const SizedBox(height: 1),
                   Text(
                     "TAP",
                     style: TextStyle(
                       color: AppColors.textPrimary(context),
                       fontWeight: FontWeight.bold,
                       fontSize: 8,
                       letterSpacing: 1.0,
                     ),
                   )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSettingsTrackStrip({
      required BuildContext context,
      required String label,
      required double value,
      required Function(double) onChanged,
      Function(double)? onChangeEnd,
      required bool isMuted,
      required VoidCallback onMuteToggle,
      required bool isSolo,
      required VoidCallback onSoloToggle,
      required bool isActive,
      bool hideSolo = false,
  }) {
      return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
              KnobControl(
                  value: value,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                  min: 0,
                  max: 1,
                  label: label,
                  labelColor: isActive ? AppColors.accentGreen(context) : AppColors.accentRed(context),
              ),
              const SizedBox(width: 16),
              // Mute Button
              GestureDetector(
                  onTap: onMuteToggle,
                  child: Container(
                      width: 40,
                      height: 32,
                      decoration: BoxDecoration(
                          color: isMuted ? AppColors.accentRed(context) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border(context)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                          'M',
                          style: TextStyle(
                              color: isMuted ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                          ),
                      ),
                  ),
              ),
              if (!hideSolo) ...[
                  const SizedBox(width: 8),
                  // Solo Button
                  GestureDetector(
                      onTap: onSoloToggle,
                      child: Container(
                          width: 40,
                          height: 32,
                          decoration: BoxDecoration(
                              color: isSolo ? AppColors.accentCyan(context) : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border(context)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                              'S',
                              style: TextStyle(
                                  color: isSolo ? Colors.black : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                              ),
                          ),
                      ),
                  ),
              ],
          ],
      );
  }

  Widget _buildMetronomeInstance({
    required BuildContext context,
    required HomeMetronomeInstance instance,
    required Function(String) onStructureChange,
    required Function(int pulseIndex, int subIndex, int type) onPulseSubdivisionChange,
    required Function(double) onVolChanged,
    required VoidCallback onMuteToggle,
    required VoidCallback onSoloToggle,
    required VoidCallback onRemove,
  }) {
    if (!_structureControllers.containsKey(instance.id)) {
        _structureControllers[instance.id] = TextEditingController(text: instance.structure);
    } else if (_activePatternIdForKeyboard != instance.id) {
        // Sync back controller when not editing it
        _structureControllers[instance.id]!.text = instance.structure;
    }

    bool isEditing = _activePatternIdForKeyboard == instance.id;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Expanded(
                 flex: 2,
                 child: Text(instance.title, style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, letterSpacing: 1.5), overflow: TextOverflow.ellipsis),
               ),
               // Grouping Text Field / Formatted Structure Display
               Expanded(
                 flex: 3,
                 child: GestureDetector(
                   onTap: () {
                       setState(() {
                           _activePatternIdForKeyboard = instance.id;
                       });
                   },
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                     decoration: BoxDecoration(
                         color: isEditing ? AppColors.accentCyan(context).withOpacity(0.1) : AppColors.background(context).withOpacity(0.5),
                         border: Border.all(
                           color: isEditing ? AppColors.accentCyan(context) : AppColors.border(context).withOpacity(0.5),
                           width: isEditing ? 2.0 : 1.0,
                         ),
                         borderRadius: BorderRadius.circular(4),
                     ),
                      child: isEditing 
                        ? SizedBox(
                            height: 24,
                            child: TextField(
                              controller: _structureControllers[instance.id],
                              readOnly: true,
                              showCursor: true,
                              cursorColor: AppColors.accentCyan(context),
                              style: TextStyle(
                                color: AppColors.accentCyan(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 2.0,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: "Ej. 3+2",
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary(context).withOpacity(0.5),
                                ),
                              ),
                            ),
                          )
                       : FittedBox(
                           fit: BoxFit.scaleDown,
                           alignment: Alignment.centerLeft,
                           child: _buildFormattedStructure(context, instance.structure),
                         ),
                   ),
                 ),
               ),
               const SizedBox(width: 8),
               Container(
                 width: 36,
                 height: 36,
                 decoration: BoxDecoration(
                   color: AppColors.background(context).withOpacity(0.5),
                   borderRadius: BorderRadius.circular(4),
                 ),
                 child: IconButton(
                   padding: EdgeInsets.zero,
                   icon: Icon(Icons.close, color: AppColors.accentRed(context).withOpacity(0.7), size: 18),
                   onPressed: onRemove,
                 ),
               )
            ],
          ),
          const SizedBox(height: 8),
          // Sequencer Cells (Responsive & Auto-Wrapping)
          LayoutBuilder(
            builder: (context, constraints) {
               int items = instance.pulses.length;
               int rows = 1;
               // If cells get too squeezed (e.g. less than 45px width each), we divide them into multiple rows
               if (items > 0 && constraints.maxWidth / items < 45.0) {
                 rows = 2; 
                 // We could scale to 3 rows if items > 16, but 2 handles most standard use cases cleanly
                 if (items > 16) rows = 3;
               }
               int itemsPerRow = (items / rows).ceil();
               
               List<Widget> rowWidgets = [];
               for(int r = 0; r < rows; r++) {
                   int start = r * itemsPerRow;
                   int end = start + itemsPerRow;
                   if (end > items) end = items;
                   if (start >= items) break;
                   
                   List<Widget> cellWidgets = [];
                   for (int i = start; i < end; i++) {
                     final pulse = instance.pulses[i];
                     int subdivCount = pulse.subdivisions.length;
                     
                     cellWidgets.add(
                       Expanded(
                         flex: (pulse.durationRatio * 100).round().clamp(1, 10000),
                         child: Container(
                           margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                           height: rows == 1 ? 42 : 36, // Container total height
                           decoration: BoxDecoration(
                             border: Border.all(color: AppColors.border(context), width: 1.5),
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(6),
                             child: Row(
                               crossAxisAlignment: CrossAxisAlignment.end, // Align to bottom so the "step down" happens from the top
                               children: List.generate(subdivCount, (subIndex) {
                                 int currentType = pulse.subdivisions[subIndex];
                                 bool isHead = subIndex == 0;
                                 
                                 return Expanded(
                                   child: GestureDetector(
                                     onTap: () {
                                        int newType = (currentType + 1) % 4;
                                        onPulseSubdivisionChange(i, subIndex, newType);
                                     },
                                     child: Container(
                                       // Create the height difference step for sub-beats
                                       margin: EdgeInsets.only(top: isHead ? 0 : 8),
                                       decoration: BoxDecoration(
                                         color: currentType == 0 ? AppColors.background(context) : _getColorForType(context, currentType).withOpacity(0.2),
                                         border: Border(
                                           right: subIndex < subdivCount - 1 
                                              ? BorderSide(color: AppColors.background(context), width: 3) // Harder, thicker dark line between sub-cells
                                              : BorderSide.none,
                                           top: isHead ? BorderSide.none : BorderSide(color: AppColors.border(context).withOpacity(0.5), width: 1), // Top border for chopped down sub-beats
                                         )
                                       ),
                                       alignment: Alignment.center,
                                       child: Column(
                                         mainAxisAlignment: MainAxisAlignment.center,
                                         children: [
                                           // Only show the big number on the FIRST subdivision head of the pulse
                                           if (subIndex == 0)
                                             Text(
                                               '${i + 1}', 
                                               style: TextStyle(
                                                 color: currentType == 0 ? AppColors.textSecondary(context) : AppColors.textPrimary(context),
                                                 fontWeight: FontWeight.bold,
                                                 fontSize: rows == 1 ? 16 : 12
                                               )
                                             ),
                                           if (currentType != 0)
                                             FittedBox(
                                               fit: BoxFit.scaleDown,
                                               child: Text(
                                                  _getLabelForType(currentType),
                                                  style: TextStyle(
                                                     color: _getColorForType(context, currentType),
                                                     fontSize: 8, // Smaller text for subdivided boxes
                                                     fontWeight: FontWeight.bold,
                                                     letterSpacing: -0.5,
                                                  )
                                               ),
                                             )
                                         ],
                                       ),
                                     ),
                                   ),
                                 );
                               }),
                             ),
                           ),
                         ),
                       ),
                     );
                   }
                   // Pad the last row with empty space if needed
                   while (cellWidgets.length < itemsPerRow) {
                       cellWidgets.add(Expanded(child: const SizedBox.shrink()));
                   }
                   rowWidgets.add(Row(children: cellWidgets));
               }
               return Column(children: rowWidgets);
            }
          ),
          const SizedBox(height: 6),
          // Track Strip (Volume, Mute, Solo) — compact inline row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 36,
                child: KnobControl(
                  value: instance.volume,
                  onChanged: onVolChanged,
                  min: 0,
                  max: 1,
                  label: 'VOL',
                  labelColor: instance.volume > 0 ? AppColors.accentGreen(context) : AppColors.accentRed(context),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onMuteToggle,
                child: Container(
                  width: 32,
                  height: 26,
                  decoration: BoxDecoration(
                    color: instance.isMuted ? AppColors.accentRed(context) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  alignment: Alignment.center,
                  child: Text('M', style: TextStyle(color: instance.isMuted ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onSoloToggle,
                child: Container(
                  width: 32,
                  height: 26,
                  decoration: BoxDecoration(
                    color: instance.isSolo ? AppColors.accentCyan(context) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  alignment: Alignment.center,
                  child: Text('S', style: TextStyle(color: instance.isSolo ? Colors.black : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColorForType(BuildContext context, int type) {
     switch (type) {
        case 1: return AppColors.accentRed(context);
        case 2: return AppColors.accentCyan(context);
        case 3: return AppColors.accentGreen(context);
        default: return AppColors.surfaceHighlight(context);
     }
  }
  
  String _getLabelForType(int type) {
     switch (type) {
        case 1: return "ALTO";
        case 2: return "BAJO";
        case 3: return "MEDIO";
        default: return "";
     }
  }

  // --- CUSTOM KEYBOARD ---
  /// Builds a formatted structure display where subdivision appears below a divider.
  /// e.g. "2/3" → "2" over "―" over "3"
  /// e.g. "2:3/3" → "2:3" over "―" over "3"
  /// e.g. "3+2" → "3" + "2" (no subdivisions, no divider)
  Widget _buildFormattedStructure(BuildContext context, String structure) {
    final String cleaned = structure.replaceAll(' ', '');
    if (cleaned.isEmpty) {
      return Text("—", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14));
    }

    final List<String> segments = cleaned.split('+');
    final List<Widget> segmentWidgets = [];

    for (int s = 0; s < segments.length; s++) {
      if (s > 0) {
        segmentWidgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text("+", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14, fontWeight: FontWeight.bold)),
        ));
      }

      final String seg = segments[s];
      String topPart;
      String? bottomPart;

      if (seg.contains('/')) {
        final slashIdx = seg.indexOf('/');
        topPart = seg.substring(0, slashIdx);
        bottomPart = seg.substring(slashIdx + 1);
      } else {
        topPart = seg;
      }

      if (bottomPart != null) {
        // Fraction-style: top / divider / bottom
        final textColor = AppColors.textPrimary(context);
        final topWidth = topPart.length * 10.0 + 8;
        final bottomWidth = bottomPart.length * 10.0 + 8;
        final width = (topWidth > bottomWidth ? topWidth : bottomWidth).clamp(24.0, 120.0);

        segmentWidgets.add(SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(topPart, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
              Container(
                width: width - 4,
                height: 1,
                color: AppColors.textSecondary(context).withOpacity(0.5),
                margin: const EdgeInsets.symmetric(vertical: 1),
              ),
              Text(bottomPart, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
            ],
          ),
        ));
      } else {
        // Simple number, no subdivision
        segmentWidgets.add(Text(topPart, style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: segmentWidgets,
    );
  }

  Widget _buildCustomKeyboard({
      required BuildContext context, 
      required int instanceId,
      required TextEditingController controller,
      required Function(String) onSubmit,
      required Function(String) onUpdateLive,
  }) {
      return Container(
          padding: const EdgeInsets.only(top: 6, bottom: 12, left: 4, right: 4),
          decoration: BoxDecoration(
              color: AppColors.surfaceHighlight(context),
              border: Border(top: BorderSide(color: AppColors.accentCyan(context), width: 2)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -4))]
          ),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                  // Text display row showing what's being typed
                  Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: AppColors.background(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accentCyan(context).withOpacity(0.5)),
                      ),
                      child: TextField(
                          controller: controller,
                          readOnly: true,
                          showCursor: true,
                          cursorColor: AppColors.accentCyan(context),
                          style: TextStyle(
                              color: AppColors.accentCyan(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 2.0,
                          ),
                          decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              hintText: "Ej. 3+2",
                              hintStyle: TextStyle(
                                  color: AppColors.textSecondary(context).withOpacity(0.5),
                              ),
                          ),
                      ),
                  ),
                  Row(
                      children: [
                          Expanded(child: _buildKeyBtn("1", controller, onUpdateLive)),
                          Expanded(child: _buildKeyBtn("2", controller, onUpdateLive)),
                          Expanded(child: _buildKeyBtn("3", controller, onUpdateLive)),
                          Expanded(child: _buildKeyBtn("+", controller, onUpdateLive, isControl: true, color: AppColors.accentGreen(context))),
                      ],
                  ),
                  Row(
                      children: [
                          Expanded(child: _buildKeyBtn("4", controller, onUpdateLive)),
                          Expanded(child: _buildKeyBtn("5", controller, onUpdateLive)),
                          Expanded(child: _buildKeyBtn("6", controller, onUpdateLive)),
                          Expanded(child: _buildKeyBtn("/", controller, onUpdateLive, isControl: true, color: AppColors.accentGreen(context))),
                      ],
                  ),
                  Row(
                      children: [
                          Expanded(child: _buildKeyBtn("7", controller, onUpdateLive)),
                          Expanded(child: _buildKeyBtn("8", controller, onUpdateLive)),
                          Expanded(child: _buildKeyBtn("9", controller, onUpdateLive)),
                          Expanded(child: _buildKeyBtn(":", controller, onUpdateLive, isControl: true, color: AppColors.accentGreen(context))),
                      ],
                  ),
                  Row(
                      children: [
                          Expanded(child: _buildKeyBtn("0", controller, onUpdateLive)),
                          Expanded(child: _buildKeyBtn("OK", controller, (v) => onSubmit(controller.text), isControl: true, color: AppColors.accentCyan(context))),
                          Expanded(child: _buildKeyBtn("\u232b", controller, onUpdateLive, isControl: true, color: AppColors.accentRed(context), icon: Icons.backspace)),
                      ],
                  ),
              ],
          ),
      );
  }

  Widget _buildKeyBtn(String keyData, TextEditingController controller, Function(String) onChange, {bool isControl = false, Color? color, IconData? icon}) {
      return GestureDetector(
          onTap: () {
              if (keyData == "OK") {
                  onChange(controller.text);
              } else if (keyData == "\u232b") {
                  if (controller.text.isNotEmpty) {
                      final int pos = controller.selection.baseOffset;
                      if (pos > 0) {
                          controller.text = controller.text.substring(0, pos - 1) + controller.text.substring(pos);
                          controller.selection = TextSelection.collapsed(offset: pos - 1);
                          onChange(controller.text);
                      } else if (pos == -1) {
                          // Cursor not active, delete from end
                          controller.text = controller.text.substring(0, controller.text.length - 1);
                          onChange(controller.text);
                      }
                  }
              } else {
                  final int pos = controller.selection.baseOffset;
                  final String text = controller.text;
                  
                  // Limit digits: max 2 consecutive digits per numeric slot
                  if (RegExp(r'[0-9]').hasMatch(keyData)) {
                      final int insertPos = pos >= 0 ? pos : text.length;
                      // Count consecutive digits before insert position
                      int digitsBefore = 0;
                      for (int i = insertPos - 1; i >= 0; i--) {
                          if (RegExp(r'[0-9]').hasMatch(text[i])) {
                              digitsBefore++;
                          } else {
                              break;
                          }
                      }
                      // Count consecutive digits after insert position
                      int digitsAfter = 0;
                      for (int i = insertPos; i < text.length; i++) {
                          if (RegExp(r'[0-9]').hasMatch(text[i])) {
                              digitsAfter++;
                          } else {
                              break;
                          }
                      }
                      if (digitsBefore + digitsAfter >= 2) return; // Block input
                  }
                  
                  if (pos >= 0) {
                      controller.text = text.substring(0, pos) + keyData + text.substring(pos);
                      controller.selection = TextSelection.collapsed(offset: pos + keyData.length);
                  } else {
                      controller.text += keyData;
                  }
                  onChange(controller.text);
              }
          },
          child: Container(
              margin: const EdgeInsets.all(2),
              height: 36,
              decoration: BoxDecoration(
                  color: isControl ? (color ?? AppColors.surface(context)).withOpacity(0.2) : AppColors.surface(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isControl ? (color ?? AppColors.border(context)) : AppColors.border(context)),
              ),
              alignment: Alignment.center,
              child: icon != null 
                  ? Icon(icon, color: isControl ? (color ?? AppColors.textPrimary(context)) : AppColors.textPrimary(context), size: 18)
                  : Text(
                      keyData,
                      style: TextStyle(
                          color: isControl ? (color ?? AppColors.textPrimary(context)) : AppColors.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                      ),
                  ),
          ),
      );
  }
}

class _MacroCycleVisualizer extends StatefulWidget {
  final MetronomeProvider metronome;

  const _MacroCycleVisualizer({Key? key, required this.metronome}) : super(key: key);

  @override
  State<_MacroCycleVisualizer> createState() => _MacroCycleVisualizerState();
}

class _MacroCycleVisualizerState extends State<_MacroCycleVisualizer> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final newProgress = widget.metronome.currentMacroProgress;
      if (_progressNotifier.value != newProgress) {
        _progressNotifier.value = newProgress;
      }
      // Auto-stop ticker when playback stops
      if (!widget.metronome.isPlaying) {
        _ticker.stop();
        _wasPlaying = false;
        // Snap to 0
        _progressNotifier.value = widget.metronome.currentMacroProgress;
      }
    });
    // Only start if already playing
    if (widget.metronome.isPlaying) {
      _ticker.start();
      _wasPlaying = true;
    }
    // Listen for play/stop changes to start/stop ticker
    widget.metronome.addListener(_onMetronomeChanged);
  }

  void _onMetronomeChanged() {
    final isPlaying = widget.metronome.isPlaying;
    if (isPlaying && !_wasPlaying) {
      if (!_ticker.isActive) _ticker.start();
      _wasPlaying = true;
    } else if (!isPlaying && _wasPlaying) {
      // Will be stopped inside the ticker callback after snapping
      // But also handle immediate stop
      if (_ticker.isActive) _ticker.stop();
      _wasPlaying = false;
      _progressNotifier.value = widget.metronome.currentMacroProgress;
    }
    // Rebuild the cell matrix only when instances/structure changes (not on every tick)
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.metronome.removeListener(_onMetronomeChanged);
    _ticker.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  Color _getColorForTypeLocal(BuildContext context, int type) {
     switch (type) {
        case 1: return AppColors.accentRed(context);
        case 2: return AppColors.accentCyan(context);
        case 3: return AppColors.accentGreen(context);
        default: return AppColors.surfaceHighlight(context);
     }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.metronome.instances.isEmpty) return const SizedBox.shrink();

    int macroBeats = widget.metronome.macroCycleBeats;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text("CICLO MACRO", style: TextStyle(color: AppColors.textSecondary(context), fontSize: 10, letterSpacing: 2.0, fontWeight: FontWeight.bold)),
               Text("$macroBeats Pulsos", style: TextStyle(color: AppColors.accentCyan(context), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Matrix of cells — only rebuilds when instances/structure changes
                  Column(
                     children: widget.metronome.instances.map((instance) {
                       // Compute how many times this instance's pattern repeats within macroBeats
                       double cycleDuration = 0.0;
                       for (var p in instance.pulses) {
                         cycleDuration += p.durationRatio;
                       }
                       if (cycleDuration <= 0) cycleDuration = instance.pulses.length.toDouble();
                       int repeats = (macroBeats / cycleDuration).round().clamp(1, 100);
                       
                       // Build cells: repeat the pattern
                       List<Widget> cells = [];
                       for (int r = 0; r < repeats; r++) {
                         for (int pi = 0; pi < instance.pulses.length; pi++) {
                           final pulse = instance.pulses[pi];
                           int flexValue = (pulse.durationRatio * 100).round().clamp(1, 10000);
                           
                           cells.add(
                             Expanded(
                               flex: flexValue,
                               child: Container(
                                 margin: const EdgeInsets.symmetric(horizontal: 1),
                                 child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: List.generate(pulse.subdivisions.length, (subIndex) {
                                        int type = pulse.subdivisions[subIndex];
                                        bool isHead = subIndex == 0;
                                        
                                        Color color = type == 0 
                                           ? AppColors.background(context) 
                                           : _getColorForTypeLocal(context, type);
                                           
                                        return Expanded(
                                           child: Container(
                                               margin: EdgeInsets.only(top: isHead ? 0 : 3),
                                               decoration: BoxDecoration(
                                                   color: type == 0 ? color : color.withOpacity(0.4),
                                                   border: Border(
                                                       right: subIndex < pulse.subdivisions.length - 1
                                                           ? BorderSide(color: AppColors.background(context), width: 1.0)
                                                           : BorderSide(color: type == 0 ? AppColors.border(context) : color.withOpacity(0.8), width: 1),
                                                       top: isHead ? BorderSide(color: type == 0 ? AppColors.border(context) : color.withOpacity(0.8), width: 1) : BorderSide(color: Colors.transparent, width: 1),
                                                       bottom: BorderSide(color: type == 0 ? AppColors.border(context) : color.withOpacity(0.8), width: 1),
                                                       left: isHead ? BorderSide(color: type == 0 ? AppColors.border(context) : color.withOpacity(0.8), width: 1) : BorderSide(color: Colors.transparent, width: 1),
                                                   ),
                                               ),
                                           ),
                                        );
                                   }),
                                 ),
                               ),
                             ),
                           );
                         }
                       }
                       
                       return Container(
                         margin: const EdgeInsets.only(bottom: 6),
                         height: 16,
                         child: Row(children: cells),
                       );
                     }).toList(),
                   ),
                  
                  // Playhead — ONLY this rebuilds at 60fps via ValueNotifier
                  ValueListenableBuilder<double>(
                    valueListenable: _progressNotifier,
                    builder: (context, progress, child) {
                      return Positioned(
                        left: constraints.maxWidth * progress,
                        top: -4,
                        bottom: 0,
                        child: child!,
                      );
                    },
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: Colors.white,
                         boxShadow: kIsWeb ? null : [
                           BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 4, spreadRadius: 1)
                         ]
                      ),
                    ),
                  ),
                ],
              );
            }
          ),
        ],
      ),
    );
  }
}
