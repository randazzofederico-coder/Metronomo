import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist_model.dart';

/// Repository service for managing saved Playlists.
///
/// Provides CRUD operations with automatic persistence to SharedPreferences.
class PlaylistRepository {
  static const String _storageKey = 'playlist_library';

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  /// Loads all playlists from persistent storage.
  Future<List<Playlist>> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
        _playlists = jsonList
            .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _playlists = [];
      }
    } else {
      _playlists = [];
    }

    return List.unmodifiable(_playlists);
  }

  /// Saves all playlists to persistent storage.
  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_playlists.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  /// Adds a new playlist and persists.
  Future<void> addPlaylist(Playlist playlist) async {
    _playlists.add(playlist);
    await _savePlaylists();
  }

  /// Updates an existing playlist by ID and persists.
  Future<void> updatePlaylist(Playlist updated) async {
    final index = _playlists.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _playlists[index] = updated.copyWith(updatedAt: DateTime.now());
      await _savePlaylists();
    }
  }

  /// Deletes a playlist by ID and persists.
  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
  }

  /// Retrieves a playlist by ID, or null if not found.
  Playlist? getPlaylistById(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Reorders playlists by moving an item from [oldIndex] to [newIndex].
  Future<void> reorderPlaylists(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = _playlists.removeAt(oldIndex);
    _playlists.insert(newIndex, item);
    await _savePlaylists();
  }
}
