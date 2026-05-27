import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/crop.dart';
import '../models/crop_activity.dart';
import '../models/harvest.dart';
import 'core_providers.dart';

// Typed providers below — imports of CropActivity/Harvest used in generics.

final cropsListProvider = StreamProvider<List<Crop>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(cropRepositoryProvider).watchCrops(user.uid);
});

/// Derived from the live crops list — auto-updates on any change.
final cropByIdProvider = Provider.family<AsyncValue<Crop?>, String>((ref, id) {
  return ref.watch(cropsListProvider).whenData((list) {
    try {
      return list.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  });
});

final cropActivitiesProvider = StreamProvider.family
    .autoDispose<List<CropActivity>, String>((ref, cropId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(cropActivityRepositoryProvider)
      .watchForCrop(user.uid, cropId);
});

final cropHarvestsProvider = StreamProvider.family
    .autoDispose<List<Harvest>, String>((ref, cropId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(harvestRepositoryProvider)
      .watchForCrop(user.uid, cropId);
});
