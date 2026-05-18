import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/animal.dart';
import '../../../providers/core_providers.dart';
import '../../../theme/app_theme.dart';

class SellAnimalDialog extends ConsumerStatefulWidget {
  const SellAnimalDialog({super.key, required this.animal});

  final Animal animal;

  @override
  ConsumerState<SellAnimalDialog> createState() => _SellAnimalDialogState();
}

class _SellAnimalDialogState extends ConsumerState<SellAnimalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _buyerNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void dispose() {
    _priceController.dispose();
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(saleRepositoryProvider).sellAnimal(
            animal: widget.animal,
            salePrice: double.parse(_priceController.text),
            saleDate: _date.toIso8601String().substring(0, 10),
            buyerName: _buyerNameController.text.trim().isEmpty
                ? null
                : _buyerNameController.text.trim(),
            buyerPhone: _buyerPhoneController.text.trim().isEmpty
                ? null
                : _buyerPhoneController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Vendre ${widget.animal.farmId}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Prix de vente (TND) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Prix invalide';
                  return null;
                },
              ),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Vendre'),
        ),
      ],
    );
  }
}
