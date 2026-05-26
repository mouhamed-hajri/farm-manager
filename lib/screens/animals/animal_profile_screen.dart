import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../models/female_rating.dart';
import '../../models/animal_ledger.dart';
import '../../models/reproduction_event.dart';
import '../../models/species.dart';
import '../../models/weight_measurement.dart';
import '../../providers/animal_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/sale_provider.dart';
import '../../providers/species_provider.dart';
import '../../theme/app_theme.dart';
import 'dialogs/add_health_event_dialog.dart';
import 'dialogs/add_reproduction_event_dialog.dart';
import 'dialogs/add_weight_measurement_dialog.dart';
import 'dialogs/sell_animal_dialog.dart';
import 'dialogs/mark_animal_dead_dialog.dart';

final _weightsForAnimalProvider = StreamProvider.family
    .autoDispose<List<WeightMeasurement>, ({String userId, String animalId})>(
        (ref, key) {
  return ref
      .read(weightMeasurementRepositoryProvider)
      .watchForAnimal(key.userId, key.animalId);
});

class AnimalProfileScreen extends ConsumerWidget {
  const AnimalProfileScreen({super.key, required this.animalId});

  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animalAsync = ref.watch(animalByIdProvider(animalId));

    return animalAsync.when(
      loading: () => Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          appBar: AppBar(), body: Center(child: Text('Erreur : $e'))),
      data: (animal) {
        if (animal == null) {
          return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Animal introuvable')));
        }
        return _AnimalProfileLoaded(animal: animal);
      },
    );
  }
}

class _AnimalProfileLoaded extends StatelessWidget {
  const _AnimalProfileLoaded({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final isFemale = animal.gender == AnimalGender.female;
    return DefaultTabController(
      length: isFemale ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(animal.farmId),
          bottom: TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.info_outline), text: 'Infos'),
              const Tab(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  text: 'Finances'),
              if (isFemale)
                const Tab(
                    icon: Icon(Icons.family_restroom), text: 'Naissances'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _InfoTab(animal: animal),
            _FinanceTab(animal: animal),
            if (isFemale) _ReproductionTab(animal: animal),
          ],
        ),
      ),
    );
  }
}

// ─── Info Tab ─────────────────────────────────────────────────────────────────

class _InfoTab extends ConsumerWidget {
  const _InfoTab({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speciesAsync = ref.watch(speciesByIdProvider(animal.speciesId));
    final saleAsync = ref.watch(salesForAnimalProvider(animal.id));

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusChip(status: animal.status),
                  const SizedBox(width: 8),
                  if (animal.isCountedUnderMother)
                    _FinanceBadge(
                        label: 'Finance chez mère', color: Colors.orange),
                  if (animal.effectiveFinanceMode ==
                      AnimalFinanceMode.independentFemaleCenter)
                    _FinanceBadge(
                        label: 'Centre indépendant', color: AppColors.green),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Link to mother for animals counted under her
        if (animal.isCountedUnderMother && animal.motherId != null) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.female, size: 18),
            label: const Text('Ouvrir la fiche de la mère'),
            onPressed: () => context.push('/animals/animal/${animal.motherId}'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
          ),
          const SizedBox(height: 12),
        ],
        if (animal.status == AnimalStatus.active) ...[
          // Finance toggle for female offspring
          if (animal.gender == AnimalGender.female && animal.motherId != null)
            _FemaleFinanceToggle(animal: animal),
          // Weaning button for any offspring not yet weaned
          if (animal.motherId != null && animal.weaningDate == null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.child_care, size: 18),
                label: const Text('Enregistrer le sevrage'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null && context.mounted) {
                    await ref.read(animalRepositoryProvider).recordWeaning(
                          animal,
                          picked.toIso8601String().substring(0, 10),
                        );
                  }
                },
              ),
            ),
          ],
          if (animal.motherId != null && animal.weaningDate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.child_care, size: 16, color: AppColors.green),
                  const SizedBox(width: 6),
                  Text('Sevré le ${animal.weaningDate}',
                      style: const TextStyle(
                          color: AppColors.green, fontSize: 13)),
                ],
              ),
            ),
          const SizedBox(height: 8),
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
                          _kv('Prix',
                              '${sale.totalPrice.toStringAsFixed(0)} TND'),
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
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (animal.deathDate != null) _kv('Date', animal.deathDate!),
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
                    animal.gender == AnimalGender.male ? 'Mâle ♂' : 'Femelle ♀'),
                if (animal.ageLabel != null) _kv('Âge', animal.ageLabel!),
                if (animal.birthDate != null) _kv('Né le', animal.birthDate!),
                if (animal.breed != null) _kv('Race', animal.breed!),
                if (animal.color != null) _kv('Couleur', animal.color!),
                if (animal.weight != null)
                  _kv('Poids', '${animal.weight} kg'),
                _kv('Santé', _healthLabel(animal.healthStatus)),
                if (animal.purchaseDate != null)
                  _kv('Acheté le', animal.purchaseDate!),
                if (animal.purchasePrice != null)
                  _kv('Prix d\'achat',
                      '${animal.purchasePrice!.toStringAsFixed(0)} TND'),
                if (animal.sellerName != null)
                  _kv('Vendeur', animal.sellerName!),
                if (animal.motherId != null)
                  _kvWidget(
                    'Mère',
                    GestureDetector(
                      onTap: () =>
                          context.push('/animals/animal/${animal.motherId}'),
                      child: Text(animal.motherId!,
                          style: const TextStyle(
                              color: AppColors.green,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                if (animal.fatherId != null)
                  _kvWidget(
                    'Père',
                    GestureDetector(
                      onTap: () =>
                          context.push('/animals/animal/${animal.fatherId}'),
                      child: Text(animal.fatherId!,
                          style: const TextStyle(
                              color: AppColors.green,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                if (animal.notes != null) _kv('Notes', animal.notes!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _HealthSection(animal: animal),
        const SizedBox(height: 16),
        _CroissanceSection(animal: animal),
        if (animal.gender == AnimalGender.female) ...[
          const SizedBox(height: 16),
          _NotationSection(animal: animal),
        ],
        if (animal.gender == AnimalGender.female) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un petit'),
              onPressed: () => context.push(
                '/animals/species/${animal.speciesId}/new',
                extra: {'motherId': animal.id},
              ),
            ),
          ),
        ],
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
                    'Supprimer ${animal.farmId} définitivement ? Toutes les dépenses et ventes liées seront supprimées.'),
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
                width: 110,
                child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(
                child: Text(v,
                    style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      );

  Widget _kvWidget(String k, Widget v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(k, style: const TextStyle(color: Colors.grey))),
            Expanded(child: v),
          ],
        ),
      );
}

// ─── Female Finance Toggle ────────────────────────────────────────────────────

class _FemaleFinanceToggle extends ConsumerWidget {
  const _FemaleFinanceToggle({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIndependent =
        animal.effectiveFinanceMode == AnimalFinanceMode.independentFemaleCenter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mode financier',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _ToggleBtn(
                label: 'Sous la mère',
                icon: Icons.family_restroom,
                selected: !isIndependent,
                color: Colors.orange,
                onTap: isIndependent
                    ? () => _revert(context, ref)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ToggleBtn(
                label: 'Indépendante',
                icon: Icons.star_outline,
                selected: isIndependent,
                color: AppColors.green,
                onTap: isIndependent
                    ? null
                    : () => _makeIndependent(context, ref),
              ),
            ),
          ],
        ),
        if (isIndependent && animal.valuationAmount != null) ...[
          const SizedBox(height: 4),
          Text(
            'Valeur estimée : ${animal.valuationAmount!.toStringAsFixed(0)} TND (créditée à la mère)',
            style: const TextStyle(fontSize: 12, color: AppColors.green),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _makeIndependent(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valeur estimée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Entrez la valeur estimée de cette femelle.\nCe montant sera crédité à la mère.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant (TND)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (amount != null && context.mounted) {
      await ref.read(animalRepositoryProvider).makeIndependent(animal, amount);
    }
  }

  Future<void> _revert(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remettre sous la mère ?'),
        content: const Text(
            'La valeur estimée sera supprimée et le crédit retiré de la fiche de la mère.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmer')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(animalRepositoryProvider).makeCountedUnderMother(animal);
    }
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
              color: selected ? color : Colors.grey.withValues(alpha: 0.4),
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20, color: selected ? color : Colors.grey),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ─── Finance Tab ──────────────────────────────────────────────────────────────

class _FinanceTab extends ConsumerWidget {
  const _FinanceTab({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(animalLedgerProvider(animal.id));
    return ledgerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (ledger) => ledger == null
          ? const SizedBox.shrink()
          : _LedgerView(ledger: ledger, animal: animal),
    );
  }
}


class _LedgerView extends StatelessWidget {
  const _LedgerView({required this.ledger, required this.animal});
  final AnimalLedger ledger;
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final totalExp = ledger.totalExpenses;
    final totalInc = ledger.totalIncome;
    final net = ledger.netResult;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Mother-link banner for males counted under mother
        if (animal.isCountedUnderMother) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ce bilan est aussi inclus dans la fiche de la mère',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (animal.motherId != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.female, size: 16),
                    label: const Text('Ouvrir la fiche de la mère'),
                    onPressed: () =>
                        context.push('/animals/animal/${animal.motherId}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Summary card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _summaryRow('Dépenses totales',
                    '−${totalExp.toStringAsFixed(0)} TND', AppColors.red),
                _summaryRow('Revenus totaux',
                    '+${totalInc.toStringAsFixed(0)} TND', AppColors.green),
                const Divider(),
                _summaryRow(
                  net >= 0 ? 'Bénéfice' : 'Perte nette',
                  '${net >= 0 ? "+" : ""}${net.toStringAsFixed(0)} TND',
                  net >= 0 ? AppColors.green : AppColors.red,
                  bold: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Owner own expenses
        if (ledger.ownerExpenses.isNotEmpty) ...[
          const Text('Mes dépenses directes',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...ledger.ownerExpenses.map((e) => _expenseTile(e)),
          const SizedBox(height: 12),
        ],
        // Owner sales
        if (ledger.ownerSales.isNotEmpty) ...[
          const Text('Mes ventes',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...ledger.ownerSales.map((s) => _saleTile(s)),
          const SizedBox(height: 12),
        ],
        // Male offspring
        if (ledger.maleOffspring.isNotEmpty) ...[
          const Text('Enfants mâles (comptés ici)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...ledger.maleOffspring.map((o) => _offspringCard(context, o)),
          const SizedBox(height: 12),
        ],
        // Female offspring counted under this animal
        if (ledger.femaleOffspring
            .where((f) => f.isCountedUnderMother)
            .isNotEmpty) ...[
          const Text('Femelles (sous la mère)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...ledger.femaleOffspring
              .where((f) => f.isCountedUnderMother)
              .map((f) => Card(
                    child: ListTile(
                      leading: const Text('♀',
                          style:
                              TextStyle(fontSize: 22, color: Colors.orange)),
                      title: Text(f.farmId,
                          style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: const Text('Comptée ici',
                          style:
                              TextStyle(fontSize: 12, color: Colors.orange)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => context.push('/animals/animal/${f.id}'),
                    ),
                  )),
          const SizedBox(height: 12),
        ],
        // Daughter valuations credited to this ledger
        if (ledger.daughterValuations.isNotEmpty) ...[
          const Text('Valeurs femelles indépendantes',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...ledger.femaleOffspring
              .where((f) =>
                  ledger.daughterValuations.containsKey(f.id))
              .map((f) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.add_circle_outline,
                        color: AppColors.green, size: 18),
                    title: Text(
                        '+${ledger.daughterValuations[f.id]!.toStringAsFixed(0)} TND · ${f.farmId}',
                        style: const TextStyle(fontFamily: 'monospace')),
                    subtitle: const Text('Valeur estimée (indépendante)',
                        style: TextStyle(fontSize: 11)),
                  )),
          const SizedBox(height: 12),
        ],
        // Female offspring independent (finance center of their own)
        if (ledger.femaleOffspring
            .where((f) =>
                f.effectiveFinanceMode ==
                AnimalFinanceMode.independentFemaleCenter)
            .isNotEmpty) ...[
          const Text('Femelles indépendantes',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...ledger.femaleOffspring
              .where((f) =>
                  f.effectiveFinanceMode ==
                  AnimalFinanceMode.independentFemaleCenter)
              .map((f) => Card(
                    child: ListTile(
                      leading: const Text('♀',
                          style: TextStyle(
                              fontSize: 22, color: AppColors.green)),
                      title: Text(f.farmId,
                          style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: const Text('Centre financier indépendant',
                          style:
                              TextStyle(fontSize: 12, color: Colors.teal)),
                      trailing:
                          const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () =>
                          context.push('/animals/animal/${f.id}'),
                    ),
                  )),
        ],
      ],
    );
  }

  Widget _offspringCard(BuildContext context, Animal o) {
    final exps = ledger.expensesFor(o.id);
    final sals = ledger.salesFor(o.id);
    final expTotal = exps.fold<double>(0, (s, e) => s + e.amount);
    final salTotal = sals.fold<double>(0, (s, e) => s + e.totalPrice);
    final net = salTotal - expTotal;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: const Text('♂',
            style: TextStyle(fontSize: 22, color: Colors.blueGrey)),
        title: GestureDetector(
          onTap: () => context.push('/animals/animal/${o.id}'),
          child: Text(o.farmId,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  color: AppColors.green,
                  fontWeight: FontWeight.bold)),
        ),
        subtitle: Text([
          if (o.status == AnimalStatus.sold && salTotal > 0)
            'Vendu : +${salTotal.toStringAsFixed(0)} TND',
          if (expTotal > 0) 'Dépenses : ${expTotal.toStringAsFixed(0)} TND',
          if (o.status == AnimalStatus.active) 'Actif',
        ].join(' · '), overflow: TextOverflow.ellipsis, maxLines: 2),
        trailing: net != 0
            ? Text(
                '${net >= 0 ? "+" : ""}${net.toStringAsFixed(0)} TND',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: net >= 0 ? AppColors.green : AppColors.red),
              )
            : null,
      ),
    );
  }

  Widget _expenseTile(expense) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.remove_circle_outline,
            color: AppColors.red, size: 18),
        title: Text('${expense.amount.toStringAsFixed(0)} TND · ${expense.category}'),
        subtitle: Text(expense.date),
      );

  Widget _saleTile(sale) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.add_circle_outline,
            color: AppColors.green, size: 18),
        title: Text('+${sale.totalPrice.toStringAsFixed(0)} TND'),
        subtitle: Text(sale.saleDate),
      );

  Widget _summaryRow(String label, String value, Color color,
      {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
          ],
        ),
      );
}

// ─── Reproduction Tab ─────────────────────────────────────────────────────────

class _ReproductionTab extends ConsumerWidget {
  const _ReproductionTab({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Arbre de reproduction',
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
        ),
        Expanded(
          child: StreamBuilder(
            stream: ref
                .read(reproductionEventRepositoryProvider)
                .watchForAnimal(animal.userId, animal.id),
            builder: (ctx, snap) {
              final events = snap.data ?? const [];
              if (events.isEmpty) {
                return const Center(
                  child: Text('Aucun événement de reproduction',
                      style: TextStyle(color: Colors.grey)),
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
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: sortedGroups.length,
                itemBuilder: (_, i) => _BirthGroupCard(
                  mother: animal,
                  groupId: sortedGroups[i].key,
                  events: sortedGroups[i].value,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MatingAttempt {
  _MatingAttempt({required this.mating});
  final ReproductionEvent mating;
  ReproductionEvent? failed; // mating_failed event, if any
}

class _BirthGroupCard extends ConsumerWidget {
  const _BirthGroupCard({
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

    // Build mating attempts in order, pairing each mating with its outcome.
    final attempts = <_MatingAttempt>[];
    ReproductionEvent? pregnancy;
    ReproductionEvent? pregnancyLoss;
    ReproductionEvent? birth;
    ReproductionEvent? canceled;

    for (final e in sorted) {
      if (e.eventType == ReproductionEventType.mating) {
        attempts.add(_MatingAttempt(mating: e));
      } else if (e.eventType == ReproductionEventType.matingFailed &&
          attempts.isNotEmpty &&
          attempts.last.failed == null) {
        attempts.last.failed = e;
      } else if (e.eventType == ReproductionEventType.pregnancyConfirmed) {
        pregnancy = e;
      } else if (e.eventType == ReproductionEventType.pregnancyLoss) {
        pregnancyLoss = e;
      } else if (e.eventType == ReproductionEventType.birth) {
        birth = e;
      } else if (e.eventType == ReproductionEventType.cycleCanceled) {
        canceled = e;
      }
    }

    final isClosed = birth != null || pregnancyLoss != null || canceled != null;
    final isPregnant = pregnancy != null && !isClosed;
    final lastAttemptPending =
        attempts.isNotEmpty && attempts.last.failed == null && !isPregnant && !isClosed;
    final lastAttemptFailed =
        attempts.isNotEmpty && attempts.last.failed != null && !isPregnant && !isClosed;

    // Father: birth event first, then last mating that had a partnerId.
    final fatherId = birth?.partnerId ??
        attempts.reversed
            .map((a) => a.mating.partnerId)
            .firstWhere((id) => id != null, orElse: () => null);

    final allAnimals = ref.watch(allAnimalsProvider).asData?.value ?? const [];
    final fatherAnimal =
        fatherId != null ? allAnimals.where((a) => a.id == fatherId).firstOrNull : null;
    final offspring = birth != null
        ? allAnimals.where((a) => a.birthEventId == birth!.id).toList()
        : <Animal>[];

    // Card header
    final (headerIcon, headerLabel, headerColor) = switch (true) {
      _ when birth != null => (Icons.child_friendly, 'Naissance — ${birth.eventDate}', AppColors.green),
      _ when pregnancyLoss != null => (Icons.heart_broken, 'Perte de gestation — ${pregnancyLoss.eventDate}', AppColors.red),
      _ when canceled != null => (Icons.cancel_outlined, 'Cycle annulé — ${canceled.eventDate}', Colors.grey),
      _ when isPregnant => (Icons.pregnant_woman, 'Gestation en cours', Colors.orange),
      _ => (Icons.favorite_border, 'Cycle en cours', Colors.blueGrey),
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(headerIcon, color: headerColor, size: 18),
                const SizedBox(width: 6),
                Text(headerLabel,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: headerColor)),
              ],
            ),
            const SizedBox(height: 8),

            // Mating attempts timeline
            ...attempts.asMap().entries.map((entry) {
              final i = entry.key;
              final a = entry.value;
              final label = attempts.length > 1
                  ? 'Accouplement ${i + 1}'
                  : 'Accouplement';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _step(Icons.male, label, a.mating.eventDate, Colors.blueGrey),
                  if (a.failed != null)
                    _step(Icons.close, 'Échec', a.failed!.eventDate, AppColors.red),
                ],
              );
            }),

            // Pregnancy & birth/loss
            if (pregnancy != null)
              _step(
                Icons.pregnant_woman,
                'Gestation confirmée${pregnancy.dueDate == null ? "" : " · prévue ${pregnancy.dueDate}"}',
                pregnancy.eventDate,
                Colors.orange,
              ),
            if (birth != null)
              _step(
                Icons.child_friendly,
                'Naissance${birth.offspringCount == null ? "" : " · ${birth.offspringCount} jeune(s)"}',
                birth.eventDate,
                AppColors.green,
              ),
            if (pregnancyLoss != null)
              _step(Icons.heart_broken, 'Perte de gestation',
                  pregnancyLoss.eventDate, AppColors.red),
            if (canceled != null)
              _step(Icons.cancel_outlined,
                  'Annulé${canceled.notes == null ? "" : " — ${canceled.notes}"}',
                  canceled.eventDate, Colors.grey),

            // Father
            if (fatherAnimal != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => context.push('/animals/animal/${fatherAnimal.id}'),
                child: Row(
                  children: [
                    const Icon(Icons.male, size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    const Text('Père : ',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Flexible(
                      child: Text(
                        fatherAnimal.farmId +
                            ((fatherAnimal.nickname?.isNotEmpty ?? false)
                                ? ' (${fatherAnimal.nickname})'
                                : ''),
                        style: const TextStyle(
                            color: AppColors.green,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (fatherId == null && birth != null) ...[
              const SizedBox(height: 4),
              const Text('Père inconnu',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],

            // Offspring chips
            if (birth != null) ...[
              if (offspring.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Jeunes',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: offspring.map((o) => _OffspringChip(offspring: o)).toList(),
                ),
              ],
              if (offspring.length < (birth.offspringCount ?? 1)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(offspring.isEmpty
                      ? 'Créer les jeunes (${birth.offspringCount ?? 1})'
                      : 'Ajouter un jeune (${offspring.length}/${birth.offspringCount ?? 1})'),
                  onPressed: () => context.push(
                    '/animals/species/${mother.speciesId}/new',
                    extra: <String, String?>{
                      'motherId': mother.id,
                      'fatherId': fatherId,
                      'birthEventId': birth!.id,
                    },
                  ),
                ),
              ],
            ],

            // Action buttons based on cycle state
            if (!isClosed) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (lastAttemptPending) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pregnant_woman, size: 16),
                      label: const Text('Confirmer gestation'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AddReproductionEventDialog(
                          mother: mother,
                          pregnancyGroupId: groupId,
                          suggestedType: ReproductionEventType.pregnancyConfirmed,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Marquer échec'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AddReproductionEventDialog(
                          mother: mother,
                          pregnancyGroupId: groupId,
                          suggestedType: ReproductionEventType.matingFailed,
                        ),
                      ),
                    ),
                  ],
                  if (lastAttemptFailed)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Réessayer'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AddReproductionEventDialog(
                          mother: mother,
                          pregnancyGroupId: groupId,
                          suggestedType: ReproductionEventType.mating,
                        ),
                      ),
                    ),
                  if (isPregnant) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.child_friendly, size: 16),
                      label: const Text('Naissance'),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AddReproductionEventDialog(
                          mother: mother,
                          pregnancyGroupId: groupId,
                          suggestedType: ReproductionEventType.birth,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.heart_broken, size: 16),
                      label: const Text('Perte de gestation'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: const BorderSide(color: AppColors.red)),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AddReproductionEventDialog(
                          mother: mother,
                          pregnancyGroupId: groupId,
                          suggestedType: ReproductionEventType.pregnancyLoss,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _step(IconData icon, String label, String date, Color color) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
}

class _OffspringChip extends ConsumerWidget {
  const _OffspringChip({required this.offspring});
  final Animal offspring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMale = offspring.gender == AnimalGender.male;
    final isCountedUnder = offspring.isCountedUnderMother;
    return GestureDetector(
      onTap: () => context.push('/animals/animal/${offspring.id}'),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (isMale ? Colors.blueGrey : AppColors.green)
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: (isMale ? Colors.blueGrey : AppColors.green)
                  .withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(offspring.farmId,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            Text(isMale ? '♂ Mâle' : '♀ Femelle',
                style: const TextStyle(fontSize: 10)),
            Text(
              isCountedUnder
                  ? 'Sous la mère'
                  : (!isMale ? 'Indépendante' : ''),
              style: TextStyle(
                  fontSize: 9,
                  color: isCountedUnder ? Colors.orange : Colors.teal),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

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
      height: 200,
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
                  style: const TextStyle(fontSize: 80))),
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
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class _FinanceBadge extends StatelessWidget {
  const _FinanceBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
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
                              '${_typeLabel(e.eventType)} · ${e.date}${e.vetName == null ? "" : " · ${e.vetName}"}${e.nextDueDate == null ? "" : "\nRappel: ${e.nextDueDate}"}',
                              overflow: TextOverflow.ellipsis, maxLines: 3),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ─── Croissance Section ───────────────────────────────────────────────────────

class _CroissanceSection extends ConsumerWidget {
  const _CroissanceSection({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_weightsForAnimalProvider(
        (userId: animal.userId, animalId: animal.id)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, color: AppColors.green),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Croissance',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) =>
                        AddWeightMeasurementDialog(animal: animal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erreur : $e'),
              data: (list) => _content(context, ref, list),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(
      BuildContext context, WidgetRef ref, List<WeightMeasurement> list) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Aucune mesure. Ajoutez un poids pour démarrer le suivi de croissance.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final sorted = [...list]
      ..sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
    final birth = animal.birthDate != null
        ? DateTime.tryParse(animal.birthDate!)
        : null;

    int ageDays(WeightMeasurement m) {
      final d = DateTime.tryParse(m.measurementDate);
      if (d == null) return 0;
      final base = birth ?? DateTime.tryParse(sorted.first.measurementDate);
      if (base == null) return 0;
      return d.difference(base).inDays;
    }

    final latest = sorted.last;
    final latestAge = ageDays(latest);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sorted.length >= 2)
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(
                    axisNameWidget:
                        Text('âge (jours)', style: TextStyle(fontSize: 10)),
                    sideTitles:
                        SideTitles(showTitles: true, reservedSize: 26),
                  ),
                  leftTitles: const AxisTitles(
                    axisNameWidget:
                        Text('kg', style: TextStyle(fontSize: 10)),
                    sideTitles:
                        SideTitles(showTitles: true, reservedSize: 32),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (final m in sorted)
                        FlSpot(ageDays(m).toDouble(), m.weight),
                    ],
                    isCurved: false,
                    color: AppColors.green,
                    barWidth: 2,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Au moins 2 mesures sont nécessaires pour afficher le graphique.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        const SizedBox(height: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Dernier poids : ${latest.weight.toStringAsFixed(1)} kg ($latestAge j)',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.green),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Historique',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ...sorted.reversed.map((m) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle,
                  size: 8, color: AppColors.green),
              title: Text(
                  '${m.weight.toStringAsFixed(1)} kg · ${m.measurementDate} (${ageDays(m)} j)',
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              subtitle: m.notes == null
                  ? null
                  : Text(m.notes!,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.grey),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Supprimer cette mesure ?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler')),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.red,
                                foregroundColor: Colors.white),
                            child: const Text('Supprimer')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref
                        .read(weightMeasurementRepositoryProvider)
                        .delete(m.id);
                  }
                },
              ),
            )),
      ],
    );
  }
}

// ─── Notation Section ─────────────────────────────────────────────────────────

class _NotationSection extends ConsumerWidget {
  const _NotationSection({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(femaleRatingProvider(animal.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ratingAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (rating) => _NotationCard(rating: rating),
        ),
      ],
    );
  }
}

class _NotationCard extends StatelessWidget {
  const _NotationCard({required this.rating});
  final FemaleRating? rating;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                const Text('Score global',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (rating?.composite != null)
                  _StarRow(score: rating!.composite!, size: 18)
                else
                  const Text('Données insuffisantes',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Divider(height: 20),
            _MetricRow(
              label: '🐣 Productivité / an',
              score: rating?.productiviteScore,
              raw: rating?.birthsPerYear != null
                  ? '${rating!.birthsPerYear!.toStringAsFixed(1)}/an'
                  : null,
            ),
            _MetricRow(
              label: '🍼 Portée moyenne',
              score: rating?.porteeScore,
              raw: rating?.avgLitterSize != null
                  ? '${rating!.avgLitterSize!.toStringAsFixed(1)} petits'
                  : null,
            ),
            _MetricRow(
              label: '💚 Taux de survie',
              score: rating?.survieScore,
              raw: rating?.survivalRate != null
                  ? '${(rating!.survivalRate! * 100).toStringAsFixed(0)}%'
                  : null,
            ),
            _MetricRow(
              label: '⚖️ Croissance sevrage',
              score: rating?.croissanceScore,
              raw: rating?.avgWeaningGainPercent != null
                  ? '+${rating!.avgWeaningGainPercent!.toStringAsFixed(0)}%'
                  : null,
            ),
            _MetricRow(
              label: '🏥 Santé',
              score: rating?.santeScore,
              raw: rating?.illnessesPerYear != null
                  ? '${rating!.illnessesPerYear!.toStringAsFixed(1)} maladies/an'
                  : null,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.score,
    this.raw,
    this.isLast = false,
  });

  final String label;
  final double? score;
  final String? raw;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13))),
          if (score != null)
            _StarRow(score: score!)
          else
            Text('—',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          if (raw != null) ...[
            const SizedBox(width: 6),
            Text('($raw)',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.score, this.size = 13});
  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final full = score.floor();
    final hasHalf = (score - full) >= 0.25 && (score - full) < 0.75;
    final empty = 5 - full - (hasHalf ? 1 : 0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++)
          Icon(Icons.star, color: Colors.amber, size: size),
        if (hasHalf)
          Icon(Icons.star_half, color: Colors.amber, size: size),
        for (int i = 0; i < empty; i++)
          Icon(Icons.star_border, color: Colors.grey[400], size: size),
      ],
    );
  }
}
