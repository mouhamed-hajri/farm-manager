# Weight Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the farmer to record multiple weight measurements per animal and visualize growth (kg vs age in days) on the animal profile, so the data can later be used to rate mothers.

**Architecture:** New Drift table `weight_measurements`, model + repository following the existing `Breed`/`BreedRepository` pattern. Cloud sync via the existing Firestore sync pipeline. UI consists of an optional birth-weight field in `add_edit_animal_screen.dart` plus a new "Croissance" section in the animal profile using `fl_chart` for the growth curve.

**Tech Stack:** Flutter 3.x, Dart 3.x, Drift, Riverpod 2.5, Firestore, `fl_chart` (new dependency).

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/database/tables/weight_measurements_table.dart` | **New** Drift table definition |
| `lib/models/weight_measurement.dart` | **New** model + copyWith + Firestore I/O |
| `lib/repositories/weight_measurement_repository.dart` | **New** repo following BreedRepository pattern |
| `lib/database/app_database.dart` | Register table, schema v5, migration, queries, companion helper, extension |
| `lib/providers/core_providers.dart` | Add `weightMeasurementRepositoryProvider` |
| `lib/services/firebase_service.dart` | Upload/fetch/delete weight measurements |
| `lib/services/sync_service.dart` | Add to `syncPending` + `restoreFromCloud` |
| `lib/providers/sync_provider.dart` | Pass new repo into SyncService |
| `lib/main.dart` | Same wiring in background isolate |
| `lib/screens/animals/dialogs/add_weight_measurement_dialog.dart` | **New** add-weight dialog |
| `lib/screens/animals/add_edit_animal_screen.dart` | Optional birth-weight field; save as first measurement |
| `lib/screens/animals/animal_profile_screen.dart` | New "Croissance" section: chart + history list + add button |
| `pubspec.yaml` | Add `fl_chart` |

---

## Task 1: Add fl_chart dependency

**Files:** `pubspec.yaml`

- [ ] **Step 1: Open `pubspec.yaml` and add `fl_chart` under `dependencies`**

Add this line in the `dependencies:` block (next to other packages like `flutter_riverpod`):

```yaml
  fl_chart: ^0.69.0
```

- [ ] **Step 2: Fetch the package**

```bash
cd "M:\LENOVO\Desktop\Projects\farm" && flutter pub get
```

Expected: "Got dependencies!" no errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add fl_chart for growth visualization"
```

---

## Task 2: Data layer — table + model + Drift migration v4→v5

**Files:**
- Create: `lib/database/tables/weight_measurements_table.dart`
- Create: `lib/models/weight_measurement.dart`
- Modify: `lib/database/app_database.dart`

- [ ] **Step 1: Create the Drift table**

Create `lib/database/tables/weight_measurements_table.dart`:

```dart
import 'package:drift/drift.dart';

class WeightMeasurementsTable extends Table {
  @override
  String get tableName => 'weight_measurements';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get animalId => text()();
  RealColumn get weight => real()();
  TextColumn get measurementDate => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: Create the model**

Create `lib/models/weight_measurement.dart`:

```dart
class WeightMeasurement {
  final String id;
  final String userId;
  final String animalId;
  final double weight;
  final String measurementDate;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const WeightMeasurement({
    required this.id,
    required this.userId,
    required this.animalId,
    required this.weight,
    required this.measurementDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  WeightMeasurement copyWith({
    String? id,
    String? userId,
    String? animalId,
    double? weight,
    String? measurementDate,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      WeightMeasurement(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        animalId: animalId ?? this.animalId,
        weight: weight ?? this.weight,
        measurementDate: measurementDate ?? this.measurementDate,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'animalId': animalId,
        'weight': weight,
        'measurementDate': measurementDate,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory WeightMeasurement.fromFirestore(Map<String, dynamic> m) =>
      WeightMeasurement(
        id: m['id'] as String,
        userId: m['userId'] as String,
        animalId: m['animalId'] as String,
        weight: (m['weight'] as num).toDouble(),
        measurementDate: m['measurementDate'] as String,
        notes: m['notes'] as String?,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}
```

- [ ] **Step 3: Register table + bump schema in `app_database.dart`**

In `lib/database/app_database.dart`:

(a) After the existing `import 'tables/settings_table.dart';`, add:

```dart
import 'tables/weight_measurements_table.dart';
```

(b) In the `@DriftDatabase(tables: [...])` list (currently ends with `SettingsTable`), add a final entry:

```dart
  SettingsTable,
  WeightMeasurementsTable,
])
```

(c) Bump `schemaVersion` from `4` to `5`:

```dart
  @override
  int get schemaVersion => 5;
```

(d) In the `onUpgrade` callback, add the v5 migration as the last branch (after `if (from < 4) { await m.createTable(breedsTable); }`):

```dart
          if (from < 5) {
            await m.createTable(weightMeasurementsTable);
          }
```

- [ ] **Step 4: Add queries to `app_database.dart`**

At the bottom of the `AppDatabase` class (after the existing breeds queries), add this block:

```dart
  // ─── Weight Measurements ──────────────────────────────────────────────────

  Stream<List<WeightMeasurementsTableData>> watchWeightMeasurementsForAnimal(
          String userId, String animalId) =>
      (select(weightMeasurementsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.animalId.equals(animalId))
            ..orderBy([(t) => OrderingTerm.asc(t.measurementDate)]))
          .watch();

  Future<List<WeightMeasurementsTableData>> getAllWeightMeasurements(
          String userId) =>
      (select(weightMeasurementsTable)
            ..where((t) => t.userId.equals(userId)))
          .get();

  Future<int> insertWeightMeasurement(
          WeightMeasurementsTableCompanion entry) =>
      into(weightMeasurementsTable).insertOnConflictUpdate(entry);

  Future<int> deleteWeightMeasurement(String id) =>
      (delete(weightMeasurementsTable)..where((t) => t.id.equals(id))).go();

  Future<List<WeightMeasurementsTableData>> getPendingWeightMeasurements(
          String userId) =>
      (select(weightMeasurementsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markWeightMeasurementSynced(String id) async {
    await (update(weightMeasurementsTable)..where((t) => t.id.equals(id))).write(
      const WeightMeasurementsTableCompanion(syncStatus: Value('synced')),
    );
  }
```

(e) Update `countPendingSync` to also count pending weight measurements. Find the existing `countPendingSync` method and add this line into the sum (mirror how `breeds` is counted):

```dart
    final weightCount = await (select(weightMeasurementsTable)
              ..where((t) =>
                  t.userId.equals(userId) & t.syncStatus.equals('pending')))
            .get()
            .then((rows) => rows.length);
    // ... add weightCount to the total
```

(f) At the very bottom of the file, after the existing `extension BreedDataExt on BreedsTableData {...}`, add:

```dart
extension WeightMeasurementDataExt on WeightMeasurementsTableData {
  WeightMeasurement toModel() => WeightMeasurement(
        id: id,
        userId: userId,
        animalId: animalId,
        weight: weight,
        measurementDate: measurementDate,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}
```

And add the import at the top of the file (near the other model imports):

```dart
import '../models/weight_measurement.dart';
```

- [ ] **Step 5: Regenerate Drift code**

```bash
cd "M:\LENOVO\Desktop\Projects\farm" && dart run build_runner build --delete-conflicting-outputs
```

Expected: "Succeeded after Xs". No errors. The file `app_database.g.dart` gets new `WeightMeasurementsTableData` and `WeightMeasurementsTableCompanion` classes.

- [ ] **Step 6: Run analyzer**

```bash
flutter analyze lib/database/app_database.dart lib/database/tables/weight_measurements_table.dart lib/models/weight_measurement.dart
```

Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/database/tables/weight_measurements_table.dart lib/models/weight_measurement.dart lib/database/app_database.dart lib/database/app_database.g.dart
git commit -m "feat: add weight_measurements table + model (schema v5)"
```

---

## Task 3: Repository

**Files:** Create `lib/repositories/weight_measurement_repository.dart`

- [ ] **Step 1: Create the repository file**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/weight_measurement.dart';

class WeightMeasurementRepository {
  WeightMeasurementRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<WeightMeasurement>> watchForAnimal(
          String userId, String animalId) =>
      _db.watchWeightMeasurementsForAnimal(userId, animalId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<WeightMeasurement> add(WeightMeasurement m) async {
    final now = DateTime.now().toIso8601String();
    final toSave = m.copyWith(
      id: m.id.isEmpty ? _uuid.v4() : m.id,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertWeightMeasurement(WeightMeasurementsTableCompanion(
      id: Value(toSave.id),
      userId: Value(toSave.userId),
      animalId: Value(toSave.animalId),
      weight: Value(toSave.weight),
      measurementDate: Value(toSave.measurementDate),
      notes: Value(toSave.notes),
      createdAt: Value(toSave.createdAt),
      updatedAt: Value(toSave.updatedAt),
      syncStatus: Value(toSave.syncStatus),
    ));
    return toSave;
  }

  Future<void> delete(String id) => _db.deleteWeightMeasurement(id);

  Future<List<WeightMeasurement>> getPending(String userId) async {
    final rows = await _db.getPendingWeightMeasurements(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) =>
      _db.markWeightMeasurementSynced(id);
}
```

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze lib/repositories/weight_measurement_repository.dart
```

Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/repositories/weight_measurement_repository.dart
git commit -m "feat: add WeightMeasurementRepository"
```

---

## Task 4: Wire provider + Firebase service + sync service + main.dart

**Files:**
- Modify: `lib/providers/core_providers.dart`
- Modify: `lib/services/firebase_service.dart`
- Modify: `lib/services/sync_service.dart`
- Modify: `lib/providers/sync_provider.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Add provider in `core_providers.dart`**

Add this import at the top:

```dart
import '../repositories/weight_measurement_repository.dart';
```

After the existing `breedRepositoryProvider`, add:

```dart
final weightMeasurementRepositoryProvider =
    Provider<WeightMeasurementRepository>((ref) {
  return WeightMeasurementRepository(ref.watch(appDatabaseProvider));
});
```

- [ ] **Step 2: Add Firebase methods in `firebase_service.dart`**

Add the import:

```dart
import '../models/weight_measurement.dart';
```

After the existing `Breeds` section, add this section:

```dart
  // ─── Weight Measurements ──────────────────────────────────────────────────

  Future<void> uploadWeightMeasurement(WeightMeasurement m) =>
      _coll(m.userId, 'weightMeasurements')
          .doc(m.id)
          .set(m.toFirestore(), SetOptions(merge: true));

  Future<List<WeightMeasurement>> fetchAllWeightMeasurements(
      String userId) async {
    final snap = await _coll(userId, 'weightMeasurements').get();
    return snap.docs
        .map((d) => WeightMeasurement.fromFirestore(d.data()))
        .toList();
  }

  Future<void> deleteWeightMeasurement(String userId, String id) =>
      _coll(userId, 'weightMeasurements').doc(id).delete();
```

- [ ] **Step 3: Add to SyncService in `sync_service.dart`**

Add the import:

```dart
import '../repositories/weight_measurement_repository.dart';
```

Add to the constructor parameters (in the existing `required:` block, after `breedRepo`):

```dart
    required this.weightMeasurementRepo,
```

Add the field (after `BreedRepository breedRepo`):

```dart
  final WeightMeasurementRepository weightMeasurementRepo;
```

In `syncPending`, add this loop right after the Health section (look for `// Health` … `await healthRepo.markSynced…` block):

```dart
      // Weight measurements
      for (final m in await weightMeasurementRepo.getPending(userId)) {
        await firebaseService.uploadWeightMeasurement(m);
        await weightMeasurementRepo.markSynced(m.id);
        uploaded++;
      }
```

In `restoreFromCloud`, after the existing breed restore, add:

```dart
      final weights = await firebaseService.fetchAllWeightMeasurements(userId);
```

And include `weights` in the `db.restoreFromCloud(...)` call. Then update `db.restoreFromCloud` signature in `app_database.dart` to accept `List<WeightMeasurement> weights` (mirror how `breeds` was added). Inside `restoreFromCloud`, add after the breed batch:

```dart
        batch.deleteWhere(weightMeasurementsTable, (t) => t.userId.equals(userId));
        for (final m in weights) {
          batch.insert(weightMeasurementsTable, WeightMeasurementsTableCompanion(
            id: Value(m.id),
            userId: Value(m.userId),
            animalId: Value(m.animalId),
            weight: Value(m.weight),
            measurementDate: Value(m.measurementDate),
            notes: Value(m.notes),
            createdAt: Value(m.createdAt),
            updatedAt: Value(m.updatedAt),
            syncStatus: const Value('synced'),
          ));
        }
```

- [ ] **Step 4: Wire it in `sync_provider.dart`**

In `lib/providers/sync_provider.dart`, in the SyncService construction, add:

```dart
    weightMeasurementRepo: ref.watch(weightMeasurementRepositoryProvider),
```

- [ ] **Step 5: Wire it in `main.dart` (background isolate)**

In `lib/main.dart`, after `final breedRepo = BreedRepository(db);`, add:

```dart
        final weightMeasurementRepo = WeightMeasurementRepository(db);
```

Add the import at the top:

```dart
import 'repositories/weight_measurement_repository.dart';
```

In the `SyncService(...)` block, add:

```dart
          weightMeasurementRepo: weightMeasurementRepo,
```

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/providers/core_providers.dart lib/services/firebase_service.dart lib/services/sync_service.dart lib/providers/sync_provider.dart lib/main.dart lib/database/app_database.dart
```

Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add lib/providers/core_providers.dart lib/services/firebase_service.dart lib/services/sync_service.dart lib/providers/sync_provider.dart lib/main.dart lib/database/app_database.dart
git commit -m "feat: wire WeightMeasurementRepository into sync pipeline"
```

---

## Task 5: Add weight measurement dialog

**Files:** Create `lib/screens/animals/dialogs/add_weight_measurement_dialog.dart`

- [ ] **Step 1: Create the dialog**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/animal.dart';
import '../../../models/weight_measurement.dart';
import '../../../providers/core_providers.dart';
import '../../../theme/app_theme.dart';

class AddWeightMeasurementDialog extends ConsumerStatefulWidget {
  const AddWeightMeasurementDialog({super.key, required this.animal});

  final Animal animal;

  @override
  ConsumerState<AddWeightMeasurementDialog> createState() =>
      _AddWeightMeasurementDialogState();
}

class _AddWeightMeasurementDialogState
    extends ConsumerState<AddWeightMeasurementDialog> {
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final raw = _weightCtrl.text.trim().replaceAll(',', '.');
    final weight = double.tryParse(raw);
    if (weight == null || weight <= 0) {
      setState(() => _error = 'Poids invalide');
      return;
    }
    final dateStr = _date.toIso8601String().substring(0, 10);
    final birth = widget.animal.birthDate;
    if (birth != null && dateStr.compareTo(birth) < 0) {
      setState(() => _error = 'La date ne peut pas être avant la naissance');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(weightMeasurementRepositoryProvider)
          .add(WeightMeasurement(
            id: '',
            userId: widget.animal.userId,
            animalId: widget.animal.id,
            weight: weight,
            measurementDate: dateStr,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            createdAt: '',
            updatedAt: '',
            syncStatus: 'pending',
          ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Erreur : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un poids'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _weightCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Poids (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _date.toIso8601String().substring(0, 10),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const Icon(Icons.edit, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      const TextStyle(color: AppColors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
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
```

- [ ] **Step 2: Analyze**

```bash
flutter analyze lib/screens/animals/dialogs/add_weight_measurement_dialog.dart
```

Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/animals/dialogs/add_weight_measurement_dialog.dart
git commit -m "feat: add AddWeightMeasurementDialog"
```

---

## Task 6: Add birth-weight field to add_edit_animal_screen.dart

**Files:** Modify `lib/screens/animals/add_edit_animal_screen.dart`

- [ ] **Step 1: Add imports**

At the top of the file, next to other model imports:

```dart
import '../../models/weight_measurement.dart';
```

- [ ] **Step 2: Add a controller field in the State class**

Inside the `_AddEditAnimalScreenState` class, next to the other `TextEditingController` fields, add:

```dart
  final _birthWeightCtrl = TextEditingController();
```

And dispose it in the `dispose()` method:

```dart
    _birthWeightCtrl.dispose();
```

- [ ] **Step 3: Render the field — only when creating a newborn**

Find the part of `build()` where breed/color/etc. fields are rendered. The "newborn" flow is identified by `_birthEventId != null` (passed via `extra`). Add this field block right after the birthDate picker section (look for `birthDate` related widget):

```dart
            if (_birthEventId != null && !_isEditing) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _birthWeightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Poids à la naissance (kg) — optionnel',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
```

(Use whatever variable names already exist in this file for "is creating newborn"; adapt names if `_isEditing` / `_birthEventId` differ.)

- [ ] **Step 4: Save the measurement after the animal**

Find the save logic in `_save()` (or whatever the save method is named). After the animal is created (`addAnimal(...)` call), add:

```dart
      final birthWeightRaw =
          _birthWeightCtrl.text.trim().replaceAll(',', '.');
      final birthWeight = double.tryParse(birthWeightRaw);
      if (birthWeight != null &&
          birthWeight > 0 &&
          savedAnimal.birthDate != null) {
        await ref
            .read(weightMeasurementRepositoryProvider)
            .add(WeightMeasurement(
              id: '',
              userId: savedAnimal.userId,
              animalId: savedAnimal.id,
              weight: birthWeight,
              measurementDate: savedAnimal.birthDate!,
              notes: 'Poids à la naissance',
              createdAt: '',
              updatedAt: '',
              syncStatus: 'pending',
            ));
      }
```

(Adapt `savedAnimal` to whatever variable holds the result of `addAnimal()` in the actual file.)

- [ ] **Step 5: Analyze**

```bash
flutter analyze lib/screens/animals/add_edit_animal_screen.dart
```

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/animals/add_edit_animal_screen.dart
git commit -m "feat: capture birth weight when creating newborn"
```

---

## Task 7: Add "Croissance" section to animal profile

**Files:** Modify `lib/screens/animals/animal_profile_screen.dart`

- [ ] **Step 1: Add imports**

At the top of the file:

```dart
import 'package:fl_chart/fl_chart.dart';
import '../../models/weight_measurement.dart';
import 'dialogs/add_weight_measurement_dialog.dart';
```

- [ ] **Step 2: Add a stream provider near the top of the file (outside any class)**

After existing top-level providers (if any), add:

```dart
final _weightsForAnimalProvider =
    StreamProvider.family.autoDispose<List<WeightMeasurement>, ({String userId, String animalId})>((ref, key) {
  return ref
      .read(weightMeasurementRepositoryProvider)
      .watchForAnimal(key.userId, key.animalId);
});
```

- [ ] **Step 3: Build the Croissance section widget**

Add this widget class at the bottom of the file (next to the other widget classes in the file):

```dart
class _CroissanceSection extends ConsumerWidget {
  const _CroissanceSection({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_weightsForAnimalProvider(
        (userId: animal.userId, animalId: animal.id)));

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, color: AppColors.green),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Croissance',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) =>
                        AddWeightMeasurementDialog(animal: animal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erreur : $e'),
              data: (list) => _content(context, ref, list),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref,
      List<WeightMeasurement> list) {
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Aucune mesure. Ajoutez un poids pour démarrer le suivi de croissance.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final sorted = [...list]
      ..sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
    final birth = animal.birthDate != null
        ? DateTime.tryParse(animal.birthDate!)
        : null;

    int ageDays(WeightMeasurement m) {
      final d = DateTime.tryParse(m.measurementDate);
      if (d == null) return 0;
      final ref = birth ?? DateTime.tryParse(sorted.first.measurementDate);
      if (ref == null) return 0;
      return d.difference(ref).inDays;
    }

    final latest = sorted.last;
    final latestAge = ageDays(latest);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sorted.length >= 2)
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('âge (jours)',
                        style: TextStyle(fontSize: 10)),
                    sideTitles: const SideTitles(
                        showTitles: true, reservedSize: 26),
                  ),
                  leftTitles: AxisTitles(
                    axisNameWidget: const Text('kg',
                        style: TextStyle(fontSize: 10)),
                    sideTitles: const SideTitles(
                        showTitles: true, reservedSize: 32),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (final m in sorted)
                        FlSpot(ageDays(m).toDouble(), m.weight)
                    ],
                    isCurved: false,
                    color: AppColors.green,
                    barWidth: 2,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Au moins 2 mesures sont nécessaires pour afficher le graphique.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        const SizedBox(height: 10),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Dernier poids : ${latest.weight.toStringAsFixed(1)} kg ($latestAge j)',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.green),
          ),
        ),
        const SizedBox(height: 10),
        const Text('Historique',
            style:
                TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        ...sorted.reversed.map((m) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle, size: 8, color: AppColors.green),
              title: Text(
                  '${m.weight.toStringAsFixed(1)} kg · ${m.measurementDate} (${ageDays(m)} j)',
                  style: const TextStyle(fontSize: 13)),
              subtitle: m.notes == null
                  ? null
                  : Text(m.notes!,
                      style: const TextStyle(fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.grey),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Supprimer cette mesure ?'),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, false),
                            child: const Text('Annuler')),
                        ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.red,
                                foregroundColor: Colors.white),
                            child: const Text('Supprimer')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref
                        .read(weightMeasurementRepositoryProvider)
                        .delete(m.id);
                  }
                },
              ),
            )),
      ],
    );
  }
}
```

- [ ] **Step 4: Insert the section into the profile UI**

Find the profile body's main `Column` / `ListView` (likely in the existing _ProfileTab or similar). After the existing financial/reproduction sections, add:

```dart
            _CroissanceSection(animal: animal),
```

(Choose location based on the existing tab structure — for the simplest path, append it inside the "Info" tab below the existing content.)

- [ ] **Step 5: Analyze**

```bash
flutter analyze lib/screens/animals/animal_profile_screen.dart
```

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/animals/animal_profile_screen.dart
git commit -m "feat: add growth chart + history to animal profile"
```

---

## Task 8: Build, install, manual verification

- [ ] **Step 1: Build the debug APK**

```bash
cd "M:\LENOVO\Desktop\Projects\farm" && flutter build apk --debug
```

Expected: `Built build\app\outputs\flutter-apk\app-debug.apk`.

- [ ] **Step 2: Install on phone and launch**

```bash
adb -s 192.168.100.46:43173 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s 192.168.100.46:43173 shell monkey -p com.example.farm_manager -c android.intent.category.LAUNCHER 1
```

- [ ] **Step 3: Verify the four scenarios**

**A — Birth weight at newborn creation:**
1. Open an existing mother → mating cycle → record birth with offspring count 1.
2. Tap "Créer les jeunes" → fill the form → enter "Poids à la naissance" = 2.5 → save.
3. Open the new newborn's profile → scroll to **Croissance** → expect 1 entry: "2.5 kg · YYYY-MM-DD (0 j)".

**B — Add subsequent weights:**
1. On the newborn's profile, tap **"+ Ajouter"** in Croissance.
2. Enter weight 8.0 kg, date 30 days after birth → save.
3. Expect: chart appears with 2 points + line, history shows both entries with ages "0 j" and "30 j".

**C — Delete a measurement:**
1. Long/tap the trash icon on the latest entry → confirm.
2. Expect: chart updates, "Dernier poids" reverts to the previous one.

**D — Animal without birth date:**
1. Open an animal that has no birthDate → add 2 weight measurements → expect chart to render using "days since first measurement" as X axis.

- [ ] **Step 4: Inspect Firestore sync**

After a sync run (background or restart), check Firebase Console → Firestore → `users/<uid>/weightMeasurements` → confirm the measurements appear.

If anything fails, capture screenshot + logcat:

```bash
adb -s 192.168.100.46:43173 exec-out screencap -p > screen_bug.png
adb -s 192.168.100.46:43173 logcat -d -t 200 > logcat_bug.txt
```

- [ ] **Step 5: If all four scenarios pass — done**

No commit (verification only).

---

## Self-Review

**Spec coverage:**
- ✅ New table + model + repo → Tasks 2, 3
- ✅ Schema v5 migration → Task 2 Step 3 (d)
- ✅ Firebase sync upload/fetch/delete → Task 4 Steps 2, 3
- ✅ Background isolate wiring → Task 4 Step 5
- ✅ Birth weight field in newborn form → Task 6
- ✅ Croissance section with chart + history + add button → Task 7
- ✅ Add dialog with validation → Task 5
- ✅ fl_chart dependency → Task 1
- ✅ Edge cases: no birthDate fallback, future/before-birth date validation, delete confirm

**Placeholder scan:**
- The two places marked "Adapt … to whatever variable holds …" in Task 6 are necessary because the exact variable names in `add_edit_animal_screen.dart` weren't visible in the spec. The implementing engineer must read the file first.
- No "TBD"/"TODO"/"implement later".

**Type / name consistency:**
- Table class: `WeightMeasurementsTable`, instance: `weightMeasurementsTable` — consistent everywhere.
- Model: `WeightMeasurement` — consistent.
- Repository: `WeightMeasurementRepository`, provider: `weightMeasurementRepositoryProvider`, sync field: `weightMeasurementRepo` — consistent.
- Method names: `watchForAnimal`, `add`, `delete`, `getPending`, `markSynced` — consistent with `Breed`/`ReproductionEvent` patterns.

No gaps.
