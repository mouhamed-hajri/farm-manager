import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/animal.dart';
import '../../../models/health_event.dart';
import '../../../providers/core_providers.dart';
import '../../../theme/app_theme.dart';

class AddHealthEventDialog extends ConsumerStatefulWidget {
  const AddHealthEventDialog({super.key, required this.animal});

  final Animal animal;

  @override
  ConsumerState<AddHealthEventDialog> createState() =>
      _AddHealthEventDialogState();
}

class _AddHealthEventDialogState extends ConsumerState<AddHealthEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _vetController = TextEditingController();
  final _notesController = TextEditingController();
  String _type = HealthEventType.treatment;
  DateTime _date = DateTime.now();
  DateTime? _nextDue;
  bool _loading = false;

  @override
  void dispose() {
    _descController.dispose();
    _vetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(DateTime? cur, void Function(DateTime) on,
      {bool allowFuture = false}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: cur ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: allowFuture
          ? DateTime.now().add(const Duration(days: 365 * 5))
          : DateTime.now(),
    );
    if (d != null) on(d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final saved = await ref.read(healthEventRepositoryProvider).add(HealthEvent(
            id: '',
            userId: widget.animal.userId,
            animalId: widget.animal.id,
            eventType: _type,
            description: _descController.text.trim(),
            date: _date.toIso8601String().substring(0, 10),
            vetName: _vetController.text.trim().isEmpty
                ? null
                : _vetController.text.trim(),
            nextDueDate: _type == HealthEventType.vaccination && _nextDue != null
                ? _nextDue!.toIso8601String().substring(0, 10)
                : null,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            createdAt: '',
            updatedAt: '',
            syncStatus: 'pending',
          ));
      // Schedule vaccination reminder if applicable.
      if (saved.eventType == HealthEventType.vaccination &&
          saved.nextDueDate != null) {
        await ref
            .read(reminderServiceProvider)
            .scheduleVaccinationReminder(saved, widget.animal.farmId);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Événement de santé'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: HealthEventType.treatment, child: Text('Traitement')),
                  DropdownMenuItem(
                      value: HealthEventType.vaccination, child: Text('Vaccination')),
                  DropdownMenuItem(
                      value: HealthEventType.illness, child: Text('Maladie')),
                  DropdownMenuItem(
                      value: HealthEventType.recovery, child: Text('Guérison')),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(_date.toIso8601String().substring(0, 10)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () =>
                    _pickDate(_date, (d) => setState(() => _date = d)),
              ),
              TextFormField(
                controller: _vetController,
                decoration: const InputDecoration(
                  labelText: 'Vétérinaire',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_type == HealthEventType.vaccination) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Prochaine vaccination (rappel)'),
                  subtitle: Text(_nextDue == null
                      ? 'Aucune'
                      : _nextDue!.toIso8601String().substring(0, 10)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _pickDate(
                      _nextDue, (d) => setState(() => _nextDue = d),
                      allowFuture: true),
                ),
              ],
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
