import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/crop.dart';
import '../models/crop_activity.dart';
import '../models/expense.dart';
import '../models/history_entry.dart';
import 'expense_repository.dart';
import 'history_repository.dart';

class CropActivityRepository {
  CropActivityRepository(this._db, this._expenseRepo, this._historyRepo);

  final AppDatabase _db;
  final ExpenseRepository _expenseRepo;
  final HistoryRepository _historyRepo;
  final _uuid = const Uuid();

  Stream<List<CropActivity>> watchForCrop(String userId, String cropId) =>
      _db.watchActivitiesForCrop(userId, cropId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<List<CropActivity>> getAll(String userId) async {
    final rows = await _db.getAllCropActivities(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  /// Creates an activity. If [cost] > 0, also creates a linked Expense and
  /// stores its id on `linkedExpenseId`.
  Future<CropActivity> add(CropActivity activity, {required Crop crop}) async {
    final now = DateTime.now().toIso8601String();
    final id = activity.id.isEmpty ? _uuid.v4() : activity.id;

    String? linkedExpenseId;
    if (activity.cost != null && activity.cost! > 0) {
      final exp = await _expenseRepo.addExpense(Expense(
        id: '',
        userId: activity.userId,
        scope: ExpenseScope.crop,
        linkedCropId: activity.cropId,
        linkedFieldId: crop.fieldId,
        amount: activity.cost!,
        category: CropActivityType.expenseCategoryFor(activity.activityType),
        date: activity.date,
        description:
            '${CropActivityType.emoji(activity.activityType)} ${CropActivityType.labelFr(activity.activityType)}'
            '${activity.description?.isNotEmpty == true ? ' — ${activity.description}' : ''}',
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      ));
      linkedExpenseId = exp.id;
    }

    final toSave = activity.copyWith(
      id: id,
      linkedExpenseId: linkedExpenseId,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertCropActivity(_toCompanion(toSave));

    // History entry
    await _historyRepo.insertHistoryDirect(HistoryEntry(
      id: _uuid.v4(),
      userId: toSave.userId,
      actionType: 'crop_activity_added',
      title:
          '${CropActivityType.emoji(toSave.activityType)} ${CropActivityType.labelFr(toSave.activityType)} — ${crop.nameFr}',
      description: toSave.description?.isNotEmpty == true
          ? toSave.description
          : (toSave.cost != null
              ? '${toSave.cost!.toStringAsFixed(0)} TND'
              : null),
      relatedType: 'crop',
      relatedId: toSave.cropId,
      date: toSave.date,
      createdAt: now,
      syncStatus: 'pending',
    ));

    return toSave;
  }

  /// Deletes the activity. Also deletes the linked expense (if any).
  Future<void> delete(CropActivity activity) async {
    if (activity.linkedExpenseId != null) {
      await _expenseRepo.deleteExpense(activity.linkedExpenseId!);
    }
    await _db.deleteCropActivity(activity.id);
  }

  Future<List<CropActivity>> getPending(String userId) async {
    final rows = await _db.getPendingCropActivities(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markCropActivitySynced(id);

  CropActivitiesTableCompanion _toCompanion(CropActivity a) =>
      CropActivitiesTableCompanion(
        id: Value(a.id),
        userId: Value(a.userId),
        cropId: Value(a.cropId),
        activityType: Value(a.activityType),
        date: Value(a.date),
        description: Value(a.description),
        cost: Value(a.cost),
        linkedExpenseId: Value(a.linkedExpenseId),
        notes: Value(a.notes),
        createdAt: Value(a.createdAt),
        updatedAt: Value(a.updatedAt),
        syncStatus: Value(a.syncStatus),
      );
}
