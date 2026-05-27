import 'dart:io';
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

enum _Range { thisMonth, thisYear, all }

class _CropDashboardScreenState extends ConsumerState<CropDashboardScreen> {
  _Range _range = _Range.thisYear;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _applyRange(_Range.thisYear);
  }

  void _applyRange(_Range r) {
    final n = DateTime.now();
    setState(() {
      _range = r;
      switch (r) {
        case _Range.thisMonth:
          _rangeStart = DateTime(n.year, n.month, 1);
          _rangeEnd = n;
        case _Range.thisYear:
          _rangeStart = DateTime(n.year, 1, 1);
          _rangeEnd = n;
        case _Range.all:
          _rangeStart = null;
          _rangeEnd = null;
      }
    });
  }

  bool _inRange(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return false;
    final s = _rangeStart, e = _rangeEnd;
    if (s == null || e == null) return true;
    return !d.isBefore(s) && !d.isAfter(e);
  }

  @override
  Widget build(BuildContext context) {
    final cropAsync = ref.watch(cropByIdProvider(widget.cropId));
    final activitiesAsync = ref.watch(cropActivitiesProvider(widget.cropId));
    final harvestsAsync = ref.watch(cropHarvestsProvider(widget.cropId));
    final fields = ref.watch(fieldsListProvider).asData?.value ?? const [];

    final allActivities =
        (activitiesAsync.asData?.value ?? const []).cast<CropActivity>();
    final allHarvests =
        (harvestsAsync.asData?.value ?? const []).cast<Harvest>();

    final activities = allActivities.where((a) => _inRange(a.date)).toList();
    final harvests =
        allHarvests.where((h) => _inRange(h.harvestDate)).toList();

    final totalExpenses =
        activities.fold<double>(0, (s, a) => s + (a.cost ?? 0));
    final totalKg =
        harvests.fold<double>(0, (s, h) => s + (h.quantityInKg ?? 0));
    final totalRevenue =
        harvests.fold<double>(0, (s, h) => s + (h.totalPrice ?? 0));
    final profit = totalRevenue - totalExpenses;
    final profitPerKg = totalKg > 0 ? profit / totalKg : null;

    return Scaffold(
      appBar: AppBar(
        title: cropAsync.when(
          data: (c) =>
              Text(c == null ? 'Culture' : '${c.iconEmoji} ${c.nameFr}'),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Culture'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Modifier',
            onPressed: () =>
                context.push('/cultures/crop/${widget.cropId}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Supprimer',
            onPressed: () => _confirmDelete(context),
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
            padding: const EdgeInsets.all(16),
            children: [
              _buildPhotoHeader(crop),
              const SizedBox(height: 12),
              _buildInfoCard(crop, linkedField),
              const SizedBox(height: 8),
              _buildStatusRow(crop),
              const SizedBox(height: 16),
              _buildRangeChips(),
              const SizedBox(height: 12),
              _buildKpiCard(
                  totalExpenses, totalKg, totalRevenue, profit, profitPerKg),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.agriculture, size: 18),
                    label: const Text('Activité'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white),
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
                        foregroundColor: Colors.white),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AddHarvestDialog(crop: crop),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                const Text('Journal',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                    '${timelineItems.length} entrée${timelineItems.length == 1 ? '' : 's'}',
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              if (timelineItems.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                          'Aucune activité sur cette période',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                  ),
                )
              else
                ...timelineItems
                    .map((item) => _buildTimelineTile(context, item)),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPhotoHeader(Crop crop) {
    final hasLocal = crop.photoLocalPath != null &&
        File(crop.photoLocalPath!).existsSync();
    final hasCloud = crop.photoCloudUrl?.isNotEmpty ?? false;
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: hasLocal
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(crop.photoLocalPath!),
                  fit: BoxFit.cover, width: double.infinity))
          : hasCloud
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(crop.photoCloudUrl!,
                      fit: BoxFit.cover, width: double.infinity))
              : Center(
                  child: Text(crop.iconEmoji,
                      style: const TextStyle(fontSize: 64)),
                ),
    );
  }

  Widget _buildInfoCard(Crop crop, FarmField? linkedField) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.label_outline, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(_kindLabel(crop.kind),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            if (crop.areaOrCountText != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.aspect_ratio, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(crop.areaOrCountText!),
              ]),
            ],
            if (linkedField != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.landscape, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(linkedField.name),
              ]),
            ],
            if (crop.notes != null) ...[
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notes, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(child: Text(crop.notes!)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(Crop crop) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: CropStatus.all.map((s) {
          final selected = crop.status == s;
          final color = s == CropStatus.growing
              ? AppColors.green
              : s == CropStatus.lost
                  ? AppColors.red
                  : Colors.grey[700]!;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${CropStatus.emoji(s)} ${CropStatus.labelFr(s)}'),
              selected: selected,
              selectedColor: color.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: selected ? color : Colors.grey[600],
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (v) async {
                if (v && !selected) {
                  await ref.read(cropRepositoryProvider).markStatus(crop, s);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRangeChips() => Wrap(
        spacing: 6,
        children: [
          ChoiceChip(
              label: const Text('Ce mois'),
              selected: _range == _Range.thisMonth,
              onSelected: (_) => _applyRange(_Range.thisMonth)),
          ChoiceChip(
              label: const Text('Cette année'),
              selected: _range == _Range.thisYear,
              onSelected: (_) => _applyRange(_Range.thisYear)),
          ChoiceChip(
              label: const Text('Tout'),
              selected: _range == _Range.all,
              onSelected: (_) => _applyRange(_Range.all)),
        ],
      );

  Widget _buildKpiCard(double exp, double kg, double rev, double profit,
      double? profitPerKg) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _kpiRow('Dépenses', '${exp.toStringAsFixed(0)} TND',
                AppColors.red),
            const SizedBox(height: 4),
            _kpiRow(
              'Récolte',
              kg > 0
                  ? '${kg.toStringAsFixed(0)} kg  ·  ${rev.toStringAsFixed(0)} TND'
                  : '${rev.toStringAsFixed(0)} TND',
              AppColors.green,
            ),
            const Divider(),
            _kpiRow(
              profit >= 0 ? 'Bénéfice' : 'Perte',
              '${profit.toStringAsFixed(0)} TND',
              profit >= 0 ? AppColors.green : AppColors.red,
              bold: true,
            ),
            if (profitPerKg != null) ...[
              const SizedBox(height: 4),
              _kpiRow(
                'Bénéfice / kg',
                '${profitPerKg.toStringAsFixed(2)} TND/kg',
                profitPerKg >= 0 ? AppColors.green : AppColors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kpiRow(String label, String value, Color color,
          {bool bold = false}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  fontSize: bold ? 16 : 14)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  fontSize: bold ? 16 : 14)),
        ],
      );

  Widget _buildTimelineTile(BuildContext context, _TimelineItem item) {
    return Card(
      child: ListTile(
        dense: true,
        leading: Text(item.emoji, style: const TextStyle(fontSize: 22)),
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${item.date}${item.subtitle != null ? '  ·  ${item.subtitle}' : ''}',
          overflow: TextOverflow.ellipsis,
        ),
        trailing: item.amount != null
            ? Text(
                '${item.amount!.toStringAsFixed(0)} TND',
                style: TextStyle(
                    color: item.isHarvest ? AppColors.green : AppColors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              )
            : null,
        onLongPress: () => _showDeleteDialog(context, item),
      ),
    );
  }

  Future<void> _showDeleteDialog(
      BuildContext context, _TimelineItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Supprimer cette ${item.isHarvest ? 'récolte' : 'activité'} ?'),
        content: const Text('Cette action est irréversible.'),
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
      if (item.isHarvest && item.harvest != null) {
        await ref.read(harvestRepositoryProvider).delete(item.harvest!);
      } else if (item.activity != null) {
        await ref
            .read(cropActivityRepositoryProvider)
            .delete(item.activity!);
      }
    }
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

  String _kindLabel(String kind) {
    switch (kind) {
      case 'tree':
        return 'Arbre fruitier';
      case 'vegetable':
        return 'Légume';
      case 'crop':
        return 'Grande culture';
      default:
        return 'Autre';
    }
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

  factory _TimelineItem.fromActivity(CropActivity a) {
    final title = a.description?.isNotEmpty == true
        ? a.description!
        : CropActivityType.labelFr(a.activityType);
    return _TimelineItem(
      date: a.date,
      emoji: CropActivityType.emoji(a.activityType),
      title: title,
      subtitle: a.notes,
      amount: a.cost,
      isHarvest: false,
      activity: a,
    );
  }

  factory _TimelineItem.fromHarvest(Harvest h) {
    return _TimelineItem(
      date: h.harvestDate,
      emoji: '🚜',
      title: 'Récolte: ${h.quantity.toStringAsFixed(0)} ${HarvestUnit.labelFr(h.unit)}',
      subtitle: h.notes,
      amount: h.totalPrice,
      isHarvest: true,
      harvest: h,
    );
  }
}
