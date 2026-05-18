import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/crop.dart';
import 'core_providers.dart';

final cropsListProvider = StreamProvider<List<Crop>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(cropRepositoryProvider).watchCrops(user.uid);
});

final cropByIdProvider = FutureProvider.family<Crop?, String>((ref, id) {
  return ref.watch(cropRepositoryProvider).getById(id);
});
