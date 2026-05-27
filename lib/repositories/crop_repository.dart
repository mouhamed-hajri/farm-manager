import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/crop.dart';
import '../models/history_entry.dart';
import 'history_repository.dart';

class CropRepository {
  CropRepository(this._db, [this._historyRepo]);

  final AppDatabase _db;
  final HistoryRepository? _historyRepo;
  final _uuid = const Uuid();

  Stream<List<Crop>> watchCrops(String userId) =>
      _db.watchCrops(userId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<List<Crop>> getCrops(String userId) async {
    final rows = await _db.getCrops(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<Crop?> getById(String id) async {
    final row = await _db.getCropById(id);
    return row?.toModel();
  }

  Future<Crop> addCrop(Crop crop) async {
    final now = DateTime.now().toIso8601String();
    final toSave = crop.copyWith(
      id: crop.id.isEmpty ? _uuid.v4() : crop.id,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertCrop(_toCompanion(toSave));
    return toSave;
  }

  Future<Crop> updateCrop(Crop crop) async {
    final now = DateTime.now().toIso8601String();
    final toSave = crop.copyWith(updatedAt: now, syncStatus: 'pending');
    await _db.updateCrop(_toCompanion(toSave));
    return toSave;
  }

  Future<void> deleteCrop(String id) async {
    // Cascade: remove all activities + harvests for this crop first.
    await _db.deleteCropActivitiesForCrop(id);
    await _db.deleteHarvestsForCrop(id);
    await _db.deleteCrop(id);
  }

  /// Updates the crop's lifecycle status (growing / harvested / lost).
  /// Records a history entry so the change is traceable.
  Future<Crop> markStatus(Crop crop, String status) async {
    final now = DateTime.now().toIso8601String();
    final updated = crop.copyWith(
      status: status,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.updateCrop(_toCompanion(updated));
    if (_historyRepo != null) {
      await _historyRepo.insertHistoryDirect(HistoryEntry(
        id: _uuid.v4(),
        userId: crop.userId,
        actionType: 'crop_status_changed',
        title:
            '${CropStatus.emoji(status)} ${crop.nameFr} — ${CropStatus.labelFr(status)}',
        relatedType: 'crop',
        relatedId: crop.id,
        date: now.substring(0, 10),
        createdAt: now,
        syncStatus: 'pending',
      ));
    }
    return updated;
  }

  Future<void> seedDefaultsIfEmpty(String userId) async {
    final existing = await getCrops(userId);
    if (existing.isNotEmpty) return;
    final now = DateTime.now().toIso8601String();
    final defaults = <Crop>[
      Crop(
        id: _uuid.v4(),
        userId: userId,
        nameFr: 'Oranges',
        nameAr: 'برتقال',
        iconEmoji: '🍊',
        kind: CropKind.tree,
        seasonMonths: const [11, 12, 1, 2, 3],
        isDefault: true,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      ),
      Crop(
        id: _uuid.v4(),
        userId: userId,
        nameFr: 'Patates',
        nameAr: 'بطاطا',
        iconEmoji: '🥔',
        kind: CropKind.vegetable,
        seasonMonths: const [],
        isDefault: true,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      ),
      Crop(
        id: _uuid.v4(),
        userId: userId,
        nameFr: 'Olives',
        nameAr: 'زيتون',
        iconEmoji: '🫒',
        kind: CropKind.tree,
        seasonMonths: const [10, 11, 12],
        isDefault: true,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      ),
      Crop(
        id: _uuid.v4(),
        userId: userId,
        nameFr: 'Tomates',
        nameAr: 'طماطم',
        iconEmoji: '🍅',
        kind: CropKind.vegetable,
        seasonMonths: const [6, 7, 8, 9],
        isDefault: true,
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      ),
    ];
    for (final c in defaults) {
      await addCrop(c);
    }
  }

  Future<List<Crop>> getPending(String userId) async {
    final rows = await _db.getPendingCrops(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markCropSynced(id);

  CropsTableCompanion _toCompanion(Crop c) => CropsTableCompanion(
        id: Value(c.id),
        userId: Value(c.userId),
        nameFr: Value(c.nameFr),
        nameAr: Value(c.nameAr),
        iconEmoji: Value(c.iconEmoji),
        kind: Value(c.kind),
        seasonMonths: Value(c.seasonMonthsJson()),
        fieldId: Value(c.fieldId),
        areaOrCountText: Value(c.areaOrCountText),
        photoLocalPath: Value(c.photoLocalPath),
        photoCloudUrl: Value(c.photoCloudUrl),
        notes: Value(c.notes),
        isDefault: Value(c.isDefault),
        status: Value(c.status),
        createdAt: Value(c.createdAt),
        updatedAt: Value(c.updatedAt),
        syncStatus: Value(c.syncStatus),
      );
}
