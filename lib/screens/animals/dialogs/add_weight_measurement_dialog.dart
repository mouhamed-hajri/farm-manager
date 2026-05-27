import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/animal.dart';
import '../../../models/weight_measurement.dart';
import '../../../providers/core_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/date_field.dart';

class AddWeightMeasurementDialog extends ConsumerStatefulWidget {
  const AddWeightMeasurementDialog({super.key, required this.animal});

  final Animal animal;

  @override
  ConsumerState<AddWeightMeasurementDialog> createState() =>
      _AddWeightMeasurementDialogState();
}

class _AddWeightMeasurementDialogState
    extends ConsumerState<AddWeightMeasurementDialog> {
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }


  Future<void> _save() async {
    final raw = _weightCtrl.text.trim().replaceAll(',', '.');
    final weight = double.tryParse(raw);
    if (weight == null || weight <= 0) {
      setState(() => _error = 'Poids invalide');
      return;
    }
    final dateStr = _date.toIso8601String().substring(0, 10);
    final birth = widget.animal.birthDate;
    if (birth != null && dateStr.compareTo(birth) < 0) {
      setState(
          () => _error = 'La date ne peut pas être avant la naissance');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(weightMeasurementRepositoryProvider)
          .add(WeightMeasurement(
            id: '',
            userId: widget.animal.userId,
            animalId: widget.animal.id,
            weight: weight,
            measurementDate: dateStr,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            createdAt: '',
            updatedAt: '',
            syncStatus: 'pending',
          ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Erreur : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un poids'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _weightCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Poids (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DateField(
              label: 'Date',
              initialDate: _date,
              lastDate: DateTime.now(),
              required: true,
              onChanged: (d) {
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: Colors.white),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
