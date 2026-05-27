import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/history_entry.dart';
import '../services/firebase_service.dart';

class HistoryRepository {
  HistoryRepository(this._db, this._firebase);

  final AppDatabase _db;
  final FirebaseService _firebase;

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

  /// Deletes a single history entry locally + on Firestore.
  /// Firestore failure is swallowed (offline-first); the local row is gone
  /// either way so the user gets immediate feedback.
  Future<void> deleteEntry(HistoryEntry entry) async {
    await _db.deleteHistory(entry.id);
    try {
      await _firebase.deleteHistory(entry.userId, entry.id);
    } catch (_) {/* offline-tolerant */}
  }

  Future<void> deleteAllForUser(String userId) async {
    await _db.deleteAllHistoryForUser(userId);
  }

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
