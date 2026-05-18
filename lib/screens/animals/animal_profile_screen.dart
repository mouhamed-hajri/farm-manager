import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../models/species.dart';
import '../../providers/animal_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/expense_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/species_provider.dart';
import '../../theme/app_theme.dart';
import 'dialogs/sell_animal_dialog.dart';
import 'dialogs/mark_animal_dead_dialog.dart';

class AnimalProfileScreen extends ConsumerWidget {
  const AnimalProfileScreen({super.key, required this.animalId});

  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animalAsync = ref.watch(animalByIdProvider(animalId));

    return Scaffold(
      appBar: AppBar(
        title: animalAsync.when(
          data: (a) => Text(a?.farmId ?? 'Animal'),
          loading: () => const Text('...'),
          error: (_, __) => const Text('Animal'),
        ),
      ),
      body: animalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (animal) {
          if (animal == null) {
            return const Center(child: Text('Animal introuvable'));
          }
          return _Body(animal: animal);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesAsync = ref.watch(speciesByIdProvider(animal.speciesId));
    final saleAsync = ref.watch(salesForAnimalProvider(animal.id));
    final expensesAsync = ref.watch(expensesForAnimalProvider(animal.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PhotoHeader(animal: animal, species: speciesAsync.asData?.value),
        const SizedBox(height: 16),
        Center(
          child: Column(
            children: [
              Text(animal.farmId,
                  style: const TextStyle(
                      fontSize: 24,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold)),
              if (animal.nickname?.isNotEmpty ?? false)
                Text(animal.nickname!,
                    style: const TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 8),
              _StatusChip(status: animal.status),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (animal.status == AnimalStatus.active) ...[
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Modifier'),
                onPressed: () => context.go(
                    '/animals/species/${animal.speciesId}/${animal.id}'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.sell),
                label: const Text('Vendre'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: Colors.white),
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) => SellAnimalDialog(animal: animal)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.dangerous),
                label: const Text('Décédé'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white),
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) => MarkAnimalDeadDialog(animal: animal)),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (animal.status == AnimalStatus.sold)
          saleAsync.when(
            data: (sale) => sale == null
                ? const SizedBox.shrink()
                : Card(
                    color: AppColors.blue.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Détails de la vente',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          _kv('Prix', '${sale.totalPrice.toStringAsFixed(0)} TND'),
                          _kv('Date', sale.saleDate),
                          if (sale.buyerName != null)
                            _kv('Acheteur', sale.buyerName!),
                          if (sale.buyerPhone != null)
                            _kv('Téléphone', sale.buyerPhone!),
                          if (sale.notes != null) _kv('Notes', sale.notes!),
                        ],
                      ),
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        if (animal.status == AnimalStatus.dead)
          Card(
            color: AppColors.red.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Décès',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  if (animal.deathDate != null)
                    _kv('Date', animal.deathDate!),
                  if (animal.deathCause != null)
                    _kv('Cause', animal.deathCause!),
                  if (animal.deathNotes != null)
                    _kv('Notes', animal.deathNotes!),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text('Détails',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _kv('Sexe',
                    animal.gender == AnimalGender.male ? 'Mâle' : 'Femelle'),
                if (animal.birthDate != null)
                  _kv('Né le', animal.birthDate!),
                if (animal.breed != null) _kv('Race', animal.breed!),
                if (animal.color != null) _kv('Couleur', animal.color!),
                if (animal.weight != null) _kv('Poids', '${animal.weight} kg'),
                _kv('Santé', _healthLabel(animal.healthStatus)),
                if (animal.purchaseDate != null)
                  _kv('Acheté le', animal.purchaseDate!),
                if (animal.purchasePrice != null)
                  _kv('Prix d\'achat',
                      '${animal.purchasePrice!.toStringAsFixed(0)} TND'),
                if (animal.sellerName != null)
                  _kv('Vendeur', animal.sellerName!),
                if (animal.notes != null) _kv('Notes', animal.notes!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Dépenses liées',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        expensesAsync.when(
          data: (list) {
            if (list.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Aucune dépense liée'),
                ),
              );
            }
            final total = list.fold<double>(0, (s, e) => s + e.amount);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('${list.length} dépenses · ${total.toStringAsFixed(0)} TND total',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(),
                    ...list.map((e) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('${e.amount.toStringAsFixed(0)} TND · ${e.category}'),
                          subtitle: Text(e.date),
                        )),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erreur: $e'),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete, color: AppColors.red),
          label: const Text('Supprimer',
              style: TextStyle(color: AppColors.red)),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Confirmer'),
                content: Text(
                    'Supprimer ${animal.farmId} définitivement ? Cette action est irréversible.'),
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
              await ref
                  .read(animalRepositoryProvider)
                  .deleteAnimal(animal.id);
              if (context.mounted) context.pop();
            }
          },
        ),
      ],
    );
  }

  String _healthLabel(String s) {
    switch (s) {
      case HealthStatus.sick:
        return 'Malade';
      case HealthStatus.pregnant:
        return 'Gestante';
      default:
        return 'En bonne santé';
    }
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 120,
                child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      );
}

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.animal, required this.species});

  final Animal animal;
  final Species? species;

  @override
  Widget build(BuildContext context) {
    final hasLocal = animal.photoLocalPath != null &&
        File(animal.photoLocalPath!).existsSync();
    final hasCloud = animal.photoCloudUrl?.isNotEmpty ?? false;

    final image = hasLocal
        ? Image.file(File(animal.photoLocalPath!), fit: BoxFit.cover)
        : hasCloud
            ? Image.network(animal.photoCloudUrl!, fit: BoxFit.cover)
            : null;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: image != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(width: double.infinity, child: image),
            )
          : Center(
              child: Text(species?.iconEmoji ?? '🐾',
                  style: const TextStyle(fontSize: 96))),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case AnimalStatus.sold:
        color = AppColors.blue;
        label = 'Vendu';
        break;
      case AnimalStatus.dead:
        color = AppColors.red;
        label = 'Décédé';
        break;
      default:
        color = AppColors.green;
        label = 'Actif';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(label,
          style:
              TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
