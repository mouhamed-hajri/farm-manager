import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/history_entry.dart';
import '../../providers/animal_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/field_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/species_provider.dart';
import '../../providers/sync_provider.dart' show syncStateProvider, SyncStatus;
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger seed of defaults once after auth.
    ref.watch(speciesSeederProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مزرعتي · Ma Ferme'),
      ),
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Animaux'),
          BottomNavigationBarItem(icon: Icon(Icons.grass), label: 'Cultures'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Finances'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Plus'),
        ],
      ),
    );
  }
}

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animalStats = ref.watch(allAnimalsStatsProvider);
    final expenseStats = ref.watch(expenseStatsProvider);
    final expensesAsync = ref.watch(expenseListProvider);
    final fieldsAsync = ref.watch(fieldsListProvider);
    final salesAsync = ref.watch(salesListProvider);
    final syncState = ref.watch(syncStateProvider);
    final historyAsync = ref.watch(historyListProvider);

    final now = DateTime.now();
    final monthPrefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthPrefix =
        '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}';

    final salesList = salesAsync.asData?.value ?? const [];
    final expensesList = expensesAsync.asData?.value ?? const [];

    final incomeThisMonth = salesList
        .where((s) => s.saleDate.startsWith(monthPrefix))
        .fold<double>(0.0, (sum, s) => sum + s.totalPrice);
    final incomeLastMonth = salesList
        .where((s) => s.saleDate.startsWith(lastMonthPrefix))
        .fold<double>(0.0, (sum, s) => sum + s.totalPrice);
    final expenseLastMonth = expensesList
        .where((e) => e.date.startsWith(lastMonthPrefix))
        .fold<double>(0.0, (sum, e) => sum + e.amount);

    final profitThisMonth = incomeThisMonth - expenseStats.totalThisMonth;
    final profitLastMonth = incomeLastMonth - expenseLastMonth;
    final profitDelta = profitThisMonth - profitLastMonth;
    final incomeDelta = incomeThisMonth - incomeLastMonth;

    String fmtDelta(double v) {
      final sign = v >= 0 ? '+' : '−';
      return '$sign${v.abs().toStringAsFixed(0)} TND vs mois dernier';
    }

    final fieldCount = fieldsAsync.asData?.value.length ?? 0;
    final rentedCount = fieldsAsync.asData?.value
            .where((f) => f.ownership == 'rented')
            .length ??
        0;

    return RefreshIndicator(
      onRefresh: () => ref.read(syncStateProvider.notifier).sync(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Aperçu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            children: [
              StatCard(
                label: 'Animaux actifs',
                value: '${animalStats.active}',
                icon: Icons.pets,
                color: AppColors.green,
              ),
              StatCard(
                label: 'Vendus ce mois',
                value: '${animalStats.soldThisMonth}',
                icon: Icons.sell,
                color: AppColors.blue,
              ),
              StatCard(
                label: 'Dépenses (mois)',
                value:
                    '${expenseStats.totalThisMonth.toStringAsFixed(0)} TND',
                icon: Icons.money_off,
                color: AppColors.red,
              ),
              StatCard(
                label: 'Revenus (mois)',
                value: '${incomeThisMonth.toStringAsFixed(0)} TND',
                icon: Icons.attach_money,
                color: AppColors.green,
                delta: incomeLastMonth > 0 ? fmtDelta(incomeDelta) : null,
                deltaPositive: incomeDelta >= 0,
              ),
              StatCard(
                label: 'Bénéfice (mois)',
                value: '${profitThisMonth.toStringAsFixed(0)} TND',
                icon: Icons.trending_up,
                color: profitThisMonth >= 0
                    ? AppColors.green
                    : AppColors.red,
                delta: (incomeLastMonth > 0 || expenseLastMonth > 0)
                    ? fmtDelta(profitDelta)
                    : null,
                deltaPositive: profitDelta >= 0,
              ),
              StatCard(
                label: 'Champs',
                value: '$fieldCount · $rentedCount loués',
                icon: Icons.landscape,
                color: AppColors.blue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickActionButton(
                icon: Icons.add,
                label: 'Animal',
                color: AppColors.green,
                onTap: () => context.go('/animals'),
              ),
              _QuickActionButton(
                icon: Icons.money_off,
                label: 'Dépense',
                color: AppColors.red,
                onTap: () => context.push('/finances/expense/new'),
              ),
              _QuickActionButton(
                icon: Icons.attach_money,
                label: 'Vente',
                color: AppColors.blue,
                onTap: () => context.push('/finances/sale/new'),
              ),
              _QuickActionButton(
                icon: Icons.cloud_upload,
                label: syncState.status == SyncStatus.syncing
                    ? '...'
                    : 'Sauvegarder',
                color: Colors.deepPurple,
                onTap: () =>
                    ref.read(syncStateProvider.notifier).sync(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Activités récentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          historyAsync.when(
            data: (list) => list.isEmpty
                ? _empty()
                : Column(
                    children: list
                        .take(15)
                        .map((e) => _HistoryTile(entry: e))
                        .toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Text('Erreur : $e', style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Aucune activité pour le moment',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _color().withValues(alpha: 0.15),
          child: Icon(_icon(), color: _color(), size: 20),
        ),
        title: Text(entry.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(
          entry.description?.isNotEmpty == true ? entry.description! : entry.date,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        dense: true,
      ),
    );
  }

  Color _color() {
    switch (entry.actionType) {
      case 'animal_added':
        return AppColors.green;
      case 'animal_sold':
        return AppColors.blue;
      case 'animal_died':
        return AppColors.red;
      case 'expense_added':
        return AppColors.red;
      case 'crop_sold':
      case 'product_sold':
      case 'sale_added':
        return AppColors.green;
      case 'backup_completed':
      case 'restore_completed':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  IconData _icon() {
    switch (entry.actionType) {
      case 'animal_added':
        return Icons.add_circle;
      case 'animal_sold':
        return Icons.sell;
      case 'animal_died':
        return Icons.cancel;
      case 'expense_added':
        return Icons.remove_circle;
      case 'crop_sold':
      case 'product_sold':
      case 'sale_added':
        return Icons.attach_money;
      case 'backup_completed':
        return Icons.cloud_done;
      case 'restore_completed':
        return Icons.restore;
      default:
        return Icons.info;
    }
  }
}
