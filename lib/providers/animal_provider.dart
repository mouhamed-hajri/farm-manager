import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/animal.dart';
import '../models/animal_ledger.dart';
import 'core_providers.dart';

final allAnimalsProvider = StreamProvider<List<Animal>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(animalRepositoryProvider).watchAllAnimals(user.uid);
});

final animalsBySpeciesProvider =
    StreamProvider.family<List<Animal>, String>((ref, speciesId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(animalRepositoryProvider)
      .watchAnimalsBySpecies(user.uid, speciesId);
});

final animalByIdProvider = FutureProvider.family<Animal?, String>((ref, id) {
  return ref.watch(animalRepositoryProvider).getById(id);
});

final animalLedgerProvider =
    FutureProvider.autoDispose.family<AnimalLedger?, String>((ref, animalId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(null);
  return ref.watch(animalRepositoryProvider).getFinanceLedger(user.uid, animalId);
});

final allAnimalsStatsProvider = Provider<AnimalsStats>((ref) {
  final async = ref.watch(allAnimalsProvider);
  return async.when(
    data: AnimalsStats.fromList,
    loading: () => const AnimalsStats(),
    error: (_, __) => const AnimalsStats(),
  );
});

class AnimalsStats {
  final int total;
  final int active;
  final int sold;
  final int dead;
  final int soldThisMonth;
  final int diedThisMonth;

  const AnimalsStats({
    this.total = 0,
    this.active = 0,
    this.sold = 0,
    this.dead = 0,
    this.soldThisMonth = 0,
    this.diedThisMonth = 0,
  });

  factory AnimalsStats.fromList(List<Animal> list) {
    final now = DateTime.now();
    final monthPrefix =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return AnimalsStats(
      total: list.length,
      active: list.where((a) => a.status == AnimalStatus.active).length,
      sold: list.where((a) => a.status == AnimalStatus.sold).length,
      dead: list.where((a) => a.status == AnimalStatus.dead).length,
      soldThisMonth: list
          .where((a) =>
              a.status == AnimalStatus.sold &&
              a.updatedAt.startsWith(monthPrefix))
          .length,
      diedThisMonth: list
          .where((a) =>
              a.status == AnimalStatus.dead &&
              (a.deathDate ?? a.updatedAt).startsWith(monthPrefix))
          .length,
    );
  }
}
