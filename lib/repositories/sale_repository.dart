import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/animal.dart';
import '../models/history_entry.dart';
import '../models/sale.dart';
import 'history_repository.dart';

class SaleRepository {
  SaleRepository(this._db, this._historyRepo);

  final AppDatabase _db;
  final HistoryRepository _historyRepo;
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

      // Flip animal status
      final updatedAnimal = animal.copyWith(
        status: AnimalStatus.sold,
        updatedAt: now,
        syncStatus: 'pending',
      );
      await _db.updateAnimal(AnimalsTableCompanion(
        id: Value(updatedAnimal.id),
        userId: Value(updatedAnimal.userId),
        speciesId: Value(updatedAnimal.speciesId),
        farmId: Value(updatedAnimal.farmId),
        nickname: Value(updatedAnimal.nickname),
        gender: Value(updatedAnimal.gender),
        breed: Value(updatedAnimal.breed),
        color: Value(updatedAnimal.color),
        birthDate: Value(updatedAnimal.birthDate),
        weight: Value(updatedAnimal.weight),
        healthStatus: Value(updatedAnimal.healthStatus),
        status: Value(updatedAnimal.status),
        purchaseDate: Value(updatedAnimal.purchaseDate),
        purchasePrice: Value(updatedAnimal.purchasePrice),
        sellerName: Value(updatedAnimal.sellerName),
        sellerPhone: Value(updatedAnimal.sellerPhone),
        purchaseLocation: Value(updatedAnimal.purchaseLocation),
        photoLocalPath: Value(updatedAnimal.photoLocalPath),
        photoCloudUrl: Value(updatedAnimal.photoCloudUrl),
        motherId: Value(updatedAnimal.motherId),
        fatherId: Value(updatedAnimal.fatherId),
        deathDate: Value(updatedAnimal.deathDate),
        deathCause: Value(updatedAnimal.deathCause),
        deathNotes: Value(updatedAnimal.deathNotes),
        notes: Value(updatedAnimal.notes),
        createdAt: Value(updatedAnimal.createdAt),
        updatedAt: Value(updatedAnimal.updatedAt),
        syncStatus: Value(updatedAnimal.syncStatus),
      ));

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
