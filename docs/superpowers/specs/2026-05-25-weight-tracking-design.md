# Newborn Weight Tracking — Design Spec
**Date:** 2026-05-25
**Status:** Approved

## Problem

The app currently has only a single `weight` field on `Animal`, which is overwritten each edit. Farmers want to track an animal's growth over time — especially newborns from birth through weaning — to later rate mothers based on offspring growth performance.

## Goal

Let the farmer record multiple weight measurements per animal at any point in life. Show the measurements as a growth chart (weight vs age in days) on the animal profile. The latest measurement implicitly represents the current/weaning weight.

## Scope

- Birth weight can be entered when creating a newborn (in the existing "Créer les jeunes" form).
- Additional weights can be added anytime via a button on the animal profile.
- Growth chart on the animal profile: weight (kg) on Y, age (days) on X.
- Cloud sync follows the existing repository pattern.
- Out of scope: mom-rating logic, reference growth curves, species-specific norms.

## Data Model

### New Drift table: `weight_measurements`

| Column | Type | Constraints |
|---|---|---|
| id | TEXT | primary key (UUID) |
| userId | TEXT | not null |
| animalId | TEXT | not null |
| weight | REAL | not null, kg |
| measurementDate | TEXT | not null, YYYY-MM-DD |
| notes | TEXT | nullable |
| createdAt | TEXT | not null |
| updatedAt | TEXT | not null |
| syncStatus | TEXT | default 'pending' |

Drift schema version bumps from **4 → 5**. Migration adds the new table.

### Dart model

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
  // ... copyWith, toFirestore, fromFirestore
}
```

### Repository

`WeightMeasurementRepository` with:
- `watchForAnimal(userId, animalId) → Stream<List<WeightMeasurement>>` (sorted by date ascending)
- `add(WeightMeasurement)` → assigns id + timestamps, sets syncStatus='pending'
- `delete(id)`
- `getPending(userId)` → for sync
- `markSynced(id)`

### Firestore sync

`FirebaseService` adds:
- `uploadWeightMeasurement(WeightMeasurement)` → writes to `users/{uid}/weightMeasurements/{id}`
- `fetchAllWeightMeasurements(userId)` → returns all
- `deleteWeightMeasurement(userId, id)`

`SyncService.syncPending` includes weight measurements in its pass. `restoreFromCloud` fetches and restores.

## UX

### 1. Birth weight at newborn creation

In `add_edit_animal_screen.dart`, when `birthEventId` is set (creating a newborn from a birth event), an extra optional field appears:

```
[ Poids à la naissance (kg) ]   [optional]
```

If filled, on save the screen creates a `WeightMeasurement` with `measurementDate = birthDate` and `weight = <field value>`. If the field is empty, no measurement is created.

For animals that already exist, this field is hidden (the farmer uses the profile button instead).

### 2. "Croissance" section on the animal profile

A new section in the animal profile (placed after the existing Reproduction tab content, or as a new tab — see Implementation Notes), containing:

**Header row:**
- Title: "Croissance"
- "+ Ajouter" outlined button

**Chart (only if ≥ 2 measurements):**
- `fl_chart` line chart
- X axis: **age in days** (computed as `measurementDate - birthDate`)
- Y axis: **weight in kg**
- Markers at each data point
- Smooth line connecting them
- Y axis auto-scales to data
- X axis auto-scales

If `birthDate` is null, fall back to "days since first measurement" — X axis label changes accordingly.

If only 0 or 1 measurement exists: show a placeholder "Au moins 2 mesures nécessaires pour le graphique."

**Latest reading badge:**
```
Dernier poids: 18.0 kg  (75 jours)
```

**History list** below the chart:
```
• 2026-04-15  18.0 kg  (75 j)   [🗑️]
• 2026-03-22  12.0 kg  (51 j)
• 2026-02-15   2.5 kg  (15 j)
• 2026-02-01   2.0 kg   (0 j)
```

Latest entry on top. Trash icon to delete (with confirm dialog).

### 3. Add weight dialog

`add_weight_measurement_dialog.dart`:

```
┌────────────────────────────────┐
│ Ajouter un poids               │
├────────────────────────────────┤
│ Poids (kg): [______]           │
│ Date:       [2026-05-25] 📅   │
│ Notes:      [____________]     │
├────────────────────────────────┤
│            [Annuler] [Sauver]  │
└────────────────────────────────┘
```

Validation: weight must parse to a positive double; date can't be before the animal's birthDate (if known) or in the future.

## Data Flow

```
User creates newborn with birth weight 2.0 kg
  → AddEditAnimalScreen saves Animal
  → If birthWeightField filled, also saves a WeightMeasurement
       (measurementDate = animal.birthDate, weight = 2.0)

User opens animal profile → Croissance section
  → WeightMeasurementRepository.watchForAnimal streams the list
  → Chart renders, history list renders

User taps "+ Ajouter"
  → Dialog opens
  → On save: WeightMeasurementRepository.add(...)
  → Stream auto-updates chart and list

Background sync (periodic)
  → SyncService.syncPending uploads pending weight measurements to Firestore
```

## Files

| File | Change |
|---|---|
| `lib/database/tables/weight_measurements_table.dart` | **New** |
| `lib/models/weight_measurement.dart` | **New** |
| `lib/repositories/weight_measurement_repository.dart` | **New** |
| `lib/database/app_database.dart` | Register table; bump schema v4→v5; add migration; add queries (watch, insert, delete, getPending, markSynced, getAllForAnimal) |
| `lib/providers/core_providers.dart` | Add `weightMeasurementRepositoryProvider` |
| `lib/services/firebase_service.dart` | Add upload/fetch/delete |
| `lib/services/sync_service.dart` | Include in `syncPending` and `restoreFromCloud` |
| `lib/providers/sync_provider.dart` | Pass new repo into SyncService |
| `lib/main.dart` | Same wiring in background isolate |
| `lib/screens/animals/add_edit_animal_screen.dart` | Add optional birth weight field; save as first measurement |
| `lib/screens/animals/animal_profile_screen.dart` | Add "Croissance" section with chart + list + add button |
| `lib/screens/animals/dialogs/add_weight_measurement_dialog.dart` | **New** dialog |
| `pubspec.yaml` | Add `fl_chart: ^0.69.0` (or current stable) |

## Edge Cases

- **No birth date**: chart X-axis falls back to "days since first measurement". History list shows "?? j" for age.
- **Future measurement date**: dialog validates against today's date.
- **Date before birth date**: dialog validates.
- **Duplicate same-date readings**: allowed; both shown.
- **Delete latest measurement**: chart and "latest" badge update from the next-most-recent one.
- **0 measurements**: section shows empty state with "Ajouter le premier poids" button.
- **Schema migration on existing devices**: drift `onUpgrade` from v4 to v5 creates the new table; no data loss.

## Testing

- Unit tests on the age-in-days computation helper (handles null birthDate, same-day, etc.)
- Manual UI verification: create newborn with birth weight → see chart point → add second weight → chart updates with line → delete latest → "latest" badge reverts.

## Out of Scope (later)

- Mom-rating algorithm using offspring weight gains
- Species/breed reference growth curves
- Export growth chart to image
- Bulk weight entry for multiple animals at once
