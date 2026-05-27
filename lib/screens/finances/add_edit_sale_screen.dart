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
import '../../widgets/date_field.dart';
import '../../widgets/photo_picker_widget.dart';

class AddEditSaleScreen extends ConsumerStatefulWidget {
  const AddEditSaleScreen({
    super.key,
    this.preselectedScope,
    this.preselectedAnimalId,
    this.preselectedSpeciesId,
    this.preselectedCropId,
  });

  final String? preselectedScope;
  final String? preselectedAnimalId;
  final String? preselectedSpeciesId;
  final String? preselectedCropId;

  @override
  ConsumerState<AddEditSaleScreen> createState() => _AddEditSaleScreenState();
}

class _AddEditSaleScreenState extends ConsumerState<AddEditSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _totalPriceController = TextEditingController();
  final _productController = TextEditingController();
  final _buyerNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  late String _scope;
  late String _unit;
  DateTime _date = DateTime.now();
  String? _photoLocalPath;
  String? _linkedSpeciesId;
  String? _linkedAnimalId;
  String? _linkedCropId;
  bool _loading = false;
  // Tracks which price field the user last typed in so we know what to recompute
  // when the quantity changes. 'total' means total is the source of truth (the
  // common case — "I sold 3 caisses for 90 TND"); 'unit' means unit price is.
  String _priceSource = 'total';
  bool _syncingPrice = false;

  @override
  void initState() {
    super.initState();
    _scope = widget.preselectedScope ?? SaleScope.crop;
    _unit = _scope == SaleScope.animal ? SaleUnit.piece : SaleUnit.grandeCaisse;
    _linkedAnimalId = widget.preselectedAnimalId;
    _linkedSpeciesId = widget.preselectedSpeciesId;
    _linkedCropId = widget.preselectedCropId;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _unitPriceController.dispose();
    _totalPriceController.dispose();
    _productController.dispose();
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    // Show as integer if whole, else 2 decimals — keeps the UI clean
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  void _onQtyChanged() {
    final qty = double.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) {
      setState(() {});
      return;
    }
    _syncingPrice = true;
    if (_priceSource == 'total') {
      final total = double.tryParse(_totalPriceController.text) ?? 0;
      if (total > 0) {
        _unitPriceController.text = _fmt(total / qty);
      }
    } else {
      final unit = double.tryParse(_unitPriceController.text) ?? 0;
      if (unit > 0) {
        _totalPriceController.text = _fmt(unit * qty);
      }
    }
    _syncingPrice = false;
    setState(() {});
  }

  void _onTotalChanged() {
    if (_syncingPrice) return;
    _priceSource = 'total';
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final total = double.tryParse(_totalPriceController.text) ?? 0;
    if (qty > 0 && total > 0) {
      _syncingPrice = true;
      _unitPriceController.text = _fmt(total / qty);
      _syncingPrice = false;
    } else if (total == 0) {
      _syncingPrice = true;
      _unitPriceController.clear();
      _syncingPrice = false;
    }
    setState(() {});
  }

  void _onUnitChanged() {
    if (_syncingPrice) return;
    _priceSource = 'unit';
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final unit = double.tryParse(_unitPriceController.text) ?? 0;
    if (qty > 0 && unit > 0) {
      _syncingPrice = true;
      _totalPriceController.text = _fmt(unit * qty);
      _syncingPrice = false;
    } else if (unit == 0) {
      _syncingPrice = true;
      _totalPriceController.clear();
      _syncingPrice = false;
    }
    setState(() {});
  }

  void _onScopeChanged(String s) {
    setState(() {
      _scope = s;
      _linkedSpeciesId = null;
      _linkedAnimalId = null;
      _linkedCropId = null;
      _productController.clear();
      _qtyController.text = '1';
      _unitPriceController.clear();
      _totalPriceController.clear();
      _priceSource = 'total';
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

  double get _total {
    // Single source of truth: whatever the user last edited or what got computed
    final t = double.tryParse(_totalPriceController.text) ?? 0;
    if (t > 0) return t;
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
              salePrice: double.parse(_unitPriceController.text.replaceAll(',', '.')),
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
        final qty = double.parse(_qtyController.text.replaceAll(',', '.'));
        final total = double.tryParse(_totalPriceController.text) ?? 0;
        final unitFromField = double.tryParse(_unitPriceController.text) ?? 0;
        // Total is canonical when present; unit price is derived (qty > 0 guaranteed by validator)
        final unit = total > 0 ? total / qty : unitFromField;
        final finalTotal = total > 0 ? total : unit * qty;
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
              unitPrice: unit,
              totalPrice: finalTotal,
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
                    onChanged: (_) => _onQtyChanged(),
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
              // Primary field: total price. Big and prominent — what dad will type.
              TextFormField(
                controller: _totalPriceController,
                decoration: const InputDecoration(
                  labelText: 'Prix total (TND) *',
                  helperText: 'Le prix unitaire est calculé automatiquement',
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.green),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _onTotalChanged(),
                validator: (v) {
                  // Either total OR unit must be filled
                  final t = double.tryParse((v ?? '').replaceAll(',', '.'));
                  final u = double.tryParse(_unitPriceController.text.replaceAll(',', '.'));
                  if ((t == null || t <= 0) && (u == null || u <= 0)) {
                    return 'Prix requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Secondary field: unit price. Auto-computed; editable for users
              // who prefer to enter it directly (then total recomputes).
              TextFormField(
                controller: _unitPriceController,
                decoration: const InputDecoration(
                  labelText: 'Prix unitaire (TND)',
                  helperText: 'Ou tapez le prix unitaire — le total se met à jour',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _onUnitChanged(),
              ),
            ],
            if (_scope == SaleScope.animal)
              TextFormField(
                controller: _unitPriceController,
                decoration: const InputDecoration(
                  labelText: 'Prix de vente (TND) *',
                  prefixIcon: Icon(Icons.attach_money, color: AppColors.green),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Prix invalide';
                  return null;
                },
              ),
            const SizedBox(height: 12),
            DateField(
              label: 'Date de vente',
              initialDate: _date,
              lastDate: DateTime.now(),
              required: true,
              onChanged: (d) {
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
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
