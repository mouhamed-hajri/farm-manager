import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/crop.dart';
import '../../../models/crop_activity.dart';
import '../../../providers/core_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/date_field.dart';

class AddCropActivityDialog extends ConsumerStatefulWidget {
  const AddCropActivityDialog({super.key, required this.crop});
  final Crop crop;

  @override
  ConsumerState<AddCropActivityDialog> createState() =>
      _AddCropActivityDialogState();
}

class _AddCropActivityDialogState
    extends ConsumerState<AddCropActivityDialog> {
  final _descCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _type = CropActivityType.watered;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final cost = double.tryParse(_costCtrl.text.trim().replaceAll(',', '.'));
      final activity = CropActivity(
        id: '',
        userId: user.uid,
        cropId: widget.crop.id,
        activityType: _type,
        date: _date.toIso8601String().substring(0, 10),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        cost: cost,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: '',
        updatedAt: '',
        syncStatus: 'pending',
      );
      await ref
          .read(cropActivityRepositoryProvider)
          .add(activity, crop: widget.crop);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCost =
        (double.tryParse(_costCtrl.text.trim().replaceAll(',', '.')) ?? 0) > 0;
    return AlertDialog(
      title: const Text('Nouvelle activité'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: CropActivityType.all.map((t) {
                final selected = _type == t;
                return ChoiceChip(
                  label: Text(
                      '${CropActivityType.emoji(t)} ${CropActivityType.labelFr(t)}'),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
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
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (ex: NPK 15-15-15)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Coût (TND) — optionnel',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (hasCost) ...[
              const SizedBox(height: 4),
              Text(
                'Une dépense sera créée automatiquement.',
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
