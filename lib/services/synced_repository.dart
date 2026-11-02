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

  T _stamp(T item, {required int rev, bool deleted = false, DateTime? deletedAt}) {
    return item.withSync(
      rev: rev,
      deleted: deleted,
      deletedAt: deletedAt,
      device: DeviceIdentity.id,
      updatedAt: _clock(),
    );
  }

  /// Adds [item] at the end with `rev` 1. If its id already exists (e.g. a
  /// tombstone being re-created by an import), that entry is replaced in place
  /// with `rev + 1` instead of creating a duplicate id.
  Future<T> create(T item) async {
    final index = _indexOf(item.id);
    final T stored;
    if (index == -1) {
      stored = _stamp(item, rev: 1);
      _items.add(stored);
    } else {
      stored = _stamp(item, rev: _items[index].rev + 1);
      _items[index] = stored;
    }
    await save();
    return stored;
  }

  /// Replaces the active item with the same id (`rev + 1`). Returns null if
  /// there's no such active item.
  Future<T?> update(T item) async {
    final index = _indexOf(item.id);
    if (index == -1 || _items[index].deleted) return null;
    final stored = _stamp(item, rev: _items[index].rev + 1);
    _items[index] = stored;
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

  /// Undo of [delete]: revives the tombstone (`rev + 1`) at its original
  /// position, with the data of [item]. If the tombstone is gone, re-inserts
  /// [item] at [activeIndex]. No-op if the item is already active.
  Future<T?> restore(T item, int activeIndex) async {
    final index = _indexOf(item.id);
    if (index != -1 && !_items[index].deleted) return null;
    final T stored;
    if (index != -1) {
      stored = _stamp(item, rev: _items[index].rev + 1);
      _items[index] = stored;
    } else {
      stored = _stamp(item, rev: item.rev + 1);
      _items.insert(_rawIndexForActive(activeIndex), stored);
    }
    await save();
    return stored;
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

  int _rawIndexForActive(int activeIndex) {
    final act = _items.where((e) => !e.deleted).toList();
    if (activeIndex <= 0) return act.isEmpty ? _items.length : _items.indexOf(act.first);
    if (activeIndex >= act.length) return _items.length;
    return _items.indexOf(act[activeIndex]);
  }
}
