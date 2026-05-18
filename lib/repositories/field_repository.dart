import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/field.dart';

class FieldRepository {
  FieldRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<FarmField>> watchFields(String userId) =>
      _db.watchFields(userId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<FarmField?> getById(String id) async {
    final row = await _db.getFieldById(id);
    return row?.toModel();
  }

  Future<FarmField> addField(FarmField field) async {
    final now = DateTime.now().toIso8601String();
    final toSave = field.copyWith(
      id: field.id.isEmpty ? _uuid.v4() : field.id,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertField(_toCompanion(toSave));
    return toSave;
  }

  Future<FarmField> updateField(FarmField field) async {
    final now = DateTime.now().toIso8601String();
    final toSave = field.copyWith(updatedAt: now, syncStatus: 'pending');
    await _db.updateField(_toCompanion(toSave));
    return toSave;
  }

  Future<void> deleteField(String id) => _db.deleteField(id);

  Future<List<FarmField>> getPending(String userId) async {
    final rows = await _db.getPendingFields(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markFieldSynced(id);

  FieldsTableCompanion _toCompanion(FarmField f) => FieldsTableCompanion(
        id: Value(f.id),
        userId: Value(f.userId),
        name: Value(f.name),
        areaText: Value(f.areaText),
        locationText: Value(f.locationText),
        ownership: Value(f.ownership),
        photoLocalPath: Value(f.photoLocalPath),
        photoCloudUrl: Value(f.photoCloudUrl),
        rentAmount: Value(f.rentAmount),
        rentPeriod: Value(f.rentPeriod),
        rentStartDate: Value(f.rentStartDate),
        rentEndDate: Value(f.rentEndDate),
        landlordName: Value(f.landlordName),
        landlordPhone: Value(f.landlordPhone),
        notes: Value(f.notes),
        createdAt: Value(f.createdAt),
        updatedAt: Value(f.updatedAt),
        syncStatus: Value(f.syncStatus),
      );
}
