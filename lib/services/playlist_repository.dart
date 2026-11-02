import '../models/playlist_model.dart';
import 'synced_repository.dart';

/// Repository service for managing saved Playlists.
///
/// Persists to SharedPreferences (`playlist_library`) with sync metadata:
/// see [SyncedRepository] (rev, tombstones, purge). Playlists are
/// self-contained (sessions embedded): see [Playlist].
class PlaylistRepository extends SyncedRepository<Playlist> {
  PlaylistRepository({super.clock, super.sync});

  @override
  String get storageKey => 'playlist_library';

  @override
  String get collection => 'playlists';

  @override
  Playlist fromJson(Map<String, dynamic> json) => Playlist.fromJson(json);
}
