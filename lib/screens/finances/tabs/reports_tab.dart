import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/expense.dart';
import '../../../models/sale.dart';
import '../../../providers/animal_provider.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/field_provider.dart';
import '../../../providers/sale_provider.dart';
import '../../../providers/species_provider.dart';
import '../../../theme/app_theme.dart';

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

enum _Range { today, week, month, year, custom }

class _ReportsTabState extends ConsumerState<ReportsTab> {
  _Range _range = _Range.month;
  DateTime _start = _startOfMonth();
  DateTime _end = DateTime.now();

  static DateTime _startOfMonth() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  void _setRange(_Range r) {
    final n = DateTime.now();
    setState(() {
      _range = r;
      _end = n;
      switch (r) {
        case _Range.today:
          _start = DateTime(n.year, n.month, n.day);
          break;
        case _Range.week:
          _start = n.subtract(Duration(days: n.weekday - 1));
          _start = DateTime(_start.year, _start.month, _start.day);
          break;
        case _Range.month:
          _start = DateTime(n.year, n.month, 1);
          break;
        case _Range.year:
          _start = DateTime(n.year, 1, 1);
          break;
        case _Range.custom:
          break;
      }
    });
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _start, end: _end),
    );
    if (picked != null) {
      setState(() {
        _range = _Range.custom;
        _start = picked.start;
        _end = picked.end;
      });
    }
  }

  bool _inRange(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    return !d.isBefore(_start) && !d.isAfter(_end);
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseListProvider).asData?.value ?? const [];
    final sales = ref.watch(salesListProvider).asData?.value ?? const [];
    final species = ref.watch(speciesListProvider).asData?.value ?? const [];
    final crops = ref.watch(cropsListProvider).asData?.value ?? const [];
    final fields = ref.watch(fieldsListProvider).asData?.value ?? const [];
    final animals = ref.watch(allAnimalsProvider).asData?.value ?? const [];

    final filteredExpenses = expenses.where((e) => _inRange(e.date)).toList();
    final filteredSales = sales.where((s) => _inRange(s.saleDate)).toList();

    final totalExpenses =
        filteredExpenses.fold<double>(0, (s, e) => s + e.amount);
    final totalIncome =
        filteredSales.fold<double>(0, (s, e) => s + e.totalPrice);
    final profit = totalIncome - totalExpenses;

    final expensesByScope = <String, double>{};
    for (final e in filteredExpenses) {
      expensesByScope[e.scope] = (expensesByScope[e.scope] ?? 0) + e.amount;
    }
    final salesByScope = <String, double>{};
    for (final s in filteredSales) {
      salesByScope[s.scope] = (salesByScope[s.scope] ?? 0) + s.totalPrice;
    }

    final animalIdToSpecies = {for (final a in animals) a.id: a.speciesId};

    // Profit by species
    final profitBySpecies = <String, List<double>>{};
    for (final s in species) {
      profitBySpecies[s.id] = [0, 0];
    }
    for (final e in filteredExpenses) {
      final sid = e.linkedSpeciesId ??
          (e.linkedAnimalId == null ? null : animalIdToSpecies[e.linkedAnimalId]);
      if (sid != null && profitBySpecies.containsKey(sid)) {
        profitBySpecies[sid]![0] += e.amount;
      }
    }
    for (final s in filteredSales) {
      if (s.scope == SaleScope.animal && s.linkedAnimalId != null) {
        final sid = animalIdToSpecies[s.linkedAnimalId];
        if (sid != null && profitBySpecies.containsKey(sid)) {
          profitBySpecies[sid]![1] += s.totalPrice;
        }
      }
    }

    // Profit by crop
    final profitByCrop = <String, List<double>>{};
    for (final c in crops) {
      profitByCrop[c.id] = [0, 0];
    }
    for (final e in filteredExpenses) {
      if (e.linkedCropId != null && profitByCrop.containsKey(e.linkedCropId)) {
        profitByCrop[e.linkedCropId]![0] += e.amount;
      }
    }
    for (final s in filteredSales) {
      if (s.scope == SaleScope.crop &&
          s.linkedCropId != null &&
          profitByCrop.containsKey(s.linkedCropId)) {
        profitByCrop[s.linkedCropId]![1] += s.totalPrice;
      }
    }

    // Profit by field
    final profitByField = <String, double>{};
    for (final f in fields) {
      profitByField[f.id] = 0;
    }
    for (final e in filteredExpenses) {
      final fid = e.linkedFieldId;
      if (fid != null && profitByField.containsKey(fid)) {
        profitByField[fid] = (profitByField[fid] ?? 0) - e.amount;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _rangeChips(),
        const SizedBox(height: 16),
        _summary(totalExpenses, totalIncome, profit),
        const SizedBox(height: 16),
        _section('Dépenses par catégorie', _kvMap(expensesByScope, _scopeLabel, suffix: 'TND')),
        _section('Revenus par catégorie', _kvMap(salesByScope, _scopeLabel, suffix: 'TND')),
        _section(
          'Bénéfice par espèce',
          profitBySpecies.entries.map((kv) {
            final s = species.firstWhere((sp) => sp.id == kv.key,
                orElse: () => species.first);
            final spent = kv.value[0];
            final earned = kv.value[1];
            final p = earned - spent;
            return _profitRow(
                '${s.iconEmoji} ${s.nameFr}', spent, earned, p);
          }).toList(),
        ),
        _section(
          'Bénéfice par culture',
          profitByCrop.entries.map((kv) {
            final c = crops.firstWhere((cr) => cr.id == kv.key,
                orElse: () => crops.first);
            final spent = kv.value[0];
            final earned = kv.value[1];
            final p = earned - spent;
            return _profitRow('${c.iconEmoji} ${c.nameFr}', spent, earned, p);
          }).toList(),
        ),
        if (fields.isNotEmpty)
          _section(
            'Bénéfice par champ',
            profitByField.entries.map((kv) {
              final f = fields.firstWhere((fi) => fi.id == kv.key,
                  orElse: () => fields.first);
              return _profitRow(f.name, -kv.value, 0, kv.value);
            }).toList(),
          ),
      ],
    );
  }

  Widget _rangeChips() {
    return Wrap(
      spacing: 6,
      children: [
        ChoiceChip(
            label: const Text('Aujourd\'hui'),
            selected: _range == _Range.today,
            onSelected: (_) => _setRange(_Range.today)),
        ChoiceChip(
            label: const Text('Semaine'),
            selected: _range == _Range.week,
            onSelected: (_) => _setRange(_Range.week)),
        ChoiceChip(
            label: const Text('Mois'),
            selected: _range == _Range.month,
            onSelected: (_) => _setRange(_Range.month)),
        ChoiceChip(
            label: const Text('Année'),
            selected: _range == _Range.year,
            onSelected: (_) => _setRange(_Range.year)),
        ChoiceChip(
            label: const Text('Personnalisé'),
            selected: _range == _Range.custom,
            onSelected: (_) => _pickCustom()),
      ],
    );
  }

  Widget _summary(double exp, double inc, double profit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _summaryRow('Dépenses', exp.toStringAsFixed(0), AppColors.red),
            _summaryRow('Revenus', inc.toStringAsFixed(0), AppColors.green),
            const Divider(),
            _summaryRow(
              profit >= 0 ? 'Bénéfice' : 'Perte',
              profit.toStringAsFixed(0),
              profit >= 0 ? AppColors.green : AppColors.red,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
          Text('$value TND',
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _kvMap(Map<String, double> map, String Function(String) label,
      {required String suffix}) {
    return map.entries
        .map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label(e.key)),
                  Text('${e.value.toStringAsFixed(0)} $suffix'),
                ],
              ),
            ))
        .toList();
  }

  Widget _profitRow(String label, double spent, double earned, double profit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dépensé ${spent.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Gagné ${earned.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                'B: ${profit.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: profit >= 0 ? AppColors.green : AppColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _scopeLabel(String s) {
    switch (s) {
      case ExpenseScope.animal:
        return 'Animal';
      case ExpenseScope.crop:
        return 'Culture';
      case ExpenseScope.field:
        return 'Champ';
      case ExpenseScope.general:
        return 'Général';
      case SaleScope.product:
        return 'Produit';
      case SaleScope.other:
        return 'Autre';
      default:
        return s;
    }
  }
}
