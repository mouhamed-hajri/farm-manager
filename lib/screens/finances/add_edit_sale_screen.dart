import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../models/sale.dart';
import '../../providers/animal_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/crop_provider.dart';
import '../../providers/species_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_picker_widget.dart';

class AddEditSaleScreen extends ConsumerStatefulWidget {
  const AddEditSaleScreen({super.key});

  @override
  ConsumerState<AddEditSaleScreen> createState() => _AddEditSaleScreenState();
}

class _AddEditSaleScreenState extends ConsumerState<AddEditSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _productController = TextEditingController();
  final _buyerNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  String _scope = SaleScope.crop;
  String _unit = SaleUnit.grandeCaisse;
  DateTime _date = DateTime.now();
  String? _photoLocalPath;
  String? _linkedSpeciesId;
  String? _linkedAnimalId;
  String? _linkedCropId;
  bool _loading = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _unitPriceController.dispose();
    _productController.dispose();
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onScopeChanged(String s) {
    setState(() {
      _scope = s;
      _linkedSpeciesId = null;
      _linkedAnimalId = null;
      _linkedCropId = null;
      _productController.clear();
      _qtyController.text = '1';
      switch (s) {
        case SaleScope.animal:
          _unit = SaleUnit.piece;
          break;
        case SaleScope.crop:
          _unit = SaleUnit.grandeCaisse;
          break;
        default:
          _unit = SaleUnit.piece;
      }
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  double get _total {
    final q = double.tryParse(_qtyController.text) ?? 0;
    final p = double.tryParse(_unitPriceController.text) ?? 0;
    return q * p;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _loading = true);

    try {
      if (_scope == SaleScope.animal && _linkedAnimalId != null) {
        final animal =
            await ref.read(animalRepositoryProvider).getById(_linkedAnimalId!);
        if (animal == null) return;
        await ref.read(saleRepositoryProvider).sellAnimal(
              animal: animal,
              salePrice: double.parse(_unitPriceController.text),
              saleDate: _date.toIso8601String().substring(0, 10),
              buyerName: _buyerNameController.text.trim().isEmpty
                  ? null
                  : _buyerNameController.text.trim(),
              buyerPhone: _buyerPhoneController.text.trim().isEmpty
                  ? null
                  : _buyerPhoneController.text.trim(),
              receiptPhotoLocalPath: _photoLocalPath,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );
      } else {
        final qty = double.parse(_qtyController.text);
        final price = double.parse(_unitPriceController.text);
        await ref.read(saleRepositoryProvider).addSale(Sale(
              id: '',
              userId: user.uid,
              scope: _scope,
              linkedCropId: _scope == SaleScope.crop ? _linkedCropId : null,
              productName: _scope == SaleScope.product || _scope == SaleScope.other
                  ? _productController.text.trim()
                  : null,
              quantity: qty,
              unit: _unit,
              unitPrice: price,
              totalPrice: qty * price,
              buyerName: _buyerNameController.text.trim().isEmpty
                  ? null
                  : _buyerNameController.text.trim(),
              buyerPhone: _buyerPhoneController.text.trim().isEmpty
                  ? null
                  : _buyerPhoneController.text.trim(),
              saleDate: _date.toIso8601String().substring(0, 10),
              receiptPhotoLocalPath: _photoLocalPath,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              createdAt: '',
              updatedAt: '',
              syncStatus: 'pending',
            ));
      }
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
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _scope,
              decoration: const InputDecoration(
                labelText: 'Type de vente',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: SaleScope.animal, child: Text('Animal')),
                DropdownMenuItem(value: SaleScope.crop, child: Text('Culture')),
                DropdownMenuItem(value: SaleScope.product, child: Text('Produit')),
                DropdownMenuItem(value: SaleScope.other, child: Text('Autre')),
              ],
              onChanged: (v) => _onScopeChanged(v ?? SaleScope.crop),
            ),
            const SizedBox(height: 12),
            if (_scope == SaleScope.animal) _animalLinkSection(),
            if (_scope == SaleScope.crop) _cropLinkSection(),
            if (_scope == SaleScope.product || _scope == SaleScope.other) ...[
              const SizedBox(height: 4),
              TextFormField(
                controller: _productController,
                decoration: InputDecoration(
                  labelText: _scope == SaleScope.product
                      ? 'Produit (lait, œufs, laine, etc.) *'
                      : 'Description *',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
            ],
            if (_scope != SaleScope.animal) ...[
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Quantité *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Quantité invalide';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(
                      labelText: 'Unité',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: SaleUnit.kg, child: Text('kg')),
                      DropdownMenuItem(
                          value: SaleUnit.grandeCaisse,
                          child: Text('Grande caisse')),
                      DropdownMenuItem(
                          value: SaleUnit.petiteCaisse,
                          child: Text('Petite caisse')),
                      DropdownMenuItem(
                          value: SaleUnit.piece, child: Text('Pièce')),
                      DropdownMenuItem(
                          value: SaleUnit.litre, child: Text('Litre')),
                    ],
                    onChanged: (v) => setState(() => _unit = v ?? _unit),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _unitPriceController,
              decoration: InputDecoration(
                labelText: _scope == SaleScope.animal
                    ? 'Prix de vente (TND) *'
                    : 'Prix unitaire (TND) *',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0) return 'Prix invalide';
                return null;
              },
            ),
            if (_scope != SaleScope.animal && _total > 0) ...[
              const SizedBox(height: 8),
              Text('Total : ${_total.toStringAsFixed(2)} TND',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.green)),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date de vente'),
              subtitle: Text(_date.toIso8601String().substring(0, 10)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            TextFormField(
              controller: _buyerNameController,
              decoration: const InputDecoration(
                labelText: 'Acheteur',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buyerPhoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            PhotoPickerWidget(
              localPath: _photoLocalPath,
              label: 'Photo de la facture (optionnel)',
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
              return DropdownButtonFormField<String>(
                initialValue: _linkedAnimalId,
                decoration: const InputDecoration(
                  labelText: 'Animal à vendre *',
                  border: OutlineInputBorder(),
                ),
                items: filtered
                    .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(
                            '${a.farmId}${a.nickname == null ? "" : " · ${a.nickname}"}')))
                    .toList(),
                onChanged: (v) => setState(() => _linkedAnimalId = v),
                validator: (v) => v == null ? 'Requis' : null,
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
}
