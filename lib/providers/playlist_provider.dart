import 'dart:async';
import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../services/playlist_repository.dart';

/// Manages the playlist library state for the UI.
class PlaylistProvider extends ChangeNotifier {
  final PlaylistRepository _repository;

  PlaylistProvider({PlaylistRepository? repository})
      : _repository = repository ?? PlaylistRepository();

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  final Completer<void> _loadCompleter = Completer<void>();
  Future<void> get ensureLoaded => _loadCompleter.future;

  /// Loads playlists from persistent storage.
  Future<void> loadPlaylists() async {
    _playlists = List<Playlist>.from(await _repository.loadPlaylists());

    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
    notifyListeners();
  }

  /// Adds a new playlist to the library.
  Future<void> addPlaylist(Playlist playlist) async {
    await _loadCompleter.future;
    _playlists.add(playlist);
    await _repository.addPlaylist(playlist);
    notifyListeners();
  }

  /// Updates an existing playlist in the library.
  Future<void> updatePlaylist(Playlist updated) async {
    await _loadCompleter.future;
    final index = _playlists.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _playlists[index] = updated.copyWith(updatedAt: DateTime.now());
      await _repository.updatePlaylist(_playlists[index]);
      notifyListeners();
    }
  }

  /// Deletes a playlist from the library.
  Future<void> deletePlaylist(String playlistId) async {
    await _loadCompleter.future;
    _playlists.removeWhere((p) => p.id == playlistId);
    await _repository.deletePlaylist(playlistId);
    notifyListeners();
  }

  /// Retrieves a playlist by ID, or null if not found.
  Playlist? getPlaylistById(String id) {
    try {
      return _playlists.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Adds a session ID to a playlist at the end.
  Future<void> addSessionToPlaylist(String playlistId, String sessionId) async {
    await _loadCompleter.future;
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      final updatedIds = List<String>.from(playlist.sessionIds)..add(sessionId);
      _playlists[index] = playlist.copyWith(sessionIds: updatedIds);
      await _repository.updatePlaylist(_playlists[index]);
      notifyListeners();
    }
  }

  /// Removes a session at a specific index from a playlist.
  Future<void> removeSessionFromPlaylist(String playlistId, int sessionIndex) async {
    await _loadCompleter.future;
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      final updatedIds = List<String>.from(playlist.sessionIds)
        ..removeAt(sessionIndex);
      _playlists[index] = playlist.copyWith(sessionIds: updatedIds);
      await _repository.updatePlaylist(_playlists[index]);
      notifyListeners();
    }
  }

  /// Reorders sessions within a playlist.
  Future<void> reorderSessionInPlaylist(
      String playlistId, int oldIndex, int newIndex) async {
    await _loadCompleter.future;
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      final updatedIds = List<String>.from(playlist.sessionIds);
      if (oldIndex < newIndex) newIndex -= 1;
      final item = updatedIds.removeAt(oldIndex);
      updatedIds.insert(newIndex, item);
      _playlists[index] = playlist.copyWith(sessionIds: updatedIds);
      await _repository.updatePlaylist(_playlists[index]);
      notifyListeners();
    }
  }
}
