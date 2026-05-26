import 'package:flutter_test/flutter_test.dart';
import 'package:farm_manager/models/animal.dart';
import 'package:farm_manager/services/consanguinity_service.dart';

Animal _animal(String id, {String? motherId, String? fatherId}) => Animal(
      id: id,
      userId: 'u1',
      speciesId: 's1',
      farmId: id,
      gender: AnimalGender.female,
      healthStatus: HealthStatus.healthy,
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
        healthStatus: HealthStatus.healthy,
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
