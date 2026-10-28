import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/audio/click_synth.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/screens/settings_screen.dart';
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
import 'package:metronomo_standalone/theme/beat_colors.dart';
import 'package:metronomo_standalone/widgets/formatted_structure.dart';
import 'package:metronomo_standalone/widgets/macro_cycle.dart';
import 'package:metronomo_standalone/widgets/mixer_strip.dart';
import 'package:metronomo_standalone/widgets/pattern_card.dart';
import 'package:metronomo_standalone/widgets/playback_clock.dart';
import 'package:metronomo_standalone/widgets/sequencer_grid.dart';
import 'package:metronomo_standalone/widgets/transport_bar.dart';

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

  /// Structure value when editing started (restored on Esc / invalid input).
  String _structureBeforeEdit = '';

  /// Anchors the desktop keypad popover to the field being edited.
  final LayerLink _keypadLink = LayerLink();

  /// From this width on, the keypad is a popover next to the field instead
  /// of a full-width bar at the bottom.
  static const double _wideLayoutBreakpoint = 600;
  bool _wasPlayingBeforeBackground = false;
  
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
      _migrateLegacySessions();

      _checkForSharedLink();
      // Links arriving while the app runs (App Links / PWA launchQueue).
      DeepLinkService().listenIncomingLinks(_handleShareId);
    });
  }

  /// One-time migration: sessions saved before patterns were embedded get a
  /// copy of their library patterns, so they stop depending on the library.
  Future<void> _migrateLegacySessions() async {
    final patProvider = context.read<PatternEditorProvider>();
    final sessionProvider = context.read<SessionProvider>();
    await patProvider.ensureLoaded;
    final migrated = await sessionProvider.embedMissingPatterns(patProvider.getPatternById);
    if (migrated > 0) debugPrint('Migrated $migrated legacy session(s) to embedded patterns');
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
        icon: Icon(icon, color: AppColors.primary(ctx)),
        title: Text('$label recibido'),
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
            child: Text('ABRIR', style: TextStyle(color: AppColors.primary(ctx), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// If the current session has unsaved changes, offers Save / Discard /
  /// Cancel. Returns true when it's OK to replace the current session.
  Future<bool> _protectUnsavedSession() async {
    final metronome = context.read<MetronomeProvider>();
    if (!metronome.isSessionDirty) return true;

    final name = metronome.activeSessionName ?? 'Sin Título';
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cambios sin guardar'),
        content: Text('La sesión «$name» tiene cambios sin guardar. ¿Qué querés hacer antes de continuar?'),
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
        if (await _overwriteActiveSession(offerUndo: false)) return true;
        if (!mounted) return false;
        return _showSaveSessionDialog(context);
      default:
        return false;
    }
  }

  /// Generic destructive-action confirmation. Returns true if confirmed.
  Future<bool> _confirmDelete(BuildContext context, {required String title, required String message}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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

  PopupMenuItem<T> _menuItem<T>(T value, IconData icon, String label, {Color? color}) {
    return PopupMenuItem<T>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? AppColors.textSecondary(context)),
          const SizedBox(width: 12),
          Text(label, style: color == null ? null : TextStyle(color: color)),
        ],
      ),
    );
  }

  Future<void> _onSessionMenu(_SessionMenu action) async {
    final metronome = context.read<MetronomeProvider>();
    final settings = context.read<SettingsProvider>();
    switch (action) {
      case _SessionMenu.newSession:
        await _newSession();
      case _SessionMenu.open:
        _showLoadSessionDialog(context, metronome, settings);
      case _SessionMenu.saveAs:
        await _showSaveSessionDialog(context);
      case _SessionMenu.share:
        // Shares what's on screen (saved or not).
        final session = metronome.createSession(
          metronome.activeSessionName ?? 'Sesión',
          '',
          settings,
        );
        _shareSession(metronome.activeSessionId != null ? session.copyWith(id: metronome.activeSessionId) : session);
      case _SessionMenu.playlists:
        _closeAllKeyboards();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaylistsScreen()));
      case _SessionMenu.settings:
        _closeAllKeyboards();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    }
  }

  /// Starts a new empty session, protecting unsaved changes first.
  Future<void> _newSession() async {
    _closeAllKeyboards();
    final proceed = await _protectUnsavedSession();
    if (!proceed || !mounted) return;
    context.read<MetronomeProvider>().clearSession();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sesión nueva'),
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
        content: Text('«${instance.title}» eliminado'),
        duration: const Duration(seconds: 4),
        // Since Flutter 3.38 snackbars with an action persist by default.
        persist: false,
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: AppColors.primary(context),
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
        // Patterns are embedded in the session; legacy sessions fall back to
        // the library. The list is still sent for older app versions.
        final patProvider = context.read<PatternEditorProvider>();
        await patProvider.ensureLoaded;
        final embedded = session.withEmbeddedPatterns(patProvider.getPatternById);
        return DeepLinkService().createSessionLink(embedded, embedded.embeddedPatterns);
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

  // --- SAVING ---
  // Sessions embed their patterns: saving a session never touches the
  // pattern library (patterns go there only via "Guardar en librería").

  /// Overwrites the active session with the current state.
  /// Returns false if there's no active session in the library (e.g. it was
  /// deleted): callers should fall back to "save as".
  Future<bool> _overwriteActiveSession({bool offerUndo = true}) async {
    final metronome = context.read<MetronomeProvider>();
    final settings = context.read<SettingsProvider>();
    final sessionProvider = context.read<SessionProvider>();
    final id = metronome.activeSessionId;
    final previous = id == null ? null : sessionProvider.getSessionById(id);
    if (previous == null) return false;

    final session = metronome
        .createSession(metronome.activeSessionName ?? previous.name, previous.description, settings)
        .copyWith(id: previous.id, createdAt: previous.createdAt);
    await sessionProvider.updateSession(session);
    metronome.markSessionClean(session.id, session.name);

    if (!mounted) return true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('«${session.name}» guardada'),
      duration: const Duration(seconds: 3),
      persist: false,
      action: offerUndo
          ? SnackBarAction(
              label: 'DESHACER',
              onPressed: () async {
                // Restore the previous version in the library; the current
                // work stays on screen, marked as unsaved again.
                await sessionProvider.updateSession(previous);
                metronome.markSessionDirty();
              },
            )
          : null,
    ));
    return true;
  }

  /// Saves the current state as a new session. Returns true if saved.
  Future<bool> _saveSessionAs(String name, String description) async {
    final metronome = context.read<MetronomeProvider>();
    final settings = context.read<SettingsProvider>();
    final sessionProvider = context.read<SessionProvider>();

    // New id: "save as" must never overwrite the original session.
    final session = metronome.createSession(name, description, settings).copyWith(id: const Uuid().v4());
    await sessionProvider.addSession(session);
    metronome.markSessionClean(session.id, session.name);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«${session.name}» guardada')));
    }
    return true;
  }

  /// 💾 action: overwrite directly if the session exists, otherwise ask a name.
  Future<bool> _saveSession() async {
    _closeAllKeyboards();
    if (await _overwriteActiveSession()) return true;
    if (!mounted) return false;
    return _showSaveSessionDialog(context);
  }

  /// "Guardar como…" dialog. Returns true if a new session was saved.
  Future<bool> _showSaveSessionDialog(BuildContext context) async {
    _closeAllKeyboards();
    final metronome = context.read<MetronomeProvider>();
    final nameController = TextEditingController(text: metronome.activeSessionName ?? '');
    final descController = TextEditingController();

    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) {
        void submit() {
          final name = nameController.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(ctx, (name, descController.text.trim()));
        }

        return AlertDialog(
          title: const Text("Guardar Sesión"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                style: TextStyle(color: AppColors.textPrimary(ctx)),
                decoration: InputDecoration(
                  labelText: "Nombre de la Sesión",
                  labelStyle: TextStyle(color: AppColors.textSecondary(ctx)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border(ctx))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary(ctx))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                onSubmitted: (_) => submit(),
                style: TextStyle(color: AppColors.textPrimary(ctx)),
                decoration: InputDecoration(
                  labelText: "Descripción (opcional)",
                  labelStyle: TextStyle(color: AppColors.textSecondary(ctx)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border(ctx))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary(ctx))),
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
              onPressed: submit,
              child: Text("GUARDAR", style: TextStyle(color: AppColors.primary(ctx), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (result == null || !mounted) return false;
    return _saveSessionAs(result.$1, result.$2);
  }

  void _showLoadSessionDialog(BuildContext context, MetronomeProvider metronome, SettingsProvider settings) {
    _closeAllKeyboards();
    showModalBottomSheet(
      context: context,
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
                                      final ok = await _confirmDelete(
                                        ctx,
                                        title: 'Eliminar patrón',
                                        message: '¿Eliminar «${pat.name}» de la librería?\n\nLas sesiones que lo usan no cambian: tienen su propia copia.',
                                      );
                                      if (!ok) return;
                                      // Safety net: make sure no legacy session still depends on it.
                                      await ctx.read<SessionProvider>().embedMissingPatterns(patProvider.getPatternById);
                                      await patProvider.deletePattern(pat.id);
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
            icon: Icon(Icons.save_rounded, color: AppColors.textSecondary(context)),
            onPressed: _saveSession,
            tooltip: "Guardar sesión",
          ),
          PopupMenuButton<_SessionMenu>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary(context)),
            tooltip: 'Más opciones',
            onSelected: _onSessionMenu,
            itemBuilder: (_) => [
              _menuItem(_SessionMenu.newSession, Icons.add_circle_outline, 'Nueva sesión'),
              _menuItem(_SessionMenu.open, Icons.folder_open_rounded, 'Abrir sesión…'),
              _menuItem(_SessionMenu.saveAs, Icons.save_as_rounded, 'Guardar como…'),
              _menuItem(_SessionMenu.share, Icons.share_outlined, 'Compartir sesión'),
              const PopupMenuDivider(),
              _menuItem(_SessionMenu.playlists, Icons.queue_music_rounded, 'Playlists'),
              _menuItem(_SessionMenu.settings, Icons.settings_rounded, 'Ajustes'),
            ],
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
              return PlaybackClock(metronome: metronome, child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          children: [
                            MacroCycle(metronome: metronome, showEditHints: true),
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
              ));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalControls(BuildContext context, MetronomeProvider metronome) {
    return TransportBar(
      isPlaying: metronome.isPlaying,
      bpm: metronome.bpm,
      onTogglePlay: metronome.togglePlay,
      onBpmChanged: metronome.updateBPM,
      trailing: TapTempoButton(onTap: metronome.tapTempo),
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

    final bool isEditing = _activePatternIdForKeyboard == instance.id;
    final edit = _volumeEdit;

    return PatternCard(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           // Title (tap to rename)
           Expanded(
             flex: 2,
             child: Tooltip(
               message: 'Tocá para renombrar',
               child: InkWell(
                 borderRadius: BorderRadius.circular(4),
                 onTap: () => _renameInstance(instance),
                 child: Padding(
                   padding: const EdgeInsets.symmetric(vertical: 4),
                   child: Row(
                     children: [
                       Flexible(
                         child: Text(
                           instance.title,
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis,
                           style: TextStyle(
                             color: AppColors.textPrimary(context),
                             fontWeight: FontWeight.bold,
                             letterSpacing: 1.5,
                             fontStyle: instance.isDirty ? FontStyle.italic : FontStyle.normal,
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
                   ),
                 ),
               ),
             ),
           ),
           // Grouping Text Field / Formatted Structure Display
           Expanded(
             flex: 3,
             child: GestureDetector(
               onTap: () => _startStructureEdit(instance.id),
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                     color: isEditing ? AppColors.primary(context).withOpacity(0.1) : AppColors.background(context).withOpacity(0.5),
                     border: Border.all(
                       color: isEditing ? AppColors.primary(context) : AppColors.border(context).withOpacity(0.5),
                       width: isEditing ? 2.0 : 1.0,
                     ),
                     borderRadius: BorderRadius.circular(4),
                 ),
                 child: isEditing
                   ? _buildStructureEditor(context, instance.id)
                   : FittedBox(
                       fit: BoxFit.scaleDown,
                       alignment: Alignment.centerLeft,
                       child: FormattedStructure(instance.structure),
                     ),
               ),
             ),
           ),
           const SizedBox(width: 4),
           // Pattern actions
           PopupMenuButton<_PatternMenu>(
             tooltip: 'Opciones del patrón',
             icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary(context)),
             onSelected: (action) => _onPatternMenu(action, instance, onRemove),
             itemBuilder: (_) => [
               _menuItem(_PatternMenu.rename, Icons.edit_outlined, 'Renombrar'),
               _menuItem(_PatternMenu.saveToLibrary, Icons.library_add_outlined, 'Guardar en la librería'),
               _menuItem(_PatternMenu.share, Icons.share_outlined, 'Compartir patrón'),
               _menuItem(_PatternMenu.duplicate, Icons.copy_rounded, 'Duplicar'),
               const PopupMenuDivider(),
               _menuItem(_PatternMenu.remove, Icons.close_rounded, 'Quitar de la sesión', color: AppColors.accentRed(context)),
             ],
           ),
        ],
      ),
      // Sequencer Cells (Responsive & Auto-Wrapping)
      sequencer: SequencerGrid(
        pulses: instance.pulses,
        // Quick tap: cycle the sound type
        onCellTap: (c) {
          final current = instance.pulses[c.pulse].subdivisions[c.sub];
          onPulseSubdivisionChange(c.pulse, c.sub, (current + 1) % BeatColors.typeCount);
        },
        // Long press: "volume mode" — drag up/down to change the event volume.
        onCellLongPressStart: (c) {
          final pulse = instance.pulses[c.pulse];
          _startVolumeEdit(instance.id, c.pulse, c.sub, pulse.subdivisions[c.sub], pulse.volumeAt(c.sub));
        },
        onCellLongPressMove: _updateVolumeEdit,
        onCellLongPressEnd: _endVolumeEdit,
        highlightedCell: edit != null && edit.instanceId == instance.id
            ? (pulse: edit.pulseIndex, sub: edit.subIndex)
            : null,
      ),
      // Track Strip (Volume, Mute, Solo, Sound) — compact inline row
      footer: MixerStrip(
        volume: instance.volume,
        onVolumeChanged: onVolChanged,
        isMuted: instance.isMuted,
        onMuteToggle: onMuteToggle,
        isSolo: instance.isSolo,
        onSoloToggle: onSoloToggle,
        trailing: _buildInstanceSoundSelector(context, instance),
      ),
    );
  }

  Future<void> _onPatternMenu(_PatternMenu action, HomeMetronomeInstance instance, VoidCallback onRemove) async {
    _closeAllKeyboards();
    final metronome = context.read<MetronomeProvider>();
    switch (action) {
      case _PatternMenu.rename:
        await _renameInstance(instance);
      case _PatternMenu.saveToLibrary:
        await _savePatternToLibrary(instance);
      case _PatternMenu.share:
        _sharePattern(metronome.createPatternFromInstance(instance.id, name: instance.title));
      case _PatternMenu.duplicate:
        metronome.duplicateInstance(instance.id);
      case _PatternMenu.remove:
        onRemove();
    }
  }

  /// Rename dialog for a pattern of the session.
  Future<void> _renameInstance(HomeMetronomeInstance instance) async {
    _closeAllKeyboards();
    final controller = TextEditingController(text: instance.title);
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        void submit() {
          final v = controller.text.trim();
          if (v.isNotEmpty) Navigator.pop(ctx, v);
        }

        return AlertDialog(
          title: const Text('Renombrar patrón'),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: AppColors.textPrimary(ctx)),
            decoration: InputDecoration(
              labelText: 'Nombre',
              labelStyle: TextStyle(color: AppColors.textSecondary(ctx)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary(ctx))),
            ),
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary(ctx))),
            ),
            TextButton(
              onPressed: submit,
              child: Text('OK', style: TextStyle(color: AppColors.primary(ctx), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    if (name != null && name != instance.title && mounted) {
      context.read<MetronomeProvider>().renameInstance(instance.id, name);
    }
  }

  /// Saves (or updates) the instance as a pattern in the library.
  /// The pattern keeps its id, so saving again updates the same library entry.
  Future<void> _savePatternToLibrary(HomeMetronomeInstance instance) async {
    final patProvider = context.read<PatternEditorProvider>();
    final metronome = context.read<MetronomeProvider>();
    final pat = metronome.createPatternFromInstance(instance.id, name: instance.title);
    final existed = patProvider.getPatternById(pat.id) != null;

    await patProvider.upsertPattern(pat);
    metronome.markInstanceClean(instance.id, pat.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existed ? '«${pat.name}» actualizado en la librería' : '«${pat.name}» guardado en la librería'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Per-pattern sound set selector ("Global" = follows the sound chosen in Settings).
  Widget _buildInstanceSoundSelector(BuildContext context, HomeMetronomeInstance instance) {
    final metronome = context.read<MetronomeProvider>();
    final hasOverride = instance.soundSet != null;
    final label = metronome.effectiveSoundSet(instance);
    const globalValue = '__global__';
    final accent = AppColors.primary(context);

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
    final color = BeatColors.of(context, edit.type);
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

  // --- CUSTOM KEYBOARD ---

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
            final Color color = complete ? AppColors.primary(context) : AppColors.accentRed(context);
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

/// Actions of the session menu (AppBar ⋮).
enum _SessionMenu { newSession, open, saveAs, share, playlists, settings }

/// Actions of the pattern card menu (⋮).
enum _PatternMenu { rename, saveToLibrary, share, duplicate, remove }
