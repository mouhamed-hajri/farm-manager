import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/breed.dart';

class BreedRepository {
  BreedRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<Breed>> watchBreeds(String userId, String speciesId) =>
      _db.watchBreeds(userId, speciesId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<List<Breed>> getBreeds(String userId, String speciesId) async {
    final rows = await _db.getBreeds(userId, speciesId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<Breed> addBreed({
    required String userId,
    required String speciesId,
    required String name,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    await _db.insertBreed(BreedsTableCompanion(
      id: Value(id),
      userId: Value(userId),
      speciesId: Value(speciesId),
      name: Value(name),
      createdAt: Value(now),
      updatedAt: Value(now),
      syncStatus: const Value('pending'),
    ));
    return Breed(
      id: id,
      userId: userId,
      speciesId: speciesId,
      name: name,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
  }

  Future<void> deleteBreed(String id) => _db.deleteBreed(id);

  Future<List<Breed>> getPending(String userId) async {
    final rows = await _db.getPendingBreeds(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markBreedSynced(id);

  Future<List<Breed>> getAllBreeds(String userId) async {
    final rows = await _db.getAllBreeds(userId);
    return rows.map((r) => r.toModel()).toList();
  }
}
