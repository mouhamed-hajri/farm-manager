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

  Future<List<ReproductionEvent>> getForAnimal(String userId, String animalId) async {
    final rows = await _db.getAllReproductionForAnimal(userId, animalId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<List<ReproductionEvent>> getAllForUser(String userId) async {
    final rows = await _db.getAllReproductionEventsForUser(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  /// Closes all open reproduction cycles for a female (on death or sale).
  Future<void> cancelOpenCycles(String userId, String animalId, String reason) async {
    final all = await _db.getAllReproductionForAnimal(userId, animalId);
    final events = all.map((r) => r.toModel()).toList();

    final groups = <String, List<ReproductionEvent>>{};
    for (final e in events) {
      final gid = e.pregnancyGroupId ?? e.id;
      groups.putIfAbsent(gid, () => []).add(e);
    }

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final closingTypes = {
      ReproductionEventType.birth,
      ReproductionEventType.pregnancyLoss,
      ReproductionEventType.cycleCanceled,
    };

    for (final entry in groups.entries) {
      final types = entry.value.map((e) => e.eventType).toSet();
      if (types.intersection(closingTypes).isEmpty) {
        await add(ReproductionEvent(
          id: '',
          userId: userId,
          animalId: animalId,
          eventType: ReproductionEventType.cycleCanceled,
          eventDate: today,
          pregnancyGroupId: entry.key,
          notes: reason,
          createdAt: '',
          updatedAt: '',
          syncStatus: 'pending',
        ));
      }
    }
  }

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
