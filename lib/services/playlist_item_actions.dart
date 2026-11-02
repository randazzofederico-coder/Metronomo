import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../l10n/l10n.dart';
import '../models/playlist_model.dart';
import '../models/session_model.dart';
import '../providers/playlist_provider.dart';
import '../providers/session_provider.dart';
import 'session_opener.dart';

/// Playlist item actions shared by the playlist editor and the player.

/// "Restaurar en la biblioteca": puts the item's snapshot back in the session
/// library under its linked id (reviving the tombstone if it's still there,
/// so the id stays the same). Items without a link get one (the snapshot id).
/// Returns the library session, or null if the playlist is gone.
Future<Session?> restorePlaylistItemToLibrary(
  BuildContext context,
  String playlistId,
  PlaylistItem item,
) async {
  final sessions = context.read<SessionProvider>();
  final playlists = context.read<PlaylistProvider>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;

  final id = item.sourceSessionId ?? item.session.id;
  final restored = await sessions.restoreFromSnapshot(item.session, id: id);
  if (item.sourceSessionId == null) {
    await playlists.linkItemToLibrary(playlistId, item.id, id);
  }
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(content: Text(l10n.playlistItemRestored(restored.name))));
  return restored;
}

/// "Editar sesión": opens the item's **library** session in Tocar as the
/// active session (same as opening it from the library), so it can be edited
/// and saved normally; every playlist that contains it follows. If the
/// session is no longer in the library, offers to restore it first.
Future<void> editPlaylistItemSession(
  BuildContext context,
  String playlistId,
  PlaylistItem item,
) async {
  final sessions = context.read<SessionProvider>();
  final linked = item.sourceSessionId;
  var library = linked == null ? null : sessions.getSessionById(linked);

  if (library == null) {
    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.playlistItemRestoreTitle),
        content: Text(ctx.l10n.playlistItemRestoreMessage(item.session.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel.toUpperCase(), style: TextStyle(color: AppColors.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ctx.l10n.playlistItemRestoreToLibrary,
              style: TextStyle(color: AppColors.primary(ctx), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (restore != true || !context.mounted) return;
    library = await restorePlaylistItemToLibrary(context, playlistId, item);
    if (library == null || !context.mounted) return;
  }

  await SessionOpener.open(context, library);
}
