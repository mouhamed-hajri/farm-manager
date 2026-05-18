import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/reproduction_event.dart';

class ReproductionEventRepository {
  ReproductionEventRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<ReproductionEvent>> watchForAnimal(String userId, String animalId) =>
      _db.watchReproductionForAnimal(userId, animalId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<ReproductionEvent> add(ReproductionEvent event) async {
    final now = DateTime.now().toIso8601String();
    final toSave = event.copyWith(
      id: event.id.isEmpty ? _uuid.v4() : event.id,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertReproductionEvent(_toCompanion(toSave));
    return toSave;
  }

  Future<void> delete(String id) => _db.deleteReproductionEvent(id);

  Future<List<ReproductionEvent>> getPending(String userId) async {
    final rows = await _db.getPendingReproductionEvents(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markReproductionEventSynced(id);

  ReproductionEventsTableCompanion _toCompanion(ReproductionEvent e) =>
      ReproductionEventsTableCompanion(
        id: Value(e.id),
        userId: Value(e.userId),
        animalId: Value(e.animalId),
        eventType: Value(e.eventType),
        partnerId: Value(e.partnerId),
        eventDate: Value(e.eventDate),
        dueDate: Value(e.dueDate),
        offspringCount: Value(e.offspringCount),
        pregnancyGroupId: Value(e.pregnancyGroupId),
        notes: Value(e.notes),
        createdAt: Value(e.createdAt),
        updatedAt: Value(e.updatedAt),
        syncStatus: Value(e.syncStatus),
      );
}
