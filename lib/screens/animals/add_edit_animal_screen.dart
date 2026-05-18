import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/animal.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_picker_widget.dart';

class AddEditAnimalScreen extends ConsumerStatefulWidget {
  const AddEditAnimalScreen({
    super.key,
    required this.speciesId,
    this.animalId,
    this.motherId,
    this.fatherId,
  });

  final String speciesId;
  final String? animalId;
  final String? motherId;
  final String? fatherId;

  @override
  ConsumerState<AddEditAnimalScreen> createState() =>
      _AddEditAnimalScreenState();
}

class _AddEditAnimalScreenState extends ConsumerState<AddEditAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _breedController = TextEditingController();
  final _colorController = TextEditingController();
  final _weightController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _sellerNameController = TextEditingController();
  final _sellerPhoneController = TextEditingController();
  final _purchaseLocationController = TextEditingController();
  final _notesController = TextEditingController();
  String _gender = AnimalGender.male;
  String _healthStatus = HealthStatus.healthy;
  DateTime? _birthDate;
  DateTime? _purchaseDate;
  String? _photoLocalPath;
  String? _photoCloudUrl;
  String _farmIdPreview = '...';
  Animal? _existing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final species = await ref.read(speciesRepositoryProvider).getById(widget.speciesId);
    if (species == null) return;

    if (widget.animalId != null) {
      final existing = await ref.read(animalRepositoryProvider).getById(widget.animalId!);
      if (existing != null) {
        setState(() {
          _existing = existing;
          _farmIdPreview = existing.farmId;
          _nicknameController.text = existing.nickname ?? '';
          _breedController.text = existing.breed ?? '';
          _colorController.text = existing.color ?? '';
          _weightController.text =
              existing.weight == null ? '' : existing.weight.toString();
          _purchasePriceController.text =
              existing.purchasePrice == null ? '' : existing.purchasePrice.toString();
          _sellerNameController.text = existing.sellerName ?? '';
          _sellerPhoneController.text = existing.sellerPhone ?? '';
          _purchaseLocationController.text = existing.purchaseLocation ?? '';
          _notesController.text = existing.notes ?? '';
          _gender = existing.gender;
          _healthStatus = existing.healthStatus;
          _birthDate = existing.birthDate == null ? null : DateTime.tryParse(existing.birthDate!);
          _purchaseDate = existing.purchaseDate == null ? null : DateTime.tryParse(existing.purchaseDate!);
          _photoLocalPath = existing.photoLocalPath;
          _photoCloudUrl = existing.photoCloudUrl;
        });
      }
    } else {
      final preview = await ref.read(farmIdServiceProvider).preview(user.uid, species.idPrefix);
      if (mounted) setState(() => _farmIdPreview = preview);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _breedController.dispose();
    _colorController.dispose();
    _weightController.dispose();
    _purchasePriceController.dispose();
    _sellerNameController.dispose();
    _sellerPhoneController.dispose();
    _purchaseLocationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(DateTime? current, void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) onPicked(picked);
  }

  String _formatDate(DateTime? d) =>
      d == null ? 'Choisir' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final species = await ref.read(speciesRepositoryProvider).getById(widget.speciesId);
      if (species == null) return;

      final now = DateTime.now().toIso8601String();

      if (_existing == null) {
        await ref.read(animalRepositoryProvider).addAnimal(
              animal: Animal(
                id: '',
                userId: user.uid,
                speciesId: widget.speciesId,
                farmId: '', // filled in by repository
                nickname: _nicknameController.text.trim().isEmpty
                    ? null
                    : _nicknameController.text.trim(),
                gender: _gender,
                breed: _breedController.text.trim().isEmpty
                    ? null
                    : _breedController.text.trim(),
                color: _colorController.text.trim().isEmpty
                    ? null
                    : _colorController.text.trim(),
                birthDate: _birthDate?.toIso8601String().substring(0, 10),
                weight: double.tryParse(_weightController.text),
                healthStatus: _healthStatus,
                status: AnimalStatus.active,
                purchaseDate: _purchaseDate?.toIso8601String().substring(0, 10),
                purchasePrice: double.tryParse(_purchasePriceController.text),
                sellerName: _sellerNameController.text.trim().isEmpty
                    ? null
                    : _sellerNameController.text.trim(),
                sellerPhone: _sellerPhoneController.text.trim().isEmpty
                    ? null
                    : _sellerPhoneController.text.trim(),
                purchaseLocation: _purchaseLocationController.text.trim().isEmpty
                    ? null
                    : _purchaseLocationController.text.trim(),
                photoLocalPath: _photoLocalPath,
                photoCloudUrl: _photoCloudUrl,
                motherId: widget.motherId,
                fatherId: widget.fatherId,
                notes: _notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim(),
                createdAt: now,
                updatedAt: now,
                syncStatus: 'pending',
              ),
              speciesIdPrefix: species.idPrefix,
            );
      } else {
        await ref.read(animalRepositoryProvider).updateAnimal(
              _existing!.copyWith(
                nickname: _nicknameController.text.trim().isEmpty
                    ? null
                    : _nicknameController.text.trim(),
                gender: _gender,
                breed: _breedController.text.trim().isEmpty
                    ? null
                    : _breedController.text.trim(),
                color: _colorController.text.trim().isEmpty
                    ? null
                    : _colorController.text.trim(),
                birthDate: _birthDate?.toIso8601String().substring(0, 10),
                weight: double.tryParse(_weightController.text),
                healthStatus: _healthStatus,
                purchaseDate: _purchaseDate?.toIso8601String().substring(0, 10),
                purchasePrice: double.tryParse(_purchasePriceController.text),
                sellerName: _sellerNameController.text.trim().isEmpty
                    ? null
                    : _sellerNameController.text.trim(),
                sellerPhone: _sellerPhoneController.text.trim().isEmpty
                    ? null
                    : _sellerPhoneController.text.trim(),
                purchaseLocation: _purchaseLocationController.text.trim().isEmpty
                    ? null
                    : _purchaseLocationController.text.trim(),
                photoLocalPath: _photoLocalPath,
                photoCloudUrl: _photoCloudUrl,
                notes: _notesController.text.trim().isEmpty
                    ? null
                    : _notesController.text.trim(),
              ),
            );
      }
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).asData?.value;
    final isSimple = settings?.isSimpleMode ?? true;

    return Scaffold(
      appBar: AppBar(
          title: Text(_existing == null ? 'Nouvel animal' : 'Modifier animal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag, color: AppColors.green),
                  const SizedBox(width: 8),
                  const Text('ID de la ferme : ',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(_farmIdPreview,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PhotoPickerWidget(
              localPath: _photoLocalPath,
              cloudUrl: _photoCloudUrl,
              label: 'Photo',
              onChanged: (path) => setState(() {
                _photoLocalPath = path;
                if (path != null) _photoCloudUrl = null;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Surnom (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(
                labelText: 'Sexe',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: AnimalGender.male, child: Text('Mâle ♂')),
                DropdownMenuItem(value: AnimalGender.female, child: Text('Femelle ♀')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? AnimalGender.male),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _healthStatus,
              decoration: const InputDecoration(
                labelText: 'État de santé',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: HealthStatus.healthy, child: Text('En bonne santé')),
                DropdownMenuItem(value: HealthStatus.sick, child: Text('Malade')),
                DropdownMenuItem(value: HealthStatus.pregnant, child: Text('Gestante')),
              ],
              onChanged: (v) => setState(() => _healthStatus = v ?? HealthStatus.healthy),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date de naissance'),
              subtitle: Text(_formatDate(_birthDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () =>
                  _pickDate(_birthDate, (d) => setState(() => _birthDate = d)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purchasePriceController,
              decoration: const InputDecoration(
                labelText: 'Prix d\'achat (TND)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final n = double.tryParse(v);
                if (n == null) return 'Nombre invalide';
                if (n < 0) return 'Doit être positif';
                return null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date d\'achat'),
              subtitle: Text(_formatDate(_purchaseDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(
                  _purchaseDate, (d) => setState(() => _purchaseDate = d)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellerNameController,
              decoration: const InputDecoration(
                labelText: 'Nom du vendeur',
                border: OutlineInputBorder(),
              ),
            ),
            if (!isSimple) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _sellerPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone du vendeur',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _purchaseLocationController,
                decoration: const InputDecoration(
                  labelText: 'Lieu d\'achat',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _breedController,
                decoration: const InputDecoration(
                  labelText: 'Race',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _colorController,
                decoration: const InputDecoration(
                  labelText: 'Couleur',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Poids (kg)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
