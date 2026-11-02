import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';
import 'package:metronomo_standalone/l10n/l10n.dart';
import 'package:metronomo_standalone/widgets/undo_snackbar.dart';
import 'package:metronomo_standalone/services/share_actions.dart';
import 'package:metronomo_standalone/services/playlist_item_actions.dart';
import 'package:metronomo_standalone/models/playlist_model.dart';
import 'package:metronomo_standalone/providers/pattern_editor_provider.dart';
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
          existing != null ? ctx.l10n.playlistsEditTitle : ctx.l10n.playlistsNewTitle,
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
                labelText: ctx.l10n.commonName,
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
                labelText: ctx.l10n.playlistsDescriptionLabel,
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
            child: Text(ctx.l10n.commonCancel.toUpperCase(), style: TextStyle(color: AppColors.textSecondary(ctx))),
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
              existing != null ? ctx.l10n.playlistsUpdateButton : ctx.l10n.commonCreate.toUpperCase(),
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
      title: context.l10n.playlistsDeleteTitle,
      message: context.l10n.playlistsDeleteConfirm(playlist.name),
    );
    if (!ok || !mounted) return;
    final provider = context.read<PlaylistProvider>();
    final removed = await provider.deletePlaylist(playlist.id);
    if (removed == null || !mounted) return;
    showUndoSnackBar(
      context,
      message: context.l10n.playlistsDeleted(playlist.name),
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
              label: Text(context.l10n.playlistsNewButton),
            )
          : null,
      appBar: widget.embedded ? null : AppBar(
        title: Text(context.l10n.playlistsTitle, style: TextStyle(letterSpacing: 2.0)),
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
            tooltip: context.l10n.playlistsNewTitle,
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
                  context.l10n.playlistsNoMatch,
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
                      context.l10n.playlistsEmpty,
                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.playlistsEmptyHint,
                      style: TextStyle(color: AppColors.textSecondary(context).withOpacity(0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showCreatePlaylistDialog(),
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.playlistsCreateButton),
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

            return Builder(
              builder: (context) {
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, widget.embedded ? 88 : 12),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final sessionCount = playlist.items.length;

                    // Session names for subtitle (library version, or the
                    // snapshot if the session is no longer in the library).
                    final sessionNames = provider.resolvedSessions(playlist).map((s) => s.name).toList();

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
                                          context.l10n.playlistsSessionCount(sessionCount),
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
                                    tooltip: context.l10n.playlistsOptions,
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
                                      _menuItem('share', Icons.share_outlined, context.l10n.commonShare),
                                      _menuItem('edit', Icons.edit_outlined, context.l10n.commonRename),
                                      const PopupMenuDivider(),
                                      _menuItem('delete', Icons.delete_outline, context.l10n.commonDelete, color: AppColors.accentRed(context)),
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
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceHighlight(context),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.border(context)),
                                      ),
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: AppColors.textSecondary(context),
                                          fontSize: 11,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (sessionNames.length > 5)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      context.l10n.playlistsMoreCount(sessionNames.length - 5),
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
                      ctx.l10n.playlistsAddSession,
                      style: TextStyle(color: AppColors.textPrimary(ctx), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (sessions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        ctx.l10n.playlistsAddSessionEmpty,
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
                              context.l10n.playlistsSessionSubtitle(session.globalBpm, session.patternsConfig.length),
                              style: TextStyle(color: AppColors.textSecondary(ctx)),
                            ),
                            onTap: () async {
                              // The item links to the library session (edits
                              // there are reflected) and keeps a snapshot
                              // (patterns embedded) in case it's deleted.
                              final patProvider = context.read<PatternEditorProvider>();
                              final playlistProvider = context.read<PlaylistProvider>();
                              await patProvider.ensureLoaded;
                              final copy = session.withEmbeddedPatterns(patProvider.getPatternById);
                              await playlistProvider.addSessionToPlaylist(playlistId, copy);
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
    return Consumer<PlaylistProvider>(
      builder: (context, playlistProvider, _) {
        final playlist = playlistProvider.getPlaylistById(playlistId);
        if (playlist == null) {
          return Scaffold(
            backgroundColor: AppColors.background(context),
            appBar: AppBar(
              backgroundColor: AppColors.surface(context),
              title: Text(context.l10n.playlistsNotFoundTitle),
            ),
            body: Center(
              child: Text(context.l10n.playlistsNotFoundMessage, style: TextStyle(color: AppColors.textSecondary(context))),
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
                tooltip: context.l10n.playlistsAddSession,
              ),
              if (playlist.items.isNotEmpty)
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
                  tooltip: context.l10n.playlistsPlay,
                ),
            ],
          ),
          body: SafeArea(
            child: playlist.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.playlist_add, size: 48, color: AppColors.textSecondary(context).withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.playlistsDetailEmpty,
                          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.playlistsDetailEmptyHint,
                          style: TextStyle(color: AppColors.textSecondary(context).withOpacity(0.6), fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _showAddSessionSheet(context),
                          icon: const Icon(Icons.add),
                          label: Text(context.l10n.playlistsAddSessionButton),
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
                      playlistProvider.reorderItemsInPlaylist(playlistId, oldIndex, newIndex);
                    },
                    itemCount: playlist.items.length,
                    itemBuilder: (context, index) {
                      // Library version of the session (source of truth), or
                      // the snapshot if it's no longer in the library.
                      final item = playlist.items[index];
                      final session = playlistProvider.resolveSession(item);
                      final inLibrary = playlistProvider.isInLibrary(item);
                      final secondary = AppColors.textSecondary(context);

                      return Container(
                        key: ValueKey('$playlistId-${item.id}'),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceHighlight(context),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "${index + 1}",
                              style: TextStyle(
                                color: AppColors.primary(context),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          title: Text(
                            session.name,
                            style: TextStyle(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.playlistsSessionSubtitle(session.globalBpm, session.patternsConfig.length),
                                style: TextStyle(color: secondary, fontSize: 12),
                              ),
                              // Subtle indicator: the playlist plays its saved
                              // snapshot; the session can be brought back.
                              if (!inLibrary)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 4,
                                    children: [
                                      Icon(Icons.link_off_rounded, size: 13, color: secondary.withOpacity(0.7)),
                                      Text(
                                        context.l10n.playlistItemNotInLibrary,
                                        style: TextStyle(
                                          color: secondary.withOpacity(0.7),
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: () => restorePlaylistItemToLibrary(context, playlistId, item),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          child: Text(
                                            context.l10n.playlistItemRestoreToLibrary,
                                            style: TextStyle(
                                              color: AppColors.primary(context),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: secondary, size: 20),
                                tooltip: context.l10n.playlistItemEditSession,
                                onPressed: () => editPlaylistItemSession(context, playlistId, item),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: AppColors.accentRed(context), size: 20),
                                tooltip: context.l10n.playlistsRemoveSession,
                                onPressed: () async {
                                  final removed = await playlistProvider.removeItemFromPlaylist(playlistId, index);
                                  if (removed == null || !context.mounted) return;
                                  showUndoSnackBar(
                                    context,
                                    message: context.l10n.playlistsSessionRemoved(session.name),
                                    // Back in time: the playlist exactly as it was.
                                    onUndo: () => playlistProvider.undoItemRemoval(removed.$2),
                                  );
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                              Icon(Icons.drag_handle, color: secondary.withOpacity(0.5)),
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
