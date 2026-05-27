import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/animal.dart';
import '../../../providers/core_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/date_field.dart';

class MarkAnimalDeadDialog extends ConsumerStatefulWidget {
  const MarkAnimalDeadDialog({super.key, required this.animal});

  final Animal animal;

  @override
  ConsumerState<MarkAnimalDeadDialog> createState() =>
      _MarkAnimalDeadDialogState();
}

class _MarkAnimalDeadDialogState extends ConsumerState<MarkAnimalDeadDialog> {
  final _causeController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;


  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(animalRepositoryProvider).markDead(
            widget.animal,
            deathDate: _date.toIso8601String().substring(0, 10),
            deathCause: _causeController.text.trim().isEmpty
                ? null
                : _causeController.text.trim(),
            deathNotes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Marquer ${widget.animal.farmId} comme décédé'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DateField(
              label: 'Date du décès',
              initialDate: _date,
              lastDate: DateTime.now(),
              required: true,
              onChanged: (d) {
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _causeController,
              decoration: const InputDecoration(
                labelText: 'Cause',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirmer'),
        ),
      ],
    );
  }
}
