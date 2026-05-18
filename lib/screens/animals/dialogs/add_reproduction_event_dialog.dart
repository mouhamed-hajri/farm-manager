import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/animal.dart';
import '../../../models/reproduction_event.dart';
import '../../../providers/animal_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../theme/app_theme.dart';

class AddReproductionEventDialog extends ConsumerStatefulWidget {
  const AddReproductionEventDialog({
    super.key,
    required this.mother,
    this.pregnancyGroupId,
    this.suggestedType,
  });

  final Animal mother;
  final String? pregnancyGroupId;
  final String? suggestedType;

  @override
  ConsumerState<AddReproductionEventDialog> createState() =>
      _AddReproductionEventDialogState();
}

class _AddReproductionEventDialogState
    extends ConsumerState<AddReproductionEventDialog> {
  late String _type;
  DateTime _eventDate = DateTime.now();
  DateTime? _dueDate;
  String? _partnerId;
  final _offspringCountController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.suggestedType ?? ReproductionEventType.mating;
  }

  @override
  void dispose() {
    _offspringCountController.dispose();
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
          ? DateTime.now().add(const Duration(days: 365 * 2))
          : DateTime.now(),
    );
    if (d != null) on(d);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final groupId =
          widget.pregnancyGroupId ?? const Uuid().v4();
      final saved = await ref.read(reproductionEventRepositoryProvider).add(
            ReproductionEvent(
              id: '',
              userId: widget.mother.userId,
              animalId: widget.mother.id,
              eventType: _type,
              partnerId: _partnerId,
              eventDate: _eventDate.toIso8601String().substring(0, 10),
              dueDate: _type == ReproductionEventType.pregnancyConfirmed
                  ? _dueDate?.toIso8601String().substring(0, 10)
                  : null,
              offspringCount: _type == ReproductionEventType.birth
                  ? int.tryParse(_offspringCountController.text)
                  : null,
              pregnancyGroupId: groupId,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              createdAt: '',
              updatedAt: '',
              syncStatus: 'pending',
            ),
          );
      if (saved.eventType == ReproductionEventType.pregnancyConfirmed &&
          saved.dueDate != null) {
        await ref
            .read(reminderServiceProvider)
            .schedulePregnancyReminder(saved, widget.mother.farmId);
      }
      if (!mounted) return;
      Navigator.pop(context, groupId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalsAsync = ref.watch(allAnimalsProvider);
    final maleAnimals = animalsAsync.asData?.value
            .where((a) =>
                a.speciesId == widget.mother.speciesId &&
                a.gender == AnimalGender.male &&
                a.status == AnimalStatus.active)
            .toList() ??
        const [];

    return AlertDialog(
      title: const Text('Événement de reproduction'),
      content: SingleChildScrollView(
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
                    value: ReproductionEventType.mating,
                    child: Text('Accouplement')),
                DropdownMenuItem(
                    value: ReproductionEventType.pregnancyConfirmed,
                    child: Text('Confirmer gestation')),
                DropdownMenuItem(
                    value: ReproductionEventType.birth,
                    child: Text('Naissance')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(_eventDate.toIso8601String().substring(0, 10)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                  _eventDate, (d) => setState(() => _eventDate = d)),
            ),
            if (_type == ReproductionEventType.mating &&
                maleAnimals.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _partnerId,
                decoration: const InputDecoration(
                  labelText: 'Mâle (optionnel)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Inconnu')),
                  ...maleAnimals.map((a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(
                          '${a.farmId}${a.nickname == null ? "" : " · ${a.nickname}"}'))),
                ],
                onChanged: (v) => setState(() => _partnerId = v),
              ),
            ],
            if (_type == ReproductionEventType.pregnancyConfirmed) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date de mise bas prévue'),
                subtitle: Text(_dueDate == null
                    ? 'Choisir'
                    : _dueDate!.toIso8601String().substring(0, 10)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(
                    _dueDate, (d) => setState(() => _dueDate = d),
                    allowFuture: true),
              ),
            ],
            if (_type == ReproductionEventType.birth) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _offspringCountController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de jeunes',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
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
