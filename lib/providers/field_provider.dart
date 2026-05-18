import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/field.dart';
import 'core_providers.dart';

final fieldsListProvider = StreamProvider<List<FarmField>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(fieldRepositoryProvider).watchFields(user.uid);
});

final fieldByIdProvider = FutureProvider.family<FarmField?, String>((ref, id) {
  return ref.watch(fieldRepositoryProvider).getById(id);
});
