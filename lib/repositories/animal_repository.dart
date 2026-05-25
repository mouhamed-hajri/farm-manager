import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/animal.dart';
import '../models/animal_ledger.dart';
import '../models/expense.dart';
import '../models/history_entry.dart';
import '../models/sale.dart';
import '../services/farm_id_service.dart';
import '../services/firebase_service.dart';
import 'expense_repository.dart';
import 'history_repository.dart';
import 'reproduction_event_repository.dart';

class AnimalRepository {
  AnimalRepository(
    this._db,
    this._expenseRepo,
    this._historyRepo,
    this._farmIdService,
    this._firebase,
    this._reproRepo,
  );

  final AppDatabase _db;
  final ExpenseRepository _expenseRepo;
  final HistoryRepository _historyRepo;
  final FarmIdService _farmIdService;
  final FirebaseService _firebase;
  final ReproductionEventRepository _reproRepo;
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
  /// Sets financeOwnerId/financeMode based on gender and motherId.
  /// If [purchasePrice] > 0, also creates an expense + history entry.
  Future<Animal> addAnimal({
    required Animal animal,
    required String speciesIdPrefix,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    return _db.transaction<Animal>(() async {
      final farmId = await _farmIdService.generate(animal.userId, speciesIdPrefix);

      // Compute finance mode and owner.
      final String financeMode;
      final String financeOwnerId;
      if (animal.gender == AnimalGender.male && animal.motherId != null) {
        financeMode = AnimalFinanceMode.countedUnderMother;
        financeOwnerId = animal.motherId!;
      } else if (animal.gender == AnimalGender.female && animal.motherId != null) {
        financeMode = AnimalFinanceMode.independentFemaleCenter;
        financeOwnerId = id;
      } else {
        financeMode = AnimalFinanceMode.self;
        financeOwnerId = id;
      }

      final toSave = animal.copyWith(
        id: id,
        farmId: farmId,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
        financeOwnerId: financeOwnerId,
        financeMode: financeMode,
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

  /// Deletes an animal and all its linked expenses and sales — both locally
  /// and from Firestore (fire-and-forget; errors are swallowed for offline).
  Future<void> deleteAnimal(String id) async {
    final animal = await _db.getAnimalById(id);
    List<String> expenseIds = [];
    List<String> saleIds = [];
    await _db.transaction(() async {
      if (animal != null) {
        expenseIds = await _db.deleteExpensesForAnimal(animal.userId, id);
        saleIds = await _db.deleteSalesForAnimal(animal.userId, id);
      }
      await _db.deleteAnimal(id);
    });
    if (animal != null) {
      for (final eid in expenseIds) {
        try { await _firebase.deleteExpense(animal.userId, eid); } catch (_) {}
      }
      for (final sid in saleIds) {
        try { await _firebase.deleteSale(animal.userId, sid); } catch (_) {}
      }
      try { await _firebase.deleteAnimal(animal.userId, id); } catch (_) {}
    }
  }

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

    if (animal.gender == AnimalGender.female) {
      await _reproRepo.cancelOpenCycles(
          animal.userId, animal.id, 'Décès de l\'animal');
    }

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

  Future<List<Animal>> getByMotherId(String userId, String motherId) async {
    final rows = await _db.getAnimalsByMotherId(userId, motherId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<List<Animal>> getByBirthEventId(String userId, String birthEventId) async {
    final rows = await _db.getAnimalsByBirthEventId(userId, birthEventId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<List<Animal>> getMalesForSpecies(String userId, String speciesId) async {
    final rows = await _db.getMalesForSpecies(userId, speciesId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<AnimalLedger?> getFinanceLedger(String userId, String ownerId) async {
    final ownerRow = await _db.getAnimalById(ownerId);
    if (ownerRow == null) return null;
    final owner = ownerRow.toModel();

    // All animals counted under this owner (by financeOwnerId).
    final allRows = await _db.getAnimalsByFinanceOwner(userId, ownerId);
    final maleOffspring = allRows
        .map((r) => r.toModel())
        .where((a) => a.id != ownerId)
        .toList();

    // Female offspring: motherId = owner, gender = female.
    final allChildren = await _db.getAnimalsByMotherId(userId, ownerId);
    final femaleOffspring = allChildren
        .map((r) => r.toModel())
        .where((a) => a.gender == AnimalGender.female)
        .toList();

    // Expenses and sales for owner + male offspring.
    final ownerExp = (await _db.getExpensesForAnimal(userId, ownerId))
        .map((r) => r.toModel())
        .toList();
    final ownerSal = (await _db.getSalesForAnimal(userId, ownerId))
        .map((r) => r.toModel())
        .toList();

    final offspringExp = <String, List<Expense>>{};
    final offspringSal = <String, List<Sale>>{};
    for (final o in maleOffspring) {
      offspringExp[o.id] = (await _db.getExpensesForAnimal(userId, o.id))
          .map((r) => r.toModel())
          .toList();
      offspringSal[o.id] = (await _db.getSalesForAnimal(userId, o.id))
          .map((r) => r.toModel())
          .toList();
    }

    return AnimalLedger(
      owner: owner,
      maleOffspring: maleOffspring,
      femaleOffspring: femaleOffspring,
      ownerExpenses: ownerExp,
      offspringExpenses: offspringExp,
      ownerSales: ownerSal,
      offspringSales: offspringSal,
    );
  }

  Future<List<Animal>> getBySpecies(String userId, String speciesId) async {
    final rows = await _db.getAnimalsBySpecies(userId, speciesId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<List<Animal>> getAll(String userId) async {
    final rows = await _db.getAllAnimals(userId);
    return rows.map((r) => r.toModel()).toList();
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
        financeOwnerId: Value(a.effectiveFinanceOwnerId),
        financeMode: Value(a.effectiveFinanceMode),
        birthEventId: Value(a.birthEventId),
        createdAt: Value(a.createdAt),
        updatedAt: Value(a.updatedAt),
        syncStatus: Value(a.syncStatus),
      );
}
