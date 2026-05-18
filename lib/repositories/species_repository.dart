import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/species.dart';

class SpeciesRepository {
  SpeciesRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<Species>> watchSpecies(String userId) =>
      _db.watchSpecies(userId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<List<Species>> getSpecies(String userId) async {
    final rows = await _db.getSpecies(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<Species?> getById(String id) async {
    final row = await _db.getSpeciesById(id);
    return row?.toModel();
  }

  Future<Species> addSpecies(Species species) async {
    final now = DateTime.now().toIso8601String();
    final toSave = species.copyWith(
      id: species.id.isEmpty ? _uuid.v4() : species.id,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertSpecies(_toCompanion(toSave));
    return toSave;
  }

  Future<Species> updateSpecies(Species species) async {
    final now = DateTime.now().toIso8601String();
    final toSave = species.copyWith(updatedAt: now, syncStatus: 'pending');
    await _db.updateSpecies(_toCompanion(toSave));
    return toSave;
  }

  Future<void> deleteSpecies(String id) => _db.deleteSpecies(id);

  Future<void> seedDefaultsIfEmpty(String userId) async {
    final existing = await getSpecies(userId);
    if (existing.isNotEmpty) return;
    final now = DateTime.now().toIso8601String();
    await addSpecies(Species(
      id: _uuid.v4(),
      userId: userId,
      nameFr: 'Moutons',
      nameAr: 'أغنام',
      iconEmoji: '🐑',
      idPrefix: 'MOU',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    ));
    await addSpecies(Species(
      id: _uuid.v4(),
      userId: userId,
      nameFr: 'Vaches',
      nameAr: 'أبقار',
      iconEmoji: '🐄',
      idPrefix: 'VAC',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    ));
  }

  Future<List<Species>> getPending(String userId) async {
    final rows = await _db.getPendingSpecies(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markSpeciesSynced(id);

  SpeciesTableCompanion _toCompanion(Species s) => SpeciesTableCompanion(
        id: Value(s.id),
        userId: Value(s.userId),
        nameFr: Value(s.nameFr),
        nameAr: Value(s.nameAr),
        iconEmoji: Value(s.iconEmoji),
        idPrefix: Value(s.idPrefix),
        isDefault: Value(s.isDefault),
        createdAt: Value(s.createdAt),
        updatedAt: Value(s.updatedAt),
        syncStatus: Value(s.syncStatus),
      );
}
