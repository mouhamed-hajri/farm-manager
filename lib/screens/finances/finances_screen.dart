import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../models/crop.dart';
import '../../models/expense.dart';
import '../../models/sale.dart';
import '../../models/species.dart';
import '../../providers/animal_provider.dart';
import '../../providers/crop_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/species_provider.dart';
import '../../theme/app_theme.dart';
import 'tabs/reports_tab.dart';

class FinancesScreen extends ConsumerStatefulWidget {
  const FinancesScreen({super.key});

  @override
  ConsumerState<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends ConsumerState<FinancesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
        title: const Text('Finances'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Dépenses'),
            Tab(text: 'Ventes'),
            Tab(text: 'Rapports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_ExpensesTab(), _SalesTab(), ReportsTab()],
      ),
    );
  }
}

// ─── Shared lookup maps ───────────────────────────────────────────────────────

class _Ctx {
  const _Ctx({
    required this.animalsById,
    required this.speciesById,
    required this.cropsById,
  });
  final Map<String, Animal> animalsById;
  final Map<String, Species> speciesById;
  final Map<String, Crop> cropsById;
}

// ─── Expenses tab ─────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expenseListProvider);
    final animals = ref.watch(allAnimalsProvider).asData?.value ?? const [];
    final species = ref.watch(speciesListProvider).asData?.value ?? const [];
    final crops = ref.watch(cropsListProvider).asData?.value ?? const [];

    final ctx = _Ctx(
      animalsById: {for (final a in animals) a.id: a},
      speciesById: {for (final s in species) s.id: s},
      cropsById: {for (final c in crops) c.id: c},
    );

    return Scaffold(
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) => list.isEmpty
            ? _empty(Icons.money_off, 'Aucune dépense')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: list.length,
                itemBuilder: (_, i) => _ExpenseBanner(
                  expense: list[i],
                  ctx: ctx,
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/finances/expense/new'),
        icon: const Icon(Icons.add),
        label: const Text('Dépense'),
        backgroundColor: AppColors.red,
      ),
    );
  }
}

class _ExpenseBanner extends StatelessWidget {
  const _ExpenseBanner({required this.expense, required this.ctx});
  final Expense expense;
  final _Ctx ctx;

  @override
  Widget build(BuildContext context) {
    final animal = expense.linkedAnimalId != null
        ? ctx.animalsById[expense.linkedAnimalId]
        : null;
    final species = animal != null
        ? ctx.speciesById[animal.speciesId]
        : expense.linkedSpeciesId != null
            ? ctx.speciesById[expense.linkedSpeciesId]
            : null;
    final crop = expense.linkedCropId != null
        ? ctx.cropsById[expense.linkedCropId]
        : null;

    final categoryLabel = _categoryLabel(expense.category);
    final scopeLabel = _scopeLabel(expense.scope);
    final subtitle = expense.description != null && expense.description!.isNotEmpty
        ? expense.description!
        : '$scopeLabel · $categoryLabel';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left image strip — constrained so it never drives infinite height
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80, maxHeight: 120),
              child: SizedBox(
                width: 88,
                child: _FinanceImage(
                  animal: animal,
                  species: species,
                  crop: crop,
                  scope: expense.scope,
                  accentColor: AppColors.red,
                ),
              ),
            ),
            // Right content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          '−${expense.amount.toStringAsFixed(0)} TND',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: AppColors.red),
                        ),
                        const Spacer(),
                        Text(expense.date,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    if (animal != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.pets,
                              size: 12, color: AppColors.green),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              animal.displayName,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _scopeLabel(String s) {
    switch (s) {
      case ExpenseScope.animal:
        return 'Animal';
      case ExpenseScope.crop:
        return 'Culture';
      case ExpenseScope.field:
        return 'Champ';
      default:
        return 'Général';
    }
  }

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
        return 'Main d\'œuvre';
      case 'breeder_valuation':
        return 'Transfert interne';
      default:
        return c;
    }
  }
}

// ─── Sales tab ────────────────────────────────────────────────────────────────

class _SalesTab extends ConsumerWidget {
  const _SalesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesListProvider);
    final animals = ref.watch(allAnimalsProvider).asData?.value ?? const [];
    final species = ref.watch(speciesListProvider).asData?.value ?? const [];
    final crops = ref.watch(cropsListProvider).asData?.value ?? const [];

    final ctx = _Ctx(
      animalsById: {for (final a in animals) a.id: a},
      speciesById: {for (final s in species) s.id: s},
      cropsById: {for (final c in crops) c.id: c},
    );

    return Scaffold(
      body: salesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (list) => list.isEmpty
            ? _empty(Icons.sell, 'Aucune vente')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                itemCount: list.length,
                itemBuilder: (_, i) => _SaleBanner(
                  sale: list[i],
                  ctx: ctx,
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/finances/sale/new'),
        icon: const Icon(Icons.add),
        label: const Text('Vente'),
        backgroundColor: AppColors.green,
      ),
    );
  }
}

class _SaleBanner extends StatelessWidget {
  const _SaleBanner({required this.sale, required this.ctx});
  final Sale sale;
  final _Ctx ctx;

  @override
  Widget build(BuildContext context) {
    final animal = sale.linkedAnimalId != null
        ? ctx.animalsById[sale.linkedAnimalId]
        : null;
    final species =
        animal != null ? ctx.speciesById[animal.speciesId] : null;
    final crop =
        sale.linkedCropId != null ? ctx.cropsById[sale.linkedCropId] : null;

    final subtitle = _subtitle(sale, animal, crop);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left image strip
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80, maxHeight: 120),
              child: SizedBox(
                width: 88,
                child: _FinanceImage(
                  animal: animal,
                  species: species,
                  crop: crop,
                  scope: sale.scope,
                  accentColor: AppColors.green,
                ),
              ),
            ),
            // Right content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          '+${sale.totalPrice.toStringAsFixed(0)} TND',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: AppColors.green),
                        ),
                        const Spacer(),
                        Text(sale.saleDate,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[700]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    if (sale.buyerName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sale.buyerName!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Sale sale, Animal? animal, Crop? crop) {
    if (sale.scope == SaleScope.animal) {
      final name = animal?.displayName ?? 'Animal';
      final qty = sale.quantity > 1
          ? ' · ${sale.quantity.toStringAsFixed(0)} têtes'
          : '';
      return '$name$qty';
    }
    if (sale.scope == SaleScope.crop) {
      final name = crop?.nameFr ?? 'Culture';
      final qty =
          '${sale.quantity.toStringAsFixed(0)} ${_unitLabel(sale.unit)}';
      return '$name · $qty';
    }
    if (sale.scope == SaleScope.product) {
      return sale.productName ?? 'Produit';
    }
    return 'Vente · ${_unitLabel(sale.unit)}';
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

// ─── Shared image strip ───────────────────────────────────────────────────────

class _FinanceImage extends StatelessWidget {
  const _FinanceImage({
    required this.animal,
    required this.species,
    required this.crop,
    required this.scope,
    required this.accentColor,
  });

  final Animal? animal;
  final Species? species;
  final Crop? crop;
  final String scope;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    // Priority 1: animal photo (local or cloud)
    if (animal != null) {
      final hasLocal = animal!.photoLocalPath != null &&
          File(animal!.photoLocalPath!).existsSync();
      if (hasLocal) {
        return Image.file(
          File(animal!.photoLocalPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emoji(_animalEmoji()),
        );
      }
      if (animal!.photoCloudUrl?.isNotEmpty ?? false) {
        return Image.network(
          animal!.photoCloudUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emoji(_animalEmoji()),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _emoji(_animalEmoji()),
        );
      }
    }

    // Priority 2: species emoji (for animal scope without photo)
    if (scope == ExpenseScope.animal || scope == SaleScope.animal) {
      return _emoji(species?.iconEmoji ?? '🐾',
          bg: accentColor.withValues(alpha: 0.12));
    }

    // Priority 3: crop emoji
    if (crop != null) {
      return _emoji(crop!.iconEmoji,
          bg: Colors.green.withValues(alpha: 0.12));
    }
    if (scope == ExpenseScope.crop || scope == SaleScope.crop) {
      return _emoji('🌱', bg: Colors.green.withValues(alpha: 0.12));
    }

    // Priority 4: product
    if (scope == SaleScope.product) {
      return _emoji('📦', bg: Colors.brown.withValues(alpha: 0.10));
    }

    // Priority 5: field
    if (scope == ExpenseScope.field) {
      return _emoji('🌾', bg: Colors.orange.withValues(alpha: 0.10));
    }

    // Fallback: money icon
    return _icon(
      accentColor == AppColors.red ? Icons.money_off : Icons.attach_money,
      accentColor,
    );
  }

  String _animalEmoji() => species?.iconEmoji ?? '🐾';

  Widget _emoji(String emoji, {Color? bg}) => ColoredBox(
        color: bg ?? accentColor.withValues(alpha: 0.10),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 40)),
        ),
      );

  Widget _icon(IconData icon, Color color) => ColoredBox(
        color: color.withValues(alpha: 0.10),
        child: Center(
          child: Icon(icon, size: 36, color: color),
        ),
      );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _empty(IconData icon, String text) => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(fontSize: 18, color: Colors.grey[700])),
        ],
      ),
    );
