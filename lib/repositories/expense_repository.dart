import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/expense.dart';

class ExpenseRepository {
  ExpenseRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<Expense>> watchAllExpenses(String userId) =>
      _db.watchAllExpenses(userId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Stream<List<Expense>> watchExpensesForAnimal(String userId, String animalId) =>
      _db.watchExpensesForAnimal(userId, animalId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Stream<List<Expense>> watchExpensesForCrop(String userId, String cropId) =>
      _db.watchExpensesForCrop(userId, cropId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Stream<List<Expense>> watchExpensesForField(String userId, String fieldId) =>
      _db.watchExpensesForField(userId, fieldId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<Expense> addExpense(Expense expense) async {
    final now = DateTime.now().toIso8601String();
    final toSave = expense.copyWith(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertExpense(_toCompanion(toSave));
    return toSave;
  }

  Future<Expense> updateExpense(Expense expense) async {
    final now = DateTime.now().toIso8601String();
    final toSave = expense.copyWith(updatedAt: now, syncStatus: 'pending');
    await _db.updateExpense(_toCompanion(toSave));
    return toSave;
  }

  Future<void> deleteExpense(String id) => _db.deleteExpense(id);

  Future<void> insertExpenseDirect(Expense expense) async {
    await _db.insertExpense(_toCompanion(expense));
  }

  Future<List<Expense>> getPendingExpenses(String userId) async {
    final rows = await _db.getPendingExpenses(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markExpenseSynced(id);

  ExpensesTableCompanion _toCompanion(Expense e) => ExpensesTableCompanion(
        id: Value(e.id),
        userId: Value(e.userId),
        scope: Value(e.scope),
        linkedAnimalId: Value(e.linkedAnimalId),
        linkedSpeciesId: Value(e.linkedSpeciesId),
        linkedCropId: Value(e.linkedCropId),
        linkedFieldId: Value(e.linkedFieldId),
        amount: Value(e.amount),
        category: Value(e.category),
        date: Value(e.date),
        description: Value(e.description),
        receiptPhotoLocalPath: Value(e.receiptPhotoLocalPath),
        receiptPhotoCloudUrl: Value(e.receiptPhotoCloudUrl),
        createdAt: Value(e.createdAt),
        updatedAt: Value(e.updatedAt),
        syncStatus: Value(e.syncStatus),
      );
}
