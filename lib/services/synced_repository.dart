import 'dart:convert';

import 'package:fede_apps_core/fede_apps_core.dart' show DeviceIdentity, SyncFields;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/synced_item.dart';

/// Library stored in SharedPreferences as a JSON list, with sync metadata
/// (see [SyncedItem] / [SyncFields]).
///
/// * [all] contains every item **including tombstones** (internal use:
///   persistence, future sync). Everything user-facing must use [active].
/// * Every persisted change sets `rev` (create = 1, then +1), `updatedAt`
///   and `dev` (= [DeviceIdentity.id]). The stored item is the reference for
///   `rev`, so callers may pass stale copies (e.g. undo of an overwrite).
/// * [delete] leaves a tombstone; [restore] (undo) revives it.
/// * Undo = going back in time ([restore] / [restoreSnapshot]): the item comes
///   back exactly as it was (data, `createdAt`/`updatedAt`, position); only
///   `rev` (+1) and `dev` move forward.
/// * [load] purges tombstones older than [SyncFields.tombstoneRetention].
/// * The order of the list is local presentation only: [reorder] doesn't
///   change any item (no rev bump).
abstract class SyncedRepository<T extends SyncedItem<T>> {
  SyncedRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// SharedPreferences key.
  String get storageKey;

  T fromJson(Map<String, dynamic> json);

  List<T> _items = [];

  /// Every item, tombstones included (internal).
  List<T> get all => List.unmodifiable(_items);

  /// Non-deleted items, in order (what the UI sees).
  List<T> get active => List.unmodifiable(_items.where((e) => !e.deleted));

  /// Active item by id, or null (tombstones are not found).
  T? byId(String id) {
    for (final e in _items) {
      if (e.id == id && !e.deleted) return e;
    }
    return null;
  }

  int _indexOf(String id) => _items.indexWhere((e) => e.id == id);

  /// Loads the library and purges expired tombstones (persisting if any).
  Future<List<T>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(storageKey);
    _items = [];
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final list = json.decode(jsonString) as List<dynamic>;
        _items = list.map((e) => fromJson(Map<String, dynamic>.from(e as Map))).toList();
      } catch (_) {
        _items = [];
      }
    }
    final now = _clock();
    final before = _items.length;
    _items.removeWhere((e) =>
        SyncFields.shouldPurge(deleted: e.deleted, deletedAt: e.deletedAt, now: now));
    if (_items.length != before) await save();
    return active;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, json.encode(_items.map((e) => e.toJson()).toList()));
  }

  /// Sets the sync metadata. `updatedAt` = now unless [updatedAt] is given
  /// (undo / internal changes that must keep the user-visible time).
  T _stamp(T item, {required int rev, bool deleted = false, DateTime? deletedAt, DateTime? updatedAt}) {
    return item.withSync(
      rev: rev,
      deleted: deleted,
      deletedAt: deletedAt,
      device: DeviceIdentity.id,
      updatedAt: updatedAt ?? _clock(),
    );
  }

  /// Adds [item] at the end with `rev` 1. If its id already exists (e.g. a
  /// tombstone being re-created by an import), that entry is replaced in place
  /// with `rev + 1` instead of creating a duplicate id.
  ///
  /// With [keepUpdatedAt] the item keeps its own `updatedAt` (e.g. a session
  /// restored to the library from a playlist snapshot).
  Future<T> create(T item, {bool keepUpdatedAt = false}) async {
    final index = _indexOf(item.id);
    final updatedAt = keepUpdatedAt ? item.updatedAt : null;
    final T stored;
    if (index == -1) {
      stored = _stamp(item, rev: 1, updatedAt: updatedAt);
      _items.add(stored);
    } else {
      stored = _stamp(item, rev: _items[index].rev + 1, updatedAt: updatedAt);
      _items[index] = stored;
    }
    await save();
    return stored;
  }

  /// Replaces the active item with the same id (`rev + 1`). Returns null if
  /// there's no such active item.
  ///
  /// With [keepUpdatedAt] the stored `updatedAt` is kept: for internal
  /// bookkeeping that doesn't change what the user sees (e.g. refreshing a
  /// playlist's fallback snapshots). `rev` still goes up for the sync.
  Future<T?> update(T item, {bool keepUpdatedAt = false}) async {
    final index = _indexOf(item.id);
    if (index == -1 || _items[index].deleted) return null;
    final stored = _stamp(
      item,
      rev: _items[index].rev + 1,
      updatedAt: keepUpdatedAt ? _items[index].updatedAt : null,
    );
    _items[index] = stored;
    await save();
    return stored;
  }

  /// "Go back in time" (undo): stores [snapshot] **exactly** as it was — all
  /// its data and its own `updatedAt` — as an active item. Only the sync
  /// bookkeeping moves forward: `rev` = stored `rev + 1` (so a future sync
  /// knows the restore happened) and `dev` = this device.
  ///
  /// * Existing id (active or tombstone): replaced in place; if
  ///   [activeIndex] is given, moved to that position among the active items.
  /// * Unknown id (e.g. tombstone already purged): inserted at [activeIndex]
  ///   (default: the end) with `rev = snapshot.rev + 1`.
  Future<T> restoreSnapshot(T snapshot, {int? activeIndex}) async {
    final index = _indexOf(snapshot.id);
    final T stored;
    if (index == -1) {
      stored = _stamp(snapshot, rev: snapshot.rev + 1, updatedAt: snapshot.updatedAt);
      _items.insert(_rawIndexForActive(activeIndex ?? active.length), stored);
    } else {
      stored = _stamp(snapshot, rev: _items[index].rev + 1, updatedAt: snapshot.updatedAt);
      _items[index] = stored;
      if (activeIndex != null) _moveToActiveIndex(stored, activeIndex);
    }
    await save();
    return stored;
  }

  /// Applies [change] to the active item [id] and stores it (`rev + 1`).
  Future<T?> mutate(String id, T Function(T current) change) async {
    final current = byId(id);
    if (current == null) return null;
    return update(change(current));
  }

  /// Tombstones the item (`deleted`, `deletedAt` = now, `rev + 1`).
  /// Returns the item as it was and its position among the active items.
  Future<(T, int)?> delete(String id) async {
    final index = _indexOf(id);
    if (index == -1 || _items[index].deleted) return null;
    final activeIndex = active.indexWhere((e) => e.id == id);
    final previous = _items[index];
    _items[index] = _stamp(previous, rev: previous.rev + 1, deleted: true, deletedAt: _clock());
    await save();
    return (previous, activeIndex);
  }

  /// Undo of [delete]: brings [item] back exactly as it was (data and
  /// `updatedAt`, see [restoreSnapshot]) at its original position
  /// [activeIndex], reviving the tombstone (`rev + 1`). If the tombstone is
  /// gone, re-inserts [item]. No-op if the item is already active.
  Future<T?> restore(T item, int activeIndex) async {
    final index = _indexOf(item.id);
    if (index != -1 && !_items[index].deleted) return null;
    return restoreSnapshot(item, activeIndex: activeIndex);
  }

  /// Moves an active item from [oldIndex] to [newIndex] (active positions,
  /// [newIndex] already adjusted for the removal). Local order only.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final act = active;
    if (oldIndex < 0 || oldIndex >= act.length) return;
    final item = act[oldIndex];
    _items.remove(item);
    final remaining = _items.where((e) => !e.deleted).toList();
    final target = newIndex.clamp(0, remaining.length);
    final rawIndex = target >= remaining.length
        ? _items.length
        : _items.indexOf(remaining[target]);
    _items.insert(rawIndex, item);
    await save();
  }

  /// Moves the (active) [item] so that it ends up at [activeIndex] among the
  /// active items. Does nothing if it's already there (keeps the raw layout).
  void _moveToActiveIndex(T item, int activeIndex) {
    final current = active.indexWhere((e) => e.id == item.id);
    if (current == -1 || current == activeIndex) return;
    _items.removeWhere((e) => e.id == item.id);
    _items.insert(_rawIndexForActive(activeIndex), item);
  }

  int _rawIndexForActive(int activeIndex) {
    final act = _items.where((e) => !e.deleted).toList();
    if (activeIndex <= 0) return act.isEmpty ? _items.length : _items.indexOf(act.first);
    if (activeIndex >= act.length) return _items.length;
    return _items.indexOf(act[activeIndex]);
  }
}
