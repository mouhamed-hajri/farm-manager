import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../providers/animal_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/species_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animal_grid_card.dart';

class AnimalListScreen extends ConsumerStatefulWidget {
  const AnimalListScreen({super.key, required this.speciesId});

  final String speciesId;

  @override
  ConsumerState<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends ConsumerState<AnimalListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speciesAsync = ref.watch(speciesByIdProvider(widget.speciesId));
    final animalsAsync = ref.watch(animalsBySpeciesProvider(widget.speciesId));
    final allExpensesAsync = ref.watch(expenseListProvider);
    final allSalesAsync = ref.watch(salesListProvider);
    final species = speciesAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(species?.nameFr ?? 'Animaux'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Arbre généalogique',
            onPressed: () =>
                context.push('/animals/tree/${widget.speciesId}'),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Classement femelles',
            onPressed: () => context.push('/animals/ranking'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Modifier l\'espèce',
            onPressed: () =>
                context.push('/animals/species/edit/${widget.speciesId}'),
          ),
        ],
      ),
      body: animalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (all) {
          final expenses = allExpensesAsync.asData?.value ?? const [];
          final sales = allSalesAsync.asData?.value ?? const [];
          final animalIdsInSpecies = all.map((a) => a.id).toSet();
          final spent = expenses
              .where((e) =>
                  e.linkedSpeciesId == widget.speciesId ||
                  (e.linkedAnimalId != null &&
                      animalIdsInSpecies.contains(e.linkedAnimalId)))
              .fold<double>(0, (s, e) => s + e.amount);
          final earned = sales
              .where((s) =>
                  s.linkedAnimalId != null &&
                  animalIdsInSpecies.contains(s.linkedAnimalId))
              .fold<double>(0, (s, e) => s + e.totalPrice);
          final profit = earned - spent;

          return Column(
            children: [
              _StatsBar(
                active: all.where((a) => a.status == AnimalStatus.active).length,
                sold: all.where((a) => a.status == AnimalStatus.sold).length,
                dead: all.where((a) => a.status == AnimalStatus.dead).length,
                spent: spent,
                earned: earned,
                profit: profit,
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher par ID ou nom',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, _) {
                    final query = value.text.toLowerCase();
                    final filtered = query.isEmpty
                        ? all
                        : all
                            .where((a) =>
                                a.farmId.toLowerCase().contains(query) ||
                                (a.nickname ?? '').toLowerCase().contains(query))
                            .toList();
                    final active = filtered
                        .where((a) => a.status == AnimalStatus.active)
                        .toList();
                    final sold = filtered
                        .where((a) => a.status == AnimalStatus.sold)
                        .toList();
                    final dead = filtered
                        .where((a) => a.status == AnimalStatus.dead)
                        .toList();

                    if (filtered.isEmpty) return _empty();

                    const delegate = SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    );

                    return RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(animalsBySpeciesProvider(widget.speciesId)),
                      child: CustomScrollView(
                        slivers: [
                          if (active.isNotEmpty) ...[
                            const SliverToBoxAdapter(
                                child: _SectionLabel('Actifs')),
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (ctx, i) => AnimalGridCard(
                                      animal: active[i], species: species),
                                  childCount: active.length,
                                ),
                                gridDelegate: delegate,
                              ),
                            ),
                          ],
                          if (sold.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _CollapsibleSection(
                                label: 'Animaux vendus (${sold.length})',
                                animals: sold,
                                species: species,
                                delegate: delegate,
                              ),
                            ),
                          ],
                          if (dead.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _CollapsibleSection(
                                label: 'Animaux morts (${dead.length})',
                                animals: dead,
                                species: species,
                                delegate: delegate,
                              ),
                            ),
                          ],
                          const SliverToBoxAdapter(child: SizedBox(height: 80)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/animals/species/${widget.speciesId}/new'),
        icon: const Icon(Icons.add),
        label: const Text('Animal'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Aucun animal',
                style: TextStyle(fontSize: 18, color: Colors.grey[700])),
            const SizedBox(height: 8),
            const Text(
                'Appuyez sur "+ Animal" pour ajouter votre premier animal',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
}

// Sold/dead sections stay collapsed by default — only expand on demand.
// Using a plain StatefulWidget avoids rebuilding the entire SliverList.
class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.label,
    required this.animals,
    required this.species,
    required this.delegate,
  });

  final String label;
  final List<Animal> animals;
  final dynamic species;
  final SliverGridDelegateWithFixedCrossAxisCount delegate;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: widget.delegate,
              itemCount: widget.animals.length,
              itemBuilder: (ctx, i) => AnimalGridCard(
                  animal: widget.animals[i], species: widget.species),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8, top: 8, bottom: 6),
        child: Text(text,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      );
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.active,
    required this.sold,
    required this.dead,
    required this.spent,
    required this.earned,
    required this.profit,
  });

  final int active;
  final int sold;
  final int dead;
  final double spent;
  final double earned;
  final double profit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _stat('Actifs', '$active', AppColors.green)),
          Expanded(child: _stat('Vendus', '$sold', AppColors.blue)),
          Expanded(child: _stat('Morts', '$dead', AppColors.red)),
          Expanded(child: _stat('Dépenses', '${spent.toStringAsFixed(0)} TND', AppColors.red)),
          Expanded(child: _stat('Revenus', '${earned.toStringAsFixed(0)} TND', AppColors.green)),
          Expanded(child: _stat(
            profit >= 0 ? 'Bénéfice' : 'Perte',
            '${profit.abs().toStringAsFixed(0)} TND',
            profit >= 0 ? AppColors.green : AppColors.red,
          )),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
        ],
      );
}
