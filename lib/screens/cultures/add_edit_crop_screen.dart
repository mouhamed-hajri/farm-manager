import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/crop.dart';
import '../../providers/core_providers.dart';
import '../../providers/field_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/crop_kind_grid_picker.dart';
import '../../widgets/date_field.dart';
import '../../widgets/photo_picker_widget.dart';

class AddEditCropScreen extends ConsumerStatefulWidget {
  const AddEditCropScreen({super.key, this.cropId, this.preselectedFieldId});

  final String? cropId;
  final String? preselectedFieldId;

  @override
  ConsumerState<AddEditCropScreen> createState() => _AddEditCropScreenState();
}

class _AddEditCropScreenState extends ConsumerState<AddEditCropScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameFrController = TextEditingController();
  final _nameArController = TextEditingController();
  final _emojiController = TextEditingController(text: '🌱');
  final _treeCountController = TextEditingController();
  final _notesController = TextEditingController();
  String _kind = CropKind.tree;
  String _lifecycle = CropLifecycle.perennial;
  DateTime? _plantedDate;
  String? _fieldId;
  String? _photoLocalPath;
  String? _photoCloudUrl;
  bool _showCustomName = false; // true if user picked "Autre" or is editing a non-preset
  Crop? _existing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fieldId = widget.preselectedFieldId;
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
      _treeCountController.text = c.treeCount?.toString() ?? '';
      _notesController.text = c.notes ?? '';
      _kind = c.kind;
      _lifecycle = c.lifecycle;
      _plantedDate =
          c.plantedDate != null ? DateTime.tryParse(c.plantedDate!) : null;
      _fieldId = c.fieldId;
      _photoLocalPath = c.photoLocalPath;
      _photoCloudUrl = c.photoCloudUrl;
      // Reveal manual name fields if the existing crop isn't in the preset catalog.
      _showCustomName =
          !CropPreset.catalog.any((p) => p.nameFr == c.nameFr);
    });
  }

  @override
  void dispose() {
    _nameFrController.dispose();
    _nameArController.dispose();
    _emojiController.dispose();
    _treeCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyPreset(CropPreset p) {
    setState(() {
      _nameFrController.text = p.nameFr;
      _nameArController.text = p.nameAr;
      _emojiController.text = p.iconEmoji;
      _kind = p.kind;
      _lifecycle = p.lifecycle;
      _showCustomName = false;
    });
  }

  void _enableCustom() {
    setState(() {
      _nameFrController.clear();
      _nameArController.clear();
      _emojiController.text = '🌱';
      _showCustomName = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    if (_nameFrController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une culture')),
      );
      return;
    }
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
      seasonMonths: _existing?.seasonMonths ?? const [],
      fieldId: _fieldId,
      areaOrCountText: _existing?.areaOrCountText,
      photoLocalPath: _photoLocalPath,
      photoCloudUrl: _photoCloudUrl,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isDefault: _existing?.isDefault ?? false,
      status: _existing?.status ?? CropStatus.growing,
      lifecycle: _lifecycle,
      plantedDate: _plantedDate?.toIso8601String().substring(0, 10),
      treeCount: int.tryParse(_treeCountController.text.trim()),
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
    final isPerennial = _lifecycle == CropLifecycle.perennial;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _existing == null ? 'Nouvelle culture' : 'Modifier culture'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Crop kind picker ───────────────────────────────────────
            const Text('Type de culture *',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CropKindGridPicker(
              selectedNameFr: _nameFrController.text,
              onPick: _applyPreset,
              onCustomTap: _enableCustom,
            ),

            // Custom-name fields appear only when "Autre" is chosen (or editing
            // an old crop that isn't in the catalog).
            if (_showCustomName) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameFrController,
                decoration: const InputDecoration(
                  labelText: 'Nom (FR) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameArController,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'Nom (AR)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emojiController,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'Icône',
                  border: OutlineInputBorder(),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: CropKind.tree, child: Text('Arbre')),
                  DropdownMenuItem(
                      value: CropKind.crop, child: Text('Grande culture')),
                  DropdownMenuItem(
                      value: CropKind.vegetable, child: Text('Légume')),
                  DropdownMenuItem(
                      value: CropKind.other, child: Text('Autre')),
                ],
                onChanged: (v) => setState(() => _kind = v ?? CropKind.crop),
              ),
            ],

            const SizedBox(height: 16),

            // ─── Lifecycle toggle ───────────────────────────────────────
            const Text('Cycle de vie',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: CropLifecycle.perennial,
                  label: Text('Pérenne'),
                  icon: Icon(Icons.park, size: 18),
                ),
                ButtonSegment(
                  value: CropLifecycle.annual,
                  label: Text('Annuelle'),
                  icon: Icon(Icons.grass, size: 18),
                ),
              ],
              selected: {_lifecycle},
              onSelectionChanged: (s) =>
                  setState(() => _lifecycle = s.first),
            ),
            const SizedBox(height: 4),
            Text(
              isPerennial
                  ? 'Arbre / plante qui vit plusieurs années.'
                  : 'Plantée chaque saison (blé, tomates, …).',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),

            // ─── Field link ─────────────────────────────────────────────
            fieldsAsync.maybeWhen(
              data: (fields) => DropdownButtonFormField<String?>(
                initialValue: _fieldId,
                decoration: const InputDecoration(
                  labelText: 'Champ *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('— Choisir un champ —')),
                  ...fields.map((f) => DropdownMenuItem<String?>(
                      value: f.id, child: Text(f.name))),
                ],
                onChanged: (v) => setState(() => _fieldId = v),
                validator: (v) => v == null ? 'Choisissez un champ' : null,
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // ─── Planted date ───────────────────────────────────────────
            DateField(
              label: isPerennial
                  ? 'Date de plantation (optionnel)'
                  : 'Date de semis (optionnel)',
              initialDate: _plantedDate,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _plantedDate = d),
            ),
            const SizedBox(height: 16),

            // ─── Tree count (only for perennials) ───────────────────────
            if (isPerennial)
              TextFormField(
                controller: _treeCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre d\'arbres (optionnel)',
                  hintText: 'ex: 80',
                  border: OutlineInputBorder(),
                ),
              ),

            if (isPerennial) const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // ─── Photo (optional, at the bottom) ────────────────────────
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8, bottom: 4),
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.photo_outlined, size: 20),
              title: const Text('Photo (optionnel)',
                  style: TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
              children: [
                PhotoPickerWidget(
                  localPath: _photoLocalPath,
                  cloudUrl: _photoCloudUrl,
                  onChanged: (p) => setState(() {
                    _photoLocalPath = p;
                    if (p != null) _photoCloudUrl = null;
                  }),
                ),
              ],
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
}
