import 'package:flutter_test/flutter_test.dart';
import 'package:farm_manager/models/animal.dart';
import 'package:farm_manager/models/female_rating.dart';
import 'package:farm_manager/models/health_event.dart';
import 'package:farm_manager/models/reproduction_event.dart';
import 'package:farm_manager/models/weight_measurement.dart';
import 'package:farm_manager/services/female_rating_service.dart';

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
      test('2 births in 2 years from mating start → ~1.0/yr → 3 stars', () {
        final female = _female(id: 'f1');
        final r = _compute(
          female: female,
          endDate: DateTime(2024, 1, 1),
          events: [
            _mating(date: '2022-01-01'),
            _birth(date: '2022-08-01'),
            _birth(date: '2023-07-01'),
          ],
        );
        expect(r.productiviteScore, 3.0);
        expect(r.birthsPerYear, closeTo(1.0, 0.1));
      });

      test('2 births in 1 year → ≥2/yr → 5 stars', () {
        final r = _compute(
          female: _female(),
          endDate: DateTime(2023, 6, 1),
          events: [
            _mating(date: '2022-06-01'),
            _birth(date: '2023-01-01'),
            _birth(date: '2023-05-01'),
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
      test('returns null score when only 1 female in species (no peer comparison)', () {
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
        // f1=3, f2=1, f3=2, f4=2, f5=2 → f1 below-count=4, percentile=0.8 → 5★
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
