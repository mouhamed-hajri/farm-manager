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
        data: (list) => list.isEmpty
            ? _empty('Aucun champ', 'Appuyez sur "+" pour ajouter un champ.')
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _FieldCard(field: list[i]),
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
                  Container(
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

class _CropsTab extends ConsumerWidget {
  const _CropsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cropsAsync = ref.watch(cropsListProvider);
    return Scaffold(
      body: cropsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) => list.isEmpty
            ? Center(
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
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _CropCard(crop: list[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/cultures/crop/new'),
        icon: const Icon(Icons.add),
        label: const Text('Culture'),
        backgroundColor: AppColors.green,
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  const _CropCard({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(crop.iconEmoji, style: const TextStyle(fontSize: 32)),
        title:
            Text(crop.nameFr, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(crop.isYearRound
            ? 'Toute l\'année · ${crop.nameAr}'
            : 'Saison: ${_seasonRange(crop.seasonMonths)} · ${crop.nameAr}'),
        onTap: () => context.push('/cultures/crop/${crop.id}'),
      ),
    );
  }

  String _seasonRange(List<int> months) {
    if (months.isEmpty) return '12 mois';
    const names = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return months.map((m) => names[m - 1]).join(', ');
  }
}
