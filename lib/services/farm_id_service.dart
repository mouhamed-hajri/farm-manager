import 'package:drift/drift.dart';
import '../database/app_database.dart';

class FarmIdService {
  FarmIdService(this._db);

  final AppDatabase _db;

  /// Atomically increments counter and returns the next farm_id.
  /// Format: PREFIX-YEAR-NNNN (e.g., MOU-2026-0001).
  Future<String> generate(String userId, String prefix) async {
    final year = DateTime.now().year;
    return _db.transaction(() async {
      final existing = await _db.getCounter(userId, prefix, year);
      final next = (existing?.lastNumber ?? 0) + 1;
      await _db.upsertCounter(FarmIdCountersTableCompanion(
        userId: Value(userId),
        prefix: Value(prefix),
        year: Value(year),
        lastNumber: Value(next),
        syncStatus: const Value('pending'),
      ));
      return '$prefix-$year-${next.toString().padLeft(4, '0')}';
    });
  }

  /// Peeks at the next id without incrementing (for form preview).
  Future<String> preview(String userId, String prefix) async {
    final year = DateTime.now().year;
    final existing = await _db.getCounter(userId, prefix, year);
    final next = (existing?.lastNumber ?? 0) + 1;
    return '$prefix-$year-${next.toString().padLeft(4, '0')}';
  }
}
