import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/crop.dart';
import '../../models/expense.dart';
import '../../models/field.dart';
import '../../models/sale.dart';
import '../../providers/core_providers.dart';
import '../../providers/crop_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/field_provider.dart';
import '../../providers/sale_provider.dart';
import '../../theme/app_theme.dart';

class FieldDashboardScreen extends ConsumerStatefulWidget {
  const FieldDashboardScreen({super.key, required this.fieldId});

  final String fieldId;

  @override
  ConsumerState<FieldDashboardScreen> createState() =>
      _FieldDashboardScreenState();
}

enum _Range { thisMonth, lastMonth, thisYear, lastYear, custom }

class _FieldDashboardScreenState extends ConsumerState<FieldDashboardScreen> {
  _Range _range = _Range.thisMonth;
  DateTime _start = _startOfMonth();
  DateTime _end = DateTime.now();
  String? _cropFilter; // crop id to narrow stats

  static DateTime _startOfMonth() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  void _setRange(_Range r) {
    final n = DateTime.now();
    setState(() {
      _range = r;
      switch (r) {
        case _Range.thisMonth:
          _start = DateTime(n.year, n.month, 1);
          _end = n;
          break;
        case _Range.lastMonth:
          final lastMonth = DateTime(n.year, n.month - 1, 1);
          _start = lastMonth;
          _end = DateTime(n.year, n.month, 0); // last day of previous month
          break;
        case _Range.thisYear:
          _start = DateTime(n.year, 1, 1);
          _end = n;
          break;
        case _Range.lastYear:
          _start = DateTime(n.year - 1, 1, 1);
          _end = DateTime(n.year - 1, 12, 31);
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
    final fieldAsync = ref.watch(fieldByIdProvider(widget.fieldId));
    final expenses = ref.watch(expenseListProvider).asData?.value ?? const [];
    final sales = ref.watch(salesListProvider).asData?.value ?? const [];
    final crops = ref.watch(cropsListProvider).asData?.value ?? const [];

    // Crops linked to this field
    final cropsHere = crops.where((c) => c.fieldId == widget.fieldId).toList();
    final cropIdsHere = cropsHere.map((c) => c.id).toSet();

    // Expenses linked to this field directly
    final fieldExpenses = expenses
        .where((e) => e.linkedFieldId == widget.fieldId)
        .where((e) => _inRange(e.date))
        .toList();
    // Expenses on crops growing here
    final cropExpensesHere = expenses
        .where((e) =>
            e.linkedCropId != null && cropIdsHere.contains(e.linkedCropId))
        .where((e) => _inRange(e.date))
        .where((e) => _cropFilter == null || e.linkedCropId == _cropFilter)
        .toList();
    // Sales of crops growing here
    final cropSalesHere = sales
        .where((s) =>
            s.scope == SaleScope.crop &&
            s.linkedCropId != null &&
            cropIdsHere.contains(s.linkedCropId))
        .where((s) => _inRange(s.saleDate))
        .where((s) => _cropFilter == null || s.linkedCropId == _cropFilter)
        .toList();

    final totalExpenses = (_cropFilter == null
            ? fieldExpenses.fold<double>(0, (s, e) => s + e.amount)
            : 0.0) +
        cropExpensesHere.fold<double>(0, (s, e) => s + e.amount);
    final totalRevenue =
        cropSalesHere.fold<double>(0, (s, e) => s + e.totalPrice);
    final profit = totalRevenue - totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: fieldAsync.when(
          data: (f) => Text(f?.name ?? 'Champ'),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Champ'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
            onPressed: () =>
                context.push('/cultures/field/${widget.fieldId}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: 'Supprimer',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: fieldAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (field) {
          if (field == null) {
            return const Center(child: Text('Champ introuvable'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PhotoHeader(field: field),
              const SizedBox(height: 12),
              _InfoCard(field: field),
              if (field.ownership == FieldOwnership.rented)
                _RentCard(field: field),
              const SizedBox(height: 16),
              _rangeChips(),
              if (cropsHere.isNotEmpty) ...[
                const SizedBox(height: 10),
                _cropFilterRow(cropsHere),
              ],
              const SizedBox(height: 16),
              _summaryCard(totalExpenses, totalRevenue, profit),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.money_off),
                    label: const Text('Ajouter dépense'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white),
                    onPressed: () => context.push(
                      '/finances/expense/new',
                      extra: <String, String?>{
                        'scope': 'field',
                        'fieldId': widget.fieldId,
                      },
                    ),
                  ),
                  if (cropsHere.isNotEmpty)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.attach_money),
                      label: const Text('Ajouter vente'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white),
                      onPressed: () => context.push(
                        '/finances/sale/new',
                        extra: <String, String?>{
                          'scope': 'crop',
                          'cropId': _cropFilter ?? cropsHere.first.id,
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (cropsHere.isNotEmpty) ...[
                const Text('Cultures dans ce champ',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...cropsHere.map((c) => _CropTile(crop: c)),
                const SizedBox(height: 16),
              ],
              const Text('Dépenses sur la période',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (fieldExpenses.isEmpty && cropExpensesHere.isEmpty)
                _emptyMini('Aucune dépense')
              else ...[
                ..._cropFilter == null
                    ? fieldExpenses.map(
                        (e) => _ExpenseTile(expense: e, label: 'Champ'))
                    : <Widget>[],
                ...cropExpensesHere.map((e) {
                  final crop = crops.firstWhere(
                    (c) => c.id == e.linkedCropId,
                    orElse: () => crops.first,
                  );
                  return _ExpenseTile(
                      expense: e, label: '${crop.iconEmoji} ${crop.nameFr}');
                }),
              ],
              const SizedBox(height: 16),
              const Text('Ventes des cultures sur la période',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (cropSalesHere.isEmpty)
                _emptyMini('Aucune vente')
              else
                ...cropSalesHere.map((s) {
                  final crop = crops.firstWhere(
                    (c) => c.id == s.linkedCropId,
                    orElse: () => crops.first,
                  );
                  return _SaleTile(sale: s, cropEmoji: crop.iconEmoji);
                }),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _rangeChips() => Wrap(
        spacing: 6,
        children: [
          ChoiceChip(
              label: const Text('Ce mois'),
              selected: _range == _Range.thisMonth,
              onSelected: (_) => _setRange(_Range.thisMonth)),
          ChoiceChip(
              label: const Text('Mois dernier'),
              selected: _range == _Range.lastMonth,
              onSelected: (_) => _setRange(_Range.lastMonth)),
          ChoiceChip(
              label: const Text('Cette année'),
              selected: _range == _Range.thisYear,
              onSelected: (_) => _setRange(_Range.thisYear)),
          ChoiceChip(
              label: const Text('Année dernière'),
              selected: _range == _Range.lastYear,
              onSelected: (_) => _setRange(_Range.lastYear)),
          ChoiceChip(
              label: const Text('Personnalisé'),
              selected: _range == _Range.custom,
              onSelected: (_) => _pickCustom()),
        ],
      );

  Widget _cropFilterRow(List<Crop> cropsHere) {
    return Wrap(
      spacing: 6,
      children: [
        ChoiceChip(
          label: const Text('Toutes cultures'),
          selected: _cropFilter == null,
          onSelected: (_) => setState(() => _cropFilter = null),
        ),
        ...cropsHere.map((c) => ChoiceChip(
              label: Text('${c.iconEmoji} ${c.nameFr}'),
              selected: _cropFilter == c.id,
              onSelected: (_) => setState(() => _cropFilter = c.id),
            )),
      ],
    );
  }

  Widget _summaryCard(double exp, double rev, double profit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _row('Dépenses', '${exp.toStringAsFixed(0)} TND', AppColors.red),
            const SizedBox(height: 4),
            _row('Revenus', '${rev.toStringAsFixed(0)} TND', AppColors.green),
            const Divider(),
            _row(
              profit >= 0 ? 'Bénéfice' : 'Perte',
              '${profit.toStringAsFixed(0)} TND',
              profit >= 0 ? AppColors.green : AppColors.red,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool bold = false}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color,
                  fontSize: bold ? 16 : 14)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color: color,
                  fontSize: bold ? 16 : 14)),
        ],
      );

  Widget _emptyMini(String text) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(text, style: TextStyle(color: Colors.grey[600])),
          ),
        ),
      );

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le champ ?'),
        content: const Text(
            'Cette action est irréversible. Les cultures et dépenses liées resteront mais perdront leur lien à ce champ.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(fieldRepositoryProvider).deleteField(widget.fieldId);
      if (context.mounted) context.pop();
    }
  }
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.field});
  final FarmField field;

  @override
  Widget build(BuildContext context) {
    final hasLocal = field.photoLocalPath != null &&
        File(field.photoLocalPath!).existsSync();
    final hasCloud = field.photoCloudUrl?.isNotEmpty ?? false;
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: hasLocal
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(field.photoLocalPath!),
                  fit: BoxFit.cover, width: double.infinity))
          : hasCloud
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(field.photoCloudUrl!,
                      fit: BoxFit.cover, width: double.infinity))
              : const Center(
                  child: Icon(Icons.landscape, size: 80, color: AppColors.green),
                ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.field});
  final FarmField field;

  @override
  Widget build(BuildContext context) {
    final ownershipLabel = field.ownership == FieldOwnership.rented ? 'Loué' : 'Possédé';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.label_outline, size: 18),
              const SizedBox(width: 6),
              Text(ownershipLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            if (field.areaText != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.aspect_ratio, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(field.areaText!)),
              ]),
            ],
            if (field.locationText != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.place, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(field.locationText!)),
              ]),
            ],
            if (field.notes != null) ...[
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notes, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(field.notes!)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _RentCard extends StatelessWidget {
  const _RentCard({required this.field});
  final FarmField field;

  @override
  Widget build(BuildContext context) {
    int? daysLeft;
    if (field.rentEndDate != null) {
      final end = DateTime.tryParse(field.rentEndDate!);
      if (end != null) {
        daysLeft = end.difference(DateTime.now()).inDays;
      }
    }
    Color color = AppColors.green;
    if (daysLeft != null) {
      if (daysLeft < 0) {
        color = AppColors.red;
      } else if (daysLeft <= 7) {
        color = AppColors.red;
      } else if (daysLeft <= 30) {
        color = Colors.orange;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        color: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.assignment, color: color),
                const SizedBox(width: 6),
                const Text('Contrat de location',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const SizedBox(height: 8),
              if (field.rentAmount != null)
                _kv('Loyer',
                    '${field.rentAmount!.toStringAsFixed(0)} TND ${_periodLabel(field.rentPeriod)}'),
              if (field.rentStartDate != null)
                _kv('Début', _formatDate(field.rentStartDate!)),
              if (field.rentEndDate != null)
                _kv('Fin', _formatDate(field.rentEndDate!)),
              if (field.landlordName != null)
                _kv('Propriétaire', field.landlordName!),
              if (field.landlordPhone != null)
                _kv('Téléphone', field.landlordPhone!),
              if (daysLeft != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    daysLeft < 0
                        ? 'Expiré depuis ${-daysLeft} jours'
                        : 'Expire dans $daysLeft jours',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _periodLabel(String? p) {
    switch (p) {
      case RentPeriod.month:
        return '/ mois';
      case RentPeriod.year:
        return '/ an';
      default:
        return '(total)';
    }
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      );
}

class _CropTile extends StatelessWidget {
  const _CropTile({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(crop.iconEmoji, style: const TextStyle(fontSize: 28)),
        title: Text(crop.nameFr,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(crop.isYearRound
            ? 'Toute l\'année'
            : 'Saison: ${_seasonRange(crop.seasonMonths)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/cultures/crop/${crop.id}'),
      ),
    );
  }

  String _seasonRange(List<int> months) {
    if (months.isEmpty) return '—';
    const names = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return months.map((m) => names[m - 1]).join(', ');
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.label});
  final Expense expense;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.money_off, color: AppColors.red),
        title: Text('${expense.amount.toStringAsFixed(0)} TND',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$label · ${expense.category} · ${expense.date}'),
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, required this.cropEmoji});
  final Sale sale;
  final String cropEmoji;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        leading: Text(cropEmoji, style: const TextStyle(fontSize: 24)),
        title: Text('${sale.totalPrice.toStringAsFixed(0)} TND',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.green)),
        subtitle: Text(
            '${sale.quantity.toStringAsFixed(0)} ${_unitLabel(sale.unit)} · ${sale.saleDate}${sale.buyerName == null ? "" : " · ${sale.buyerName}"}'),
      ),
    );
  }

  String _unitLabel(String u) {
    switch (u) {
      case SaleUnit.grandeCaisse:
        return 'Gd caisse';
      case SaleUnit.petiteCaisse:
        return 'Pte caisse';
      case SaleUnit.kg:
        return 'kg';
      case SaleUnit.litre:
        return 'L';
      default:
        return 'pcs';
    }
  }
}
