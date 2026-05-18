import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../models/reproduction_event.dart';
import '../../models/species.dart';
import '../../providers/animal_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/expense_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/species_provider.dart';
import '../../theme/app_theme.dart';
import 'dialogs/add_health_event_dialog.dart';
import 'dialogs/add_reproduction_event_dialog.dart';
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
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Modifier'),
                onPressed: () => context.push(
                    '/animals/species/${animal.speciesId}/${animal.id}'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.money_off),
                label: const Text('Dépense'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white),
                onPressed: () => context.push(
                  '/finances/expense/new',
                  extra: <String, String?>{
                    'scope': 'animal',
                    'animalId': animal.id,
                    'speciesId': animal.speciesId,
                  },
                ),
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
        _HealthSection(animal: animal),
        if (animal.gender == AnimalGender.female) ...[
          const SizedBox(height: 16),
          _ReproductionSection(animal: animal),
        ],
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

class _HealthSection extends ConsumerWidget {
  const _HealthSection({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Santé',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AddHealthEventDialog(animal: animal)),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        StreamBuilder(
          stream: ref
              .read(healthEventRepositoryProvider)
              .watchForAnimal(animal.userId, animal.id),
          builder: (ctx, snap) {
            final events = snap.data ?? const [];
            if (events.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Aucun événement de santé'),
                ),
              );
            }
            return Column(
              children: events
                  .map((e) => Card(
                        child: ListTile(
                          dense: true,
                          leading: Icon(_iconFor(e.eventType),
                              color: AppColors.green),
                          title: Text(e.description,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${_typeLabel(e.eventType)} · ${e.date}${e.vetName == null ? "" : " · ${e.vetName}"}${e.nextDueDate == null ? "" : "\nRappel: ${e.nextDueDate}"}'),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'vaccination':
        return Icons.vaccines;
      case 'illness':
        return Icons.sick;
      case 'recovery':
        return Icons.healing;
      default:
        return Icons.medical_services;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'treatment':
        return 'Traitement';
      case 'vaccination':
        return 'Vaccination';
      case 'illness':
        return 'Maladie';
      case 'recovery':
        return 'Guérison';
      default:
        return t;
    }
  }
}

class _ReproductionSection extends ConsumerWidget {
  const _ReproductionSection({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Reproduction',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () async {
                await showDialog(
                    context: context,
                    builder: (_) =>
                        AddReproductionEventDialog(mother: animal));
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Événement'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        StreamBuilder(
          stream: ref
              .read(reproductionEventRepositoryProvider)
              .watchForAnimal(animal.userId, animal.id),
          builder: (ctx, snap) {
            final events = snap.data ?? const [];
            if (events.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Aucun événement de reproduction'),
                ),
              );
            }
            // Group by pregnancyGroupId
            final groups = <String, List<ReproductionEvent>>{};
            for (final e in events) {
              final gid = e.pregnancyGroupId ?? e.id;
              groups.putIfAbsent(gid, () => []).add(e);
            }
            final sortedGroups = groups.entries.toList()
              ..sort((a, b) {
                final aDate = a.value
                    .map((e) => e.eventDate)
                    .reduce((x, y) => x.compareTo(y) > 0 ? x : y);
                final bDate = b.value
                    .map((e) => e.eventDate)
                    .reduce((x, y) => x.compareTo(y) > 0 ? x : y);
                return bDate.compareTo(aDate);
              });
            return Column(
              children: sortedGroups
                  .map((entry) => _PregnancyGroupCard(
                      mother: animal, groupId: entry.key, events: entry.value))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PregnancyGroupCard extends ConsumerWidget {
  const _PregnancyGroupCard({
    required this.mother,
    required this.groupId,
    required this.events,
  });

  final Animal mother;
  final String groupId;
  final List<ReproductionEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = [...events]
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));
    final mating = sorted
        .where((e) => e.eventType == ReproductionEventType.mating)
        .firstOrNull;
    final pregnancy = sorted
        .where((e) => e.eventType == ReproductionEventType.pregnancyConfirmed)
        .firstOrNull;
    final birth = sorted
        .where((e) => e.eventType == ReproductionEventType.birth)
        .firstOrNull;

    final animalsAsync = ref.watch(allAnimalsProvider);
    final offspring = animalsAsync.asData?.value
            .where((a) => a.motherId == mother.id)
            .toList() ??
        const [];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.pink, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Cycle de reproduction',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (mating != null)
              _step(Icons.male, 'Accouplement', mating.eventDate, Colors.blueGrey),
            if (pregnancy != null)
              _step(
                  Icons.pregnant_woman,
                  'Gestation confirmée${pregnancy.dueDate == null ? "" : " · prévue ${pregnancy.dueDate}"}',
                  pregnancy.eventDate,
                  Colors.orange),
            if (birth != null)
              _step(
                  Icons.child_friendly,
                  'Naissance${birth.offspringCount == null ? "" : " · ${birth.offspringCount} jeune(s)"}',
                  birth.eventDate,
                  AppColors.green),
            if (birth == null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  if (pregnancy == null)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pregnant_woman, size: 16),
                      label: const Text('Confirmer gestation'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AddReproductionEventDialog(
                          mother: mother,
                          pregnancyGroupId: groupId,
                          suggestedType:
                              ReproductionEventType.pregnancyConfirmed,
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.child_friendly, size: 16),
                    label: const Text('Enregistrer naissance'),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AddReproductionEventDialog(
                        mother: mother,
                        pregnancyGroupId: groupId,
                        suggestedType: ReproductionEventType.birth,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (birth != null && offspring.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Jeunes',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: offspring.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final o = offspring[i];
                    return InkWell(
                      onTap: () => context.push('/animals/animal/${o.id}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.green.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(o.farmId,
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold)),
                            Text(
                                o.gender == AnimalGender.male ? '♂ Mâle' : '♀ Femelle',
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (birth != null && offspring.isEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                    'Créer les jeunes (${birth.offspringCount ?? 1})'),
                onPressed: () => _createOffspring(
                    context, ref, birth.offspringCount ?? 1, mating?.partnerId),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _step(IconData icon, String label, String date, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(label)),
            Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );

  Future<void> _createOffspring(BuildContext context, WidgetRef ref,
      int count, String? fatherId) async {
    // Open the add animal screen with mother + father preset.
    // Simple approach: navigate to add animal screen once. If the user wants
    // more, they can repeat the action manually.
    context.push(
      '/animals/species/${mother.speciesId}/new',
      extra: <String, String?>{
        'motherId': mother.id,
        'fatherId': fatherId,
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
