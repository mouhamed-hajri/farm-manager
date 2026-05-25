# Female Rating System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 5-metric star-based rating system for female animals: productivity, litter size (species-relative), survival rate, weaning weight gain, and health — shown on the animal profile, list cards, and a dedicated ranking screen.

**Architecture:** A pure static `FemaleRatingService` (no async, testable) computes `FemaleRating` from in-memory data. A `FutureProvider.autoDispose.family` loads all needed data per-animal from existing repos and passes it to the service. The health event infrastructure (table, model, repo, dialog, profile section, sync) is already fully implemented — this plan builds only the rating layer and ranking UI on top of it.

**Tech Stack:** Flutter 3.x, Drift (SQLite ORM), Riverpod 2.5, GoRouter, existing HealthEventRepository / ReproductionEventRepository / WeightMeasurementRepository

---

### Task 1: FemaleRating model

**Files:**
- Create: `lib/models/female_rating.dart`

- [ ] **Step 1: Create the model**

```dart
class FemaleRating {
  const FemaleRating({
    this.productiviteScore,
    this.porteeScore,
    this.survieScore,
    this.croissanceScore,
    this.santeScore,
    this.composite,
    this.birthsPerYear,
    this.avgLitterSize,
    this.survivalRate,
    this.avgWeaningGainPercent,
    this.illnessesPerYear,
  });

  final double? productiviteScore;
  final double? porteeScore;
  final double? survieScore;
  final double? croissanceScore;
  final double? santeScore;
  final double? composite; // average of non-null scores, rounded to nearest 0.5

  // Raw values for display hints
  final double? birthsPerYear;
  final double? avgLitterSize;
  final double? survivalRate;        // 0.0–1.0
  final double? avgWeaningGainPercent;
  final double? illnessesPerYear;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/models/female_rating.dart
git commit -m "feat: add FemaleRating model"
```

---

### Task 2: DB query additions

**Files:**
- Modify: `lib/database/app_database.dart`

These are one-shot (non-stream) versions of existing queries, plus two new queries needed for bulk ranking.

- [ ] **Step 1: Add 5 methods to `app_database.dart`**

Add after the `// ─── Health events` section (around line 616):

```dart
// One-shot health events for an animal (used by rating provider)
Future<List<HealthEventsTableData>> getHealthEventsForAnimal(
        String userId, String animalId) =>
    (select(healthEventsTable)
          ..where((t) =>
              t.userId.equals(userId) & t.animalId.equals(animalId))
          ..orderBy([(t) => OrderingTerm.asc(t.date)]))
        .get();

// One-shot weight measurements for an animal (used by rating provider)
Future<List<WeightMeasurementsTableData>> getWeightMeasurementsForAnimalOnce(
        String userId, String animalId) =>
    (select(weightMeasurementsTable)
          ..where((t) =>
              t.userId.equals(userId) & t.animalId.equals(animalId))
          ..orderBy([(t) => OrderingTerm.asc(t.measurementDate)]))
        .get();

// All reproduction events for a user — used to build peer portée map
Future<List<ReproductionEventsTableData>> getAllReproductionEventsForUser(
        String userId) =>
    (select(reproductionEventsTable)
          ..where((t) => t.userId.equals(userId)))
        .get();

// All animals for a user — used by ranking screen
Future<List<AnimalsTableData>> getAllAnimals(String userId) =>
    (select(animalsTable)..where((t) => t.userId.equals(userId))).get();

// All health events for a user — used by ranking screen
Future<List<HealthEventsTableData>> getAllHealthEventsForUser(
        String userId) =>
    (select(healthEventsTable)..where((t) => t.userId.equals(userId))).get();
```

- [ ] **Step 2: Commit**

```bash
git add lib/database/app_database.dart
git commit -m "feat: add one-shot DB queries for female rating"
```

---

### Task 3: Repository method additions

**Files:**
- Modify: `lib/repositories/health_event_repository.dart`
- Modify: `lib/repositories/weight_measurement_repository.dart`
- Modify: `lib/repositories/reproduction_event_repository.dart`
- Modify: `lib/repositories/animal_repository.dart`

- [ ] **Step 1: Add to `HealthEventRepository`**

```dart
Future<List<HealthEvent>> getForAnimal(String userId, String animalId) async {
  final rows = await _db.getHealthEventsForAnimal(userId, animalId);
  return rows.map((r) => r.toModel()).toList();
}

Future<List<HealthEvent>> getAllForUser(String userId) async {
  final rows = await _db.getAllHealthEventsForUser(userId);
  return rows.map((r) => r.toModel()).toList();
}
```

- [ ] **Step 2: Add to `WeightMeasurementRepository`**

```dart
Future<List<WeightMeasurement>> getForAnimal(String userId, String animalId) async {
  final rows = await _db.getWeightMeasurementsForAnimalOnce(userId, animalId);
  return rows.map((r) => r.toModel()).toList();
}

Future<List<WeightMeasurement>> getAll(String userId) async {
  final rows = await _db.getAllWeightMeasurements(userId);
  return rows.map((r) => r.toModel()).toList();
}
```

- [ ] **Step 3: Add to `ReproductionEventRepository`**

```dart
Future<List<ReproductionEvent>> getForAnimal(String userId, String animalId) async {
  final rows = await _db.getAllReproductionForAnimal(userId, animalId);
  return rows.map((r) => r.toModel()).toList();
}

Future<List<ReproductionEvent>> getAllForUser(String userId) async {
  final rows = await _db.getAllReproductionEventsForUser(userId);
  return rows.map((r) => r.toModel()).toList();
}
```

- [ ] **Step 4: Add to `AnimalRepository`**

```dart
Future<List<Animal>> getBySpecies(String userId, String speciesId) async {
  final rows = await _db.getAnimalsBySpecies(userId, speciesId);
  return rows.map((r) => r.toModel()).toList();
}

Future<List<Animal>> getAll(String userId) async {
  final rows = await _db.getAllAnimals(userId);
  return rows.map((r) => r.toModel()).toList();
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/health_event_repository.dart lib/repositories/weight_measurement_repository.dart lib/repositories/reproduction_event_repository.dart lib/repositories/animal_repository.dart
git commit -m "feat: add one-shot repo methods for female rating"
```

---

### Task 4: FemaleRatingService (TDD)

**Files:**
- Create: `test/services/female_rating_service_test.dart`
- Create: `lib/services/female_rating_service.dart`

`FemaleRatingService.compute()` is a pure static function — no async, no dependencies, fully testable. Follow the same pattern as `ConsanguinityService`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/services/female_rating_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:farm/models/animal.dart';
import 'package:farm/models/female_rating.dart';
import 'package:farm/models/health_event.dart';
import 'package:farm/models/reproduction_event.dart';
import 'package:farm/models/weight_measurement.dart';
import 'package:farm/services/female_rating_service.dart';

Animal _female({String id = 'f1', String speciesId = 's1', String? birthDate, String? deathDate}) =>
    Animal(
      id: id, userId: 'u1', speciesId: speciesId, farmId: 'F-001',
      gender: AnimalGender.female,
      healthStatus: HealthStatus.healthy, status: AnimalStatus.active,
      createdAt: '2022-01-01T00:00:00.000', updatedAt: '2022-01-01T00:00:00.000',
      syncStatus: 'synced', birthDate: birthDate, deathDate: deathDate,
    );

Animal _offspring({required String id, required String motherId, String status = AnimalStatus.active}) =>
    Animal(
      id: id, userId: 'u1', speciesId: 's1', farmId: 'F-00$id',
      gender: AnimalGender.male, motherId: motherId,
      healthStatus: HealthStatus.healthy, status: status,
      createdAt: '2023-01-01T00:00:00.000', updatedAt: '2023-01-01T00:00:00.000',
      syncStatus: 'synced',
    );

ReproductionEvent _mating({String animalId = 'f1', String date = '2022-06-01'}) =>
    ReproductionEvent(
      id: 'e${date}m', userId: 'u1', animalId: animalId,
      eventType: ReproductionEventType.mating, eventDate: date,
      createdAt: '', updatedAt: '', syncStatus: 'synced',
    );

ReproductionEvent _birth({
  String animalId = 'f1', String date = '2023-01-01', int count = 2,
}) =>
    ReproductionEvent(
      id: 'e${date}b', userId: 'u1', animalId: animalId,
      eventType: ReproductionEventType.birth, eventDate: date,
      offspringCount: count,
      createdAt: '', updatedAt: '', syncStatus: 'synced',
    );

HealthEvent _illness({String animalId = 'f1', String date = '2023-06-01'}) =>
    HealthEvent(
      id: 'h$date', userId: 'u1', animalId: animalId,
      eventType: HealthEventType.illness, description: 'Sick',
      date: date, createdAt: '', updatedAt: '', syncStatus: 'synced',
    );

WeightMeasurement _weight({
  required String animalId, required String date, required double kg,
}) =>
    WeightMeasurement(
      id: 'w${animalId}_$date', userId: 'u1', animalId: animalId,
      weight: kg, measurementDate: date,
      createdAt: '', updatedAt: '', syncStatus: 'synced',
    );

FemaleRating _compute({
  required Animal female,
  DateTime? endDate,
  List<ReproductionEvent> events = const [],
  List<Animal> offspring = const [],
  Map<String, List<WeightMeasurement>> weightsByOffspring = const {},
  List<Animal> speciesPeers = const [],
  Map<String, List<ReproductionEvent>> peersEvents = const {},
  List<HealthEvent> healthEvents = const [],
}) =>
    FemaleRatingService.compute(
      female: female,
      endDate: endDate ?? DateTime(2024, 1, 1),
      events: events,
      offspring: offspring,
      weightsByOffspring: weightsByOffspring,
      speciesPeers: speciesPeers,
      peersEvents: peersEvents,
      healthEvents: healthEvents,
    );

void main() {
  group('FemaleRatingService', () {
    group('no data', () {
      test('returns all null scores when no events exist', () {
        final r = _compute(female: _female());
        expect(r.productiviteScore, isNull);
        expect(r.porteeScore, isNull);
        expect(r.survieScore, isNull);
        expect(r.croissanceScore, isNull);
        expect(r.santeScore, isNull);
        expect(r.composite, isNull);
      });
    });

    group('productivite', () {
      test('2 births in 2 years from mating start → 1.0/yr → 3 stars', () {
        final female = _female(id: 'f1');
        final r = _compute(
          female: female,
          endDate: DateTime(2024, 6, 1),
          events: [
            _mating(date: '2022-06-01'),
            _birth(date: '2023-01-01'),
            _birth(date: '2023-12-01'),
          ],
        );
        expect(r.productiviteScore, 3.0);
        expect(r.birthsPerYear, closeTo(1.0, 0.1));
      });

      test('2 births in 1 year → ≥2/yr → 5 stars', () {
        final r = _compute(
          female: _female(),
          endDate: DateTime(2023, 7, 1),
          events: [
            _mating(date: '2022-06-01'),
            _birth(date: '2023-01-01'),
            _birth(date: '2023-06-01'),
          ],
        );
        expect(r.productiviteScore, 5.0);
      });

      test('no births → null', () {
        final r = _compute(female: _female(), events: [_mating()]);
        expect(r.productiviteScore, isNull);
      });
    });

    group('portee', () {
      test('returns null when only 1 female in species (no peer comparison)', () {
        final female = _female(id: 'f1', speciesId: 's1');
        final r = _compute(
          female: female,
          events: [_birth(count: 2)],
          speciesPeers: [female],
          peersEvents: {'f1': [_birth(count: 2)]},
        );
        expect(r.porteeScore, isNull);
        expect(r.avgLitterSize, 2.0);
      });

      test('top female among 5 peers → 5 stars', () {
        // f1=3, f2=1, f3=2, f4=2, f5=2.5 → f1 below-count=4, percentile=0.8 → 5★
        final f1 = _female(id: 'f1');
        final f2 = _female(id: 'f2');
        final f3 = _female(id: 'f3');
        final f4 = _female(id: 'f4');
        final f5 = _female(id: 'f5');
        final r = _compute(
          female: f1,
          events: [_birth(animalId: 'f1', count: 3)],
          speciesPeers: [f1, f2, f3, f4, f5],
          peersEvents: {
            'f1': [_birth(animalId: 'f1', count: 3)],
            'f2': [_birth(animalId: 'f2', count: 1)],
            'f3': [_birth(animalId: 'f3', count: 2)],
            'f4': [_birth(animalId: 'f4', count: 2)],
            'f5': [_birth(animalId: 'f5', count: 2)],
          },
        );
        expect(r.porteeScore, 5.0);
      });

      test('bottom female → 1 or 2 stars', () {
        final f1 = _female(id: 'f1');
        final f2 = _female(id: 'f2');
        final f3 = _female(id: 'f3');
        final f4 = _female(id: 'f4');
        final f5 = _female(id: 'f5');
        final r = _compute(
          female: f1,
          events: [_birth(animalId: 'f1', count: 1)],
          speciesPeers: [f1, f2, f3, f4, f5],
          peersEvents: {
            'f1': [_birth(animalId: 'f1', count: 1)],
            'f2': [_birth(animalId: 'f2', count: 2)],
            'f3': [_birth(animalId: 'f3', count: 3)],
            'f4': [_birth(animalId: 'f4', count: 2)],
            'f5': [_birth(animalId: 'f5', count: 3)],
          },
        );
        expect(r.porteeScore, lessThanOrEqualTo(2.0));
      });
    });

    group('survie', () {
      test('3 offspring all alive → 100% → 5 stars', () {
        final f = _female();
        final o1 = _offspring(id: 'o1', motherId: 'f1');
        final o2 = _offspring(id: 'o2', motherId: 'f1');
        final o3 = _offspring(id: 'o3', motherId: 'f1');
        final r = _compute(
          female: f,
          events: [_birth(count: 3)],
          offspring: [o1, o2, o3],
        );
        expect(r.survieScore, 5.0);
        expect(r.survivalRate, closeTo(1.0, 0.01));
      });

      test('2 of 3 alive → 66% → 3 stars', () {
        final f = _female();
        final o1 = _offspring(id: 'o1', motherId: 'f1');
        final o2 = _offspring(id: 'o2', motherId: 'f1');
        final o3 = _offspring(id: 'o3', motherId: 'f1', status: AnimalStatus.dead);
        final r = _compute(
          female: f,
          events: [_birth(count: 3)],
          offspring: [o1, o2, o3],
        );
        expect(r.survieScore, 3.0);
        expect(r.survivalRate, closeTo(0.667, 0.01));
      });

      test('sold offspring counts as survived', () {
        final f = _female();
        final o1 = _offspring(id: 'o1', motherId: 'f1', status: AnimalStatus.sold);
        final r = _compute(
          female: f,
          events: [_birth(count: 1)],
          offspring: [o1],
        );
        expect(r.survieScore, 5.0);
      });

      test('no births → null', () {
        final r = _compute(female: _female());
        expect(r.survieScore, isNull);
      });
    });

    group('croissance', () {
      test('offspring weight doubles (100% gain) → 3 stars', () {
        final f = _female();
        final o = _offspring(id: 'o1', motherId: 'f1');
        final r = _compute(
          female: f,
          events: [_birth(count: 1)],
          offspring: [o],
          weightsByOffspring: {
            'o1': [
              _weight(animalId: 'o1', date: '2023-01-01', kg: 2.0),
              _weight(animalId: 'o1', date: '2023-03-01', kg: 4.0),
            ],
          },
        );
        expect(r.croissanceScore, 3.0); // 100% gain → 3 stars
        expect(r.avgWeaningGainPercent, closeTo(100.0, 0.01));
      });

      test('200% gain → 5 stars', () {
        final f = _female();
        final o = _offspring(id: 'o1', motherId: 'f1');
        final r = _compute(
          female: f,
          events: [_birth(count: 1)],
          offspring: [o],
          weightsByOffspring: {
            'o1': [
              _weight(animalId: 'o1', date: '2023-01-01', kg: 2.0),
              _weight(animalId: 'o1', date: '2023-03-01', kg: 6.0),
            ],
          },
        );
        expect(r.croissanceScore, 5.0);
      });

      test('offspring with only 1 measurement excluded', () {
        final f = _female();
        final o = _offspring(id: 'o1', motherId: 'f1');
        final r = _compute(
          female: f,
          events: [_birth(count: 1)],
          offspring: [o],
          weightsByOffspring: {
            'o1': [_weight(animalId: 'o1', date: '2023-01-01', kg: 2.0)],
          },
        );
        expect(r.croissanceScore, isNull);
      });
    });

    group('sante', () {
      test('no events at all → null', () {
        final r = _compute(female: _female());
        expect(r.santeScore, isNull);
      });

      test('has repro events, no illness → 5 stars', () {
        final r = _compute(
          female: _female(),
          events: [_mating(), _birth()],
        );
        expect(r.santeScore, 5.0);
        expect(r.illnessesPerYear, 0.0);
      });

      test('1 illness in ~5 years → ≤0.5/year → 4 stars', () {
        final r = _compute(
          female: _female(),
          endDate: DateTime(2027, 1, 1),
          events: [_mating(date: '2022-01-01')],
          healthEvents: [_illness(date: '2024-01-01')],
        );
        expect(r.santeScore, 4.0);
        expect(r.illnessesPerYear, lessThanOrEqualTo(0.5));
      });

      test('3 illnesses in 1 year → >2/year → 1 star', () {
        final r = _compute(
          female: _female(),
          endDate: DateTime(2023, 7, 1),
          events: [_mating(date: '2022-06-01')],
          healthEvents: [
            _illness(date: '2023-01-01'),
            _illness(date: '2023-03-01'),
            _illness(date: '2023-05-01'),
          ],
        );
        expect(r.santeScore, 1.0);
      });
    });

    group('composite', () {
      test('composite is average of available scores rounded to nearest 0.5', () {
        final f = _female();
        final o = _offspring(id: 'o1', motherId: 'f1');
        // productivite: 1 birth in 2 years = 0.5/yr → 2★
        // survie: 1/1 alive → 5★
        // sante: has repro events, no illness → 5★
        // portee: only 1 peer → null. croissance: no weights → null.
        // composite = avg(2, 5, 5) = 4.0 → rounded to 4.0
        final r = _compute(
          female: f,
          endDate: DateTime(2024, 1, 1),
          events: [
            _mating(date: '2022-01-01'),
            _birth(date: '2023-01-01', count: 1),
          ],
          offspring: [o],
          speciesPeers: [f], // only 1 peer → portee null
          peersEvents: {'f1': [_birth(date: '2023-01-01', count: 1)]},
        );
        expect(r.composite, 4.0);
      });
    });
  });
}
```

- [ ] **Step 2: Run the tests — expect compile failure (service not defined yet)**

```bash
flutter test test/services/female_rating_service_test.dart
```

Expected: compilation error — `FemaleRatingService` not found.

- [ ] **Step 3: Create `lib/services/female_rating_service.dart`**

```dart
import '../models/animal.dart';
import '../models/female_rating.dart';
import '../models/health_event.dart';
import '../models/reproduction_event.dart';
import '../models/weight_measurement.dart';

class FemaleRatingService {
  FemaleRatingService._();

  static FemaleRating compute({
    required Animal female,
    required DateTime endDate,
    required List<ReproductionEvent> events,
    required List<Animal> offspring,
    required Map<String, List<WeightMeasurement>> weightsByOffspring,
    required List<Animal> speciesPeers,
    required Map<String, List<ReproductionEvent>> peersEvents,
    required List<HealthEvent> healthEvents,
  }) {
    final productiviteResult = _computeProductivite(female, events, endDate);
    final porteeResult = _computePortee(events, speciesPeers, peersEvents);
    final survieResult = _computeSurvie(events, offspring);
    final croissanceResult = _computeCroissance(offspring, weightsByOffspring);
    final santeResult = _computeSante(female, events, healthEvents, endDate);

    final scores = [
      productiviteResult.$1,
      porteeResult.$1,
      survieResult.$1,
      croissanceResult.$1,
      santeResult.$1,
    ].whereType<double>().toList();

    final composite = scores.isEmpty
        ? null
        : (scores.reduce((a, b) => a + b) / scores.length * 2).round() / 2.0;

    return FemaleRating(
      productiviteScore: productiviteResult.$1,
      porteeScore: porteeResult.$1,
      survieScore: survieResult.$1,
      croissanceScore: croissanceResult.$1,
      santeScore: santeResult.$1,
      composite: composite,
      birthsPerYear: productiviteResult.$2,
      avgLitterSize: porteeResult.$2,
      survivalRate: survieResult.$2,
      avgWeaningGainPercent: croissanceResult.$2,
      illnessesPerYear: santeResult.$2,
    );
  }

  // Returns (score, birthsPerYear)
  static (double?, double?) _computeProductivite(
      Animal female, List<ReproductionEvent> events, DateTime endDate) {
    final birthEvents =
        events.where((e) => e.eventType == ReproductionEventType.birth).toList();
    if (birthEvents.isEmpty) return (null, null);

    final matings =
        events.where((e) => e.eventType == ReproductionEventType.mating).toList();
    DateTime? startDate;
    if (matings.isNotEmpty) {
      startDate = matings
          .map((e) => DateTime.parse(e.eventDate))
          .reduce((a, b) => a.isBefore(b) ? a : b);
    } else if (female.birthDate != null) {
      startDate = DateTime.tryParse(female.birthDate!);
    }
    if (startDate == null) return (null, null);

    final years = endDate.difference(startDate).inDays / 365.25;
    if (years <= 0) return (null, null);

    final birthsPerYear = birthEvents.length / years;
    double score;
    if (birthsPerYear >= 2.0) score = 5;
    else if (birthsPerYear >= 1.5) score = 4;
    else if (birthsPerYear >= 1.0) score = 3;
    else if (birthsPerYear >= 0.5) score = 2;
    else score = 1;

    return (score, birthsPerYear);
  }

  // Returns (score, avgLitterSize). Score is null if fewer than 2 peers have birth data.
  static (double?, double?) _computePortee(
      List<ReproductionEvent> events,
      List<Animal> speciesPeers,
      Map<String, List<ReproductionEvent>> peersEvents) {
    double? avgFor(List<ReproductionEvent> evts) {
      final births = evts
          .where((e) =>
              e.eventType == ReproductionEventType.birth &&
              e.offspringCount != null)
          .toList();
      if (births.isEmpty) return null;
      return births.map((e) => e.offspringCount!).reduce((a, b) => a + b) /
          births.length;
    }

    final myAvg = avgFor(events);
    if (myAvg == null) return (null, null);

    final peerAvgs = speciesPeers
        .map((p) => avgFor(peersEvents[p.id] ?? []))
        .whereType<double>()
        .toList();

    // Need at least 2 females with birth data to rank
    if (peerAvgs.length < 2) return (null, myAvg);

    final belowCount = peerAvgs.where((p) => p < myAvg).length;
    final percentile = belowCount / peerAvgs.length;

    double score;
    if (percentile >= 0.8) score = 5;
    else if (percentile >= 0.6) score = 4;
    else if (percentile >= 0.4) score = 3;
    else if (percentile >= 0.2) score = 2;
    else score = 1;

    return (score, myAvg);
  }

  // Returns (score, survivalRate 0.0–1.0)
  static (double?, double?) _computeSurvie(
      List<ReproductionEvent> events, List<Animal> offspring) {
    final birthEvents =
        events.where((e) => e.eventType == ReproductionEventType.birth).toList();
    if (birthEvents.isEmpty) return (null, null);

    final totalBorn =
        birthEvents.map((e) => e.offspringCount ?? 0).reduce((a, b) => a + b);
    if (totalBorn == 0) return (null, null);

    final survived =
        offspring.where((o) => o.status != AnimalStatus.dead).length;
    final rate = survived / totalBorn;

    double score;
    if (rate >= 0.95) score = 5;
    else if (rate >= 0.80) score = 4;
    else if (rate >= 0.65) score = 3;
    else if (rate >= 0.50) score = 2;
    else score = 1;

    return (score, rate);
  }

  // Returns (score, avgGainPercent)
  static (double?, double?) _computeCroissance(
      List<Animal> offspring,
      Map<String, List<WeightMeasurement>> weightsByOffspring) {
    final gains = <double>[];
    for (final o in offspring) {
      final weights = List<WeightMeasurement>.from(
          weightsByOffspring[o.id] ?? [])
        ..sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
      if (weights.length < 2) continue;
      final first = weights.first.weight;
      if (first <= 0) continue;
      gains.add((weights.last.weight - first) / first * 100);
    }
    if (gains.isEmpty) return (null, null);

    final avgGain = gains.reduce((a, b) => a + b) / gains.length;

    double score;
    if (avgGain >= 200) score = 5;
    else if (avgGain >= 150) score = 4;
    else if (avgGain >= 100) score = 3;
    else if (avgGain >= 50) score = 2;
    else score = 1;

    return (score, avgGain);
  }

  // Returns (score, illnessesPerYear)
  static (double?, double?) _computeSante(
      Animal female,
      List<ReproductionEvent> events,
      List<HealthEvent> healthEvents,
      DateTime endDate) {
    final hasAnyData =
        healthEvents.isNotEmpty || events.isNotEmpty || female.birthDate != null;
    if (!hasAnyData) return (null, null);

    final illnesses = healthEvents
        .where((e) => e.eventType == HealthEventType.illness)
        .toList();
    if (illnesses.isEmpty) return (5.0, 0.0);

    final dates = [
      ...events
          .map((e) => DateTime.tryParse(e.eventDate))
          .whereType<DateTime>(),
      ...healthEvents
          .map((e) => DateTime.tryParse(e.date))
          .whereType<DateTime>(),
      if (female.birthDate != null) DateTime.tryParse(female.birthDate!),
    ].whereType<DateTime>().toList()
      ..sort();

    if (dates.isEmpty) return (null, null);
    final years = endDate.difference(dates.first).inDays / 365.25;
    if (years <= 0) return (5.0, 0.0);

    final illnessesPerYear = illnesses.length / years;

    double score;
    if (illnessesPerYear > 2) score = 1;
    else if (illnessesPerYear > 1) score = 2;
    else if (illnessesPerYear > 0.5) score = 3;
    else score = 4;

    return (score, illnessesPerYear);
  }
}
```

- [ ] **Step 4: Run the tests — all should pass**

```bash
flutter test test/services/female_rating_service_test.dart
```

Expected: all tests pass. If a test fails, read the failure message and fix the service logic (not the test).

- [ ] **Step 5: Commit**

```bash
git add lib/services/female_rating_service.dart test/services/female_rating_service_test.dart
git commit -m "feat: FemaleRatingService with TDD — 5-metric star rating"
```

---

### Task 5: Rating providers

**Files:**
- Modify: `lib/providers/core_providers.dart`

- [ ] **Step 1: Add imports at the top of `core_providers.dart`**

Add alongside existing imports:

```dart
import '../models/animal.dart';
import '../models/female_rating.dart';
import '../models/health_event.dart';
import '../models/reproduction_event.dart';
import '../models/weight_measurement.dart';
import '../services/female_rating_service.dart';
```

- [ ] **Step 2: Add `femaleRatingProvider` after `settingsRepositoryProvider`**

```dart
/// Rating for a single female. Reload on demand with ref.invalidate().
final femaleRatingProvider =
    FutureProvider.autoDispose.family<FemaleRating?, String>((ref, animalId) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return null;
  final userId = user.uid;

  final animalRepo = ref.read(animalRepositoryProvider);
  final reproRepo = ref.read(reproductionEventRepositoryProvider);
  final weightRepo = ref.read(weightMeasurementRepositoryProvider);
  final healthRepo = ref.read(healthEventRepositoryProvider);

  final female = await animalRepo.getById(animalId);
  if (female == null || female.gender != AnimalGender.female) return null;

  final events = await reproRepo.getForAnimal(userId, animalId);
  final offspring = await animalRepo.getByMotherId(userId, animalId);
  final allUserRepro = await reproRepo.getAllForUser(userId);
  final speciesFemales = (await animalRepo.getBySpecies(userId, female.speciesId))
      .where((a) => a.gender == AnimalGender.female)
      .toList();
  final healthEvents = await healthRepo.getForAnimal(userId, animalId);

  // Weight measurements per offspring (parallel)
  final weightsList = await Future.wait(
    offspring.map((o) => weightRepo.getForAnimal(userId, o.id)),
  );
  final weightsByOffspring = <String, List<WeightMeasurement>>{
    for (var i = 0; i < offspring.length; i++) offspring[i].id: weightsList[i],
  };

  // Build peers events map: filter allUserRepro by animalId for each peer
  final peersEvents = <String, List<ReproductionEvent>>{
    for (final peer in speciesFemales)
      peer.id: allUserRepro.where((e) => e.animalId == peer.id).toList(),
  };
  // Ensure this female's loaded events are used (avoids re-filtering)
  peersEvents[female.id] = events;

  final endDate = female.deathDate != null
      ? DateTime.parse(female.deathDate!)
      : DateTime.now();

  return FemaleRatingService.compute(
    female: female,
    endDate: endDate,
    events: events,
    offspring: offspring,
    weightsByOffspring: weightsByOffspring,
    speciesPeers: speciesFemales,
    peersEvents: peersEvents,
    healthEvents: healthEvents,
  );
});

/// Ratings for ALL females — used by the ranking screen. Loads in bulk (no N+1 queries).
final femaleRankingProvider =
    FutureProvider.autoDispose.family<List<(Animal, FemaleRating?)>, String>(
        (ref, userId) async {
  final animalRepo = ref.read(animalRepositoryProvider);
  final reproRepo = ref.read(reproductionEventRepositoryProvider);
  final weightRepo = ref.read(weightMeasurementRepositoryProvider);
  final healthRepo = ref.read(healthEventRepositoryProvider);

  final allAnimals = await animalRepo.getAll(userId);
  final allFemales =
      allAnimals.where((a) => a.gender == AnimalGender.female).toList();

  final allRepro = await reproRepo.getAllForUser(userId);
  final allWeights = await weightRepo.getAll(userId);
  final allHealth = await healthRepo.getAllForUser(userId);

  // Group weights by animalId (sorted by date)
  final weightsByAnimal = <String, List<WeightMeasurement>>{};
  for (final w in allWeights) {
    weightsByAnimal.putIfAbsent(w.animalId, () => []).add(w);
  }
  for (final list in weightsByAnimal.values) {
    list.sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
  }

  // Group health events and repro events by animalId
  final healthByAnimal = <String, List<HealthEvent>>{};
  for (final h in allHealth) {
    healthByAnimal.putIfAbsent(h.animalId, () => []).add(h);
  }
  final reproByAnimal = <String, List<ReproductionEvent>>{};
  for (final e in allRepro) {
    reproByAnimal.putIfAbsent(e.animalId, () => []).add(e);
  }

  final results = <(Animal, FemaleRating?)>[];
  for (final female in allFemales) {
    final offspring =
        allAnimals.where((a) => a.motherId == female.id).toList();
    final weightsByOffspring = <String, List<WeightMeasurement>>{
      for (final o in offspring)
        o.id: weightsByAnimal[o.id] ?? const [],
    };
    final speciesPeers = allFemales
        .where((a) => a.speciesId == female.speciesId)
        .toList();
    final peersEvents = <String, List<ReproductionEvent>>{
      for (final p in speciesPeers)
        p.id: reproByAnimal[p.id] ?? const [],
    };
    final endDate = female.deathDate != null
        ? DateTime.parse(female.deathDate!)
        : DateTime.now();

    final rating = FemaleRatingService.compute(
      female: female,
      endDate: endDate,
      events: reproByAnimal[female.id] ?? const [],
      offspring: offspring,
      weightsByOffspring: weightsByOffspring,
      speciesPeers: speciesPeers,
      peersEvents: peersEvents,
      healthEvents: healthByAnimal[female.id] ?? const [],
    );
    results.add((female, rating));
  }

  // Rated first (composite desc), unrated last
  results.sort((a, b) {
    final ra = a.$2?.composite;
    final rb = b.$2?.composite;
    if (ra == null && rb == null) return 0;
    if (ra == null) return 1;
    if (rb == null) return -1;
    return rb.compareTo(ra);
  });

  return results;
});
```

- [ ] **Step 3: Run `flutter analyze` — zero errors**

```bash
flutter analyze lib/providers/core_providers.dart
```

- [ ] **Step 4: Commit**

```bash
git add lib/providers/core_providers.dart
git commit -m "feat: femaleRatingProvider and femaleRankingProvider"
```

---

### Task 6: _NotationSection widget in animal profile

**Files:**
- Modify: `lib/screens/animals/animal_profile_screen.dart`

The section goes after `_CroissanceSection` in `_InfoTab.build()`, shown only for female animals.

- [ ] **Step 1: Add import for `FemaleRating` at the top of `animal_profile_screen.dart`**

Add to the existing imports:

```dart
import '../../models/female_rating.dart';
import '../../services/female_rating_service.dart'; // not needed at import, but for clarity
```

Actually you only need:
```dart
import '../../models/female_rating.dart';
```

- [ ] **Step 2: Insert `_NotationSection` call in `_InfoTab.build()`**

Find this block in `_InfoTab.build()` (around line 308):

```dart
        _CroissanceSection(animal: animal),
        const SizedBox(height: 24),
        OutlinedButton.icon(
```

Replace with:

```dart
        _CroissanceSection(animal: animal),
        if (animal.gender == AnimalGender.female) ...[
          const SizedBox(height: 16),
          _NotationSection(animal: animal),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
```

- [ ] **Step 3: Add `_StarRow`, `_MetricRow`, `_NotationCard`, and `_NotationSection` widgets**

Add after the `_CroissanceSection` class (at the bottom of the file, before the last closing brace):

```dart
// ─── Notation Section ─────────────────────────────────────────────────────────

class _NotationSection extends ConsumerWidget {
  const _NotationSection({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratingAsync = ref.watch(femaleRatingProvider(animal.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ratingAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (rating) => _NotationCard(rating: rating),
        ),
      ],
    );
  }
}

class _NotationCard extends StatelessWidget {
  const _NotationCard({required this.rating});
  final FemaleRating? rating;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                const Text('Score global',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (rating?.composite != null)
                  _StarRow(score: rating!.composite!, size: 18)
                else
                  const Text('Données insuffisantes',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const Divider(height: 20),
            _MetricRow(
              label: '🐣 Productivité / an',
              score: rating?.productiviteScore,
              raw: rating?.birthsPerYear != null
                  ? '${rating!.birthsPerYear!.toStringAsFixed(1)}/an'
                  : null,
            ),
            _MetricRow(
              label: '🍼 Portée moyenne',
              score: rating?.porteeScore,
              raw: rating?.avgLitterSize != null
                  ? '${rating!.avgLitterSize!.toStringAsFixed(1)} petits'
                  : null,
            ),
            _MetricRow(
              label: '💚 Taux de survie',
              score: rating?.survieScore,
              raw: rating?.survivalRate != null
                  ? '${(rating!.survivalRate! * 100).toStringAsFixed(0)}%'
                  : null,
            ),
            _MetricRow(
              label: '⚖️ Croissance sevrage',
              score: rating?.croissanceScore,
              raw: rating?.avgWeaningGainPercent != null
                  ? '+${rating!.avgWeaningGainPercent!.toStringAsFixed(0)}%'
                  : null,
            ),
            _MetricRow(
              label: '🏥 Santé',
              score: rating?.santeScore,
              raw: rating?.illnessesPerYear != null
                  ? '${rating!.illnessesPerYear!.toStringAsFixed(1)} maladies/an'
                  : null,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.score,
    this.raw,
    this.isLast = false,
  });

  final String label;
  final double? score;
  final String? raw;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13))),
          if (score != null)
            _StarRow(score: score!)
          else
            Text('—',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          if (raw != null) ...[
            const SizedBox(width: 6),
            Text('($raw)',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.score, this.size = 13});
  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final full = score.floor();
    final hasHalf = (score - full) >= 0.25 && (score - full) < 0.75;
    final empty = 5 - full - (hasHalf ? 1 : 0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++)
          Icon(Icons.star, color: Colors.amber, size: size),
        if (hasHalf)
          Icon(Icons.star_half, color: Colors.amber, size: size),
        for (int i = 0; i < empty; i++)
          Icon(Icons.star_border, color: Colors.grey[400], size: size),
      ],
    );
  }
}
```

- [ ] **Step 4: Add `femaleRatingProvider` import in `core_providers.dart` reference**

The `femaleRatingProvider` is already in `core_providers.dart` which is already imported by `animal_profile_screen.dart`. Nothing to add.

- [ ] **Step 5: Run `flutter analyze` on the file**

```bash
flutter analyze lib/screens/animals/animal_profile_screen.dart
```

Fix any errors before committing.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/animals/animal_profile_screen.dart
git commit -m "feat: _NotationSection with 5-metric star rating on female profile"
```

---

### Task 7: FemaleRankingScreen

**Files:**
- Create: `lib/screens/animals/female_ranking_screen.dart`

- [ ] **Step 1: Create the screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../models/animal.dart';
import '../../models/female_rating.dart';
import '../../providers/core_providers.dart';

class FemaleRankingScreen extends ConsumerWidget {
  const FemaleRankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final rankingAsync = ref.watch(femaleRankingProvider(user.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Classement femelles')),
      body: rankingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (ranking) => ranking.isEmpty
            ? const Center(
                child: Text('Aucune femelle enregistrée',
                    style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ranking.length,
                itemBuilder: (ctx, i) {
                  final (animal, rating) = ranking[i];
                  return _RankCard(
                    rank: i + 1,
                    animal: animal,
                    rating: rating,
                  );
                },
              ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.rank,
    required this.animal,
    required this.rating,
  });

  final int rank;
  final Animal animal;
  final FemaleRating? rating;

  @override
  Widget build(BuildContext context) {
    final hasRating = rating?.composite != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: hasRating ? null : Colors.grey[900],
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                hasRating ? '#$rank' : '—',
                style: TextStyle(
                  color: hasRating ? Colors.amber : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            _AnimalAvatar(animal: animal),
          ],
        ),
        title: Text(animal.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: hasRating
            ? Text(
                _subtitle(rating!),
                style: const TextStyle(fontSize: 11),
              )
            : Text('Pas encore notée',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        trailing: hasRating
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StarRow(score: rating!.composite!, size: 14),
                  Text(
                    rating!.composite!.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.green),
                  ),
                ],
              )
            : null,
        onTap: () {},
      ),
    );
  }

  String _subtitle(FemaleRating r) {
    final parts = <String>[];
    if (r.birthsPerYear != null) {
      parts.add('${r.birthsPerYear!.toStringAsFixed(1)}/an');
    }
    if (r.survivalRate != null) {
      parts.add('${(r.survivalRate! * 100).toStringAsFixed(0)}% survie');
    }
    return parts.join(' · ');
  }
}

class _AnimalAvatar extends StatelessWidget {
  const _AnimalAvatar({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    if (animal.photoLocalPath != null) {
      final file = File(animal.photoLocalPath!);
      return CircleAvatar(
        radius: 18,
        backgroundImage: FileImage(file),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.green,
      child: Text(
        animal.farmId.isNotEmpty ? animal.farmId[0] : '?',
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.score, this.size = 13});
  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final full = score.floor();
    final hasHalf = (score - full) >= 0.25 && (score - full) < 0.75;
    final empty = 5 - full - (hasHalf ? 1 : 0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++)
          Icon(Icons.star, color: Colors.amber, size: size),
        if (hasHalf)
          Icon(Icons.star_half, color: Colors.amber, size: size),
        for (int i = 0; i < empty; i++)
          Icon(Icons.star_border, color: Colors.grey[400], size: size),
      ],
    );
  }
}
```

- [ ] **Step 2: Run `flutter analyze`**

```bash
flutter analyze lib/screens/animals/female_ranking_screen.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/screens/animals/female_ranking_screen.dart
git commit -m "feat: FemaleRankingScreen — sorted leaderboard of all females"
```

---

### Task 8: Route + entry points

**Files:**
- Modify: `lib/app.dart`
- Modify: `lib/screens/animals/animal_list_screen.dart`
- Modify: `lib/screens/home/home_dashboard_screen.dart`
- Modify: `lib/widgets/animal_grid_card.dart`

- [ ] **Step 1: Add route in `app.dart`**

Add the import at the top:
```dart
import 'screens/animals/female_ranking_screen.dart';
```

Add the route alongside the other GoRoute definitions (before the StatefulShellRoute block):
```dart
GoRoute(
  path: '/animals/ranking',
  builder: (_, __) => const FemaleRankingScreen(),
),
```

- [ ] **Step 2: Add trophy icon to `AnimalListScreen` AppBar**

In `animal_list_screen.dart`, find the `AppBar`:

```dart
      appBar: AppBar(
        title: Text(species?.nameFr ?? 'Animaux'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
```

Replace with:

```dart
      appBar: AppBar(
        title: Text(species?.nameFr ?? 'Animaux'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Classement femelles',
            onPressed: () => context.push('/animals/ranking'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
```

- [ ] **Step 3: Add star badge to female cards in `animal_grid_card.dart`**

Change `AnimalGridCard extends StatelessWidget` to `AnimalGridCard extends ConsumerWidget`, change `build(BuildContext context)` to `build(BuildContext context, WidgetRef ref)`, and add these imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/female_rating.dart';
import '../providers/core_providers.dart';
```

Then inside `build()`, add before the `return InkWell(...)`:

```dart
    final FemaleRating? rating = animal.gender == AnimalGender.female
        ? ref.watch(femaleRatingProvider(animal.id)).asData?.value
        : null;
```

Then inside the photo `Stack`, after the existing `Positioned` for the gender badge, add a star badge in the bottom-right corner (only for females with a composite score):

```dart
                    // Star rating badge — females only
                    if (rating?.composite != null)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                rating!.composite!.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
```

Add this `Positioned` block right after the status chip `Positioned` block (around line 116 in the original file, inside the `Stack`).

- [ ] **Step 4: Add ranking card on home dashboard**

In `home_dashboard_screen.dart`, find a suitable location (e.g., after the animal stats block). Add:

```dart
// Ranking shortcut — shown to all logged-in users
Card(
  child: ListTile(
    leading: const Icon(Icons.emoji_events, color: Colors.amber),
    title: const Text('Classement femelles',
        style: TextStyle(fontWeight: FontWeight.w600)),
    subtitle: const Text('Voir les meilleures reproductrices'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push('/animals/ranking'),
  ),
),
const SizedBox(height: 8),
```

- [ ] **Step 5: Run `flutter analyze`**

```bash
flutter analyze lib/
```

Fix all errors.

- [ ] **Step 6: Commit**

```bash
git add lib/app.dart lib/screens/animals/animal_list_screen.dart lib/screens/home/home_dashboard_screen.dart lib/widgets/animal_grid_card.dart
git commit -m "feat: ranking route, trophy AppBar button, dashboard shortcut, female star badge on list"
```

---

## Final check

- [ ] Run all tests: `flutter test`
- [ ] Run analyze: `flutter analyze lib/`
- [ ] Both clean → ready to build APK
