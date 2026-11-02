import '../models/session_model.dart';
import 'synced_repository.dart';

/// Repository service for managing saved Sessions.
///
/// Persists to SharedPreferences (`session_library`) with sync metadata:
/// see [SyncedRepository] (rev, tombstones, purge).
class SessionRepository extends SyncedRepository<Session> {
  SessionRepository({super.clock, super.sync});

  @override
  String get storageKey => 'session_library';

  @override
  String get collection => 'sessions';

  @override
  Session fromJson(Map<String, dynamic> json) => Session.fromJson(json);
}
