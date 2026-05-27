import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/crop.dart';
import '../../models/crop_activity.dart';
import '../../models/field.dart';
import '../../models/harvest.dart';
import '../../providers/core_providers.dart';
import '../../providers/crop_provider.dart';
import '../../providers/field_provider.dart';
import '../../theme/app_theme.dart';
import 'dialogs/add_crop_activity_dialog.dart';
import 'dialogs/add_harvest_dialog.dart';

class CropDashboardScreen extends ConsumerStatefulWidget {
  const CropDashboardScreen({super.key, required this.cropId});
  final String cropId;

  @override
  ConsumerState<CropDashboardScreen> createState() =>
      _CropDashboardScreenState();
}

class _CropDashboardScreenState extends ConsumerState<CropDashboardScreen> {
  int? _year;

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
    final cropAsync = ref.watch(cropByIdProvider(widget.cropId));
    final activitiesAsync = ref.watch(cropActivitiesProvider(widget.cropId));
    final harvestsAsync = ref.watch(cropHarvestsProvider(widget.cropId));
    final fields = ref.watch(fieldsListProvider).asData?.value ?? const [];

    final allActivities = activitiesAsync.asData?.value ?? const [];
    final allHarvests = harvestsAsync.asData?.value ?? const [];

    final activities = allActivities.where((a) => _inYear(a.date)).toList();
    final harvests =
        allHarvests.where((h) => _inYear(h.harvestDate)).toList();

    final years = <int>{
      DateTime.now().year,
      ...allActivities
          .map((a) => DateTime.tryParse(a.date)?.year)
          .whereType<int>(),
      ...allHarvests
          .map((h) => DateTime.tryParse(h.harvestDate)?.year)
          .whereType<int>(),
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    final totalExpenses =
        activities.fold<double>(0, (s, a) => s + (a.cost ?? 0));
    final totalKg =
        harvests.fold<double>(0, (s, h) => s + (h.quantityInKg ?? 0));
    final totalRevenue =
        harvests.fold<double>(0, (s, h) => s + (h.totalPrice ?? 0));
    final profit = totalRevenue - totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: cropAsync.when(
          data: (c) => Text(c == null ? 'Culture' : '${c.iconEmoji} ${c.nameFr}'),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Culture'),
        ),
        actions: [
          if (cropAsync.asData?.value != null)
            _StatusMenu(crop: cropAsync.asData!.value!),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                context.push('/cultures/crop/${widget.cropId}/edit');
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
      body: cropAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (crop) {
          if (crop == null) {
            return const Center(child: Text('Culture introuvable'));
          }
          final linkedField = fields
              .where((f) => f.id == crop.fieldId)
              .cast<FarmField?>()
              .firstOrNull;

          final timelineItems = <_TimelineItem>[
            ...activities.map(_TimelineItem.fromActivity),
            ...harvests.map(_TimelineItem.fromHarvest),
          ]..sort((a, b) => b.date.compareTo(a.date));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _InfoStrip(crop: crop, field: linkedField),
              const SizedBox(height: 12),
              _yearChips(years),
              const SizedBox(height: 14),
              _KpiStrip(
                kg: totalKg,
                revenue: totalRevenue,
                expenses: totalExpenses,
                profit: profit,
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.agriculture, size: 18),
                    label: const Text('Activité'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AddCropActivityDialog(crop: crop),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_basket, size: 18),
                    label: const Text('Récolte'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AddHarvestDialog(crop: crop),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Text('Journal',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800])),
                const Spacer(),
                Text(
                    '${timelineItems.length} entrée${timelineItems.length == 1 ? '' : 's'}',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              if (timelineItems.isEmpty)
                _emptyJournal(context, crop)
              else
                ...timelineItems
                    .map((it) => _TimelineTile(item: it, ref: ref)),
            ],
          );
        },
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

  Widget _emptyJournal(BuildContext context, Crop crop) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        child: Column(
          children: [
            Icon(Icons.event_note, color: Colors.grey[400], size: 40),
            const SizedBox(height: 8),
            Text(
              _year == null
                  ? 'Pas encore d\'activité'
                  : 'Pas d\'activité en $_year',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Touchez "Activité" ou "Récolte" pour commencer.',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la culture ?'),
        content: const Text(
            'Toutes les activités et récoltes liées seront supprimées.'),
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
      await ref.read(cropRepositoryProvider).deleteCrop(widget.cropId);
      if (context.mounted) context.pop();
    }
  }
}

/// Status pill in the AppBar, doubles as a popup menu to change state.
class _StatusMenu extends ConsumerWidget {
  const _StatusMenu({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = crop.status == CropStatus.growing
        ? Colors.white
        : crop.status == CropStatus.lost
            ? AppColors.red
            : Colors.grey[300]!;
    return PopupMenuButton<String>(
      tooltip: 'Statut',
      offset: const Offset(0, 40),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${CropStatus.emoji(crop.status)} ${CropStatus.labelFr(crop.status)}',
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
          ],
        ),
      ),
      onSelected: (s) async {
        await ref.read(cropRepositoryProvider).markStatus(crop, s);
      },
      itemBuilder: (_) => CropStatus.all
          .map((s) => PopupMenuItem(
                value: s,
                child: Text(
                    '${CropStatus.emoji(s)} ${CropStatus.labelFr(s)}'),
              ))
          .toList(),
    );
  }
}

/// One-liner info row: emoji + name (in AppBar already) + field + tree count
/// + planted date. Replaces the old info card.
class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.crop, required this.field});
  final Crop crop;
  final FarmField? field;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (field != null) parts.add('📍 ${field!.name}');
    if (crop.treeCount != null) parts.add('🌳 ${crop.treeCount} arbres');
    if (crop.plantedDate != null) {
      parts.add('📅 Planté ${_year(crop.plantedDate!)}');
    }
    parts.add(CropLifecycle.labelFr(crop.lifecycle));
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: parts.map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(p,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[800])),
        );
      }).toList(),
    );
  }

  String _year(String iso) {
    final d = DateTime.tryParse(iso);
    return d?.year.toString() ?? iso;
  }
}

/// 3-column KPI strip — replaces the bigger card. Big numbers, tight footprint.
class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.kg,
    required this.revenue,
    required this.expenses,
    required this.profit,
  });
  final double kg;
  final double revenue;
  final double expenses;
  final double profit;

  @override
  Widget build(BuildContext context) {
    final profitColor = profit >= 0 ? AppColors.green : AppColors.red;
    return Row(
      children: [
        Expanded(
          child: _kpi(
            'Récolte',
            kg > 0 ? '${kg.toStringAsFixed(0)} kg' : '—',
            AppColors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpi(
            'Dépenses',
            '−${expenses.toStringAsFixed(0)}',
            AppColors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpi(
            profit >= 0 ? 'Bénéfice' : 'Perte',
            '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(0)}',
            profitColor,
            highlight: true,
          ),
        ),
      ],
    );
  }

  Widget _kpi(String label, String value, Color color,
      {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: highlight
                ? color.withValues(alpha: 0.3)
                : Colors.grey.shade300,
            width: highlight ? 1.4 : 1),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: highlight ? 18 : 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (label != 'Récolte') const SizedBox(height: 2),
          if (label != 'Récolte')
            Text('TND',
                style: TextStyle(color: Colors.grey[500], fontSize: 9)),
        ],
      ),
    );
  }
}

class _TimelineItem {
  final String date;
  final String emoji;
  final String title;
  final String? subtitle;
  final double? amount;
  final bool isHarvest;
  final CropActivity? activity;
  final Harvest? harvest;

  const _TimelineItem({
    required this.date,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.amount,
    required this.isHarvest,
    this.activity,
    this.harvest,
  });

  factory _TimelineItem.fromActivity(CropActivity a) => _TimelineItem(
        date: a.date,
        emoji: CropActivityType.emoji(a.activityType),
        title: a.description?.isNotEmpty == true
            ? a.description!
            : CropActivityType.labelFr(a.activityType),
        subtitle: a.notes,
        amount: a.cost,
        isHarvest: false,
        activity: a,
      );

  factory _TimelineItem.fromHarvest(Harvest h) => _TimelineItem(
        date: h.harvestDate,
        emoji: '🚜',
        title:
            'Récolte ${h.quantity.toStringAsFixed(0)} ${HarvestUnit.labelFr(h.unit)}',
        subtitle: h.notes,
        amount: h.totalPrice,
        isHarvest: true,
        harvest: h,
      );
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.item, required this.ref});
  final _TimelineItem item;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final amtColor = item.isHarvest ? AppColors.green : AppColors.red;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        dense: true,
        leading: Text(item.emoji, style: const TextStyle(fontSize: 22)),
        title: Text(item.title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(
          item.subtitle == null || item.subtitle!.isEmpty
              ? item.date
              : '${item.date}  ·  ${item.subtitle}',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
        trailing: item.amount != null && item.amount! > 0
            ? Text(
                '${item.isHarvest ? '+' : '−'}${item.amount!.toStringAsFixed(0)} TND',
                style: TextStyle(
                    color: amtColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              )
            : null,
        onLongPress: () => _confirmRemove(context),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Supprimer cette ${item.isHarvest ? 'récolte' : 'activité'} ?'),
        content: const Text(
            'La dépense ou la vente liée sera également supprimée.'),
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
    if (ok == true) {
      if (item.isHarvest && item.harvest != null) {
        await ref.read(harvestRepositoryProvider).delete(item.harvest!);
      } else if (item.activity != null) {
        await ref
            .read(cropActivityRepositoryProvider)
            .delete(item.activity!);
      }
    }
  }
}

