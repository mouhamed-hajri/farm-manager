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
