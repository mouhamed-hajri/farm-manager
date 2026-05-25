# Female Rating System — Design Spec

**Date:** 2026-05-25  
**Status:** Approved  

---

## Overview

A 5-metric star-based rating system for female animals. Helps farmers identify their best-performing females at a glance and make informed breeding decisions. Displayed on the animal profile, animal list cards, and a dedicated ranking screen.

---

## Metrics

### 1. Productivité / an
- **Source:** Count of `birth` ReproductionEvents for the female ÷ years since first mating event to today (or death/sale date)
- **Thresholds:**
  - ★ < 0.5/year
  - ★★ 0.5–0.99/year
  - ★★★ 1.0–1.49/year
  - ★★★★ 1.5–1.99/year
  - ★★★★★ ≥ 2.0/year
- **No data:** "—" if no birth events recorded

### 2. Portée moyenne (litter size)
- **Source:** Average of `offspringCount` across all birth ReproductionEvents
- **Scoring:** Species-relative percentile — compared against all females of the same species in the farm
  - ★ bottom 20th percentile
  - ★★ 20th–40th
  - ★★★ 40th–60th
  - ★★★★ 60th–80th
  - ★★★★★ top 20th
- **Edge case:** If only 1 female of that species exists, show raw average value (e.g., "1.5 avg") without star score
- **No data:** "—" if no birth events recorded

### 3. Taux de survie
- **Source:** Count of offspring with `status != 'dead'` (active + sold both count as survived) ÷ sum of `offspringCount` across all birth events
- **Thresholds:**
  - ★ < 50%
  - ★★ 50–64%
  - ★★★ 65–79%
  - ★★★★ 80–94%
  - ★★★★★ ≥ 95%
- **No data:** "—" if no birth events recorded

### 4. Croissance sevrage (weaning weight gain %)
- **Source:** Per offspring: gain% = (last WeightMeasurement − first WeightMeasurement) / first × 100. Only included if offspring has ≥ 2 measurements. Final score = average across all included offspring.
- **Thresholds:**
  - ★ < 50% gain
  - ★★ 50–99%
  - ★★★ 100–149%
  - ★★★★ 150–199%
  - ★★★★★ ≥ 200%
- **No data:** "—" if no offspring have ≥ 2 weight measurements

### 5. Santé (health)
- **Source:** Count of `sick` health events ÷ years since first health event (or first mating, whichever is earlier)
- **Thresholds:**
  - ★ > 2 illnesses/year
  - ★★ 1–2/year
  - ★★★ 0.5–1.0/year
  - ★★★★ ≤ 0.5/year
  - ★★★★★ 0 illnesses recorded
- **No data:** "—" if no health events recorded

### Composite Score
- Average of all non-null metric scores (1–5 metrics)
- Displayed as half-star increments (rounded to nearest 0.5)
- Null if all 5 metrics have no data

---

## Health Event Log

### Data model — `health_events` table (schema v6)
| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | UUID |
| userId | TEXT | owner |
| animalId | TEXT | FK to animals |
| eventType | TEXT | `'sick'` or `'recovered'` |
| eventDate | TEXT | ISO yyyy-MM-dd |
| notes | TEXT nullable | optional notes |
| createdAt | TEXT | ISO datetime |
| updatedAt | TEXT | ISO datetime |
| syncStatus | TEXT | default `'pending'` |

### UI — Add health event dialog
- Fields: event type (Maladie / Guérison), date (date picker), notes (optional)
- Validation: eventDate required, eventType required

---

## UI

### Animal Profile — Two new cards in InfoTab

**Card 1: Notation femelle** (green left border)
- Composite score at top: stars + numeric (e.g., "4.0 / 5")
- Divider
- 5 metric rows: icon + label + progress bar + mini star score
- Metrics with no data show "—" in grey, progress bar empty

**Card 2: Historique Santé** (red left border)
- "+" button in header to add a health event
- Chronological timeline of sick/recovered events (newest first)
- Each event: colored dot (red=sick, green=recovered) + label + date + optional notes
- "Aucun événement santé enregistré" placeholder when empty
- "+ Ajouter événement santé" button at bottom

### Animal List Card
- Female cards show composite star score in top-right
- Males and females with no data: no badge shown

### Ranking Screen (`FemaleRankingScreen`)
- Accessible from: app bar action button on the animal list screen (trophy icon) and home dashboard
- Shows all females sorted by composite score descending
- Each row: rank number + photo + name + two key stat hints (births/year, survival%) + star score + numeric
- Females with no composite score shown at bottom, greyed out, labelled "Pas encore notée"
- Title: "Classement femelles · Toutes espèces"

---

## Architecture

### New files
| File | Purpose |
|---|---|
| `lib/models/health_event.dart` | HealthEvent model, copyWith, toFirestore, fromFirestore |
| `lib/database/tables/health_events_table.dart` | Drift table definition |
| `lib/repositories/health_event_repository.dart` | watchForAnimal, add, delete, getPending, markSynced |
| `lib/models/female_rating.dart` | FemaleRating with 5 nullable scores + composite + raw values |
| `lib/services/female_rating_service.dart` | Pure static FemaleRatingService.compute() — takes in-memory data, no async |
| `lib/screens/animals/dialogs/add_health_event_dialog.dart` | Add health event dialog |
| `lib/screens/animals/female_ranking_screen.dart` | Sorted leaderboard screen |

### Modified files
| File | Change |
|---|---|
| `lib/database/app_database.dart` | Add HealthEventsTable, bump schema to v6, migration, sync queries |
| `lib/providers/core_providers.dart` | Add healthEventRepositoryProvider, femaleRatingProvider(animalId) |
| `lib/services/firebase_service.dart` | uploadHealthEvent, fetchAllHealthEvents, deleteHealthEvent |
| `lib/services/sync_service.dart` | Sync loop for health events in syncPending and restoreFromCloud |
| `lib/main.dart` | Pass healthEventRepo to AnimalRepository/SyncService in background isolate |
| `lib/screens/animals/animal_profile_screen.dart` | Add _NotationSection and _SanteSection widgets in InfoTab |
| `lib/screens/animals/animal_list_screen.dart` | Composite star badge on female list cards |
| `lib/screens/home/home_dashboard_screen.dart` | Entry point button/card for ranking screen |

### FemaleRatingService interface
```dart
class FemaleRatingService {
  FemaleRatingService._();

  static FemaleRating compute({
    required Animal female,
    required List<ReproductionEvent> events,       // all events for this female
    required List<Animal> offspring,                // animals where motherId == female.id
    required Map<String, List<WeightMeasurement>> weightsByOffspring,
    required List<Animal> speciesPeers,             // other active females of same species
    required Map<String, List<ReproductionEvent>> peersEvents, // birth events by peer id
    required List<HealthEvent> healthEvents,        // all health events for this female
  }) { ... }
}
```

### FemaleRating model
```dart
class FemaleRating {
  final double? productiviteScore;   // 1–5 or null
  final double? porteeScore;         // 1–5 or null (species-relative)
  final double? survieScore;         // 1–5 or null
  final double? croissanceScore;     // 1–5 or null
  final double? santeScore;          // 1–5 or null
  final double? composite;           // average of non-null scores, null if all null

  // Raw values for display hints on ranking screen
  final double? birthsPerYear;
  final double? avgLitterSize;
  final double? survivalRate;
  final double? avgWeaningGainPercent;
  final double? illnessesPerYear;
}
```

### Provider
`femaleRatingProvider(String animalId)` — `StreamProvider.family` that watches the underlying streams (reproduction events, offspring animals, weight measurements, health events, species peers) and re-emits a new `FemaleRating` whenever any of those change. Internally combines multiple `watchX()` streams and calls `FemaleRatingService.compute()` on each emission.

---

## Edge Cases

| Scenario | Handling |
|---|---|
| Female has 0 births | All reproductive metrics show "—"; composite null |
| Only 1 female of a species | Portée shows raw avg, no star score |
| Offspring has only 1 weight measurement | Excluded from croissance calculation |
| Health events recorded but no illnesses | Santé = ★★★★★ |
| Female sold or dead | Use sale/death date as end date for births/year and illnesses/year calculation |
| All 5 metrics are "—" | No composite shown; profile shows "Données insuffisantes" |

---

## Firebase Sync

Health events sync using the same pattern as weight measurements:
- `users/{uid}/healthEvents/{id}` Firestore path
- syncPending uploads pending events, marks synced
- restoreFromCloud fetches and upserts all health events
- Firestore rule: requires `match /users/{uid}/healthEvents/{id} { allow read, write: if request.auth.uid == uid; }` — must be published manually in Firebase Console (same pattern as other sub-collections)
