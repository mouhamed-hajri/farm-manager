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

class _FieldDashboardScreenState extends ConsumerState<FieldDashboardScreen> {
  int? _year; // null = all-time

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  bool _inYear(String dateStr) {
    if (_year == null) return true;
    return DateTime.tryParse(dateStr)?.year == _year;
  }

  @override
  Widget build(BuildContext context) {
    final fieldAsync = ref.watch(fieldByIdProvider(widget.fieldId));
    final expenses = ref.watch(expenseListProvider).asData?.value ?? const [];
    final sales = ref.watch(salesListProvider).asData?.value ?? const [];
    final crops = ref.watch(cropsListProvider).asData?.value ?? const [];

    final cropsHere = crops.where((c) => c.fieldId == widget.fieldId).toList();
    final cropIds = cropsHere.map((c) => c.id).toSet();

    // Per-crop totals for the selected year
    final cropTotals = {for (final c in cropsHere) c.id: _CropTotals()};
    for (final e in expenses) {
      if (e.linkedCropId != null &&
          cropIds.contains(e.linkedCropId) &&
          _inYear(e.date)) {
        cropTotals[e.linkedCropId]!.expenses += e.amount;
      }
    }
    for (final s in sales) {
      if (s.scope == SaleScope.crop &&
          s.linkedCropId != null &&
          cropIds.contains(s.linkedCropId) &&
          _inYear(s.saleDate)) {
        cropTotals[s.linkedCropId]!.revenue += s.totalPrice;
      }
    }

    // Field-level expenses for the selected year
    final fieldExpensesAll = expenses
        .where((e) =>
            e.scope == ExpenseScope.field && e.linkedFieldId == widget.fieldId)
        .toList();
    final fieldExpenseTotal = fieldExpensesAll
        .where((e) => _inYear(e.date))
        .fold<double>(0, (s, e) => s + e.amount);

    // Years with any data for this field
    final years = <int>{
      DateTime.now().year,
      ...fieldExpensesAll
          .map((e) => DateTime.tryParse(e.date)?.year)
          .whereType<int>(),
      ...expenses
          .where((e) =>
              e.linkedCropId != null && cropIds.contains(e.linkedCropId))
          .map((e) => DateTime.tryParse(e.date)?.year)
          .whereType<int>(),
      ...sales
          .where((s) =>
              s.scope == SaleScope.crop &&
              s.linkedCropId != null &&
              cropIds.contains(s.linkedCropId))
          .map((s) => DateTime.tryParse(s.saleDate)?.year)
          .whereType<int>(),
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    final cropsRevenue =
        cropTotals.values.fold<double>(0, (s, t) => s + t.revenue);
    final cropsExpenses =
        cropTotals.values.fold<double>(0, (s, t) => s + t.expenses);
    final fieldNet = cropsRevenue - cropsExpenses - fieldExpenseTotal;
    final hasActivity =
        cropsRevenue != 0 || cropsExpenses != 0 || fieldExpenseTotal != 0;

    return Scaffold(
      appBar: AppBar(
        title: fieldAsync.when(
          data: (f) => Text(f?.name ?? 'Champ'),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Champ'),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                context.push('/cultures/field/${widget.fieldId}/edit');
              } else if (v == 'delete') {
                _confirmDelete(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Modifier'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline,
                      size: 18, color: AppColors.red),
                  SizedBox(width: 8),
                  Text('Supprimer',
                      style: TextStyle(color: AppColors.red)),
                ]),
              ),
            ],
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              _FieldHeader(field: field),
              const SizedBox(height: 12),

              if (years.length > 1 || cropsHere.isNotEmpty)
                _yearChips(years),
              const SizedBox(height: 12),

              if (cropsHere.isEmpty)
                _EmptyCrops(
                  onAdd: () => context.push(
                    '/cultures/crop/new',
                    extra: <String, String?>{'fieldId': widget.fieldId},
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: Text('Cultures',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700])),
                ),
                ...cropsHere.map((c) => _CropSummaryCard(
                      crop: c,
                      totals: cropTotals[c.id]!,
                    )),
                const SizedBox(height: 12),
              ],

              // Field-level expenses: compact row, tappable to add more
              _FieldExpensesRow(
                total: fieldExpenseTotal,
                onAdd: () => context.push(
                  '/finances/expense/new',
                  extra: <String, String?>{
                    'scope': 'field',
                    'fieldId': widget.fieldId,
                  },
                ),
              ),

              const SizedBox(height: 16),

              if (hasActivity)
                _FieldTotalCard(
                  year: _year,
                  revenue: cropsRevenue,
                  cropExpenses: cropsExpenses,
                  fieldExpenses: fieldExpenseTotal,
                  net: fieldNet,
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/cultures/crop/new',
          extra: <String, String?>{'fieldId': widget.fieldId},
        ),
        icon: const Icon(Icons.add),
        label: const Text('Culture'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  Widget _yearChips(List<int> years) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...years.map((y) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('$y'),
                  selected: _year == y,
                  onSelected: (_) => setState(() => _year = y),
                ),
              )),
          ChoiceChip(
            label: const Text('Tout'),
            selected: _year == null,
            onSelected: (_) => setState(() => _year = null),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le champ ?'),
        content: const Text(
            'Les cultures et dépenses liées resteront mais perdront leur lien à ce champ.'),
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

class _CropTotals {
  double expenses = 0;
  double revenue = 0;
  double get net => revenue - expenses;
}

/// Compact field header — small photo + name + ownership + rent expiry.
/// Replaces the previous huge empty placeholder.
class _FieldHeader extends StatelessWidget {
  const _FieldHeader({required this.field});
  final FarmField field;

  @override
  Widget build(BuildContext context) {
    final hasLocal = field.photoLocalPath != null &&
        File(field.photoLocalPath!).existsSync();
    final hasCloud = field.photoCloudUrl?.isNotEmpty ?? false;
    final hasPhoto = hasLocal || hasCloud;

    if (!hasPhoto) {
      return _InfoStrip(field: field);
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 140,
            width: double.infinity,
            child: hasLocal
                ? Image.file(File(field.photoLocalPath!), fit: BoxFit.cover)
                : Image.network(field.photoCloudUrl!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 8),
        _InfoStrip(field: field),
      ],
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.field});
  final FarmField field;

  @override
  Widget build(BuildContext context) {
    final isRented = field.ownership == FieldOwnership.rented;
    int? daysLeft;
    if (isRented && field.rentEndDate != null) {
      final end = DateTime.tryParse(field.rentEndDate!);
      if (end != null) daysLeft = end.difference(DateTime.now()).inDays;
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _badge(isRented ? '🟠 Loué' : '🟢 Possédé',
            isRented ? Colors.orange : AppColors.green),
        if (field.areaText != null) _muted(field.areaText!),
        if (field.locationText != null) _muted('📍 ${field.locationText!}'),
        if (daysLeft != null)
          _badge(
            daysLeft < 0
                ? 'Bail expiré'
                : 'Bail expire dans ${daysLeft}j',
            daysLeft <= 7
                ? AppColors.red
                : daysLeft <= 30
                    ? Colors.orange
                    : AppColors.green,
          ),
      ],
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      );

  Widget _muted(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
      );
}

class _EmptyCrops extends StatelessWidget {
  const _EmptyCrops({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              'Aucune culture pour le moment',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Ajoutez vos arbres, vos légumes, vos céréales…',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une culture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropSummaryCard extends StatelessWidget {
  const _CropSummaryCard({required this.crop, required this.totals});
  final Crop crop;
  final _CropTotals totals;

  @override
  Widget build(BuildContext context) {
    final hasData = totals.revenue != 0 || totals.expenses != 0;
    final net = totals.net;
    final netColor = net >= 0 ? AppColors.green : AppColors.red;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => context.push('/cultures/crop/${crop.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(crop.iconEmoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(crop.nameFr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ),
                        _statusPill(crop.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (hasData)
                      Text(
                        '+${totals.revenue.toStringAsFixed(0)} − ${totals.expenses.toStringAsFixed(0)} TND',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                      )
                    else
                      Text('Aucune activité cette année',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasData
                        ? '${net >= 0 ? '+' : ''}${net.toStringAsFixed(0)} TND'
                        : '—',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasData ? netColor : Colors.grey[400],
                        fontSize: 15),
                  ),
                  if (hasData)
                    Text(
                      net >= 0 ? 'Bénéfice' : 'Perte',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[600]),
                    ),
                ],
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String s) {
    final color = s == CropStatus.growing
        ? AppColors.green
        : s == CropStatus.lost
            ? AppColors.red
            : Colors.grey[600]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${CropStatus.emoji(s)} ${CropStatus.labelFr(s)}',
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _FieldExpensesRow extends StatelessWidget {
  const _FieldExpensesRow({required this.total, required this.onAdd});
  final double total;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final has = total > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: has
                ? AppColors.red.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Colors.grey.withValues(alpha: 0.25), width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.money_off,
                  color: has ? AppColors.red : Colors.grey[600], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Frais du champ',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: has ? AppColors.red : Colors.grey[800],
                          fontSize: 13),
                    ),
                    Text(
                      has
                          ? 'Plowing, irrigation générale, entretien…'
                          : 'Aucun frais. Toucher pour ajouter.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (has) ...[
                Text(
                  '−${total.toStringAsFixed(0)} TND',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.red,
                      fontSize: 15),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.add_circle_outline,
                  color: AppColors.green, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldTotalCard extends StatelessWidget {
  const _FieldTotalCard({
    required this.year,
    required this.revenue,
    required this.cropExpenses,
    required this.fieldExpenses,
    required this.net,
  });
  final int? year;
  final double revenue;
  final double cropExpenses;
  final double fieldExpenses;
  final double net;

  @override
  Widget build(BuildContext context) {
    final netColor = net >= 0 ? AppColors.green : AppColors.red;
    final yearLabel = year == null ? 'Tout' : '$year';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bilan $yearLabel',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(net >= 0 ? 'Bénéfice' : 'Perte',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                Text(
                  '${net >= 0 ? '+' : ''}${net.toStringAsFixed(0)} TND',
                  style: TextStyle(
                      color: netColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22),
                ),
              ],
            ),
            const Divider(height: 18),
            _row('Revenus cultures', '+${revenue.toStringAsFixed(0)}',
                AppColors.green),
            const SizedBox(height: 2),
            _row('Dépenses cultures', '−${cropExpenses.toStringAsFixed(0)}',
                AppColors.red),
            const SizedBox(height: 2),
            _row('Frais du champ', '−${fieldExpenses.toStringAsFixed(0)}',
                AppColors.red),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      );
}
