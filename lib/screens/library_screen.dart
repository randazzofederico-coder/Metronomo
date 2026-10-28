import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/models/pattern_model.dart';
import 'package:metronomo_standalone/models/session_model.dart';
import 'package:metronomo_standalone/providers/metronome_provider.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/screens/playlists_screen.dart';
import 'package:metronomo_standalone/services/share_actions.dart';
import 'package:metronomo_standalone/widgets/formatted_structure.dart';
import 'package:metronomo_standalone/widgets/undo_snackbar.dart';

/// "Biblioteca": sessions, library patterns and playlists in one place, with
/// search and the same actions for every item (⋮).
///
/// Opening things happens in "Tocar": the screen only reports the intent via
/// [onOpenSession] / [onAddPattern] / [onNewSession] and [HomeShell] routes it.
class LibraryScreen extends StatefulWidget {
  final Future<void> Function(Session session) onOpenSession;
  final void Function(Pattern pattern) onAddPattern;
  final Future<void> Function() onNewSession;

  const LibraryScreen({
    super.key,
    required this.onOpenSession,
    required this.onAddPattern,
    required this.onNewSession,
  });

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final TextEditingController _search = TextEditingController();
  bool _searching = false;

  /// Shows the given tab (0 = Sesiones, 1 = Patrones, 2 = Playlists).
  void showTab(int index) => _tabs.animateTo(index);

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim().toLowerCase();

  bool _matches(String name) => _query.isEmpty || name.toLowerCase().contains(_query);

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                style: TextStyle(color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre…',
                  hintStyle: TextStyle(color: AppColors.textSecondary(context)),
                  border: InputBorder.none,
                ),
              )
            : const Text('BIBLIOTECA', style: TextStyle(letterSpacing: 2.0)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded, color: AppColors.textSecondary(context)),
            tooltip: _searching ? 'Cerrar búsqueda' : 'Buscar',
            onPressed: _toggleSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary(context),
          labelColor: AppColors.primary(context),
          unselectedLabelColor: AppColors.textSecondary(context),
          tabs: const [
            Tab(text: 'Sesiones'),
            Tab(text: 'Patrones'),
            Tab(text: 'Playlists'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildSessionsTab(context),
          _buildPatternsTab(context),
          PlaylistsScreen(embedded: true, searchQuery: _query),
        ],
      ),
    );
  }

  // ── Sessions ─────────────────────────────────────────────────────────────

  Widget _buildSessionsTab(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final activeId = context.select<MetronomeProvider, String?>((m) => m.activeSessionId);
    final sessions = sessionProvider.sessions.where((s) => _matches(s.name)).toList();

    return Scaffold(
      backgroundColor: AppColors.background(context),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-session',
        onPressed: widget.onNewSession,
        icon: const Icon(Icons.add),
        label: const Text('Nueva sesión'),
      ),
      body: sessions.isEmpty
          ? _emptyState(
              context,
              icon: Icons.library_music_outlined,
              text: _query.isEmpty ? 'No hay sesiones guardadas' : 'Ninguna sesión coincide con «${_search.text.trim()}»',
              hint: _query.isEmpty ? 'Armá una sesión en Tocar y guardala con 💾' : null,
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isActive = session.id == activeId;
                final patterns = session.patternsConfig.length;
                return _LibraryTile(
                  title: session.name,
                  subtitle: '${session.globalBpm} BPM · $patterns ${patterns == 1 ? 'patrón' : 'patrones'}',
                  description: session.description,
                  icon: Icons.library_music_rounded,
                  selected: isActive,
                  badge: isActive ? 'En Tocar' : null,
                  onTap: () => widget.onOpenSession(session),
                  menu: [
                    _MenuAction(Icons.play_arrow_rounded, 'Abrir en Tocar', () => widget.onOpenSession(session)),
                    _MenuAction(Icons.share_outlined, 'Compartir', () => shareSession(context, session)),
                    _MenuAction(Icons.copy_rounded, 'Duplicar', () => _duplicateSession(session)),
                    _MenuAction(Icons.edit_outlined, 'Renombrar', () => _renameSession(session)),
                    _MenuAction(Icons.delete_outline, 'Eliminar', () => _deleteSession(session), destructive: true),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _duplicateSession(Session session) async {
    final copy = session.copyWith(
      id: const Uuid().v4(),
      name: '${session.name} (copia)',
      createdAt: DateTime.now(),
    );
    await context.read<SessionProvider>().addSession(copy);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«${copy.name}» creada')));
    }
  }

  Future<void> _renameSession(Session session) async {
    final name = await _askName(context, title: 'Renombrar sesión', initial: session.name);
    if (name == null || name == session.name || !mounted) return;
    await context.read<SessionProvider>().updateSession(session.copyWith(name: name));
    if (!mounted) return;
    context.read<MetronomeProvider>().onSessionRenamed(session.id, name);
  }

  Future<void> _deleteSession(Session session) async {
    final ok = await confirmDelete(
      context,
      title: 'Eliminar sesión',
      message: '¿Eliminar «${session.name}» de tu biblioteca?',
    );
    if (!ok || !mounted) return;
    final provider = context.read<SessionProvider>();
    final removed = await provider.deleteSession(session.id);
    if (removed == null || !mounted) return;
    showUndoSnackBar(
      context,
      message: '«${session.name}» eliminada',
      onUndo: () => provider.restoreSession(removed.$1, removed.$2),
    );
  }

  // ── Patterns ─────────────────────────────────────────────────────────────

  Widget _buildPatternsTab(BuildContext context) {
    final patProvider = context.watch<PatternEditorProvider>();
    final patterns = patProvider.patterns.where((p) => _matches(p.name)).toList();

    if (patterns.isEmpty) {
      return _emptyState(
        context,
        icon: Icons.graphic_eq_rounded,
        text: _query.isEmpty ? 'La librería de patrones está vacía' : 'Ningún patrón coincide con «${_search.text.trim()}»',
        hint: _query.isEmpty ? 'En Tocar, usá ⋮ → «Guardar en la librería» en un patrón' : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: patterns.length,
      itemBuilder: (context, index) {
        final pattern = patterns[index];
        return _LibraryTile(
          title: pattern.name,
          trailingInfo: FormattedStructure(pattern.structure),
          icon: Icons.graphic_eq_rounded,
          onTap: () => widget.onAddPattern(pattern),
          tooltip: 'Agregar a la sesión',
          menu: [
            _MenuAction(Icons.add_circle_outline, 'Agregar a la sesión', () => widget.onAddPattern(pattern)),
            _MenuAction(Icons.share_outlined, 'Compartir', () => sharePattern(context, pattern)),
            _MenuAction(Icons.edit_outlined, 'Renombrar', () => _renamePattern(pattern)),
            _MenuAction(Icons.delete_outline, 'Eliminar de la librería', () => _deletePattern(pattern), destructive: true),
          ],
        );
      },
    );
  }

  Future<void> _renamePattern(Pattern pattern) async {
    final name = await _askName(context, title: 'Renombrar patrón', initial: pattern.name);
    if (name == null || name == pattern.name || !mounted) return;
    await context.read<PatternEditorProvider>().updatePattern(pattern.copyWith(name: name));
  }

  Future<void> _deletePattern(Pattern pattern) async {
    final patProvider = context.read<PatternEditorProvider>();
    // Safety net: make sure no legacy session still depends on it.
    await context.read<SessionProvider>().embedMissingPatterns(patProvider.getPatternById);
    final removed = await patProvider.deletePattern(pattern.id);
    if (removed == null || !mounted) return;
    showUndoSnackBar(
      context,
      message: '«${pattern.name}» eliminado de la librería',
      onUndo: () => patProvider.restorePattern(removed.$1, removed.$2),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _emptyState(BuildContext context, {required IconData icon, required String text, String? hint}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textSecondary(context).withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16)),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary(context).withOpacity(0.6), fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Simple "name" dialog. Returns the trimmed name or null if cancelled.
Future<String?> _askName(BuildContext context, {required String title, required String initial}) {
  final controller = TextEditingController(text: initial);
  controller.selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = controller.text.trim();
        if (v.isNotEmpty) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        title: Text(title),
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
}

class _MenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool destructive;

  const _MenuAction(this.icon, this.label, this.onSelected, {this.destructive = false});
}

/// One row of the library: icon, title, subtitle/extra info and a ⋮ menu.
class _LibraryTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? description;
  final Widget? trailingInfo;
  final IconData icon;
  final bool selected;
  final String? badge;
  final String? tooltip;
  final VoidCallback onTap;
  final List<_MenuAction> menu;

  const _LibraryTile({
    required this.title,
    this.subtitle,
    this.description,
    this.trailingInfo,
    required this.icon,
    this.selected = false,
    this.badge,
    this.tooltip,
    required this.onTap,
    required this.menu,
  });

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.primary(context);
    final Widget tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? primary : AppColors.border(context), width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Icon(icon, color: selected ? primary : AppColors.textSecondary(context), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(badge!, style: TextStyle(color: primary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                    ],
                    if (description != null && description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textSecondary(context).withOpacity(0.7), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingInfo != null) ...[
                const SizedBox(width: 8),
                trailingInfo!,
              ],
              PopupMenuButton<int>(
                tooltip: 'Opciones',
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary(context)),
                onSelected: (i) => menu[i].onSelected(),
                itemBuilder: (_) => [
                  for (var i = 0; i < menu.length; i++)
                    PopupMenuItem<int>(
                      value: i,
                      child: Row(
                        children: [
                          Icon(menu[i].icon,
                              size: 20,
                              color: menu[i].destructive ? AppColors.accentRed(context) : AppColors.textSecondary(context)),
                          const SizedBox(width: 12),
                          Text(menu[i].label,
                              style: menu[i].destructive ? TextStyle(color: AppColors.accentRed(context)) : null),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? tile : Tooltip(message: tooltip!, waitDuration: const Duration(milliseconds: 600), child: tile);
  }
}
