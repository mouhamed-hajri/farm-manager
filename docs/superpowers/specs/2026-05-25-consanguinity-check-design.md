# Consanguinity Check — Design Spec
**Date:** 2026-05-25
**Status:** Approved

## Problem

Breeding two animals that share common ancestry (consanguinity) is harmful in livestock farming. The app currently has no guard against this. Farmers may unknowingly pair related animals, especially as the herd grows across generations.

## Goal

When a farmer saves a mating event with a known father, the app checks whether the mother and father share any common ancestor. If they do, a warning dialog appears showing how close the relationship is. The farmer can still proceed — this is a soft warning, not a block.

## Scope

- Triggers only on **mating events** with a **known father** (not "Père inconnu").
- No UI changes to the father selection grid.
- No depth limit on pedigree traversal — goes as far back as `motherId`/`fatherId` data exists.
- Designed for commercial use across all farms, not farm-specific logic.

---

## Algorithm

### Ancestor Map

`ConsanguinityService.findRelationshipDistance(userId, animalAId, animalBId) → Future<int?>`

1. Build an **ancestor map** for animal A: BFS up the family tree using `motherId` and `fatherId` on each `Animal`. The map stores `{ animalId → generationLevel }` where 0 = the animal itself, 1 = its parents, 2 = grandparents, and so on. Stops naturally when parent IDs are null (unknown ancestors).
2. Build the same map for animal B.
3. Intersect the two maps. For every common ancestor found, compute `distance = levelFromA + levelFromB`.
4. Return the **minimum distance** across all common ancestors. Return `null` if no common ancestor is found (unrelated).

### Distance Labels

| Distance | Meaning | Severity |
|---|---|---|
| `null` | Non apparenté | None — save proceeds silently |
| 1 | Relation directe — parent/enfant | ⛔ Critical |
| 2 | Consanguinité très proche — frères/sœurs | 🔴 High |
| 3 | Consanguinité proche — 3 générations | 🟠 Medium |
| 4 | Apparentés — 4 générations | 🟠 Medium |
| ≥ 5 | Apparentés — N générations | 🟡 Low |

---

## Files

### New: `lib/services/consanguinity_service.dart`

```dart
class ConsanguinityService {
  ConsanguinityService(this._animalRepo);
  final AnimalRepository _animalRepo;

  Future<int?> findRelationshipDistance(
      String userId, String animalAId, String animalBId) async {
    final mapA = await _buildAncestorMap(userId, animalAId);
    final mapB = await _buildAncestorMap(userId, animalBId);

    int? minDistance;
    for (final entry in mapA.entries) {
      if (mapB.containsKey(entry.key)) {
        final d = entry.value + mapB[entry.key]!;
        if (minDistance == null || d < minDistance) minDistance = d;
      }
    }
    return minDistance;
  }

  Future<Map<String, int>> _buildAncestorMap(
      String userId, String startId) async {
    final map = <String, int>{};
    await _traverse(userId, startId, 0, map);
    return map;
  }

  Future<void> _traverse(
      String userId, String id, int level, Map<String, int> map) async {
    if (map.containsKey(id)) return;
    map[id] = level;
    final animal = await _animalRepo.getById(id);
    if (animal == null) return;
    if (animal.motherId != null)
      await _traverse(userId, animal.motherId!, level + 1, map);
    if (animal.fatherId != null)
      await _traverse(userId, animal.fatherId!, level + 1, map);
  }
}
```

### Modified: `lib/providers/core_providers.dart`

Add:
```dart
final consanguinityServiceProvider = Provider<ConsanguinityService>((ref) {
  return ConsanguinityService(ref.watch(animalRepositoryProvider));
});
```

### Modified: `lib/screens/animals/dialogs/add_reproduction_event_dialog.dart`

In `_save()`, after confirming `_type == ReproductionEventType.mating` and `_partnerId != null`, before calling `reproductionEventRepositoryProvider.add()`:

```dart
final distance = await ref
    .read(consanguinityServiceProvider)
    .findRelationshipDistance(widget.mother.userId, widget.mother.id, _partnerId!);

if (distance != null) {
  final confirmed = await _showConsanguinityWarning(context, distance);
  if (!confirmed) {
    setState(() => _loading = false);
    return;
  }
}
```

Add `_showConsanguinityWarning(BuildContext context, int distance) → Future<bool>`:
- Shows `AlertDialog` with title "Consanguinité détectée"
- Body shows the distance label (see table above) with matching color
- Two actions:
  - "Choisir un autre mâle" → returns `false` (cancels save)
  - "Continuer quand même" → returns `true` (save proceeds)

---

## Data Flow

```
User taps "Enregistrer" in mating dialog
  → _save() called
  → _partnerId is set (father known)
  → ConsanguinityService.findRelationshipDistance(mother.id, father.id)
      → BFS ancestor map for mother
      → BFS ancestor map for father
      → intersect maps → return min distance (or null)
  → distance == null → save immediately, no dialog
  → distance != null → show warning dialog
      → "Choisir un autre mâle" → cancel save, farmer picks again
      → "Continuer quand même" → save proceeds normally
```

---

## Edge Cases

- **Unknown father** (`_partnerId == null`): check is skipped entirely.
- **No pedigree data** (both animals have null parents): check returns `null`, no warning.
- **Animal is its own ancestor** (data corruption): the `map.containsKey` guard in `_traverse` prevents infinite loops.
- **Slow traversal on deep pedigrees**: BFS is async; the `_loading` spinner is already shown during `_save()`, so UX is unaffected.
- **Distance 0** (same animal selected as both mother and father): impossible via the UI (males-only filter in `FatherSelectionScreen`), but if it occurs distance = 0 is treated as critical.

---

## Out of Scope

- No changes to the father selection grid (`FatherSelectionScreen`).
- No consanguinity coefficient (Wright's F) — distance count is sufficient for this use case.
- No history logging of consanguinity warnings.
- No per-species configuration of warning thresholds.
