import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/widgets/undo_snackbar.dart';
import 'package:metronomo_standalone/services/share_actions.dart';
import 'package:metronomo_standalone/models/playlist_model.dart';
import 'package:metronomo_standalone/providers/playlist_provider.dart';
import 'package:metronomo_standalone/providers/session_provider.dart';
import 'package:metronomo_standalone/screens/playlist_player_screen.dart';

/// Management screen for creating, editing, and launching Playlists.
///
/// With [embedded] it renders as a tab of the Library (no AppBar, FAB to
/// create); otherwise as a standalone pushed screen.
class PlaylistsScreen extends StatefulWidget {
  final bool embedded;

  /// Lower-case name filter (Library search). Empty = show all.
  final String searchQuery;

  const PlaylistsScreen({super.key, this.embedded = false, this.searchQuery = ''});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {

  // ── Create / Rename dialog ─────────────────────────────────────────────
  void _showCreatePlaylistDialog({Playlist? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing != null ? "Editar Playlist" : "Nueva Playlist",
          style: TextStyle(color: AppColors.textPrimary(ctx)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: TextStyle(color: AppColors.textPrimary(ctx)),
              decoration: InputDecoration(
                labelText: "Nombre",
                labelStyle: TextStyle(color: AppColors.textSecondary(ctx)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border(ctx))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary(ctx))),
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
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final provider = context.read<PlaylistProvider>();
              if (existing != null) {
                await provider.updatePlaylist(existing.copyWith(
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                ));
              } else {
                await provider.addPlaylist(Playlist(
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(
              existing != null ? "ACTUALIZAR" : "CREAR",
              style: TextStyle(color: AppColors.primary(ctx), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Delete (confirmation + undo) ───────────────────────────────────────
  Future<void> _deletePlaylist(Playlist playlist) async {
    final ok = await confirmDelete(
      context,
      title: 'Eliminar playlist',
      message: '¿Eliminar «${playlist.name}»? Las sesiones que contiene no se borran.',
    );
    if (!ok || !mounted) return;
    final provider = context.read<PlaylistProvider>();
    final removed = await provider.deletePlaylist(playlist.id);
    if (removed == null || !mounted) return;
    showUndoSnackBar(
      context,
      message: '«${playlist.name}» eliminada',
      onUndo: () => provider.restorePlaylist(removed.$1, removed.$2),
    );
  }

  // ── Open playlist detail (edit sessions order) ─────────────────────────
  void _openPlaylistDetail(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlaylistDetailScreen(playlistId: playlist.id),
      ),
    );
  }

  // ── Share playlist ─────────────────────────────────────────────────────
  void _sharePlaylist(Playlist playlist) => sharePlaylist(context, playlist);

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label, {Color? color}) {
    return PopupMenuItem<String>(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      // Embedded in the Library tab: no own AppBar, "new" is a FAB.
      floatingActionButton: widget.embedded
          ? FloatingActionButton.extended(
              heroTag: 'new-playlist',
              onPressed: () => _showCreatePlaylistDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva playlist'),
            )
          : null,
      appBar: widget.embedded ? null : AppBar(
        title: const Text("PLAYLISTS", style: TextStyle(letterSpacing: 2.0)),
        backgroundColor: AppColors.surface(context),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textSecondary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.primary(context)),
            onPressed: () => _showCreatePlaylistDialog(),
            tooltip: "Nueva Playlist",
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<PlaylistProvider>(
          builder: (context, provider, child) {
            final query = widget.searchQuery;
            final playlists = query.isEmpty
                ? provider.playlists
                : provider.playlists.where((p) => p.name.toLowerCase().contains(query)).toList();

            if (playlists.isEmpty && query.isNotEmpty) {
              return Center(
                child: Text(
                  'Ninguna playlist coincide con la búsqueda',
                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16),
                ),
              );
            }

            if (playlists.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.queue_music, size: 64, color: AppColors.textSecondary(context).withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      "No hay playlists",
                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Creá una playlist para organizar tus sesiones",
                      style: TextStyle(color: AppColors.textSecondary(context).withOpacity(0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showCreatePlaylistDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text("CREAR PLAYLIST"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Consumer<SessionProvider>(
              builder: (context, sessionProvider, _) {
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, widget.embedded ? 88 : 12),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final sessionCount = playlist.sessionIds.length;

                    // Resolve session names for subtitle
                    final sessionNames = playlist.sessionIds.map((id) {
                      final s = sessionProvider.getSessionById(id);
                      return s?.name ?? '(eliminada)';
                    }).toList();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openPlaylistDetail(playlist),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          playlist.name,
                                          style: TextStyle(
                                            color: AppColors.textPrimary(context),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "$sessionCount ${sessionCount == 1 ? 'sesión' : 'sesiones'}",
                                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Play button
                                  if (sessionCount > 0)
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PlaylistPlayerScreen(playlistId: playlist.id),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary(context),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary(context).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  PopupMenuButton<String>(
                                    tooltip: 'Opciones de la playlist',
                                    icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary(context)),
                                    onSelected: (action) {
                                      switch (action) {
                                        case 'share':
                                          _sharePlaylist(playlist);
                                        case 'edit':
                                          _showCreatePlaylistDialog(existing: playlist);
                                        case 'delete':
                                          _deletePlaylist(playlist);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      _menuItem('share', Icons.share_outlined, 'Compartir'),
                                      _menuItem('edit', Icons.edit_outlined, 'Renombrar'),
                                      const PopupMenuDivider(),
                                      _menuItem('delete', Icons.delete_outline, 'Eliminar', color: AppColors.accentRed(context)),
                                    ],
                                  ),
                                ],
                              ),
                              if (playlist.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  playlist.description,
                                  style: TextStyle(color: AppColors.textSecondary(context).withOpacity(0.7), fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (sessionNames.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: sessionNames.take(5).map((name) {
                                    final isDeleted = name == '(eliminada)';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDeleted
                                            ? AppColors.accentRed(context).withOpacity(0.15)
                                            : AppColors.surfaceHighlight(context),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDeleted
                                              ? AppColors.accentRed(context).withOpacity(0.3)
                                              : AppColors.border(context),
                                        ),
                                      ),
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: isDeleted
                                              ? AppColors.accentRed(context)
                                              : AppColors.textSecondary(context),
                                          fontSize: 11,
                                          fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (sessionNames.length > 5)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      "+${sessionNames.length - 5} más",
                                      style: TextStyle(color: AppColors.textSecondary(context).withOpacity(0.5), fontSize: 11),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  PLAYLIST DETAIL — Edit sessions order within a playlist
// ═════════════════════════════════════════════════════════════════════════════

class _PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;

  const _PlaylistDetailScreen({required this.playlistId});

  void _showAddSessionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Consumer<SessionProvider>(
          builder: (context, sessionProvider, _) {
            final sessions = sessionProvider.sessions;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Agregar Sesión",
                      style: TextStyle(color: AppColors.textPrimary(ctx), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        "No hay sesiones guardadas.\nCreá sesiones desde el metrónomo.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary(ctx)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return ListTile(
                            leading: Icon(Icons.music_note, color: AppColors.primary(ctx)),
                            title: Text(
                              session.name,
                              style: TextStyle(color: AppColors.textPrimary(ctx), fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${session.globalBpm} BPM • ${session.patternsConfig.length} pistas",
                              style: TextStyle(color: AppColors.textSecondary(ctx)),
                            ),
                            onTap: () async {
                              await context.read<PlaylistProvider>().addSessionToPlaylist(playlistId, session.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PlaylistProvider, SessionProvider>(
      builder: (context, playlistProvider, sessionProvider, _) {
        final playlist = playlistProvider.getPlaylistById(playlistId);
        if (playlist == null) {
          return Scaffold(
            backgroundColor: AppColors.background(context),
            appBar: AppBar(
              backgroundColor: AppColors.surface(context),
              title: const Text("Playlist no encontrada"),
            ),
            body: Center(
              child: Text("Esta playlist fue eliminada.", style: TextStyle(color: AppColors.textSecondary(context))),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background(context),
          appBar: AppBar(
            title: Text(playlist.name, style: const TextStyle(letterSpacing: 1.5)),
            backgroundColor: AppColors.surface(context),
            centerTitle: true,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.textSecondary(context)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.add, color: AppColors.primary(context)),
                onPressed: () => _showAddSessionSheet(context),
                tooltip: "Agregar Sesión",
              ),
              if (playlist.sessionIds.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.play_circle_fill, color: AppColors.primary(context)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaylistPlayerScreen(playlistId: playlist.id),
                      ),
                    );
                  },
                  tooltip: "Reproducir",
                ),
            ],
          ),
          body: SafeArea(
            child: playlist.sessionIds.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.playlist_add, size: 48, color: AppColors.textSecondary(context).withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          "Playlist vacía",
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Agregá sesiones usando el botón +",
                          style: TextStyle(color: AppColors.textSecondary(context).withOpacity(0.6), fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showAddSessionSheet(context),
                          icon: const Icon(Icons.add),
                          label: const Text("AGREGAR SESIÓN"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(12),
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary(context).withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      playlistProvider.reorderSessionInPlaylist(playlistId, oldIndex, newIndex);
                    },
                    itemCount: playlist.sessionIds.length,
                    itemBuilder: (context, index) {
                      final sessionId = playlist.sessionIds[index];
                      final session = sessionProvider.getSessionById(sessionId);
                      final isDeleted = session == null;

                      return Container(
                        key: ValueKey('$playlistId-$index-$sessionId'),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDeleted
                                ? AppColors.accentRed(context).withOpacity(0.4)
                                : AppColors.border(context),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isDeleted
                                  ? AppColors.accentRed(context).withOpacity(0.15)
                                  : AppColors.surfaceHighlight(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "${index + 1}",
                              style: TextStyle(
                                color: isDeleted ? AppColors.accentRed(context) : AppColors.primary(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          title: Text(
                            isDeleted ? "(sesión eliminada)" : session.name,
                            style: TextStyle(
                              color: isDeleted ? AppColors.accentRed(context) : AppColors.textPrimary(context),
                              fontWeight: FontWeight.bold,
                              fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                          subtitle: isDeleted
                              ? null
                              : Text(
                                  "${session.globalBpm} BPM • ${session.patternsConfig.length} pistas",
                                  style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                                ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: AppColors.accentRed(context), size: 20),
                                tooltip: 'Quitar de la playlist',
                                onPressed: () {
                                  playlistProvider.removeSessionFromPlaylist(playlistId, index);
                                  showUndoSnackBar(
                                    context,
                                    message: isDeleted ? 'Quitada de la playlist' : '«${session.name}» quitada de la playlist',
                                    onUndo: () => playlistProvider.insertSessionInPlaylist(playlistId, index, sessionId),
                                  );
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                              Icon(Icons.drag_handle, color: AppColors.textSecondary(context).withOpacity(0.5)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}
