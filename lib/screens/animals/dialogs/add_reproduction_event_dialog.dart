import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/animal.dart';
import '../../../models/reproduction_event.dart';
import '../../../providers/animal_provider.dart';
import '../../../providers/core_providers.dart';
import '../../../services/consanguinity_service.dart';
import '../../../theme/app_theme.dart';
import '../father_selection_screen.dart';

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
  String? _partnerFarmId;
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

  Future<void> _pickFather() async {
    final selected = await Navigator.of(context).push<Animal?>(
      MaterialPageRoute(
        builder: (_) => FatherSelectionScreen(
          userId: widget.mother.userId,
          speciesId: widget.mother.speciesId,
          eventDate: _eventDate,
        ),
      ),
    );
    // `selected` is null when user picks "Père inconnu"
    // Navigator.pop with null vs. not popping are differentiated by
    // checking whether the route was actually popped.
    setState(() {
      _partnerId = selected?.id;
      _partnerFarmId = selected?.farmId;
    });
  }

  Future<bool> _showConsanguinityWarning(int distance) async {
    final (label, color) = switch (distance) {
      <= 1 => ('Relation directe (parent / enfant)', AppColors.red),
      2 => ('Frères / sœurs — consanguinité très proche', AppColors.red),
      3 => ('Apparentés à 3 générations', Colors.orange),
      4 => ('Apparentés à 4 générations', Colors.orange),
      _ => ('Apparentés à $distance générations', Colors.amber),
    };

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color),
            const SizedBox(width: 8),
            const Flexible(child: Text('Consanguinité détectée')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            const Text(
              'Reproduire des animaux du même sang peut provoquer des '
              'défauts génétiques chez les jeunes. Voulez-vous continuer ?',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Choisir un autre mâle'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
            child: const Text('Continuer quand même'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      // Consanguinity check — only for matings with a known father.
      if (_type == ReproductionEventType.mating && _partnerId != null) {
        final allAnimals =
            ref.read(allAnimalsProvider).asData?.value ?? const [];
        final animalsById = {for (final a in allAnimals) a.id: a};
        final distance = ConsanguinityService.findRelationshipDistance(
          animalsById: animalsById,
          animalAId: widget.mother.id,
          animalBId: _partnerId!,
        );
        if (distance != null) {
          setState(() => _loading = false);
          final proceed = await _showConsanguinityWarning(distance);
          if (!proceed) return;
          if (!mounted) return;
          setState(() => _loading = true);
        }
      }

      final groupId = widget.pregnancyGroupId ?? const Uuid().v4();
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
    final showFather = _type == ReproductionEventType.mating ||
        _type == ReproductionEventType.birth;
    final showNoExtraFields = _type == ReproductionEventType.matingFailed ||
        _type == ReproductionEventType.pregnancyLoss;

    return AlertDialog(
      title: const Text('Événement de reproduction'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: ReproductionEventType.mating,
                    child: Text('Accouplement')),
                DropdownMenuItem(
                    value: ReproductionEventType.matingFailed,
                    child: Text('❌ Accouplement échoué')),
                DropdownMenuItem(
                    value: ReproductionEventType.pregnancyConfirmed,
                    child: Text('Confirmer gestation')),
                DropdownMenuItem(
                    value: ReproductionEventType.pregnancyLoss,
                    child: Text('💔 Perte de gestation')),
                DropdownMenuItem(
                    value: ReproductionEventType.birth,
                    child: Text('Naissance')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _pickDate(
                  _eventDate, (d) => setState(() => _eventDate = d)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.green, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.green.withValues(alpha: 0.05),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: AppColors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date de l\'événement',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.green,
                                  fontWeight: FontWeight.w600)),
                          Text(
                            _eventDate.toIso8601String().substring(0, 10),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            if (showFather && !showNoExtraFields) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.male, size: 18),
                  label: Text(_partnerFarmId != null
                      ? 'Père : $_partnerFarmId'
                      : (_partnerId == null
                          ? 'Choisir le père'
                          : 'Père inconnu')),
                  onPressed: _pickFather,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.green,
                    side: const BorderSide(color: AppColors.green),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mâles disponibles au ${_eventDate.toIso8601String().substring(0, 10)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
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
