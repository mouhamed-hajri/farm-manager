import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/animal.dart';
import '../models/expense.dart';
import '../models/history_entry.dart';
import '../models/sale.dart';
import 'history_repository.dart';
import 'reproduction_event_repository.dart';

class SaleRepository {
  SaleRepository(this._db, this._historyRepo, this._reproRepo);

  final AppDatabase _db;
  final HistoryRepository _historyRepo;
  final ReproductionEventRepository _reproRepo;
  final _uuid = const Uuid();

  Stream<List<Sale>> watchAllSales(String userId) =>
      _db.watchAllSales(userId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Stream<List<Sale>> watchSalesForCrop(String userId, String cropId) =>
      _db.watchSalesForCrop(userId, cropId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<Sale?> getSaleForAnimal(String userId, String animalId) async {
    final row = await _db.getSaleForAnimal(userId, animalId);
    return row?.toModel();
  }

  Future<Sale> addSale(Sale sale) async {
    final now = DateTime.now().toIso8601String();
    final toSave = sale.copyWith(
      id: sale.id.isEmpty ? _uuid.v4() : sale.id,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertSale(_toCompanion(toSave));
    // History
    final history = HistoryEntry(
      id: _uuid.v4(),
      userId: toSave.userId,
      actionType: _historyActionForScope(toSave.scope),
      title: _historyTitleForSale(toSave),
      description: '${toSave.totalPrice.toStringAsFixed(0)} TND${toSave.buyerName == null ? '' : ' - ${toSave.buyerName}'}',
      relatedType: 'sale',
      relatedId: toSave.id,
      date: toSave.saleDate,
      createdAt: now,
      syncStatus: 'pending',
    );
    await _historyRepo.insertHistoryDirect(history);
    return toSave;
  }

  /// Creates an animal sale and flips the animal status to 'sold' atomically.
  Future<Sale> sellAnimal({
    required Animal animal,
    required double salePrice,
    required String saleDate,
    String? buyerName,
    String? buyerPhone,
    String? receiptPhotoLocalPath,
    String? notes,
  }) async {
    final now = DateTime.now().toIso8601String();
    final saleId = _uuid.v4();

    // A breeder ram counted under his mother becomes independent when sold:
    // his valuation stays on him (so mother keeps the credit via motherId lookup),
    // and we record an internal expense = valuation as his cost basis.
    final isBreederSale = animal.isBreeder &&
        animal.isCountedUnderMother &&
        animal.valuationAmount != null;

    return _db.transaction<Sale>(() async {
      final sale = Sale(
        id: saleId,
        userId: animal.userId,
        scope: SaleScope.animal,
        linkedAnimalId: animal.id,
        quantity: 1.0,
        unit: SaleUnit.piece,
        unitPrice: salePrice,
        totalPrice: salePrice,
        buyerName: buyerName,
        buyerPhone: buyerPhone,
        saleDate: saleDate,
        receiptPhotoLocalPath: receiptPhotoLocalPath,
        notes: notes,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );
      await _db.insertSale(_toCompanion(sale));

      // Flip animal status + handle breeder finance transition.
      await _db.updateAnimal(AnimalsTableCompanion(
        id: Value(animal.id),
        userId: Value(animal.userId),
        speciesId: Value(animal.speciesId),
        farmId: Value(animal.farmId),
        nickname: Value(animal.nickname),
        gender: Value(animal.gender),
        breed: Value(animal.breed),
        color: Value(animal.color),
        birthDate: Value(animal.birthDate),
        weight: Value(animal.weight),
        healthStatus: Value(animal.healthStatus),
        status: const Value(AnimalStatus.sold),
        purchaseDate: Value(animal.purchaseDate),
        purchasePrice: Value(animal.purchasePrice),
        sellerName: Value(animal.sellerName),
        sellerPhone: Value(animal.sellerPhone),
        purchaseLocation: Value(animal.purchaseLocation),
        photoLocalPath: Value(animal.photoLocalPath),
        photoCloudUrl: Value(animal.photoCloudUrl),
        motherId: Value(animal.motherId),
        fatherId: Value(animal.fatherId),
        deathDate: Value(animal.deathDate),
        deathCause: Value(animal.deathCause),
        deathNotes: Value(animal.deathNotes),
        notes: Value(animal.notes),
        financeOwnerId: isBreederSale
            ? Value(animal.id) // independent: own ledger
            : Value(animal.effectiveFinanceOwnerId),
        financeMode: isBreederSale
            ? const Value(AnimalFinanceMode.self)
            : Value(animal.effectiveFinanceMode),
        isBreeder: Value(animal.isBreeder),
        weaningDate: Value(animal.weaningDate),
        valuationAmount: Value(animal.valuationAmount), // keep for mother credit
        birthEventId: Value(animal.birthEventId),
        createdAt: Value(animal.createdAt),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ));

      // Create internal cost-basis expense on ram's own ledger.
      if (isBreederSale) {
        await _db.insertExpense(ExpensesTableCompanion(
          id: Value(_uuid.v4()),
          userId: Value(animal.userId),
          scope: const Value(ExpenseScope.animal),
          linkedAnimalId: Value(animal.id),
          linkedSpeciesId: Value(animal.speciesId),
          amount: Value(animal.valuationAmount!),
          category: const Value('breeder_valuation'),
          date: Value(saleDate),
          description: const Value('Valeur estimée bélier (transfert interne)'),
          createdAt: Value(now),
          updatedAt: Value(now),
          syncStatus: const Value('pending'),
        ));
      }

      // Cancel open reproduction cycles if female
      if (animal.gender == AnimalGender.female) {
        await _reproRepo.cancelOpenCycles(
            animal.userId, animal.id, 'Vente de l\'animal');
      }

      // History
      await _historyRepo.insertHistoryDirect(HistoryEntry(
        id: _uuid.v4(),
        userId: animal.userId,
        actionType: 'animal_sold',
        title: 'Animal vendu : ${animal.farmId}',
        description: '${salePrice.toStringAsFixed(0)} TND${buyerName == null ? '' : ' - $buyerName'}',
        relatedType: 'animal',
        relatedId: animal.id,
        date: saleDate,
        createdAt: now,
        syncStatus: 'pending',
      ));

      return sale;
    });
  }

  Future<Sale> updateSale(Sale sale) async {
    final now = DateTime.now().toIso8601String();
    final toSave = sale.copyWith(updatedAt: now, syncStatus: 'pending');
    await _db.updateSale(_toCompanion(toSave));
    return toSave;
  }

  Future<void> deleteSale(String id) => _db.deleteSale(id);

  Future<List<Sale>> getPending(String userId) async {
    final rows = await _db.getPendingSales(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markSaleSynced(id);

  String _historyActionForScope(String scope) {
    switch (scope) {
      case SaleScope.crop:
        return 'crop_sold';
      case SaleScope.product:
        return 'product_sold';
      case SaleScope.animal:
        return 'animal_sold';
      default:
        return 'sale_added';
    }
  }

  String _historyTitleForSale(Sale s) {
    switch (s.scope) {
      case SaleScope.crop:
        return 'Vente culture';
      case SaleScope.product:
        return 'Vente produit : ${s.productName ?? ""}';
      case SaleScope.animal:
        return 'Vente animal';
      default:
        return 'Vente';
    }
  }

  SalesTableCompanion _toCompanion(Sale s) => SalesTableCompanion(
        id: Value(s.id),
        userId: Value(s.userId),
        scope: Value(s.scope),
        linkedAnimalId: Value(s.linkedAnimalId),
        linkedCropId: Value(s.linkedCropId),
        productName: Value(s.productName),
        quantity: Value(s.quantity),
        unit: Value(s.unit),
        unitPrice: Value(s.unitPrice),
        totalPrice: Value(s.totalPrice),
        buyerName: Value(s.buyerName),
        buyerPhone: Value(s.buyerPhone),
        saleDate: Value(s.saleDate),
        receiptPhotoLocalPath: Value(s.receiptPhotoLocalPath),
        receiptPhotoCloudUrl: Value(s.receiptPhotoCloudUrl),
        notes: Value(s.notes),
        createdAt: Value(s.createdAt),
        updatedAt: Value(s.updatedAt),
        syncStatus: Value(s.syncStatus),
      );
}
