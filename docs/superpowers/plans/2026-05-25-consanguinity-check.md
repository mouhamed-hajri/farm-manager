# Consanguinity Check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Warn the farmer when they try to save a mating event with a male that shares ancestry with the female, showing exactly how many generations apart they are.

**Architecture:** A pure-function service (`ConsanguinityService`) builds ancestor maps via in-memory BFS over the already-loaded animal list and returns the minimum generation distance between two animals through a common ancestor. The mating dialog calls this service before saving and shows a warning dialog if a distance is found.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod 2.5, existing `allAnimalsProvider` for animal lookup.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/services/consanguinity_service.dart` | **New.** Pure functions: `findRelationshipDistance` and helpers. No state, no DI. |
| `test/services/consanguinity_service_test.dart` | **New.** Unit tests for all pedigree scenarios. |
| `lib/screens/animals/dialogs/add_reproduction_event_dialog.dart` | **Modify.** Inject check + warning dialog into `_save()`. |

No provider is needed — the service is pure static methods.

---

## Task 1: ConsanguinityService — pure function with full unit tests

**Files:**
- Create: `lib/services/consanguinity_service.dart`
- Create: `test/services/consanguinity_service_test.dart`

This is the entire algorithm. TDD because it's pure logic and easy to test exhaustively.

- [ ] **Step 1: Write the failing test file**

Create `test/services/consanguinity_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:farm_manager/models/animal.dart';
import 'package:farm_manager/services/consanguinity_service.dart';

Animal _animal(String id, {String? motherId, String? fatherId}) => Animal(
      id: id,
      userId: 'u1',
      speciesId: 's1',
      farmId: id,
      gender: AnimalGender.female,
      status: AnimalStatus.active,
      motherId: motherId,
      fatherId: fatherId,
      createdAt: '',
      updatedAt: '',
      syncStatus: 'synced',
    );

Map<String, Animal> _index(List<Animal> animals) =>
    {for (final a in animals) a.id: a};

void main() {
  group('ConsanguinityService.findRelationshipDistance', () {
    test('returns null when animals are unrelated', () {
      final animals = _index([
        _animal('a'),
        _animal('b'),
      ]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 'a', animalBId: 'b');
      expect(d, isNull);
    });

    test('returns null when an animal id is missing from the map', () {
      final animals = _index([_animal('a')]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 'a', animalBId: 'missing');
      expect(d, isNull);
    });

    test('returns 1 when A is the direct parent of B', () {
      final animals = _index([
        _animal('parent'),
        _animal('child', motherId: 'parent'),
      ]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 'parent', animalBId: 'child');
      expect(d, 1);
    });

    test('returns 2 for full siblings (share both parents)', () {
      final animals = _index([
        _animal('mom'),
        _animal('dad'),
        _animal('s1', motherId: 'mom', fatherId: 'dad'),
        _animal('s2', motherId: 'mom', fatherId: 'dad'),
      ]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 's1', animalBId: 's2');
      expect(d, 2);
    });

    test('returns 2 for half-siblings (share one parent)', () {
      final animals = _index([
        _animal('mom'),
        _animal('dad1'),
        _animal('dad2'),
        _animal('h1', motherId: 'mom', fatherId: 'dad1'),
        _animal('h2', motherId: 'mom', fatherId: 'dad2'),
      ]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 'h1', animalBId: 'h2');
      expect(d, 2);
    });

    test('returns 2 for grandparent and grandchild', () {
      final animals = _index([
        _animal('gp'),
        _animal('p', motherId: 'gp'),
        _animal('c', motherId: 'p'),
      ]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 'gp', animalBId: 'c');
      expect(d, 2);
    });

    test('returns 3 for uncle-niece (share grandparent / parent)', () {
      final animals = _index([
        _animal('gp'),
        _animal('p1', motherId: 'gp'),
        _animal('p2', motherId: 'gp'),
        _animal('niece', motherId: 'p1'),
      ]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 'p2', animalBId: 'niece');
      expect(d, 3);
    });

    test('returns 4 for first cousins (share grandparent)', () {
      final animals = _index([
        _animal('gp'),
        _animal('p1', motherId: 'gp'),
        _animal('p2', motherId: 'gp'),
        _animal('c1', motherId: 'p1'),
        _animal('c2', motherId: 'p2'),
      ]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 'c1', animalBId: 'c2');
      expect(d, 4);
    });

    test('returns minimum distance across multiple common ancestors', () {
      final animals = _index([
        _animal('mom'),
        _animal('dad'),
        _animal('s1', motherId: 'mom', fatherId: 'dad'),
        _animal('s2', motherId: 'mom', fatherId: 'dad'),
      ]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 's1', animalBId: 's2');
      expect(d, 2);
    });

    test('does not infinite-loop when an animal is its own ancestor', () {
      final corrupt = Animal(
        id: 'cycle',
        userId: 'u1',
        speciesId: 's1',
        farmId: 'cycle',
        gender: AnimalGender.female,
        status: AnimalStatus.active,
        motherId: 'cycle',
        fatherId: null,
        createdAt: '',
        updatedAt: '',
        syncStatus: 'synced',
      );
      final animals = _index([corrupt, _animal('other')]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 'cycle', animalBId: 'other');
      expect(d, isNull);
    });

    test('returns 0 when both ids are the same animal', () {
      final animals = _index([_animal('a')]);
      final d = ConsanguinityService.findRelationshipDistance(
          animalsById: animals, animalAId: 'a', animalBId: 'a');
      expect(d, 0);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail (service does not exist)**

```bash
flutter test test/services/consanguinity_service_test.dart
```

Expected: FAILS with "Target of URI doesn't exist: 'package:farm_manager/services/consanguinity_service.dart'".

- [ ] **Step 3: Implement the service**

Create `lib/services/consanguinity_service.dart`:

```dart
import '../models/animal.dart';

class ConsanguinityService {
  ConsanguinityService._();

  /// Returns the minimum generation distance between two animals through
  /// a common ancestor, or null if they share no ancestry.
  ///
  /// Distance is the sum of generation levels of the closest common ancestor
  /// from each side. Examples:
  ///   - 0 → same animal
  ///   - 1 → parent / child
  ///   - 2 → full or half siblings, grandparent / grandchild
  ///   - 3 → uncle / niece
  ///   - 4 → first cousins
  static int? findRelationshipDistance({
    required Map<String, Animal> animalsById,
    required String animalAId,
    required String animalBId,
  }) {
    final mapA = _buildAncestorMap(animalsById, animalAId);
    final mapB = _buildAncestorMap(animalsById, animalBId);

    int? minDistance;
    for (final entry in mapA.entries) {
      final levelB = mapB[entry.key];
      if (levelB == null) continue;
      final d = entry.value + levelB;
      if (minDistance == null || d < minDistance) minDistance = d;
    }
    return minDistance;
  }

  static Map<String, int> _buildAncestorMap(
      Map<String, Animal> animalsById, String startId) {
    final map = <String, int>{};
    _traverse(animalsById, startId, 0, map);
    return map;
  }

  static void _traverse(Map<String, Animal> animalsById, String id, int level,
      Map<String, int> map) {
    if (map.containsKey(id)) return;
    map[id] = level;
    final animal = animalsById[id];
    if (animal == null) return;
    final motherId = animal.motherId;
    if (motherId != null) _traverse(animalsById, motherId, level + 1, map);
    final fatherId = animal.fatherId;
    if (fatherId != null) _traverse(animalsById, fatherId, level + 1, map);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/services/consanguinity_service_test.dart
```

Expected: All 11 tests PASS.

- [ ] **Step 5: Run flutter analyze**

```bash
flutter analyze lib/services/consanguinity_service.dart test/services/consanguinity_service_test.dart
```

Expected: No errors.

- [ ] **Step 6: Commit**

```bash
git add lib/services/consanguinity_service.dart test/services/consanguinity_service_test.dart
git commit -m "feat: add ConsanguinityService with pedigree distance check"
```

---

## Task 2: Wire warning dialog into mating save flow

**Files:**
- Modify: `lib/screens/animals/dialogs/add_reproduction_event_dialog.dart`

The dialog will call `findRelationshipDistance` after the farmer presses "Enregistrer" but before saving, only for mating events with a known father. If a distance is returned, show an `AlertDialog` with severity-colored label and two actions.

- [ ] **Step 1: Add imports**

At the top of `lib/screens/animals/dialogs/add_reproduction_event_dialog.dart`, add these imports next to the existing ones:

```dart
import '../../../services/consanguinity_service.dart';
import '../../../providers/animal_provider.dart';
```

- [ ] **Step 2: Add the warning dialog helper method**

Inside the `_AddReproductionEventDialogState` class, **after** `_pickFather()` and **before** `_save()`, add this method:

```dart
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
```

- [ ] **Step 3: Inject the check into `_save()`**

Replace the entire `_save()` method body. Current code (lines 82-120):

```dart
Future<void> _save() async {
  setState(() => _loading = true);
  try {
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
```

Replace with:

```dart
Future<void> _save() async {
  setState(() => _loading = true);
  try {
    // Consanguinity check — only for matings with a known father.
    if (_type == ReproductionEventType.mating && _partnerId != null) {
      final allAnimals = ref.read(allAnimalsProvider).asData?.value ?? const [];
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
```

- [ ] **Step 4: Run flutter analyze**

```bash
flutter analyze lib/screens/animals/dialogs/add_reproduction_event_dialog.dart
```

Expected: No errors. The pre-existing project warnings (`_total` unused, deprecated `value` field) are unrelated.

- [ ] **Step 5: Re-run service unit tests to confirm nothing broke**

```bash
flutter test test/services/consanguinity_service_test.dart
```

Expected: All 11 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/animals/dialogs/add_reproduction_event_dialog.dart
git commit -m "feat: warn on consanguinity when saving mating event"
```

---

## Task 3: Manual verification on emulator

The unit tests cover the algorithm exhaustively. The UI integration needs eyes-on verification because this is a launch-quality feature and the user explicitly wants to refine it with their dad.

**Pre-flight check:** Confirm `emulator-5554` is connected via `adb devices`. If not, start it.

- [ ] **Step 1: Build the debug APK**

```bash
flutter build apk --debug
```

Expected: build completes; `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 2: Install on emulator**

```bash
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
```

Expected: "Success".

- [ ] **Step 3: Launch the app**

```bash
adb -s emulator-5554 shell am start -n com.example.farm_manager/.MainActivity
```

- [ ] **Step 4: Verify the four scenarios manually**

Walk through these scenarios in the running app. After each, take a screenshot via `adb -s emulator-5554 exec-out screencap -p > screen_<scenario>.png` and inspect.

**Scenario A — Unrelated pair (no warning):**
1. Open a female that has no listed mother/father (or whose pedigree doesn't intersect any male's pedigree).
2. Reproduction tab → "Nouveau cycle" → mating event.
3. Pick any male that's truly unrelated.
4. Press "Enregistrer".
5. **Expected:** mating saves immediately, dialog closes, no warning.

**Scenario B — Siblings (distance 2, red):**
1. Find a female whose `motherId` matches a male's `motherId` (full or half siblings).
2. Open her, start a mating, pick that male.
3. Press "Enregistrer".
4. **Expected:** Red warning dialog: "Frères / sœurs — consanguinité très proche". Press "Choisir un autre mâle" — confirm save cancels and you're back in the mating dialog with father still selected.

**Scenario C — Cousins (distance 4, orange):**
1. Find a female and male who share a grandparent but not a parent.
2. Mating → select male → save.
3. **Expected:** Orange warning: "Apparentés à 4 générations". Press "Continuer quand même" — confirm mating saves and dialog closes.

**Scenario D — Unknown father (check skipped):**
1. Female → mating → don't pick a father, leave as "Père inconnu".
2. Save.
3. **Expected:** Saves immediately, no warning even if the female has rich pedigree data.

- [ ] **Step 5: Sanity check the cycle card**

Open the female from Scenario C in the animal profile → Reproduction tab. Confirm the cycle card shows the mating with the correct father.

- [ ] **Step 6: If anything looks wrong**

Stop. Capture a screenshot and logcat:

```bash
adb -s emulator-5554 exec-out screencap -p > screen_bug.png
adb -s emulator-5554 logcat -d -t 200 > logcat_bug.txt
```

Report which scenario failed and what was different from expected.

- [ ] **Step 7: If all four scenarios pass — done**

No commit for this task (verification only).

---

## Self-Review

**Spec coverage:**
- ✅ Pure algorithm spec (BFS ancestor map, intersect, minimum distance) → Task 1
- ✅ Distance label table → Task 2 Step 2 (`_showConsanguinityWarning`)
- ✅ Trigger only on mating with known father → Task 2 Step 3 (guard at top of `_save`)
- ✅ Two-button dialog ("Choisir un autre mâle" / "Continuer quand même") → Task 2 Step 2
- ✅ Cycle detection (animal as its own ancestor) → Task 1 test "does not infinite-loop"
- ✅ Returns null for unrelated / missing IDs → Task 1 tests

**Placeholder scan:**
- No "TBD", "TODO", or "implement later".
- Every step shows complete code or exact commands.

**Type/name consistency:**
- `findRelationshipDistance({animalsById, animalAId, animalBId})` — same signature in service, tests, and dialog.
- `_showConsanguinityWarning(int distance) → Future<bool>` — consistent everywhere.
- `AppColors.red` referenced; confirmed it exists (used elsewhere in this dialog).
- `allAnimalsProvider` confirmed in `lib/providers/animal_provider.dart`.

No gaps found.
