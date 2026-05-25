import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/weight_measurement.dart';

class WeightMeasurementRepository {
  WeightMeasurementRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<WeightMeasurement>> watchForAnimal(
          String userId, String animalId) =>
      _db.watchWeightMeasurementsForAnimal(userId, animalId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<WeightMeasurement> add(WeightMeasurement m) async {
    final now = DateTime.now().toIso8601String();
    final toSave = m.copyWith(
      id: m.id.isEmpty ? _uuid.v4() : m.id,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertWeightMeasurement(WeightMeasurementsTableCompanion(
      id: Value(toSave.id),
      userId: Value(toSave.userId),
      animalId: Value(toSave.animalId),
      weight: Value(toSave.weight),
      measurementDate: Value(toSave.measurementDate),
      notes: Value(toSave.notes),
      createdAt: Value(toSave.createdAt),
      updatedAt: Value(toSave.updatedAt),
      syncStatus: Value(toSave.syncStatus),
    ));
    return toSave;
  }

  Future<void> delete(String id) => _db.deleteWeightMeasurement(id);

  Future<List<WeightMeasurement>> getPending(String userId) async {
    final rows = await _db.getPendingWeightMeasurements(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) =>
      _db.markWeightMeasurementSynced(id);

  Future<List<WeightMeasurement>> getForAnimal(String userId, String animalId) async {
    final rows = await _db.getWeightMeasurementsForAnimalOnce(userId, animalId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<List<WeightMeasurement>> getAll(String userId) async {
    final rows = await _db.getAllWeightMeasurements(userId);
    return rows.map((r) => r.toModel()).toList();
  }
}
