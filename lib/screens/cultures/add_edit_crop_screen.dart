import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/crop.dart';
import '../../providers/core_providers.dart';
import '../../providers/field_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_picker_widget.dart';

class AddEditCropScreen extends ConsumerStatefulWidget {
  const AddEditCropScreen({super.key, this.cropId});

  final String? cropId;

  @override
  ConsumerState<AddEditCropScreen> createState() => _AddEditCropScreenState();
}

class _AddEditCropScreenState extends ConsumerState<AddEditCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameFrController = TextEditingController();
  final _nameArController = TextEditingController();
  final _emojiController = TextEditingController(text: '🌱');
  final _areaController = TextEditingController();
  final _notesController = TextEditingController();
  String _kind = CropKind.crop;
  bool _isYearRound = false;
  final Set<int> _seasonMonths = {};
  String? _fieldId;
  String? _photoLocalPath;
  String? _photoCloudUrl;
  Crop? _existing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.cropId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final c = await ref.read(cropRepositoryProvider).getById(widget.cropId!);
    if (c == null || !mounted) return;
    setState(() {
      _existing = c;
      _nameFrController.text = c.nameFr;
      _nameArController.text = c.nameAr;
      _emojiController.text = c.iconEmoji;
      _areaController.text = c.areaOrCountText ?? '';
      _notesController.text = c.notes ?? '';
      _kind = c.kind;
      _isYearRound = c.isYearRound;
      _seasonMonths
        ..clear()
        ..addAll(c.seasonMonths);
      _fieldId = c.fieldId;
      _photoLocalPath = c.photoLocalPath;
      _photoCloudUrl = c.photoCloudUrl;
    });
  }

  @override
  void dispose() {
    _nameFrController.dispose();
    _nameArController.dispose();
    _emojiController.dispose();
    _areaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _loading = true);

    final now = DateTime.now().toIso8601String();
    final crop = Crop(
      id: _existing?.id ?? '',
      userId: user.uid,
      nameFr: _nameFrController.text.trim(),
      nameAr: _nameArController.text.trim(),
      iconEmoji: _emojiController.text.trim().isEmpty
          ? '🌱'
          : _emojiController.text.trim(),
      kind: _kind,
      seasonMonths: _isYearRound ? const [] : _seasonMonths.toList()
        ..sort(),
      fieldId: _fieldId,
      areaOrCountText: _areaController.text.trim().isEmpty
          ? null
          : _areaController.text.trim(),
      photoLocalPath: _photoLocalPath,
      photoCloudUrl: _photoCloudUrl,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isDefault: _existing?.isDefault ?? false,
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
      syncStatus: 'pending',
    );

    try {
      final repo = ref.read(cropRepositoryProvider);
      if (_existing == null) {
        await repo.addCrop(crop);
      } else {
        await repo.updateCrop(crop);
      }
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(fieldsListProvider);
    return Scaffold(
      appBar: AppBar(
          title:
              Text(_existing == null ? 'Nouvelle culture' : 'Modifier culture')),
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
              controller: _nameFrController,
              decoration: const InputDecoration(
                  labelText: 'Nom (FR) *', border: OutlineInputBorder()),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameArController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                  labelText: 'Nom (AR)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emojiController,
              maxLength: 2,
              decoration: const InputDecoration(
                  labelText: 'Icône', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(
                  labelText: 'Type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: CropKind.tree, child: Text('Arbre')),
                DropdownMenuItem(value: CropKind.crop, child: Text('Culture')),
                DropdownMenuItem(value: CropKind.vegetable, child: Text('Légume')),
                DropdownMenuItem(value: CropKind.other, child: Text('Autre')),
              ],
              onChanged: (v) => setState(() => _kind = v ?? CropKind.crop),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _areaController,
              decoration: const InputDecoration(
                labelText: 'Quantité / surface (libre)',
                hintText: '200 arbres, 1 hectare, etc.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            fieldsAsync.maybeWhen(
              data: (fields) => DropdownButtonFormField<String?>(
                initialValue: _fieldId,
                decoration: const InputDecoration(
                  labelText: 'Champ (optionnel)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Aucun')),
                  ...fields.map((f) => DropdownMenuItem<String?>(
                      value: f.id, child: Text(f.name))),
                ],
                onChanged: (v) => setState(() => _fieldId = v),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Toute l\'année'),
              value: _isYearRound,
              onChanged: (v) => setState(() {
                _isYearRound = v;
                if (v) _seasonMonths.clear();
              }),
            ),
            if (!_isYearRound) ...[
              const SizedBox(height: 4),
              const Text('Mois de saison :',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(12, (i) {
                  final m = i + 1;
                  final on = _seasonMonths.contains(m);
                  return FilterChip(
                    label: Text(_monthShort(m)),
                    selected: on,
                    onSelected: (sel) => setState(() {
                      sel ? _seasonMonths.add(m) : _seasonMonths.remove(m);
                    }),
                  );
                }),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                  labelText: 'Notes', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.save),
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

  String _monthShort(int m) {
    const names = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return names[m - 1];
  }
}
