import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/breed.dart';
import '../../models/species.dart';
import '../../providers/core_providers.dart';
import '../../theme/app_theme.dart';

class AddEditSpeciesScreen extends ConsumerStatefulWidget {
  const AddEditSpeciesScreen({super.key, this.speciesId});

  final String? speciesId;

  @override
  ConsumerState<AddEditSpeciesScreen> createState() =>
      _AddEditSpeciesScreenState();
}

class _AddEditSpeciesScreenState extends ConsumerState<AddEditSpeciesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameFrController = TextEditingController();
  final _nameArController = TextEditingController();
  final _emojiController = TextEditingController(text: '🐾');
  final _prefixController = TextEditingController();
  bool _isDefault = false;
  bool _prefixManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    if (widget.speciesId != null) _loadExisting();
    _nameFrController.addListener(_onNameFrChanged);
  }

  Future<void> _loadExisting() async {
    final repo = ref.read(speciesRepositoryProvider);
    final s = await repo.getById(widget.speciesId!);
    if (s == null || !mounted) return;
    setState(() {
      _nameFrController.text = s.nameFr;
      _nameArController.text = s.nameAr;
      _emojiController.text = s.iconEmoji;
      _prefixController.text = s.idPrefix;
      _isDefault = s.isDefault;
      _prefixManuallyEdited = true; // don't auto-overwrite when editing
    });
  }

  void _onNameFrChanged() {
    if (_prefixManuallyEdited) return;
    final name = _nameFrController.text.trim();
    if (name.isEmpty) {
      _prefixController.text = '';
      return;
    }
    final prefix = name
        .replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '')
        .toUpperCase()
        .padRight(3, 'X')
        .substring(0, 3);
    if (_prefixController.text != prefix) {
      _prefixController.text = prefix;
    }
  }

  @override
  void dispose() {
    _nameFrController.dispose();
    _nameArController.dispose();
    _emojiController.dispose();
    _prefixController.dispose();
    super.dispose();
  }

  Future<bool> _isPrefixUnique(String prefix) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return true;
    final all = await ref.read(speciesRepositoryProvider).getSpecies(user.uid);
    return !all.any((s) =>
        s.idPrefix.toUpperCase() == prefix.toUpperCase() &&
        s.id != widget.speciesId);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final prefix = _prefixController.text.toUpperCase();
    if (!await _isPrefixUnique(prefix)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Le préfixe "$prefix" est déjà utilisé. Choisissez-en un autre.'),
        backgroundColor: AppColors.red,
      ));
      return;
    }

    final repo = ref.read(speciesRepositoryProvider);
    if (widget.speciesId == null) {
      await repo.addSpecies(Species(
        id: '',
        userId: user.uid,
        nameFr: _nameFrController.text.trim(),
        nameAr: _nameArController.text.trim(),
        iconEmoji: _emojiController.text.trim().isEmpty
            ? '🐾'
            : _emojiController.text.trim(),
        idPrefix: prefix,
        isDefault: _isDefault,
        createdAt: '',
        updatedAt: '',
        syncStatus: 'pending',
      ));
    } else {
      final existing = await repo.getById(widget.speciesId!);
      if (existing == null) return;
      await repo.updateSpecies(existing.copyWith(
        nameFr: _nameFrController.text.trim(),
        nameAr: _nameArController.text.trim(),
        iconEmoji: _emojiController.text.trim(),
        idPrefix: prefix,
      ));
    }
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.speciesId == null
              ? 'Nouvelle espèce'
              : 'Modifier espèce')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameFrController,
              decoration: const InputDecoration(
                labelText: 'Nom (Français)',
                hintText: 'ex. Chèvres',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameArController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'Nom (Arabe)',
                hintText: 'ماعز',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emojiController,
              decoration: const InputDecoration(
                labelText: 'Icône (emoji)',
                hintText: '🐐',
                border: OutlineInputBorder(),
              ),
              maxLength: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prefixController,
              onChanged: (_) => _prefixManuallyEdited = true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                labelText: 'Préfixe (3 lettres)',
                hintText: 'CHE',
                helperText: 'Utilisé pour générer les ID (ex. CHE-2026-0001)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().length != 3) {
                  return '3 lettres requises';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            if (widget.speciesId != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),
              _BreedsSection(speciesId: widget.speciesId!),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreedsSection extends ConsumerStatefulWidget {
  const _BreedsSection({required this.speciesId});
  final String speciesId;

  @override
  ConsumerState<_BreedsSection> createState() => _BreedsSectionState();
}

class _BreedsSectionState extends ConsumerState<_BreedsSection> {
  final _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addBreed() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await ref.read(breedRepositoryProvider).addBreed(
          userId: user.uid,
          speciesId: widget.speciesId,
          name: name,
        );
    _addController.clear();
  }

  Future<void> _deleteBreed(Breed b) async {
    await ref.read(breedRepositoryProvider).deleteBreed(b.id);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final breedsAsync = ref.watch(
      StreamProvider((ref) => ref
          .watch(breedRepositoryProvider)
          .watchBreeds(user.uid, widget.speciesId)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Races',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        breedsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Erreur : $e'),
          data: (breeds) {
            if (breeds.isEmpty) {
              return Text(
                'Aucune race ajoutée.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 4,
              children: breeds
                  .map((b) => Chip(
                        label: Text(b.name),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _deleteBreed(b),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addController,
                decoration: const InputDecoration(
                  labelText: 'Nouvelle race',
                  hintText: 'ex. Lacaune',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _addBreed(),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addBreed,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
