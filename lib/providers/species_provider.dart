import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/species.dart';
import 'core_providers.dart';

final speciesListProvider = StreamProvider<List<Species>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(speciesRepositoryProvider).watchSpecies(user.uid);
});

final speciesByIdProvider = FutureProvider.family<Species?, String>((ref, id) {
  return ref.watch(speciesRepositoryProvider).getById(id);
});

/// Triggers seeding default species (Moutons + Vaches) once after sign-in.
final speciesSeederProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  await ref.watch(speciesRepositoryProvider).seedDefaultsIfEmpty(user.uid);
  await ref.watch(cropRepositoryProvider).seedDefaultsIfEmpty(user.uid);
  await ref.watch(settingsRepositoryProvider).getOrCreate(user.uid);
});
