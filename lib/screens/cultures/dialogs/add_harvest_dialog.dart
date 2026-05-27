import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/crop.dart';
import '../../../models/harvest.dart';
import '../../../providers/core_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/date_field.dart';

class AddHarvestDialog extends ConsumerStatefulWidget {
  const AddHarvestDialog({super.key, required this.crop});
  final Crop crop;

  @override
  ConsumerState<AddHarvestDialog> createState() => _AddHarvestDialogState();
}

class _AddHarvestDialogState extends ConsumerState<AddHarvestDialog> {
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _unit = HarvestUnit.kg;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? get _qty =>
      double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));
  double? get _price =>
      double.tryParse(_priceCtrl.text.trim().replaceAll(',', '.'));
  double? get _total {
    final q = _qty, p = _price;
    if (q == null || p == null || q <= 0 || p <= 0) return null;
    return q * p;
  }

  Future<void> _save() async {
    final qty = _qty;
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Quantité invalide');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final harvest = Harvest(
        id: '',
        userId: user.uid,
        cropId: widget.crop.id,
        harvestDate: _date.toIso8601String().substring(0, 10),
        quantity: qty,
        unit: _unit,
        pricePerUnit: _price,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: '',
        updatedAt: '',
        syncStatus: 'pending',
      );
      await ref
          .read(harvestRepositoryProvider)
          .add(harvest, crop: widget.crop);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    return AlertDialog(
      title: Row(children: const [
        Text('🚜 ', style: TextStyle(fontSize: 22)),
        Expanded(child: Text('Nouvelle récolte')),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DateField(
              label: 'Date de récolte',
              initialDate: _date,
              lastDate: DateTime.now(),
              required: true,
              onChanged: (d) {
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _qtyCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Quantité *',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unité',
                    border: OutlineInputBorder(),
                  ),
                  items: HarvestUnit.all
                      .map((u) => DropdownMenuItem(
                          value: u, child: Text(HarvestUnit.labelFr(u))))
                      .toList(),
                  onChanged: (v) => setState(() => _unit = v ?? HarvestUnit.kg),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prix unitaire (TND) — optionnel',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (total != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total : ${total.toStringAsFixed(0)} TND',
                  style: const TextStyle(
                      color: AppColors.green, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Une vente sera créée automatiquement.',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: AppColors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Annuler')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
