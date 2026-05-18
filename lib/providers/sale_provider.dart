import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sale.dart';
import 'core_providers.dart';

final salesListProvider = StreamProvider<List<Sale>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(saleRepositoryProvider).watchAllSales(user.uid);
});

final salesForAnimalProvider =
    FutureProvider.family<Sale?, String>((ref, animalId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Future.value(null);
  return ref.watch(saleRepositoryProvider).getSaleForAnimal(user.uid, animalId);
});

final salesForCropProvider =
    StreamProvider.family<List<Sale>, String>((ref, cropId) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(saleRepositoryProvider).watchSalesForCrop(user.uid, cropId);
});
