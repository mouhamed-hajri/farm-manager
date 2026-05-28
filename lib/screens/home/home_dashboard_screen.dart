import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/crop.dart';
import '../../models/field.dart';
import '../../models/history_entry.dart';
import '../../providers/animal_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/crop_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/field_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/sync_provider.dart' show syncStateProvider, SyncStatus;
import '../../theme/app_theme.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  bool _restoring = false;
  String _restoreMessage = '';
  bool _initStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAccountData());
  }

  // Runs once per launch after auth. On the first launch for a (device, uid)
  // pair, if the cloud has data it is restored first. Default categories are
  // seeded ONLY after that decision — seeding before a restore would create
  // local defaults that the cloud copies then duplicate. Finally any duplicate
  // categories left by older app versions are merged.
  Future<void> _initAccountData() async {
    if (_initStarted) return;
    _initStarted = true;

    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = 'restored_user_${user.uid}';
    final alreadyRestored = prefs.getBool(key) == true;

    if (!alreadyRestored) {
      if (!mounted) return;
      setState(() {
        _restoring = true;
        _restoreMessage = 'Vérification des sauvegardes…';
      });
      try {
        final hasCloud =
            await ref.read(firebaseServiceProvider).hasAnyCloudData(user.uid);
        if (hasCloud) {
          if (mounted) {
            setState(() => _restoreMessage = 'Restauration de vos données…');
          }
          final result = await ref.read(syncStateProvider.notifier).restore();
          if (result.success) {
            await prefs.setBool(key, true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: AppColors.green,
                content: Text(
                    'Données restaurées : ${result.restoredAnimals} animaux, ${result.restoredExpenses} dépenses.'),
              ));
            }
          } else {
            // Restore failed — leave the flag unset so the next launch retries.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: AppColors.red,
                content: Text(
                    'Échec restauration : ${result.error ?? "inconnu"}'),
              ));
              setState(() => _restoring = false);
            }
            return;
          }
        } else {
          // Nothing in cloud — brand-new account for this device.
          await prefs.setBool(key, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppColors.red,
            content: Text('Erreur restauration : $e'),
          ));
          setState(() => _restoring = false);
        }
        return;
      }
    }

    // Seed defaults only after any restore has settled, then heal duplicates.
    await ref.read(speciesRepositoryProvider).seedDefaultsIfEmpty(user.uid);
    await ref.read(cropRepositoryProvider).seedDefaultsIfEmpty(user.uid);
    await ref.read(settingsRepositoryProvider).getOrCreate(user.uid);
    await ref.read(syncStateProvider.notifier).dedupeSpecies();

    if (mounted) setState(() => _restoring = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مزرعتي · Ma Ferme'),
      ),
      body: Stack(
        children: [
          widget.navigationShell,
          if (_restoring)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _restoreMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: widget.navigationShell.currentIndex,
        onTap: (i) => widget.navigationShell.goBranch(i),
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
    final cropsAsync = ref.watch(cropsListProvider);
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
    final fieldsList = fieldsAsync.asData?.value ?? const [];
    final cropsList = cropsAsync.asData?.value ?? const [];

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

    final growingCrops =
        cropsList.where((c) => c.status == CropStatus.growing).length;

    return RefreshIndicator(
      onRefresh: () => ref.read(syncStateProvider.notifier).sync(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          const _GreetingStrip(),
          const SizedBox(height: 14),
          _MonthlyHeroCard(
            monthLabel: _frenchMonth(now.month, now.year),
            profit: profitThisMonth,
            revenue: incomeThisMonth,
            expense: expenseStats.totalThisMonth,
            profitDelta: profitDelta,
            hadLastMonthData:
                incomeLastMonth != 0 || expenseLastMonth != 0,
          ),
          const SizedBox(height: 12),
          _StatsChipsRow(
            animals: animalStats.active,
            soldThisMonth: animalStats.soldThisMonth,
            crops: growingCrops,
            cropsTotal: cropsList.length,
            fields: fieldsList.length,
          ),
          const SizedBox(height: 12),
          _AlertsSection(fields: fieldsList),
          _QuickActionsGrid(
            syncing: syncState.status == SyncStatus.syncing,
            onSync: () => ref.read(syncStateProvider.notifier).sync(),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Activités récentes',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () => context.push('/history'),
                icon: const Icon(Icons.history, size: 16),
                label: const Text('Voir tout'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          historyAsync.when(
            data: (list) => list.isEmpty
                ? const _EmptyHistory()
                : Column(
                    children: list
                        .take(6)
                        .map((e) => _HistoryTile(entry: e))
                        .toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erreur : $e',
                style: const TextStyle(color: AppColors.red)),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push('/animals/ranking'),
              icon: const Icon(Icons.emoji_events,
                  size: 16, color: Colors.amber),
              label: const Text('Classement des femelles'),
            ),
          ),
        ],
      ),
    );
  }

  static String _frenchMonth(int m, int y) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '${months[m - 1]} $y';
  }
}

// ─── Greeting strip ─────────────────────────────────────────────────────────

class _GreetingStrip extends StatelessWidget {
  const _GreetingStrip();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final h = now.hour;
    final greeting =
        h < 12 ? 'Bonjour' : (h < 18 ? 'Bon après-midi' : 'Bonsoir');
    final emoji = h < 12 ? '☀️' : (h < 18 ? '🌤️' : '🌙');
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    const days = [
      'lun.',
      'mar.',
      'mer.',
      'jeu.',
      'ven.',
      'sam.',
      'dim.',
    ];
    final date =
        '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            '$greeting $emoji',
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Text(date,
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }
}

// ─── Hero card: this month's profit, with revenue/expense bars ─────────────

class _MonthlyHeroCard extends StatelessWidget {
  const _MonthlyHeroCard({
    required this.monthLabel,
    required this.profit,
    required this.revenue,
    required this.expense,
    required this.profitDelta,
    required this.hadLastMonthData,
  });

  final String monthLabel;
  final double profit;
  final double revenue;
  final double expense;
  final double profitDelta;
  final bool hadLastMonthData;

  @override
  Widget build(BuildContext context) {
    final isProfit = profit >= 0;
    final accentColor = isProfit ? AppColors.green : AppColors.red;
    final max = (revenue > expense ? revenue : expense);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.08),
            Colors.white,
          ],
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: accentColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Bilan de $monthLabel',
                    style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isProfit ? 'Bénéfice' : 'Perte',
                  style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isProfit ? '+' : '−'}${profit.abs().toStringAsFixed(0)}',
                style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 38,
                    height: 1.0),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('TND',
                    style: TextStyle(
                        color: accentColor.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (hadLastMonthData) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  profitDelta >= 0
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 14,
                  color: profitDelta >= 0
                      ? AppColors.green
                      : AppColors.red,
                ),
                const SizedBox(width: 2),
                Text(
                  '${profitDelta >= 0 ? '+' : '−'}${profitDelta.abs().toStringAsFixed(0)} TND vs mois dernier',
                  style: TextStyle(
                      color: profitDelta >= 0
                          ? AppColors.green
                          : AppColors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _bar('Revenus', revenue, max, AppColors.green),
          const SizedBox(height: 8),
          _bar('Dépenses', expense, max, AppColors.red),
        ],
      ),
    );
  }

  Widget _bar(String label, double value, double max, Color color) {
    final ratio = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
            Text('${value.toStringAsFixed(0)} TND',
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ─── Compact stats chips: animaux · cultures · champs ──────────────────────

class _StatsChipsRow extends StatelessWidget {
  const _StatsChipsRow({
    required this.animals,
    required this.soldThisMonth,
    required this.crops,
    required this.cropsTotal,
    required this.fields,
  });

  final int animals;
  final int soldThisMonth;
  final int crops;
  final int cropsTotal;
  final int fields;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _chip(
            context,
            icon: '🐑',
            value: '$animals',
            label: animals == 1 ? 'animal' : 'animaux',
            sub: soldThisMonth > 0 ? '$soldThisMonth vendus ce mois' : null,
            onTap: () => context.go('/animals'),
            color: AppColors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _chip(
            context,
            icon: '🌳',
            value: '$crops',
            label: crops == 1 ? 'culture' : 'cultures',
            sub: cropsTotal > crops ? '$cropsTotal au total' : null,
            onTap: () => context.go('/cultures'),
            color: Colors.teal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _chip(
            context,
            icon: '📍',
            value: '$fields',
            label: fields == 1 ? 'champ' : 'champs',
            sub: null,
            onTap: () => context.go('/cultures'),
            color: AppColors.blue,
          ),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context, {
    required String icon,
    required String value,
    required String label,
    required String? sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(sub,
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Alerts (only shown when there's something to flag) ────────────────────

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({required this.fields});
  final List<FarmField> fields;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rentExpiring = fields
        .where((f) => f.ownership == FieldOwnership.rented)
        .where((f) {
      if (f.rentEndDate == null) return false;
      final d = DateTime.tryParse(f.rentEndDate!);
      if (d == null) return false;
      final diff = d.difference(now).inDays;
      return diff <= 30;
    }).toList();

    if (rentExpiring.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange[800], size: 18),
                const SizedBox(width: 6),
                Text('À surveiller',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            ...rentExpiring.map((f) {
              final d = DateTime.parse(f.rentEndDate!);
              final days = d.difference(now).inDays;
              return InkWell(
                onTap: () => context.push('/cultures/field/${f.id}'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Text(days < 0 ? '📜' : '⏰',
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          days < 0
                              ? 'Bail "${f.name}" expiré depuis ${-days} jours'
                              : days == 0
                                  ? 'Bail "${f.name}" expire aujourd\'hui'
                                  : 'Bail "${f.name}" expire dans $days jours',
                          style: TextStyle(
                              color: Colors.orange[900], fontSize: 12),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Colors.orange[700], size: 16),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Quick actions grid ────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.syncing, required this.onSync});
  final bool syncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _action(
            icon: Icons.pets,
            label: 'Animal',
            color: AppColors.green,
            onTap: () => context.go('/animals'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _action(
            icon: Icons.money_off,
            label: 'Dépense',
            color: AppColors.red,
            onTap: () => context.push('/finances/expense/new'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _action(
            icon: Icons.attach_money,
            label: 'Vente',
            color: AppColors.blue,
            onTap: () => context.push('/finances/sale/new'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _action(
            icon: syncing ? Icons.cloud_sync : Icons.cloud_upload,
            label: syncing ? '…' : 'Backup',
            color: Colors.deepPurple,
            onTap: syncing ? null : onSync,
          ),
        ),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── History tiles (compact) ───────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('Aucune activité pour le moment',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon(), color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  entry.description?.isNotEmpty == true
                      ? entry.description!
                      : entry.date,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(_relativeDate(entry.date),
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }

  static String _relativeDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final diff = DateTime.now().difference(d);
    if (diff.isNegative) return iso.substring(0, 10);
    if (diff.inMinutes < 2) return 'maintenant';
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return iso.substring(0, 10);
  }

  Color _color() {
    switch (entry.actionType) {
      case 'animal_added':
      case 'crop_activity_added':
      case 'harvest_recorded':
        return AppColors.green;
      case 'animal_sold':
      case 'sale_added':
      case 'crop_sold':
      case 'product_sold':
        return AppColors.blue;
      case 'animal_died':
      case 'expense_added':
        return AppColors.red;
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
        return Icons.add_circle_outline;
      case 'animal_sold':
        return Icons.sell_outlined;
      case 'animal_died':
        return Icons.cancel_outlined;
      case 'expense_added':
        return Icons.remove_circle_outline;
      case 'crop_sold':
      case 'product_sold':
      case 'sale_added':
        return Icons.attach_money;
      case 'crop_activity_added':
        return Icons.agriculture;
      case 'harvest_recorded':
        return Icons.shopping_basket_outlined;
      case 'backup_completed':
        return Icons.cloud_done;
      case 'restore_completed':
        return Icons.restore;
      default:
        return Icons.info_outline;
    }
  }
}
