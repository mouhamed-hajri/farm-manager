import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/field.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_picker_widget.dart';

class AddEditFieldScreen extends ConsumerStatefulWidget {
  const AddEditFieldScreen({super.key, this.fieldId});

  final String? fieldId;

  @override
  ConsumerState<AddEditFieldScreen> createState() => _AddEditFieldScreenState();
}

class _AddEditFieldScreenState extends ConsumerState<AddEditFieldScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _locationController = TextEditingController();
  final _rentAmountController = TextEditingController();
  final _landlordNameController = TextEditingController();
  final _landlordPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  String _ownership = FieldOwnership.owned;
  String _rentPeriod = RentPeriod.year;
  DateTime? _rentStart;
  DateTime? _rentEnd;
  String? _photoLocalPath;
  String? _photoCloudUrl;
  FarmField? _existing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.fieldId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final f = await ref.read(fieldRepositoryProvider).getById(widget.fieldId!);
    if (f == null || !mounted) return;
    setState(() {
      _existing = f;
      _nameController.text = f.name;
      _areaController.text = f.areaText ?? '';
      _locationController.text = f.locationText ?? '';
      _rentAmountController.text =
          f.rentAmount == null ? '' : f.rentAmount.toString();
      _landlordNameController.text = f.landlordName ?? '';
      _landlordPhoneController.text = f.landlordPhone ?? '';
      _notesController.text = f.notes ?? '';
      _ownership = f.ownership;
      _rentPeriod = f.rentPeriod ?? RentPeriod.year;
      _rentStart = f.rentStartDate == null ? null : DateTime.tryParse(f.rentStartDate!);
      _rentEnd = f.rentEndDate == null ? null : DateTime.tryParse(f.rentEndDate!);
      _photoLocalPath = f.photoLocalPath;
      _photoCloudUrl = f.photoCloudUrl;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _locationController.dispose();
    _rentAmountController.dispose();
    _landlordNameController.dispose();
    _landlordPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _loading = true);

    final isRented = _ownership == FieldOwnership.rented;
    final now = DateTime.now().toIso8601String();

    final base = FarmField(
      id: _existing?.id ?? '',
      userId: user.uid,
      name: _nameController.text.trim(),
      areaText: _areaController.text.trim().isEmpty
          ? null
          : _areaController.text.trim(),
      locationText: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      ownership: _ownership,
      photoLocalPath: _photoLocalPath,
      photoCloudUrl: _photoCloudUrl,
      rentAmount: isRented ? double.tryParse(_rentAmountController.text) : null,
      rentPeriod: isRented ? _rentPeriod : null,
      rentStartDate:
          isRented ? _rentStart?.toIso8601String().substring(0, 10) : null,
      rentEndDate: isRented ? _rentEnd?.toIso8601String().substring(0, 10) : null,
      landlordName: isRented
          ? (_landlordNameController.text.trim().isEmpty
              ? null
              : _landlordNameController.text.trim())
          : null,
      landlordPhone: isRented
          ? (_landlordPhoneController.text.trim().isEmpty
              ? null
              : _landlordPhoneController.text.trim())
          : null,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
      syncStatus: 'pending',
    );

    try {
      final repo = ref.read(fieldRepositoryProvider);
      final saved = _existing == null
          ? await repo.addField(base)
          : await repo.updateField(base);
      // Schedule rent reminders (cancels existing first).
      await ref.read(reminderServiceProvider).scheduleRentReminders(saved);
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

  Future<void> _pickDate(DateTime? current, void Function(DateTime) onPicked) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) onPicked(d);
  }

  String _formatDate(DateTime? d) => d == null
      ? 'Choisir'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isRented = _ownership == FieldOwnership.rented;
    return Scaffold(
      appBar: AppBar(
          title:
              Text(_existing == null ? 'Nouveau champ' : 'Modifier champ')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PhotoPickerWidget(
              localPath: _photoLocalPath,
              cloudUrl: _photoCloudUrl,
              onChanged: (p) => setState(() {
                _photoLocalPath = p;
                if (p != null) _photoCloudUrl = null;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du champ *',
                hintText: 'Champ 1, Terrain Sud, etc.',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _areaController,
              decoration: const InputDecoration(
                labelText: 'Surface (libre)',
                hintText: '5 hectares, 2000 m², etc.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Localisation',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _ownership,
              decoration: const InputDecoration(
                labelText: 'Propriété',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: FieldOwnership.owned, child: Text('Possédé')),
                DropdownMenuItem(value: FieldOwnership.rented, child: Text('Loué')),
              ],
              onChanged: (v) => setState(() => _ownership = v ?? FieldOwnership.owned),
            ),
            if (isRented) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Contrat de location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _rentAmountController,
                    decoration: const InputDecoration(
                      labelText: 'Montant (TND)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _rentPeriod,
                    decoration: const InputDecoration(
                      labelText: 'Période',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: RentPeriod.month, child: Text('/ mois')),
                      DropdownMenuItem(value: RentPeriod.year, child: Text('/ an')),
                      DropdownMenuItem(value: RentPeriod.total, child: Text('Total')),
                    ],
                    onChanged: (v) =>
                        setState(() => _rentPeriod = v ?? RentPeriod.year),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Début du contrat'),
                subtitle: Text(_formatDate(_rentStart)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () =>
                    _pickDate(_rentStart, (d) => setState(() => _rentStart = d)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fin du contrat'),
                subtitle: Text(_formatDate(_rentEnd)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () =>
                    _pickDate(_rentEnd, (d) => setState(() => _rentEnd = d)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _landlordNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom du propriétaire',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _landlordPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone du propriétaire',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
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
}
