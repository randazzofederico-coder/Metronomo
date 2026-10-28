import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/audio/click_synth.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/screens/settings_screen.dart';
import 'package:metronomo_standalone/widgets/knob_control.dart';
import 'package:flutter/scheduler.dart';
import 'package:metronomo_standalone/providers/settings_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/services/deep_link_service.dart';
import 'package:metronomo_standalone/services/share_import_service.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/screens/playlists_screen.dart';
import 'package:metronomo_standalone/screens/playlist_player_screen.dart';
import 'package:metronomo_standalone/widgets/share_sheet.dart';
import 'package:metronomo_standalone/widgets/pattern_keypad.dart';
import 'package:metronomo_standalone/utils/structure_input.dart';
import 'package:metronomo_standalone/utils/space_play_shortcut.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> with WidgetsBindingObserver, SpacePlayShortcut {
  int? _activePatternIdForKeyboard;

  /// Event currently in "volume mode" (long press + vertical drag), or null.
  _EventVolumeEdit? _volumeEdit;

  /// Vertical drag distance (logical px) per 5% volume step.
  static const double _volumePxPerStep = 12.0;
  final Map<int, TextEditingController> _structureControllers = {};
  final Map<int, FocusNode> _structureFocusNodes = {};
  final Map<int, TextEditingController> _titleControllers = {};

  /// Structure value when editing started (restored on Esc / invalid input).
  String _structureBeforeEdit = '';

  /// Anchors the desktop keypad popover to the field being edited.
  final LayerLink _keypadLink = LayerLink();

  /// From this width on, the keypad is a popover next to the field instead
  /// of a full-width bar at the bottom.
  static const double _wideLayoutBreakpoint = 600;
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
    // Check for incoming shared links after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize working state (restore or default)
      final metronome = context.read<MetronomeProvider>();
      final settings = context.read<SettingsProvider>();
      metronome.initializeWorkingState(settings);

      _checkForSharedLink();
      // Links arriving while the app runs (App Links / PWA launchQueue).
      DeepLinkService().listenIncomingLinks(_handleShareId);
    });
  }

  Future<void> _checkForSharedLink() async {
    // Link captured in main.dart (native cold start or web `?share=`).
    final pendingId = DeepLinkService().consumePendingShareId();
    if (pendingId != null) await _handleShareId(pendingId);
  }

  bool _isHandlingShare = false;
  final List<String> _queuedShares = [];

  /// Receive flow: fetch → import to library → ask to open (protecting
  /// unsaved work) → open. Links arriving mid-flow are queued.
  Future<void> _handleShareId(String shareId) async {
    if (!mounted) return;
    if (_isHandlingShare) {
      _queuedShares.add(shareId);
      return;
    }
    _isHandlingShare = true;
    try {
      await _receiveShare(shareId);
    } finally {
      _isHandlingShare = false;
    }
    if (_queuedShares.isNotEmpty) await _handleShareId(_queuedShares.removeAt(0));
  }

  Future<void> _receiveShare(String shareId) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(width: 12),
            Text('Abriendo link compartido...', style: TextStyle(color: AppColors.textPrimary(context))),
          ],
        ),
        backgroundColor: AppColors.surfaceHighlight(context),
        duration: const Duration(seconds: 20),
      ),
    );

    final bundle = await DeepLinkService().fetchSharedBundle(shareId);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();

    if (bundle == null) {
      _showErrorSnack('El enlace compartido no es válido o ha expirado.');
      return;
    }

    final ShareImportResult result;
    try {
      result = await ShareImportService(
        patterns: context.read<PatternEditorProvider>(),
        sessions: context.read<SessionProvider>(),
        playlists: context.read<PlaylistProvider>(),
      ).import(bundle);
    } catch (e) {
      debugPrint('Share import error: $e');
      _showErrorSnack('No se pudo importar el contenido compartido.');
      return;
    }
    if (!mounted) return;

    final wantsOpen = await _askOpenImported(result);
    if (wantsOpen != true || !mounted) return;

    // Playlists open in their own player, which preserves the working state.
    if (result.type != SharedType.playlist) {
      final proceed = await _protectUnsavedSession();
      if (!proceed || !mounted) return;
    }
    await _openImported(result);
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: AppColors.textPrimary(context))),
        backgroundColor: AppColors.accentRed(context),
      ),
    );
  }

  /// "Added to your library — open now?" dialog.
  Future<bool?> _askOpenImported(ShareImportResult r) {
    final (label, icon) = switch (r.type) {
      SharedType.pattern => ('Patrón', Icons.graphic_eq_rounded),
      SharedType.session => ('Sesión', Icons.library_music_rounded),
      SharedType.playlist => ('Playlist', Icons.queue_music_rounded),
    };
    final details = switch (r.type) {
      SharedType.pattern => '',
      SharedType.session => ' (${r.patternCount} patrones)',
      SharedType.playlist => ' (${r.sessionCount} sesiones, ${r.patternCount} patrones)',
    };
    final status = r.alreadyInLibrary
        ? 'Ya estaba en tu biblioteca.'
        : 'Se agregó a tu biblioteca$details.';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHighlight(ctx),
        icon: Icon(icon, color: AppColors.accentCyan(ctx)),
        title: Text('$label recibido', style: TextStyle(color: AppColors.textPrimary(ctx))),
        content: Text('«${r.name}»\n$status\n\n¿Querés abrirlo ahora?',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('SOLO GUARDAR', style: TextStyle(color: AppColors.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ABRIR', style: TextStyle(color: AppColors.accentCyan(ctx), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// If the current session has unsaved changes, offers Save / Discard /
  /// Cancel. Returns true when it's OK to replace the current session.
  Future<bool> _protectUnsavedSession() async {
    final metronome = context.read<MetronomeProvider>();
    final settings = context.read<SettingsProvider>();
    if (!metronome.isSessionDirty) return true;

    final name = metronome.activeSessionName ?? 'Sin Título';
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHighlight(ctx),
        title: Text('Cambios sin guardar', style: TextStyle(color: AppColors.textPrimary(ctx))),
        content: Text('La sesión «$name» tiene cambios sin guardar. ¿Qué querés hacer antes de continuar?',
            style: TextStyle(color: AppColors.textSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('DESCARTAR', style: TextStyle(color: AppColors.accentRed(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text('GUARDAR', style: TextStyle(color: AppColors.accentGreen(ctx), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (!mounted) return false;
    switch (choice) {
      case 'discard':
        return true;
      case 'save':
        return metronome.activeSessionId != null
            ? _showQuickSaveDialog(context, metronome, settings)
            : _showSaveSessionDialog(context, metronome, settings);
      default:
        return false;
    }
  }

  /// Generic destructive-action confirmation. Returns true if confirmed.
  Future<bool> _confirmDelete(BuildContext context, {required String title, required String message}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHighlight(ctx),
        title: Text(title, style: TextStyle(color: AppColors.textPrimary(ctx))),
        content: Text(message, style: TextStyle(color: AppColors.textSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ELIMINAR', style: TextStyle(color: AppColors.accentRed(ctx), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Starts a new empty session, protecting unsaved changes first.
  Future<void> _newSession() async {
    _closeAllKeyboards();
    final proceed = await _protectUnsavedSession();
    if (!proceed || !mounted) return;
    context.read<MetronomeProvider>().clearSession();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sesión nueva', style: TextStyle(color: AppColors.textPrimary(context))),
        backgroundColor: AppColors.surfaceHighlight(context),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Removes a pattern from the current session, offering undo.
  void _removeInstanceWithUndo(HomeMetronomeInstance instance) {
    final metronome = context.read<MetronomeProvider>();
    final index = metronome.instances.indexWhere((i) => i.id == instance.id);
    if (index < 0) return;

    if (_activePatternIdForKeyboard == instance.id) {
      _endStructureEdit(commit: false);
    }
    _disposeStructureState(instance.id);
    metronome.removeInstance(instance.id);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('«${instance.title}» eliminado', style: TextStyle(color: AppColors.textPrimary(context))),
        backgroundColor: AppColors.surfaceHighlight(context),
        duration: const Duration(seconds: 4),
        // Since Flutter 3.38 snackbars with an action persist by default.
        persist: false,
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: AppColors.accentCyan(context),
          onPressed: () => metronome.restoreInstance(instance, index),
        ),
      ),
    );
  }

  Future<void> _openImported(ShareImportResult r) async {
    final metronome = context.read<MetronomeProvider>();
    final settings = context.read<SettingsProvider>();
    final patProvider = context.read<PatternEditorProvider>();
    final sessionProvider = context.read<SessionProvider>();

    switch (r.type) {
      case SharedType.pattern:
        final pattern = patProvider.getPatternById(r.localId);
        if (pattern != null) metronome.newSessionWithPattern(pattern);
      case SharedType.session:
        final session = sessionProvider.getSessionById(r.localId);
        if (session != null) {
          await metronome.loadSession(session, settings, getPatternById: (id) async {
            await patProvider.ensureLoaded;
            return patProvider.getPatternById(id);
          });
        }
      case SharedType.playlist:
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlaylistPlayerScreen(playlistId: r.localId)),
        );
    }
  }

  // ── Share (export) ─────────────────────────────────────────────────────

  void _sharePattern(Pattern pattern) {
    showShareSheet(
      context,
      heading: 'Compartir patrón',
      subtitle: '«${pattern.name}» · ${pattern.structure}',
      createLink: () => DeepLinkService().createPatternLink(pattern),
    );
  }

  void _shareSession(Session session) {
    showShareSheet(
      context,
      heading: 'Compartir sesión',
      subtitle: '«${session.name}» · ${session.globalBpm} BPM · ${session.patternsConfig.length} patrones',
      createLink: () async {
        final patProvider = context.read<PatternEditorProvider>();
        await patProvider.ensureLoaded;
        final patterns = <Pattern>[];
        final seen = <String>{};
        for (var config in session.patternsConfig) {
          if (!seen.add(config.patternId)) continue;
          final pat = patProvider.getPatternById(config.patternId);
          if (pat != null) patterns.add(pat);
        }
        return DeepLinkService().createSessionLink(session, patterns);
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    
    final metronome = context.read<MetronomeProvider>();
    final settings = context.read<SettingsProvider>();

    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.inactive) {
      // Persist working state before going to background
      metronome.saveWorkingState();

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
    for (var controller in _titleControllers.values) {
      controller.dispose();
    }
    for (var node in _structureFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _closeAllKeyboards() {
    _endStructureEdit(commit: true);
    FocusScope.of(context).unfocus();
  }

  // --- GLOBAL SHORTCUTS ---

  @override
  void onSpacePlayToggle() => context.read<MetronomeProvider>().togglePlay();

  /// Space types into the structure editor instead of toggling playback.
  @override
  bool get spaceShortcutBlocked => _activePatternIdForKeyboard != null;

  // --- STRUCTURE EDITING ---
  // A structure edit is a session: it starts when the field is tapped and
  // ends with confirm (Enter / OK / Tab / tap outside) or cancel (Esc).
  // The pattern is only rebuilt on confirm, and only if the value changed.

  bool _isWideLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;

  FocusNode _structureFocusNodeFor(int id) {
    return _structureFocusNodes.putIfAbsent(id, () {
      final node = FocusNode(
        debugLabel: 'pattern-structure-$id',
        onKeyEvent: (node, event) => _onStructureKey(id, event),
      );
      node.addListener(() {
        // Focus moved elsewhere (another field, a dialog...): confirm.
        if (!node.hasFocus && _activePatternIdForKeyboard == id) {
          _endStructureEdit(commit: true);
        }
      });
      return node;
    });
  }

  void _startStructureEdit(int id) {
    if (_activePatternIdForKeyboard == id) return;
    if (_activePatternIdForKeyboard != null) _endStructureEdit(commit: true);

    final metronome = context.read<MetronomeProvider>();
    final instance = metronome.instances.where((i) => i.id == id).firstOrNull;
    if (instance == null) return;

    _structureBeforeEdit = instance.structure;
    final controller = _structureControllers.putIfAbsent(id, () => TextEditingController());
    controller.text = instance.structure;
    _structureFocusNodeFor(id);

    setState(() => _activePatternIdForKeyboard = id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activePatternIdForKeyboard != id) return;
      final node = _structureFocusNodeFor(id);
      node.requestFocus();
      // Desktop: select all so typing replaces the value. Mobile: caret at end.
      controller.selection = _isWideLayout(context)
          ? TextSelection(baseOffset: 0, extentOffset: controller.text.length)
          : TextSelection.collapsed(offset: controller.text.length);
      final fieldContext = node.context;
      if (fieldContext != null) {
        Scrollable.ensureVisible(
          fieldContext,
          alignment: 0.1,
          curve: Curves.easeInOut,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  /// Ends the current structure edit. With [commit], applies the value if it
  /// is complete and changed; otherwise restores the original value.
  void _endStructureEdit({required bool commit}) {
    final id = _activePatternIdForKeyboard;
    if (id == null || !mounted) return;

    // Clear first so the focus listener doesn't re-enter.
    setState(() => _activePatternIdForKeyboard = null);

    final controller = _structureControllers[id];
    final metronome = context.read<MetronomeProvider>();
    final instance = metronome.instances.where((i) => i.id == id).firstOrNull;
    if (controller != null && instance != null) {
      final text = controller.text;
      if (commit && StructureInput.isComplete(text) && text != instance.structure) {
        metronome.updateInstanceStructure(id, text);
      } else {
        controller.text = _structureBeforeEdit;
      }
    }

    final node = _structureFocusNodes[id];
    if (node != null && node.hasFocus) node.unfocus();
  }

  /// Enter / OK: confirm only if the value is complete, otherwise keep editing.
  void _confirmStructureEdit() {
    final id = _activePatternIdForKeyboard;
    if (id == null) return;
    if (!StructureInput.isComplete(_structureControllers[id]?.text ?? '')) return;
    _endStructureEdit(commit: true);
  }

  /// Tab / Shift+Tab: confirm and jump to the next / previous pattern.
  void _moveStructureEdit({required bool forward}) {
    final id = _activePatternIdForKeyboard;
    if (id == null) return;
    if (!StructureInput.isComplete(_structureControllers[id]?.text ?? '')) return;

    final instances = context.read<MetronomeProvider>().instances;
    final index = instances.indexWhere((i) => i.id == id);
    final targetIndex = forward ? index + 1 : index - 1;

    _endStructureEdit(commit: true);
    if (index >= 0 && targetIndex >= 0 && targetIndex < instances.length) {
      _startStructureEdit(instances[targetIndex].id);
    }
  }

  KeyEventResult _onStructureKey(int id, KeyEvent event) {
    if (event is! KeyDownEvent || _activePatternIdForKeyboard != id) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _endStructureEdit(commit: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _confirmStructureEdit();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _moveStructureEdit(forward: !HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Drops the per-instance editing state of a removed pattern.
  void _disposeStructureState(int id) {
    final controller = _structureControllers.remove(id);
    final node = _structureFocusNodes.remove(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller?.dispose();
      node?.dispose();
    });
  }

  /// Returns true if the session ended up saved (overwrite or "save as").
  Future<bool> _showQuickSaveDialog(BuildContext context, MetronomeProvider metronome, SettingsProvider settings) async {
    _closeAllKeyboards();
    final result = await showDialog<Object>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHighlight(ctx),
        title: Text("Guardar Cambios", style: TextStyle(color: AppColors.textPrimary(ctx))),
        content: Text("¿Deseas sobrescribir la sesión actual '${metronome.activeSessionName}' o guardar como una nueva sesión?", style: TextStyle(color: AppColors.textSecondary(ctx))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCELAR", style: TextStyle(color: AppColors.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () {
               Navigator.pop(ctx, 'saveAs');
            },
            child: Text("GUARDAR COMO...", style: TextStyle(color: AppColors.accentCyan(ctx))),
          ),
          TextButton(
            onPressed: () async {
               final patProvider = context.read<PatternEditorProvider>();
               final sessionProvider = context.read<SessionProvider>();
               final sessionName = metronome.activeSessionName ?? "Sesión";
               
               final session = await metronome.createSession(
                 sessionName,
                 "",
                 settings,
                 ensurePatternSaved: (instance) async {
                   final pat = metronome.createPatternFromInstance(instance.id, name: instance.title);
                   if (instance.originalPatternId != null) {
                       await patProvider.updatePattern(pat);
                   } else {
                       await patProvider.addPattern(pat);
                   }
                   metronome.markInstanceClean(instance.id, pat.id);
                   return pat.id;
                 }
               );
               
               // Reuse the active session ID
               final updatedSession = session.copyWith(id: metronome.activeSessionId);
               await sessionProvider.updateSession(updatedSession);
               metronome.markSessionClean(updatedSession.id, updatedSession.name);
               
               if (ctx.mounted) {
                  Navigator.pop(ctx, true);
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Sesión sobrescrita', style: TextStyle(color: AppColors.textPrimary(ctx))), backgroundColor: AppColors.surfaceHighlight(ctx)));
               }
            },
            child: Text("SOBRESCRIBIR", style: TextStyle(color: AppColors.accentGreen(ctx), fontWeight: FontWeight.bold)),
          ),
        ],
      )
    );
    if (result == 'saveAs' && context.mounted) {
      return _showSaveSessionDialog(context, metronome, settings);
    }
    return result == true;
  }

  /// Returns true if a new session was saved.
  Future<bool> _showSaveSessionDialog(BuildContext context, MetronomeProvider metronome, SettingsProvider settings) async {
    _closeAllKeyboards();
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHighlight(ctx),
        title: Text("Guardar Sesión", style: TextStyle(color: AppColors.textPrimary(ctx))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: AppColors.textPrimary(ctx)),
              decoration: InputDecoration(
                labelText: "Nombre de la Sesión",
                labelStyle: TextStyle(color: AppColors.textSecondary(ctx)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border(ctx))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentCyan(ctx))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: TextStyle(color: AppColors.textPrimary(ctx)),
              decoration: InputDecoration(
                labelText: "Descripción (opcional)",
                labelStyle: TextStyle(color: AppColors.textSecondary(ctx)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border(ctx))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentCyan(ctx))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCELAR", style: TextStyle(color: AppColors.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              final patProvider = context.read<PatternEditorProvider>();
              final sessionProvider = context.read<SessionProvider>();

              final session = await metronome.createSession(
                nameController.text.trim(),
                descController.text.trim(),
                settings,
                ensurePatternSaved: (instance) async {
                  final pat = metronome.createPatternFromInstance(instance.id, name: instance.title);
                  if (instance.originalPatternId != null) {
                      await patProvider.updatePattern(pat);
                  } else {
                      await patProvider.addPattern(pat);
                  }
                  metronome.markInstanceClean(instance.id, pat.id);
                  return pat.id;
                }
              );

              // Clear ID to force a new creation in case we are "Save As"ing
              final newSession = session.copyWith(id: Uuid().v4());
              await sessionProvider.addSession(newSession);
              metronome.markSessionClean(newSession.id, newSession.name);

              if (ctx.mounted) {
                 Navigator.pop(ctx, true);
                 ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Sesión guardada', style: TextStyle(color: AppColors.textPrimary(ctx))), backgroundColor: AppColors.surfaceHighlight(ctx)));
              }
            },
            child: Text("GUARDAR", style: TextStyle(color: AppColors.accentCyan(ctx), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return saved == true;
  }

  void _showLoadSessionDialog(BuildContext context, MetronomeProvider metronome, SettingsProvider settings) {
    _closeAllKeyboards();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Consumer<SessionProvider>(
          builder: (context, sessionProvider, child) {
            final sessions = sessionProvider.sessions;
            
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Text("Cargar Sesión", style: TextStyle(color: AppColors.textPrimary(ctx), fontSize: 18, fontWeight: FontWeight.bold)),
                   ),
                   if (sessions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text("No hay sesiones guardadas.", style: TextStyle(color: AppColors.textSecondary(ctx))),
                      )
                   else
                      Expanded(
                        child: ListView.builder(
                          itemCount: sessions.length,
                          itemBuilder: (context, index) {
                            final session = sessions[index];
                            return ListTile(
                              title: Text(session.name, style: TextStyle(color: AppColors.textPrimary(ctx), fontWeight: FontWeight.bold)),
                              subtitle: Text("${session.globalBpm} BPM • ${session.patternsConfig.length} pistas", style: TextStyle(color: AppColors.textSecondary(ctx))),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.share_outlined, color: AppColors.textSecondary(ctx)),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _shareSession(session);
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: AppColors.accentRed(ctx)),
                                    tooltip: 'Eliminar sesión',
                                    onPressed: () async {
                                      final ok = await _confirmDelete(
                                        ctx,
                                        title: 'Eliminar sesión',
                                        message: '¿Eliminar «${session.name}» de tu biblioteca? Esta acción no se puede deshacer.',
                                      );
                                      if (ok) sessionProvider.deleteSession(session.id);
                                    },
                                  ),
                                ],
                              ),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final proceed = await _protectUnsavedSession();
                                if (!proceed || !mounted) return;
                                final patProvider = this.context.read<PatternEditorProvider>();
                                await metronome.loadSession(session, settings, getPatternById: (id) async {
                                  await patProvider.ensureLoaded;
                                  return patProvider.getPatternById(id);
                                });
                              },
                            );
                          },
                        ),
                      )
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showLoadPatternDialog(BuildContext context, MetronomeProvider metronome) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Consumer<PatternEditorProvider>(
          builder: (context, patProvider, child) {
            final patterns = patProvider.patterns;
            
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Text("Cargar Patrón", style: TextStyle(color: AppColors.textPrimary(ctx), fontSize: 18, fontWeight: FontWeight.bold)),
                   ),
                   if (patterns.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text("No hay patrones en la librería.", style: TextStyle(color: AppColors.textSecondary(ctx))),
                      )
                   else
                      Expanded(
                        child: ListView.builder(
                          itemCount: patterns.length,
                          itemBuilder: (context, index) {
                            final pat = patterns[index];
                            return ListTile(
                              title: Text(pat.name, style: TextStyle(color: AppColors.textPrimary(ctx), fontWeight: FontWeight.bold)),
                              subtitle: Text("Estructura: ${pat.structure}", style: TextStyle(color: AppColors.textSecondary(ctx))),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.share_outlined, color: AppColors.textSecondary(ctx)),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _sharePattern(pat);
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: AppColors.accentRed(ctx)),
                                    tooltip: 'Eliminar patrón',
                                    onPressed: () async {
                                      // Sessions reference library patterns by id: warn if in use.
                                      final usedBy = ctx.read<SessionProvider>().sessions
                                          .where((s) => s.patternsConfig.any((c) => c.patternId == pat.id))
                                          .map((s) => s.name)
                                          .toList();
                                      final warning = usedBy.isEmpty
                                          ? ''
                                          : '\n\n⚠ Lo usan ${usedBy.length == 1 ? 'la sesión' : '${usedBy.length} sesiones'}: ${usedBy.take(3).map((n) => '«$n»').join(', ')}${usedBy.length > 3 ? '…' : ''}. Esas sesiones perderán este patrón.';
                                      final ok = await _confirmDelete(
                                        ctx,
                                        title: 'Eliminar patrón',
                                        message: '¿Eliminar «${pat.name}» de la librería?$warning',
                                      );
                                      if (ok) patProvider.deletePattern(pat.id);
                                    },
                                  ),
                                ],
                              ),
                              onTap: () async {
                                metronome.loadPattern(pat);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      )
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Consumer<MetronomeProvider>(
          builder: (context, metronome, child) {
            final String titleText;
            if (metronome.activeSessionName != null) {
              titleText = "${metronome.activeSessionName}${metronome.isSessionDirty ? '*' : ''}";
            } else if (metronome.isSessionDirty) {
              titleText = "Sin Título *";
            } else {
              titleText = "METRÓNOMO";
            }
            return Text(
              titleText, 
              style: TextStyle(
                letterSpacing: 2.0, 
                fontStyle: metronome.isSessionDirty ? FontStyle.italic : FontStyle.normal,
              )
            );
          }
        ),
        backgroundColor: AppColors.surface(context),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.textSecondary(context)),
            onPressed: _newSession,
            tooltip: "Nueva Sesión",
          ),
          IconButton(
            icon: Icon(Icons.folder_open_rounded, color: AppColors.textSecondary(context)),
            onPressed: () {
              final metronome = context.read<MetronomeProvider>();
              final settings = context.read<SettingsProvider>();
              _showLoadSessionDialog(context, metronome, settings);
            },
            tooltip: "Cargar Sesión",
          ),
          IconButton(
            icon: Icon(Icons.save_rounded, color: AppColors.textSecondary(context)),
            onPressed: () {
              final metronome = context.read<MetronomeProvider>();
              final settings = context.read<SettingsProvider>();
              if (metronome.activeSessionId != null && metronome.isSessionDirty) {
                _showQuickSaveDialog(context, metronome, settings);
              } else {
                _showSaveSessionDialog(context, metronome, settings);
              }
            },
            tooltip: "Guardar Sesión",
          ),
          IconButton(
            icon: Icon(Icons.queue_music_rounded, color: AppColors.textSecondary(context)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
              );
            },
            tooltip: "Playlists",
          ),
          IconButton(
            icon: Icon(Icons.settings_rounded, color: AppColors.textSecondary(context)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: "Ajustes",
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Tapping outside confirms the structure being edited.
            _endStructureEdit(commit: true);
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
                                child: Builder(
                                  builder: (instanceContext) {
                                    return _buildMetronomeInstance(
                                      context: context,
                                      instanceContext: instanceContext,
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
                                       onRemove: () => _removeInstanceWithUndo(instance),
                                    );
                                  }
                                ),
                              );
                            }).toList(),
                            
                            // Add / Load Pattern Buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      metronome.addInstance(title: "Patrón ${metronome.instances.length + 1}");
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text("AÑADIR"),
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
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      _showLoadPatternDialog(context, metronome);
                                    },
                                    icon: const Icon(Icons.library_music),
                                    label: const Text("LIBRERÍA"),
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
                                ),
                              ],
                            ),
                            // Room below the field being edited for the keypad.
                            SizedBox(height: _activePatternIdForKeyboard != null ? 260 : 80),
                          ],
                        ),
                        
                        // Per-event volume legend (bottom-right) while in "volume mode"
                        if (_volumeEdit != null)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: _buildVolumeLegend(context),
                          ),

                        // Pattern structure keypad: popover next to the field on
                        // wide screens, full-width bar at the bottom on mobile.
                        if (_activePatternIdForKeyboard != null &&
                            _structureControllers[_activePatternIdForKeyboard!] != null)
                          if (_isWideLayout(context))
                            Positioned(
                              left: 0,
                              top: 0,
                              child: CompositedTransformFollower(
                                link: _keypadLink,
                                showWhenUnlinked: false,
                                targetAnchor: Alignment.bottomLeft,
                                followerAnchor: Alignment.topLeft,
                                // Target is the text inside the field box: compensate
                                // its padding (12/6) + border (2) to align with the box.
                                offset: const Offset(-14, 14),
                                child: PatternKeypad(
                                  style: PatternKeypadStyle.popover,
                                  controller: _structureControllers[_activePatternIdForKeyboard!]!,
                                  onSubmit: _confirmStructureEdit,
                                ),
                              ),
                            )
                          else
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: PatternKeypad(
                                style: PatternKeypadStyle.docked,
                                controller: _structureControllers[_activePatternIdForKeyboard!]!,
                                onSubmit: _confirmStructureEdit,
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
    
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
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
    ),
    );
  }

  Widget _buildMetronomeInstance({
    required BuildContext context,
    required BuildContext instanceContext,
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

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
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
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Flexible(
                       child: IntrinsicWidth(
                         child: TextField(
                           controller: _titleControllers.putIfAbsent(instance.id, () => TextEditingController(text: instance.title)),
                           style: TextStyle(
                               color: AppColors.textPrimary(context), 
                               fontWeight: FontWeight.bold, 
                               letterSpacing: 1.5,
                               fontStyle: instance.isDirty ? FontStyle.italic : FontStyle.normal,
                           ),
                           decoration: const InputDecoration(
                               border: InputBorder.none, 
                               isDense: true, 
                               contentPadding: EdgeInsets.zero,
                           ),
                           onTap: () {
                               Future.delayed(const Duration(milliseconds: 300), () {
                                 if (context.mounted) Scrollable.ensureVisible(instanceContext, curve: Curves.easeInOut, duration: const Duration(milliseconds: 300));
                               });
                           },
                           onChanged: (val) {
                               context.read<MetronomeProvider>().renameInstance(instance.id, val);
                           },
                         ),
                       ),
                     ),
                     if (instance.isDirty)
                       Padding(
                         padding: const EdgeInsets.only(left: 4.0),
                         child: Text("*", style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 18)),
                       ),
                     const SizedBox(width: 8),
                   ],
                 )
               ),
               // Grouping Text Field / Formatted Structure Display
               Expanded(
                 flex: 3,
                 child: GestureDetector(
                   onTap: () => _startStructureEdit(instance.id),
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
                        ? _buildStructureEditor(context, instance.id)
                       : FittedBox(
                           fit: BoxFit.scaleDown,
                           alignment: Alignment.centerLeft,
                           child: _buildFormattedStructure(context, instance.structure),
                         ),
                   ),
                 ),
               ),
               const SizedBox(width: 8),
               // Botones de acciones de la instancia
               Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Container(
                     width: 36,
                     height: 36,
                     decoration: BoxDecoration(
                       color: AppColors.background(context).withOpacity(0.5),
                       borderRadius: BorderRadius.circular(4),
                     ),
                     child: IconButton(
                       padding: EdgeInsets.zero,
                       icon: Icon(Icons.save, color: AppColors.accentGreen(context).withOpacity(0.8), size: 18),
                       onPressed: () async {
                          final patProvider = context.read<PatternEditorProvider>();
                          final metronome = context.read<MetronomeProvider>();
                          final pat = metronome.createPatternFromInstance(instance.id, name: instance.title);
                          
                          if (instance.originalPatternId != null) {
                              await patProvider.updatePattern(pat);
                          } else {
                              await patProvider.addPattern(pat);
                          }
                          
                          metronome.markInstanceClean(instance.id, pat.id);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Patrón guardado', style: TextStyle(color: AppColors.textPrimary(context))), backgroundColor: AppColors.surfaceHighlight(context), duration: const Duration(seconds: 1)));
                          }
                       },
                     ),
                   ),
                   const SizedBox(width: 4),
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
                   ),
                 ],
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
                                  final double eventVolume = pulse.volumeAt(subIndex);
                                  final bool canEditVolume = currentType != 0;
                                  final edit = _volumeEdit;
                                  final bool isEditingVolume = edit != null &&
                                      edit.instanceId == instance.id &&
                                      edit.pulseIndex == i &&
                                      edit.subIndex == subIndex;
                                  
                                  return Expanded(
                                    child: GestureDetector(
                                      // Quick tap: cycle the sound type (unchanged behaviour)
                                      onTap: () {
                                         int newType = (currentType + 1) % 4;
                                         onPulseSubdivisionChange(i, subIndex, newType);
                                      },
                                      // Long press: "volume mode" — drag up/down to change the event volume.
                                      // Only available on events that produce sound.
                                      onLongPressStart: canEditVolume
                                          ? (_) => _startVolumeEdit(instance.id, i, subIndex, currentType, eventVolume)
                                          : null,
                                      onLongPressMoveUpdate: canEditVolume
                                          ? (details) => _updateVolumeEdit(details.offsetFromOrigin.dy)
                                          : null,
                                      onLongPressEnd: canEditVolume ? (_) => _endVolumeEdit() : null,
                                      child: Container(
                                        // Create the height difference step for sub-beats
                                        margin: EdgeInsets.only(top: isHead ? 0 : 8),
                                        decoration: BoxDecoration(
                                          // Color intensity reflects the event volume
                                          color: currentType == 0
                                              ? AppColors.background(context)
                                              : AppColors.eventFill(_getColorForType(context, currentType), eventVolume, 0.2),
                                          border: Border(
                                            right: subIndex < subdivCount - 1 
                                               ? BorderSide(color: AppColors.background(context), width: 3) // Harder, thicker dark line between sub-cells
                                               : BorderSide.none,
                                            top: isHead ? BorderSide.none : BorderSide(color: AppColors.border(context).withOpacity(0.5), width: 1), // Top border for chopped down sub-beats
                                          )
                                        ),
                                        foregroundDecoration: isEditingVolume
                                            ? BoxDecoration(border: Border.all(color: _getColorForType(context, currentType), width: 2))
                                            : null,
                                        alignment: Alignment.center,
                                        // Only show the big number on the FIRST subdivision head of the pulse.
                                        // The sound type is conveyed by the color alone.
                                        child: subIndex == 0
                                            ? Text(
                                                '${i + 1}', 
                                                style: TextStyle(
                                                  color: currentType == 0 ? AppColors.textSecondary(context) : AppColors.textPrimary(context),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: rows == 1 ? 16 : 12
                                                )
                                              )
                                            : null,
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
              const SizedBox(width: 6),
              _buildInstanceSoundSelector(context, instance),
            ],
          ),
        ],
      ),
    ),
    );
  }

  /// Per-pattern sound set selector ("Global" = follows the sound chosen in Settings).
  Widget _buildInstanceSoundSelector(BuildContext context, HomeMetronomeInstance instance) {
    final metronome = context.read<MetronomeProvider>();
    final hasOverride = instance.soundSet != null;
    final label = metronome.effectiveSoundSet(instance);
    const globalValue = '__global__';
    final accent = AppColors.accentCyan(context);

    return PopupMenuButton<String>(
      tooltip: 'Sonido del patrón',
      initialValue: instance.soundSet ?? globalValue,
      onSelected: (val) => metronome.updateInstanceSoundSet(instance.id, val == globalValue ? null : val),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: globalValue,
          child: Text('Global (${metronome.currentSoundSet})'),
        ),
        const PopupMenuDivider(),
        ...ClickSynth.soundSets.map((s) => PopupMenuItem(value: s, child: Text(s))),
      ],
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: hasOverride ? accent.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: hasOverride ? accent : AppColors.border(context)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, size: 14, color: hasOverride ? accent : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: hasOverride ? AppColors.textPrimary(context) : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- PER-EVENT VOLUME ("volume mode") ---
  void _startVolumeEdit(int instanceId, int pulseIndex, int subIndex, int type, double volume) {
    HapticFeedback.mediumImpact();
    // Snap the starting point to the 5% grid
    final start = (volume * 20).round() / 20.0;
    setState(() {
      _volumeEdit = _EventVolumeEdit(
        instanceId: instanceId,
        pulseIndex: pulseIndex,
        subIndex: subIndex,
        type: type,
        startVolume: start,
        value: volume,
      );
    });
  }

  void _updateVolumeEdit(double dragDy) {
    final edit = _volumeEdit;
    if (edit == null) return;
    // Dragging up (negative dy) increases the volume
    final steps = (-dragDy / _volumePxPerStep).round();
    final maxSteps = (HomeMetronomePulse.maxEventVolume * 20).round();
    final newValue = ((edit.startVolume * 20).round() + steps).clamp(0, maxSteps) / 20.0;
    if (newValue == edit.value) return;
    HapticFeedback.selectionClick();
    setState(() => edit.value = newValue);
    context.read<MetronomeProvider>().updateEventVolume(edit.instanceId, edit.pulseIndex, edit.subIndex, newValue);
  }

  void _endVolumeEdit() {
    if (_volumeEdit == null) return;
    setState(() => _volumeEdit = null);
  }

  /// Floating legend shown in the bottom-right corner while in volume mode.
  Widget _buildVolumeLegend(BuildContext context) {
    final edit = _volumeEdit!;
    final color = _getColorForType(context, edit.type);
    final percent = (edit.value * 100).round();
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface(context).withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              percent == 0 ? Icons.volume_off_rounded : percent > 100 ? Icons.volume_up_rounded : Icons.volume_down_rounded,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: 22,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_arrow_up_rounded, size: 14, color: AppColors.textSecondary(context)),
                Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.textSecondary(context)),
              ],
            ),
          ],
        ),
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

  /// Inline editor for the pattern structure. Accepts the physical keyboard
  /// (filtered by [StructureInputFormatter]) without opening the OS soft
  /// keyboard; on touch devices the [PatternKeypad] is the input method.
  Widget _buildStructureEditor(BuildContext context, int instanceId) {
    final controller = _structureControllers[instanceId]!;
    return CompositedTransformTarget(
      link: _keypadLink,
      child: SizedBox(
        height: 24,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            // Incomplete values (e.g. "3+", "3:") are shown in red: they
            // can't be confirmed until finished.
            final bool complete = StructureInput.isComplete(controller.text);
            final Color color = complete ? AppColors.accentCyan(context) : AppColors.accentRed(context);
            return TextField(
              controller: controller,
              focusNode: _structureFocusNodeFor(instanceId),
              keyboardType: TextInputType.none,
              textInputAction: TextInputAction.done,
              inputFormatters: [StructureInputFormatter()],
              autocorrect: false,
              enableSuggestions: false,
              maxLines: 1,
              showCursor: true,
              cursorColor: color,
              style: TextStyle(
                color: color,
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
              onSubmitted: (_) => _confirmStructureEdit(),
              // Keep focus on Enter when the value is incomplete.
              onEditingComplete: () {},
              // Closing is handled by the screen's tap detector, so taps on
              // the keypad don't steal focus from the field.
              onTapOutside: (_) {},
            );
          },
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

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
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
                                                   color: type == 0 ? color : AppColors.eventFill(color, pulse.volumeAt(subIndex), 0.4),
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
    ),
    );
  }
}

/// Mutable state of the event being edited in "volume mode".
class _EventVolumeEdit {
  _EventVolumeEdit({
    required this.instanceId,
    required this.pulseIndex,
    required this.subIndex,
    required this.type,
    required this.startVolume,
    required this.value,
  });

  final int instanceId;
  final int pulseIndex;
  final int subIndex;
  final int type;
  final double startVolume;
  double value;
}
