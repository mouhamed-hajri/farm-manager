import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/crop.dart';
import '../../models/expense.dart';
import '../../models/field.dart';
import '../../models/sale.dart';
import '../../providers/crop_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/field_provider.dart';
import '../../providers/sale_provider.dart';
import '../../theme/app_theme.dart';

/// The "Cultures" bottom-nav tab. Field-first navigation: tap a field to see
/// its crops, profit per year, etc. Orphan crops (no field yet) get a section
/// at the bottom so they're discoverable but de-emphasized.
class CulturesScreen extends ConsumerWidget {
  const CulturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(fieldsListProvider);
    final cropsAsync = ref.watch(cropsListProvider);
    final expenses =
        ref.watch(expenseListProvider).asData?.value ?? const <Expense>[];
    final sales =
        ref.watch(salesListProvider).asData?.value ?? const <Sale>[];
    final currentYear = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes champs'),
        automaticallyImplyLeading: false,
      ),
      body: fieldsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (fields) {
          final crops = cropsAsync.asData?.value ?? const <Crop>[];
          final orphans = crops.where((c) => c.fieldId == null).toList();

          if (fields.isEmpty && orphans.isEmpty) {
            return _EmptyState(
              onAddField: () => context.push('/cultures/field/new'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(fieldsListProvider);
              ref.invalidate(cropsListProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                if (fields.isNotEmpty) ...[
                  ...fields.map((f) => _FieldCard(
                        field: f,
                        crops:
                            crops.where((c) => c.fieldId == f.id).toList(),
                        expenses: expenses,
                        sales: sales,
                        year: currentYear,
                      )),
                ],
                if (orphans.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 6),
                        Text('Cultures sans champ',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...orphans.map((c) => _OrphanCropCard(crop: c)),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/cultures/field/new'),
        icon: const Icon(Icons.add),
        label: const Text('Champ'),
        backgroundColor: AppColors.green,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddField});
  final VoidCallback onAddField;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.landscape, size: 96, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Aucun champ pour le moment',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(
              'Commencez par ajouter votre premier champ.\nVous y ajouterez ensuite vos cultures.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddField,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un champ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Field card with per-year net profit + crop count + ownership/rent badges.
class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.field,
    required this.crops,
    required this.expenses,
    required this.sales,
    required this.year,
  });

  final FarmField field;
  final List<Crop> crops;
  final List<Expense> expenses;
  final List<Sale> sales;
  final int year;

  bool _inYear(String date) =>
      DateTime.tryParse(date)?.year == year;

  @override
  Widget build(BuildContext context) {
    final cropIds = crops.map((c) => c.id).toSet();
    final growing =
        crops.where((c) => c.status == CropStatus.growing).length;

    double cropRev = 0, cropExp = 0, fieldExp = 0;
    for (final e in expenses) {
      if (!_inYear(e.date)) continue;
      if (e.scope == ExpenseScope.field && e.linkedFieldId == field.id) {
        fieldExp += e.amount;
      } else if (e.linkedCropId != null && cropIds.contains(e.linkedCropId)) {
        cropExp += e.amount;
      }
    }
    for (final s in sales) {
      if (!_inYear(s.saleDate)) continue;
      if (s.scope == SaleScope.crop &&
          s.linkedCropId != null &&
          cropIds.contains(s.linkedCropId)) {
        cropRev += s.totalPrice;
      }
    }
    final net = cropRev - cropExp - fieldExp;
    final hasActivity = cropRev != 0 || cropExp != 0 || fieldExp != 0;

    // Rent warning if applicable
    final isRented = field.ownership == FieldOwnership.rented;
    int? daysLeft;
    if (isRented && field.rentEndDate != null) {
      final end = DateTime.tryParse(field.rentEndDate!);
      if (end != null) daysLeft = end.difference(DateTime.now()).inDays;
    }
    final rentUrgent = daysLeft != null && daysLeft <= 30;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/cultures/field/${field.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Thumbnail(field: field),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _badge(
                          isRented ? 'Loué' : 'Possédé',
                          isRented ? Colors.orange : AppColors.green,
                        ),
                        if (crops.isNotEmpty)
                          _muted(
                              '${crops.length} culture${crops.length == 1 ? '' : 's'}${growing < crops.length ? ' ($growing en culture)' : ''}'),
                        if (field.areaText != null)
                          _muted(field.areaText!),
                        if (rentUrgent)
                          _badge(
                            daysLeft < 0
                                ? 'Bail expiré'
                                : 'Bail expire dans ${daysLeft}j',
                            daysLeft <= 7
                                ? AppColors.red
                                : Colors.orange,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasActivity)
                    Text(
                      '${net >= 0 ? '+' : ''}${net.toStringAsFixed(0)} TND',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: net >= 0
                              ? AppColors.green
                              : AppColors.red),
                    )
                  else
                    Text('—',
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 15)),
                  Text('$year',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 11)),
                ],
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600)),
      );

  Widget _muted(String text) => Text(
        text,
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      );
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.field});
  final FarmField field;

  @override
  Widget build(BuildContext context) {
    final hasLocal = field.photoLocalPath != null &&
        File(field.photoLocalPath!).existsSync();
    final hasCloud = field.photoCloudUrl?.isNotEmpty ?? false;
    Widget child;
    if (hasLocal) {
      child = Image.file(File(field.photoLocalPath!), fit: BoxFit.cover);
    } else if (hasCloud) {
      child = Image.network(field.photoCloudUrl!, fit: BoxFit.cover);
    } else {
      child = Container(
        color: AppColors.green.withValues(alpha: 0.12),
        child: const Icon(Icons.landscape,
            color: AppColors.green, size: 28),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 60, height: 60, child: child),
    );
  }
}

class _OrphanCropCard extends StatelessWidget {
  const _OrphanCropCard({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Text(crop.iconEmoji, style: const TextStyle(fontSize: 28)),
        title: Text(crop.nameFr,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Pas encore liée à un champ',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/cultures/crop/${crop.id}'),
      ),
    );
  }
}
