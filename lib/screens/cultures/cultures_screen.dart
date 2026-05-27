import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/crop.dart';
import '../../models/field.dart';
import '../../providers/crop_provider.dart';
import '../../providers/field_provider.dart';
import '../../theme/app_theme.dart';

class CulturesScreen extends ConsumerStatefulWidget {
  const CulturesScreen({super.key});

  @override
  ConsumerState<CulturesScreen> createState() => _CulturesScreenState();
}

class _CulturesScreenState extends ConsumerState<CulturesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cultures'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Champs'), Tab(text: 'Cultures')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_FieldsTab(), _CropsTab()],
      ),
    );
  }
}

class _FieldsTab extends ConsumerWidget {
  const _FieldsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(fieldsListProvider);

    return Scaffold(
      body: fieldsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(fieldsListProvider),
          child: list.isEmpty
              ? ListView(
                  children: [_empty('Aucun champ',
                      'Appuyez sur "+" pour ajouter un champ.')],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) => _FieldCard(field: list[i]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/cultures/field/new'),
        icon: const Icon(Icons.add),
        label: const Text('Champ'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  Widget _empty(String title, String hint) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.landscape, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(title,
                style: TextStyle(fontSize: 18, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(hint, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.field});
  final FarmField field;

  @override
  Widget build(BuildContext context) {
    final isRented = field.ownership == FieldOwnership.rented;
    int? daysLeft;
    if (isRented && field.rentEndDate != null) {
      final end = DateTime.tryParse(field.rentEndDate!);
      if (end != null) {
        daysLeft = end.difference(DateTime.now()).inDays;
      }
    }
    Color daysColor = AppColors.green;
    if (daysLeft != null) {
      if (daysLeft <= 7) {
        daysColor = AppColors.red;
      } else if (daysLeft <= 30) {
        daysColor = Colors.orange;
      }
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.landscape, color: AppColors.green, size: 32),
        title: Text(field.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (field.areaText != null) Text(field.areaText!),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRented
                        ? Colors.orange.withValues(alpha: 0.15)
                        : AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(isRented ? 'Loué' : 'Possédé',
                      style: TextStyle(
                          fontSize: 11,
                          color: isRented ? Colors.orange : AppColors.green,
                          fontWeight: FontWeight.w600)),
                ),
                if (daysLeft != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: daysColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        daysLeft < 0
                            ? 'Contrat expiré'
                            : 'Expire dans $daysLeft j',
                        style: TextStyle(
                            fontSize: 11,
                            color: daysColor,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () => context.push('/cultures/field/${field.id}'),
      ),
    );
  }
}

class _CropsTab extends ConsumerStatefulWidget {
  const _CropsTab();

  @override
  ConsumerState<_CropsTab> createState() => _CropsTabState();
}

class _CropsTabState extends ConsumerState<_CropsTab> {
  String? _statusFilter; // null = all

  @override
  Widget build(BuildContext context) {
    final cropsAsync = ref.watch(cropsListProvider);
    return Scaffold(
      body: cropsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (allList) {
          final list = _statusFilter == null
              ? allList
              : allList.where((c) => c.status == _statusFilter).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(cropsListProvider),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: _statusChips(allList),
                  ),
                ),
                if (list.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.grass, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text('Aucune culture',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[700])),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _CropCard(crop: list[i]),
                        childCount: list.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/cultures/crop/new'),
        icon: const Icon(Icons.add),
        label: const Text('Culture'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  Widget _statusChips(List<Crop> all) {
    final counts = <String?, int>{
      null: all.length,
      CropStatus.growing: all.where((c) => c.status == CropStatus.growing).length,
      CropStatus.harvested: all.where((c) => c.status == CropStatus.harvested).length,
      CropStatus.lost: all.where((c) => c.status == CropStatus.lost).length,
    };
    return Wrap(
      spacing: 6,
      children: [
        ChoiceChip(
          label: Text('Tout (${counts[null]})'),
          selected: _statusFilter == null,
          onSelected: (_) => setState(() => _statusFilter = null),
        ),
        ...CropStatus.all.map((s) => ChoiceChip(
              label: Text('${CropStatus.emoji(s)} ${CropStatus.labelFr(s)} (${counts[s] ?? 0})'),
              selected: _statusFilter == s,
              onSelected: (_) => setState(() => _statusFilter = s),
            )),
      ],
    );
  }
}

class _CropCard extends StatelessWidget {
  const _CropCard({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context) {
    final statusColor = crop.status == CropStatus.growing
        ? AppColors.green
        : crop.status == CropStatus.lost
            ? AppColors.red
            : Colors.grey[600]!;
    return Card(
      child: ListTile(
        leading: Text(crop.iconEmoji, style: const TextStyle(fontSize: 32)),
        title: Row(children: [
          Expanded(
            child: Text(crop.nameFr,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${CropStatus.emoji(crop.status)} ${CropStatus.labelFr(crop.status)}',
              style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        subtitle: Text(
            crop.isYearRound
                ? 'Toute l\'année · ${crop.nameAr}'
                : 'Saison: ${_seasonRange(crop.seasonMonths)} · ${crop.nameAr}',
            overflow: TextOverflow.ellipsis,
            maxLines: 2),
        onTap: () => context.push('/cultures/crop/${crop.id}'),
      ),
    );
  }

  String _seasonRange(List<int> months) {
    if (months.isEmpty) return '12 mois';
    const names = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return months.map((m) => names[m - 1]).join(', ');
  }
}
