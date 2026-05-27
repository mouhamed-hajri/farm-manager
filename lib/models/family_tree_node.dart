import 'dart:math' as math;
import 'animal.dart';

class FamilyTreeNode {
  const FamilyTreeNode({
    required this.female,
    this.mate,
    required this.maleOffspring,
    required this.femaleSubtrees,
  });

  final Animal female;
  final Animal? mate;
  final List<Animal> maleOffspring;
  final List<FamilyTreeNode> femaleSubtrees;

  bool get isLeaf => maleOffspring.isEmpty && femaleSubtrees.isEmpty;
}

class FamilyTreeBuilder {
  static const double nodeWidth = 120.0;
  static const double nodeGap = 32.0;

  static List<FamilyTreeNode> build(List<Animal> animals) {
    final byId = <String, Animal>{for (final a in animals) a.id: a};

    final childrenByMotherId = <String, List<Animal>>{};
    for (final a in animals) {
      if (a.motherId != null) {
        childrenByMotherId.putIfAbsent(a.motherId!, () => []).add(a);
      }
    }

    final rootFemales = animals.where((a) {
      if (a.gender != AnimalGender.female) return false;
      if (a.motherId == null) return true;
      return !byId.containsKey(a.motherId);
    }).toList();

    return rootFemales
        .map((f) => _buildNode(f, byId, childrenByMotherId))
        .toList();
  }

  static FamilyTreeNode _buildNode(
    Animal female,
    Map<String, Animal> byId,
    Map<String, List<Animal>> childrenByMotherId,
  ) {
    final offspring = childrenByMotherId[female.id] ?? const [];

    final maleOffspring =
        offspring.where((a) => a.gender == AnimalGender.male).toList();
    final femaleOffspring =
        offspring.where((a) => a.gender == AnimalGender.female).toList();

    // Pick primary mate: most-common fatherId among offspring that is in species set
    Animal? mate;
    final freq = <String, int>{};
    for (final child in offspring) {
      if (child.fatherId != null && byId.containsKey(child.fatherId)) {
        freq[child.fatherId!] = (freq[child.fatherId!] ?? 0) + 1;
      }
    }
    if (freq.isNotEmpty) {
      final topId =
          freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      mate = byId[topId];
    }

    return FamilyTreeNode(
      female: female,
      mate: mate,
      maleOffspring: maleOffspring,
      femaleSubtrees: femaleOffspring
          .map((f) => _buildNode(f, byId, childrenByMotherId))
          .toList(),
    );
  }

  /// Total pixel width this subtree occupies (used for connection line math).
  static double subtreeWidth(FamilyTreeNode node) {
    if (node.isLeaf) return nodeWidth;

    final maleW = node.maleOffspring.isEmpty
        ? 0.0
        : node.maleOffspring.length * nodeWidth +
            (node.maleOffspring.length - 1) * nodeGap;

    final femaleW = node.femaleSubtrees.isEmpty
        ? 0.0
        : node.femaleSubtrees.fold<double>(0, (s, sub) => s + subtreeWidth(sub)) +
            (node.femaleSubtrees.length - 1) * nodeGap;

    double childrenW;
    if (maleW > 0 && femaleW > 0) {
      childrenW = maleW + nodeGap + femaleW;
    } else {
      childrenW = math.max(maleW, femaleW);
    }

    return math.max(nodeWidth, childrenW);
  }
}
