import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/crop.dart';
import '../models/harvest.dart';
import '../models/history_entry.dart';
import '../models/sale.dart';
import 'history_repository.dart';
import 'sale_repository.dart';

class HarvestRepository {
  HarvestRepository(this._db, this._saleRepo, this._historyRepo);

  final AppDatabase _db;
  final SaleRepository _saleRepo;
  final HistoryRepository _historyRepo;
  final _uuid = const Uuid();

  Stream<List<Harvest>> watchForCrop(String userId, String cropId) =>
      _db.watchHarvestsForCrop(userId, cropId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<List<Harvest>> getAll(String userId) async {
    final rows = await _db.getAllHarvests(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  /// Creates a harvest. If [pricePerUnit] > 0, also creates a linked Sale.
  Future<Harvest> add(Harvest harvest, {required Crop crop}) async {
    final now = DateTime.now().toIso8601String();
    final id = harvest.id.isEmpty ? _uuid.v4() : harvest.id;
    final total = (harvest.pricePerUnit != null && harvest.pricePerUnit! > 0)
        ? harvest.quantity * harvest.pricePerUnit!
        : null;

    String? linkedSaleId;
    if (total != null && total > 0) {
      final sale = await _saleRepo.addSale(Sale(
        id: '',
        userId: harvest.userId,
        scope: SaleScope.crop,
        linkedCropId: harvest.cropId,
        productName: crop.nameFr,
        quantity: harvest.quantity,
        unit: _mapUnitToSaleUnit(harvest.unit),
        unitPrice: harvest.pricePerUnit!,
        totalPrice: total,
        saleDate: harvest.harvestDate,
        notes: harvest.notes,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      ));
      linkedSaleId = sale.id;
    }

    final toSave = harvest.copyWith(
      id: id,
      totalPrice: total,
      linkedSaleId: linkedSaleId,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertHarvest(_toCompanion(toSave));

    // History entry
    final unitLabel = HarvestUnit.labelFr(toSave.unit);
    await _historyRepo.insertHistoryDirect(HistoryEntry(
      id: _uuid.v4(),
      userId: toSave.userId,
      actionType: 'harvest_recorded',
      title: '🚜 Récolte — ${crop.nameFr}',
      description:
          '${toSave.quantity.toStringAsFixed(toSave.quantity == toSave.quantity.roundToDouble() ? 0 : 1)} $unitLabel'
          '${total != null ? ' · ${total.toStringAsFixed(0)} TND' : ''}',
      relatedType: 'crop',
      relatedId: toSave.cropId,
      date: toSave.harvestDate,
      createdAt: now,
      syncStatus: 'pending',
    ));

    return toSave;
  }

  /// Deletes the harvest. Also deletes the linked sale (if any).
  Future<void> delete(Harvest harvest) async {
    if (harvest.linkedSaleId != null) {
      await _saleRepo.deleteSale(harvest.linkedSaleId!);
    }
    await _db.deleteHarvest(harvest.id);
  }

  Future<List<Harvest>> getPending(String userId) async {
    final rows = await _db.getPendingHarvests(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markHarvestSynced(id);

  String _mapUnitToSaleUnit(String harvestUnit) {
    switch (harvestUnit) {
      case HarvestUnit.kg:
      case HarvestUnit.quintal:
        return SaleUnit.kg;
      case HarvestUnit.caisse:
        return SaleUnit.grandeCaisse;
      case HarvestUnit.litre:
        return SaleUnit.litre;
      default:
        return SaleUnit.piece;
    }
  }

  HarvestsTableCompanion _toCompanion(Harvest h) => HarvestsTableCompanion(
        id: Value(h.id),
        userId: Value(h.userId),
        cropId: Value(h.cropId),
        harvestDate: Value(h.harvestDate),
        quantity: Value(h.quantity),
        unit: Value(h.unit),
        pricePerUnit: Value(h.pricePerUnit),
        totalPrice: Value(h.totalPrice),
        notes: Value(h.notes),
        linkedSaleId: Value(h.linkedSaleId),
        createdAt: Value(h.createdAt),
        updatedAt: Value(h.updatedAt),
        syncStatus: Value(h.syncStatus),
      );
}
