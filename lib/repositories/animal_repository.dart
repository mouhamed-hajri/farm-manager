import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/animal.dart';
import '../models/expense.dart';
import '../models/history_entry.dart';
import '../services/farm_id_service.dart';
import 'expense_repository.dart';
import 'history_repository.dart';

class AnimalRepository {
  AnimalRepository(
    this._db,
    this._expenseRepo,
    this._historyRepo,
    this._farmIdService,
  );

  final AppDatabase _db;
  final ExpenseRepository _expenseRepo;
  final HistoryRepository _historyRepo;
  final FarmIdService _farmIdService;
  final _uuid = const Uuid();

  Stream<List<Animal>> watchAllAnimals(String userId) =>
      _db.watchAllAnimals(userId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Stream<List<Animal>> watchAnimalsBySpecies(String userId, String speciesId) =>
      _db.watchAnimalsBySpecies(userId, speciesId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<Animal?> getById(String id) async {
    final row = await _db.getAnimalById(id);
    return row?.toModel();
  }

  /// Adds a new animal. Generates a farm_id atomically using the given prefix.
  /// If [purchasePrice] > 0, also creates an expense + history entry in the
  /// same transaction.
  Future<Animal> addAnimal({
    required Animal animal,
    required String speciesIdPrefix,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    return _db.transaction<Animal>(() async {
      final farmId = await _farmIdService.generate(animal.userId, speciesIdPrefix);
      final toSave = animal.copyWith(
        id: id,
        farmId: farmId,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );

      await _db.insertAnimal(_toCompanion(toSave));

      if ((toSave.purchasePrice ?? 0) > 0) {
        final expense = Expense(
          id: _uuid.v4(),
          userId: toSave.userId,
          scope: ExpenseScope.animal,
          linkedAnimalId: toSave.id,
          linkedSpeciesId: toSave.speciesId,
          amount: toSave.purchasePrice!,
          category: 'animal_purchase',
          date: toSave.purchaseDate ?? now.substring(0, 10),
          description: 'Achat de ${toSave.displayName}',
          createdAt: now,
          updatedAt: now,
          syncStatus: 'pending',
        );
        await _expenseRepo.insertExpenseDirect(expense);

        final history = HistoryEntry(
          id: _uuid.v4(),
          userId: toSave.userId,
          actionType: 'animal_added',
          title: 'Animal ajouté : ${toSave.farmId}',
          description: '${toSave.displayName} acheté à ${toSave.purchasePrice} TND',
          relatedType: 'animal',
          relatedId: toSave.id,
          date: toSave.purchaseDate ?? now.substring(0, 10),
          createdAt: now,
          syncStatus: 'pending',
        );
        await _historyRepo.insertHistoryDirect(history);
      } else {
        final history = HistoryEntry(
          id: _uuid.v4(),
          userId: toSave.userId,
          actionType: 'animal_added',
          title: 'Animal ajouté : ${toSave.farmId}',
          description: toSave.displayName,
          relatedType: 'animal',
          relatedId: toSave.id,
          date: now.substring(0, 10),
          createdAt: now,
          syncStatus: 'pending',
        );
        await _historyRepo.insertHistoryDirect(history);
      }

      return toSave;
    });
  }

  Future<Animal> updateAnimal(Animal animal) async {
    final now = DateTime.now().toIso8601String();
    final toSave = animal.copyWith(updatedAt: now, syncStatus: 'pending');
    await _db.updateAnimal(_toCompanion(toSave));
    return toSave;
  }

  Future<void> deleteAnimal(String id) => _db.deleteAnimal(id);

  Future<void> markDead(Animal animal,
      {required String deathDate,
      String? deathCause,
      String? deathNotes}) async {
    final now = DateTime.now().toIso8601String();
    final updated = animal.copyWith(
      status: AnimalStatus.dead,
      deathDate: deathDate,
      deathCause: deathCause,
      deathNotes: deathNotes,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.updateAnimal(_toCompanion(updated));
    final history = HistoryEntry(
      id: _uuid.v4(),
      userId: animal.userId,
      actionType: 'animal_died',
      title: 'Animal décédé : ${animal.farmId}',
      description: deathCause ?? '',
      relatedType: 'animal',
      relatedId: animal.id,
      date: deathDate,
      createdAt: now,
      syncStatus: 'pending',
    );
    await _historyRepo.insertHistoryDirect(history);
  }

  Future<List<Animal>> getPendingAnimals(String userId) async {
    final rows = await _db.getPendingAnimals(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markAnimalSynced(id);

  AnimalsTableCompanion _toCompanion(Animal a) => AnimalsTableCompanion(
        id: Value(a.id),
        userId: Value(a.userId),
        speciesId: Value(a.speciesId),
        farmId: Value(a.farmId),
        nickname: Value(a.nickname),
        gender: Value(a.gender),
        breed: Value(a.breed),
        color: Value(a.color),
        birthDate: Value(a.birthDate),
        weight: Value(a.weight),
        healthStatus: Value(a.healthStatus),
        status: Value(a.status),
        purchaseDate: Value(a.purchaseDate),
        purchasePrice: Value(a.purchasePrice),
        sellerName: Value(a.sellerName),
        sellerPhone: Value(a.sellerPhone),
        purchaseLocation: Value(a.purchaseLocation),
        photoLocalPath: Value(a.photoLocalPath),
        photoCloudUrl: Value(a.photoCloudUrl),
        motherId: Value(a.motherId),
        fatherId: Value(a.fatherId),
        deathDate: Value(a.deathDate),
        deathCause: Value(a.deathCause),
        deathNotes: Value(a.deathNotes),
        notes: Value(a.notes),
        createdAt: Value(a.createdAt),
        updatedAt: Value(a.updatedAt),
        syncStatus: Value(a.syncStatus),
      );
}
