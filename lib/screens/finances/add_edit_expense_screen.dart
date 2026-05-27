import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../models/expense.dart';
import '../../providers/animal_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/crop_provider.dart';
import '../../providers/field_provider.dart';
import '../../providers/species_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/date_field.dart';
import '../../widgets/photo_picker_widget.dart';

class AddEditExpenseScreen extends ConsumerStatefulWidget {
  const AddEditExpenseScreen({
    super.key,
    this.preselectedScope,
    this.preselectedAnimalId,
    this.preselectedSpeciesId,
    this.preselectedCropId,
    this.preselectedFieldId,
  });

  final String? preselectedScope;
  final String? preselectedAnimalId;
  final String? preselectedSpeciesId;
  final String? preselectedCropId;
  final String? preselectedFieldId;

  @override
  ConsumerState<AddEditExpenseScreen> createState() =>
      _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends ConsumerState<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  late String _scope;
  late String _category;
  DateTime _date = DateTime.now();
  String? _photoLocalPath;
  String? _linkedSpeciesId;
  String? _linkedAnimalId;
  String? _linkedCropId;
  String? _linkedFieldId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _scope = widget.preselectedScope ?? ExpenseScope.general;
    _category = categoriesForScope(_scope).first;
    _linkedAnimalId = widget.preselectedAnimalId;
    _linkedSpeciesId = widget.preselectedSpeciesId;
    _linkedCropId = widget.preselectedCropId;
    _linkedFieldId = widget.preselectedFieldId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onScopeChanged(String s) {
    setState(() {
      _scope = s;
      _category = categoriesForScope(s).first;
      _linkedSpeciesId = null;
      _linkedAnimalId = null;
      _linkedCropId = null;
      _linkedFieldId = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _loading = true);

    try {
      await ref.read(expenseRepositoryProvider).addExpense(Expense(
            id: '',
            userId: user.uid,
            scope: _scope,
            linkedAnimalId: _linkedAnimalId,
            linkedSpeciesId: _scope == ExpenseScope.animal ? _linkedSpeciesId : null,
            linkedCropId: _linkedCropId,
            linkedFieldId: _linkedFieldId,
            amount: double.parse(_amountController.text.replaceAll(',', '.')),
            category: _category,
            date: _date.toIso8601String().substring(0, 10),
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            receiptPhotoLocalPath: _photoLocalPath,
            createdAt: '',
            updatedAt: '',
            syncStatus: 'pending',
          ));
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle dépense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _scope,
              decoration: const InputDecoration(
                labelText: 'Type de dépense',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: ExpenseScope.animal, child: Text('Animal')),
                DropdownMenuItem(value: ExpenseScope.crop, child: Text('Culture')),
                DropdownMenuItem(value: ExpenseScope.field, child: Text('Champ')),
                DropdownMenuItem(value: ExpenseScope.general, child: Text('Général')),
              ],
              onChanged: (v) => _onScopeChanged(v ?? ExpenseScope.general),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                border: OutlineInputBorder(),
              ),
              items: categoriesForScope(_scope)
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            if (_scope == ExpenseScope.animal) _animalLinkSection(),
            if (_scope == ExpenseScope.crop) _cropLinkSection(),
            if (_scope == ExpenseScope.field) _fieldLinkSection(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Montant (TND) *',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requis';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null || n <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DateField(
              label: 'Date',
              initialDate: _date,
              lastDate: DateTime.now(),
              required: true,
              onChanged: (d) {
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            PhotoPickerWidget(
              localPath: _photoLocalPath,
              label: 'Photo (reçu)',
              height: 140,
              onChanged: (p) => setState(() => _photoLocalPath = p),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animalLinkSection() {
    final speciesAsync = ref.watch(speciesListProvider);
    final animalsAsync = ref.watch(allAnimalsProvider);
    return Column(
      children: [
        speciesAsync.when(
          data: (species) => DropdownButtonFormField<String>(
            initialValue: _linkedSpeciesId,
            decoration: const InputDecoration(
              labelText: 'Espèce *',
              border: OutlineInputBorder(),
            ),
            items: species
                .map((s) => DropdownMenuItem(
                    value: s.id, child: Text('${s.iconEmoji} ${s.nameFr}')))
                .toList(),
            onChanged: (v) => setState(() {
              _linkedSpeciesId = v;
              _linkedAnimalId = null;
            }),
            validator: (v) => v == null ? 'Requis' : null,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Erreur: $e'),
        ),
        if (_linkedSpeciesId != null) ...[
          const SizedBox(height: 12),
          animalsAsync.when(
            data: (animals) {
              final filtered = animals
                  .where((a) =>
                      a.speciesId == _linkedSpeciesId &&
                      a.status == AnimalStatus.active)
                  .toList();
              return DropdownButtonFormField<String?>(
                initialValue: _linkedAnimalId,
                decoration: const InputDecoration(
                  labelText: 'Animal (optionnel)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Tous les animaux de cette espèce')),
                  ...filtered.map((a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text('${a.farmId}${a.nickname == null ? "" : " · ${a.nickname}"}'))),
                ],
                onChanged: (v) => setState(() => _linkedAnimalId = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Erreur: $e'),
          ),
        ],
      ],
    );
  }

  Widget _cropLinkSection() {
    final cropsAsync = ref.watch(cropsListProvider);
    return cropsAsync.when(
      data: (crops) => DropdownButtonFormField<String>(
        initialValue: _linkedCropId,
        decoration: const InputDecoration(
          labelText: 'Culture *',
          border: OutlineInputBorder(),
        ),
        items: crops
            .map((c) => DropdownMenuItem(
                value: c.id, child: Text('${c.iconEmoji} ${c.nameFr}')))
            .toList(),
        onChanged: (v) => setState(() => _linkedCropId = v),
        validator: (v) => v == null ? 'Requis' : null,
      ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erreur: $e'),
    );
  }

  Widget _fieldLinkSection() {
    final fieldsAsync = ref.watch(fieldsListProvider);
    return fieldsAsync.when(
      data: (fields) => DropdownButtonFormField<String>(
        initialValue: _linkedFieldId,
        decoration: const InputDecoration(
          labelText: 'Champ *',
          border: OutlineInputBorder(),
        ),
        items: fields
            .map((f) => DropdownMenuItem(value: f.id, child: Text(f.name)))
            .toList(),
        onChanged: (v) => setState(() => _linkedFieldId = v),
        validator: (v) => v == null ? 'Requis' : null,
      ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Erreur: $e'),
    );
  }
}
