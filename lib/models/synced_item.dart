import 'package:fede_apps_core/fede_apps_core.dart' show SyncFields;

/// Common interface of the items stored in the libraries (patterns, sessions,
/// playlists), prepared for a future cloud sync.
///
/// See [SyncFields] (fede_apps_core) for the data contract:
///  * [rev] goes up on **every** persisted change (create = 1).
///  * Deleting doesn't remove the item: it becomes a tombstone
///    ([deleted] = true, [deletedAt] = when). Tombstones are hidden from the
///    UI and purged after [SyncFields.tombstoneRetention].
///  * [device] is the `DeviceIdentity.id` of the device that made the change.
///
/// The repositories ([SyncedRepository]) are the only ones that set these
/// fields; the UI never needs to touch them.
abstract interface class SyncedItem<T> {
  String get id;
  int get rev;
  bool get deleted;
  DateTime? get deletedAt;
  String? get device;
  DateTime get updatedAt;

  /// Returns a copy with the given sync metadata (everything else unchanged).
  T withSync({
    required int rev,
    required bool deleted,
    DateTime? deletedAt,
    String? device,
    required DateTime updatedAt,
  });

  Map<String, dynamic> toJson();
}

/// Removes the sync metadata from an item JSON (used for copies that are not
/// library items: sessions embedded in playlists and shared-link payloads).
Map<String, dynamic> stripSyncFields(Map<String, dynamic> json) => json
  ..remove(SyncFields.rev)
  ..remove(SyncFields.deleted)
  ..remove(SyncFields.deletedAt)
  ..remove(SyncFields.device);
