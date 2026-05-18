import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/history_entry.dart';

class HistoryRepository {
  HistoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<HistoryEntry>> watchHistory(String userId) =>
      _db.watchHistory(userId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<void> insertHistoryDirect(HistoryEntry entry) async {
    await _db.insertHistory(_toCompanion(entry));
  }

  Future<List<HistoryEntry>> getPendingHistory(String userId) async {
    final rows = await _db.getPendingHistory(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markHistorySynced(id);

  HistoryTableCompanion _toCompanion(HistoryEntry h) => HistoryTableCompanion(
        id: Value(h.id),
        userId: Value(h.userId),
        actionType: Value(h.actionType),
        title: Value(h.title),
        description: Value(h.description),
        relatedType: Value(h.relatedType),
        relatedId: Value(h.relatedId),
        date: Value(h.date),
        createdAt: Value(h.createdAt),
        syncStatus: Value(h.syncStatus),
      );
}
