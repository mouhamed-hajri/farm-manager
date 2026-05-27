import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/expense.dart';
import '../../../models/sale.dart';
import '../../../providers/animal_provider.dart';
import '../../../providers/crop_provider.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/sale_provider.dart';
import '../../../providers/species_provider.dart';
import '../../../theme/app_theme.dart';

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

enum _Range { today, week, month, year, custom }

const _monthsFr = [
  'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
  'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
];

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
        case _Range.week:
          _start = n.subtract(Duration(days: n.weekday - 1));
          _start = DateTime(_start.year, _start.month, _start.day);
        case _Range.month:
          _start = DateTime(n.year, n.month, 1);
        case _Range.year:
          _start = DateTime(n.year, 1, 1);
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

  String get _periodLabel {
    String fmt(DateTime d) =>
        '${d.day} ${_monthsFr[d.month - 1]} ${d.year}';
    if (_start.year == _end.year &&
        _start.month == _end.month &&
        _start.day == _end.day) {
      return fmt(_start);
    }
    return '${fmt(_start)} → ${fmt(_end)}';
  }

  @override
  Widget build(BuildContext context) {
    final expenses =
        ref.watch(expenseListProvider).asData?.value ?? const [];
    final sales = ref.watch(salesListProvider).asData?.value ?? const [];
    final species =
        ref.watch(speciesListProvider).asData?.value ?? const [];
    final crops = ref.watch(cropsListProvider).asData?.value ?? const [];
    final animals =
        ref.watch(allAnimalsProvider).asData?.value ?? const [];

    final filteredExp = expenses.where((e) => _inRange(e.date)).toList();
    final filteredSal =
        sales.where((s) => _inRange(s.saleDate)).toList();

    final totalExp =
        filteredExp.fold<double>(0, (s, e) => s + e.amount);
    final totalInc =
        filteredSal.fold<double>(0, (s, e) => s + e.totalPrice);
    final profit = totalInc - totalExp;

    // Expense by category (sorted desc)
    final expByCat = <String, double>{};
    for (final e in filteredExp) {
      expByCat[e.category] = (expByCat[e.category] ?? 0) + e.amount;
    }
    final sortedExpCats = expByCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sales by scope (sorted desc)
    final salByScope = <String, double>{};
    for (final s in filteredSal) {
      salByScope[s.scope] = (salByScope[s.scope] ?? 0) + s.totalPrice;
    }
    final sortedSalScopes = salByScope.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Per species
    final animalToSpecies = {for (final a in animals) a.id: a.speciesId};
    final bySpecies = <String, _EntityData>{};
    for (final s in species) {
      bySpecies[s.id] = _EntityData('${s.iconEmoji} ${s.nameFr}');
    }
    for (final e in filteredExp) {
      final sid = e.linkedSpeciesId ??
          (e.linkedAnimalId != null
              ? animalToSpecies[e.linkedAnimalId]
              : null);
      if (sid != null) bySpecies[sid]?.exp += e.amount;
    }
    for (final s in filteredSal) {
      if (s.scope == SaleScope.animal && s.linkedAnimalId != null) {
        final sid = animalToSpecies[s.linkedAnimalId];
        if (sid != null) bySpecies[sid]?.inc += s.totalPrice;
      }
    }
    final activeSpecies = bySpecies.values
        .where((d) => d.exp > 0 || d.inc > 0)
        .toList()
      ..sort((a, b) => (b.inc - b.exp).compareTo(a.inc - a.exp));

    // Per crop
    final byCrop = <String, _EntityData>{};
    for (final c in crops) {
      byCrop[c.id] = _EntityData('${c.iconEmoji} ${c.nameFr}');
    }
    for (final e in filteredExp) {
      if (e.linkedCropId != null) byCrop[e.linkedCropId]?.exp += e.amount;
    }
    for (final s in filteredSal) {
      if (s.scope == SaleScope.crop && s.linkedCropId != null) {
        byCrop[s.linkedCropId]?.inc += s.totalPrice;
      }
    }
    final activeCrops = byCrop.values
        .where((d) => d.exp > 0 || d.inc > 0)
        .toList()
      ..sort((a, b) => (b.inc - b.exp).compareTo(a.inc - a.exp));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        _rangeChips(),
        const SizedBox(height: 6),
        Center(
          child: Text(
            _periodLabel,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 16),
        _kpiRow(totalExp, totalInc, profit),
        const SizedBox(height: 20),
        _monthlyTrend(expenses, sales),
        if (sortedExpCats.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionHeader(Icons.money_off_outlined, 'Dépenses par catégorie', AppColors.red),
          const SizedBox(height: 10),
          _breakdownCard(sortedExpCats, totalExp, _categoryLabel, AppColors.red),
        ],
        if (sortedSalScopes.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionHeader(Icons.sell_outlined, 'Revenus par type', AppColors.green),
          const SizedBox(height: 10),
          _breakdownCard(sortedSalScopes, totalInc, _scopeLabel, AppColors.green),
        ],
        if (activeSpecies.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionHeader(Icons.pets, 'Résultats par espèce', AppColors.blue),
          const SizedBox(height: 10),
          ...activeSpecies.map((d) => _entityCard(d.name, d.exp, d.inc)),
        ],
        if (activeCrops.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionHeader(Icons.eco, 'Résultats par culture', Colors.teal),
          const SizedBox(height: 10),
          ...activeCrops.map((d) => _entityCard(d.name, d.exp, d.inc)),
        ],
      ],
    );
  }

  // ── Range chips ──────────────────────────────────────────────────────────────

  Widget _rangeChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip("Auj.", _Range.today),
          const SizedBox(width: 6),
          _chip('Semaine', _Range.week),
          const SizedBox(width: 6),
          _chip('Mois', _Range.month),
          const SizedBox(width: 6),
          _chip('Année', _Range.year),
          const SizedBox(width: 6),
          _chip('Personnalisé', _Range.custom, onTap: _pickCustom),
        ],
      ),
    );
  }

  Widget _chip(String label, _Range r, {VoidCallback? onTap}) {
    final selected = _range == r;
    return GestureDetector(
      onTap: onTap ?? () => _setRange(r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.green : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  // ── KPI row ──────────────────────────────────────────────────────────────────

  Widget _kpiRow(double exp, double inc, double profit) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard('Dépenses', exp, Icons.arrow_downward_rounded,
              AppColors.red),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard('Revenus', inc, Icons.arrow_upward_rounded,
              AppColors.green),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            profit >= 0 ? 'Bénéfice' : 'Perte',
            profit.abs(),
            profit >= 0 ? Icons.trending_up : Icons.trending_down,
            profit >= 0 ? AppColors.green : AppColors.red,
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text('TND',
              style: TextStyle(
                  fontSize: 10, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  // ── Monthly trend chart ──────────────────────────────────────────────────────

  Widget _monthlyTrend(List<Expense> allExpenses, List<Sale> allSales) {
    final now = DateTime.now();
    final labels = <int, String>{};
    final groups = <BarChartGroupData>[];
    double maxY = 100;

    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final ms =
          '${m.year}-${m.month.toString().padLeft(2, '0')}';
      final idx = 5 - i;
      labels[idx] = _monthsFr[m.month - 1];

      final inc = allSales
          .where((s) => s.saleDate.startsWith(ms))
          .fold<double>(0, (s, e) => s + e.totalPrice);
      final exp = allExpenses
          .where((e) => e.date.startsWith(ms))
          .fold<double>(0, (s, e) => s + e.amount);

      maxY = max(maxY, max(inc, exp));
      groups.add(BarChartGroupData(
        x: idx,
        barsSpace: 3,
        barRods: [
          BarChartRodData(
            toY: exp,
            color: AppColors.red.withValues(alpha: 0.70),
            width: 11,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: inc,
            color: AppColors.green.withValues(alpha: 0.70),
            width: 11,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    final interval = _niceInterval(maxY);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
            Icons.bar_chart_rounded, '6 derniers mois', Colors.blueGrey),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.25,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: interval,
                    getTitlesWidget: (v, _) => v == 0
                        ? const SizedBox.shrink()
                        : Text(
                            v >= 1000
                                ? '${(v / 1000).toStringAsFixed(0)}k'
                                : v.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final label = labels[v.toInt()];
                      if (label == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: groups,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      Colors.blueGrey.shade900,
                  getTooltipItem: (group, _, rod, rodIndex) =>
                      BarTooltipItem(
                    '${rodIndex == 0 ? 'Dép.' : 'Rev.'}\n'
                    '${rod.toY.toStringAsFixed(0)} TND',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(AppColors.red.withValues(alpha: 0.70), 'Dépenses'),
            const SizedBox(width: 20),
            _dot(AppColors.green.withValues(alpha: 0.70), 'Revenus'),
          ],
        ),
      ],
    );
  }

  double _niceInterval(double maxY) {
    if (maxY <= 0) return 100;
    final raw = maxY / 4;
    final magnitude = pow(10, log(raw) / ln10).floor().toDouble();
    final norm = raw / magnitude;
    double nice;
    if (norm <= 1) nice = 1;
    else if (norm <= 2) nice = 2;
    else if (norm <= 5) nice = 5;
    else nice = 10;
    return nice * magnitude;
  }

  Widget _dot(Color color, String label) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );

  // ── Section header ───────────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title, Color color) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      );

  // ── Category breakdown with progress bars ────────────────────────────────────

  Widget _breakdownCard(
    List<MapEntry<String, double>> entries,
    double total,
    String Function(String) labelFn,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
      ),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 0,
                  indent: 12,
                  endIndent: 12,
                  color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(labelFn(entries[i].key),
                          style: const TextStyle(fontSize: 13)),
                      Text(
                        '${entries[i].value.toStringAsFixed(0)} TND',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0
                          ? (entries[i].value / total).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 6,
                      backgroundColor:
                          color.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation(
                          color.withValues(alpha: 0.65)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Per-entity card (species / crop) ─────────────────────────────────────────

  Widget _entityCard(String name, double exp, double inc) {
    final profit = inc - exp;
    final isProfit = profit >= 0;
    final color = isProfit ? AppColors.green : AppColors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _miniStat('Dép.', exp, AppColors.red),
                      const SizedBox(width: 12),
                      _miniStat('Rev.', inc, AppColors.green),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${isProfit ? '+' : ''}${profit.toStringAsFixed(0)} TND',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, double v, Color color) => Row(
        children: [
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(width: 3),
          Text(v.toStringAsFixed(0),
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      );

  // ── Labels ───────────────────────────────────────────────────────────────────

  String _categoryLabel(String c) {
    switch (c) {
      case 'animal_purchase':
        return 'Achat animal';
      case 'feed':
        return 'Alimentation';
      case 'veterinary':
        return 'Vétérinaire';
      case 'medication':
        return 'Médicament';
      case 'equipment':
        return 'Équipement';
      case 'transport':
        return 'Transport';
      case 'labor':
        return "Main d'œuvre";
      case 'breeder_valuation':
        return 'Transfert interne';
      default:
        return c;
    }
  }

  String _scopeLabel(String s) {
    switch (s) {
      case SaleScope.animal:
        return 'Animaux';
      case SaleScope.crop:
        return 'Cultures';
      case SaleScope.product:
        return 'Produits';
      default:
        return 'Autre';
    }
  }
}

class _EntityData {
  _EntityData(this.name);
  final String name;
  double exp = 0;
  double inc = 0;
}
