import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import 'core_providers.dart';

final expenseListProvider = StreamProvider<List<Expense>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(expenseRepositoryProvider).watchAllExpenses(user.uid);
});

final expensesForAnimalProvider =
    StreamProvider.family<List<Expense>, String>((ref, animalId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(expenseRepositoryProvider)
      .watchExpensesForAnimal(user.uid, animalId);
});

final expensesForCropProvider =
    StreamProvider.family<List<Expense>, String>((ref, cropId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(expenseRepositoryProvider)
      .watchExpensesForCrop(user.uid, cropId);
});

final expensesForFieldProvider =
    StreamProvider.family<List<Expense>, String>((ref, fieldId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(expenseRepositoryProvider)
      .watchExpensesForField(user.uid, fieldId);
});

final expenseStatsProvider = Provider<ExpenseStats>((ref) {
  final expensesAsync = ref.watch(expenseListProvider);
  return expensesAsync.when(
    data: ExpenseStats.fromList,
    loading: () => const ExpenseStats(),
    error: (_, __) => const ExpenseStats(),
  );
});

class ExpenseStats {
  final double totalAll;
  final double totalThisMonth;

  const ExpenseStats({this.totalAll = 0, this.totalThisMonth = 0});

  factory ExpenseStats.fromList(List<Expense> list) {
    final now = DateTime.now();
    final monthPrefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final thisMonth = list
        .where((e) => e.date.startsWith(monthPrefix))
        .fold(0.0, (sum, e) => sum + e.amount);
    return ExpenseStats(
      totalAll: list.fold(0.0, (sum, e) => sum + e.amount),
      totalThisMonth: thisMonth,
    );
  }
}
