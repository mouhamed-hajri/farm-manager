import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/health_event.dart';

class HealthEventRepository {
  HealthEventRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<HealthEvent>> watchForAnimal(String userId, String animalId) =>
      _db.watchHealthForAnimal(userId, animalId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<HealthEvent> add(HealthEvent event) async {
    final now = DateTime.now().toIso8601String();
    final toSave = event.copyWith(
      id: event.id.isEmpty ? _uuid.v4() : event.id,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertHealthEvent(_toCompanion(toSave));
    return toSave;
  }

  Future<void> delete(String id) => _db.deleteHealthEvent(id);

  Future<List<HealthEvent>> getPending(String userId) async {
    final rows = await _db.getPendingHealthEvents(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markHealthEventSynced(id);

  HealthEventsTableCompanion _toCompanion(HealthEvent h) =>
      HealthEventsTableCompanion(
        id: Value(h.id),
        userId: Value(h.userId),
        animalId: Value(h.animalId),
        eventType: Value(h.eventType),
        description: Value(h.description),
        date: Value(h.date),
        vetName: Value(h.vetName),
        nextDueDate: Value(h.nextDueDate),
        notes: Value(h.notes),
        createdAt: Value(h.createdAt),
        updatedAt: Value(h.updatedAt),
        syncStatus: Value(h.syncStatus),
      );
}
