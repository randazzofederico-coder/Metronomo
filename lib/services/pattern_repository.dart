import '../models/pattern_model.dart';
import 'synced_repository.dart';

/// Repository service for managing the global Pattern Library.
///
/// Persists to SharedPreferences (`pattern_library`) with sync metadata:
/// see [SyncedRepository] (rev, tombstones, purge).
class PatternRepository extends SyncedRepository<Pattern> {
  PatternRepository({super.clock});

  @override
  String get storageKey => 'pattern_library';

  @override
  Pattern fromJson(Map<String, dynamic> json) => Pattern.fromJson(json);
}
