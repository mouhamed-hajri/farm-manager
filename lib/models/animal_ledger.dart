import 'animal.dart';
import 'expense.dart';
import 'sale.dart';

class AnimalLedger {
  final Animal owner;
  final List<Animal> maleOffspring;
  final List<Animal> femaleOffspring;
  final List<Expense> ownerExpenses;
  final Map<String, List<Expense>> offspringExpenses;
  final List<Sale> ownerSales;
  final Map<String, List<Sale>> offspringSales;
  // Daughters that became independent: maps daughter id → assumed valuation credited to this ledger.
  final Map<String, double> daughterValuations;

  const AnimalLedger({
    required this.owner,
    required this.maleOffspring,
    required this.femaleOffspring,
    required this.ownerExpenses,
    required this.offspringExpenses,
    required this.ownerSales,
    required this.offspringSales,
    this.daughterValuations = const {},
  });

  double get totalExpenses {
    var total = ownerExpenses.fold<double>(0, (s, e) => s + e.amount);
    for (final exps in offspringExpenses.values) {
      total += exps.fold<double>(0, (s, e) => s + e.amount);
    }
    return total;
  }

  double get totalIncome {
    var total = ownerSales.fold<double>(0, (s, e) => s + e.totalPrice);
    for (final sales in offspringSales.values) {
      total += sales.fold<double>(0, (s, e) => s + e.totalPrice);
    }
    total += daughterValuations.values.fold<double>(0, (s, v) => s + v);
    return total;
  }

  double get netResult => totalIncome - totalExpenses;

  List<Expense> expensesFor(String animalId) =>
      animalId == owner.id ? ownerExpenses : (offspringExpenses[animalId] ?? []);

  List<Sale> salesFor(String animalId) =>
      animalId == owner.id ? ownerSales : (offspringSales[animalId] ?? []);

  double netFor(String animalId) {
    final income = salesFor(animalId).fold<double>(0, (s, e) => s + e.totalPrice);
    final spent = expensesFor(animalId).fold<double>(0, (s, e) => s + e.amount);
    return income - spent;
  }
}
