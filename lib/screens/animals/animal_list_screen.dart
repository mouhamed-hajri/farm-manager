import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../models/species.dart';
import '../../providers/animal_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/species_provider.dart';
import '../../theme/app_theme.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: speciesAsync.when(
          data: (s) => Text(s?.nameFr ?? 'Animaux'),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Animaux'),
        ),
      ),
      body: animalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (all) {
          final query = _searchController.text.toLowerCase();
          final filtered = query.isEmpty
              ? all
              : all
                  .where((a) =>
                      a.farmId.toLowerCase().contains(query) ||
                      (a.nickname ?? '').toLowerCase().contains(query))
                  .toList();
          final active =
              filtered.where((a) => a.status == AnimalStatus.active).toList();
          final sold =
              filtered.where((a) => a.status == AnimalStatus.sold).toList();
          final dead =
              filtered.where((a) => a.status == AnimalStatus.dead).toList();

          final species = speciesAsync.asData?.value;

          // Stats
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
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _empty()
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          if (active.isNotEmpty) ...[
                            const _SectionLabel('Actifs'),
                            ...active.map((a) =>
                                _AnimalCard(animal: a, species: species)),
                          ],
                          if (sold.isNotEmpty)
                            ExpansionTile(
                              title:
                                  Text('Animaux vendus (${sold.length})'),
                              children: sold
                                  .map((a) =>
                                      _AnimalCard(animal: a, species: species))
                                  .toList(),
                            ),
                          if (dead.isNotEmpty)
                            ExpansionTile(
                              title: Text('Animaux morts (${dead.length})'),
                              children: dead
                                  .map((a) =>
                                      _AnimalCard(animal: a, species: species))
                                  .toList(),
                            ),
                          const SizedBox(height: 80),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.go('/animals/species/${widget.speciesId}/new'),
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('Actifs', '$active', AppColors.green),
          _stat('Vendus', '$sold', AppColors.blue),
          _stat('Morts', '$dead', AppColors.red),
          _stat('Dépenses', '${spent.toStringAsFixed(0)} TND', AppColors.red),
          _stat('Revenus', '${earned.toStringAsFixed(0)} TND', AppColors.green),
          _stat(
            profit >= 0 ? 'Bénéfice' : 'Perte',
            '${profit.abs().toStringAsFixed(0)} TND',
            profit >= 0 ? AppColors.green : AppColors.red,
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      );
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.animal, required this.species});

  final Animal animal;
  final Species? species;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    switch (animal.status) {
      case AnimalStatus.sold:
        statusColor = AppColors.blue;
        statusLabel = 'Vendu';
        break;
      case AnimalStatus.dead:
        statusColor = AppColors.red;
        statusLabel = 'Décédé';
        break;
      default:
        statusColor = AppColors.green;
        statusLabel = 'Actif';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _Avatar(animal: animal, species: species),
        title: Row(
          children: [
            Text(animal.farmId,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        subtitle: Text(
          [
            if (animal.nickname?.isNotEmpty ?? false) animal.nickname!,
            animal.gender == AnimalGender.male ? '♂' : '♀',
            if (animal.breed?.isNotEmpty ?? false) animal.breed!,
          ].join(' · '),
        ),
        onTap: () => context.go('/animals/animal/${animal.id}'),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.animal, required this.species});

  final Animal animal;
  final Species? species;

  @override
  Widget build(BuildContext context) {
    final hasLocal = animal.photoLocalPath != null &&
        File(animal.photoLocalPath!).existsSync();
    final hasCloud = animal.photoCloudUrl?.isNotEmpty ?? false;
    if (hasLocal) {
      return CircleAvatar(
          backgroundImage: FileImage(File(animal.photoLocalPath!)));
    }
    if (hasCloud) {
      return CircleAvatar(
          backgroundImage: NetworkImage(animal.photoCloudUrl!));
    }
    return CircleAvatar(
      backgroundColor: AppColors.green.withValues(alpha: 0.2),
      child: Text(species?.iconEmoji ?? '🐾',
          style: const TextStyle(fontSize: 22)),
    );
  }
}
