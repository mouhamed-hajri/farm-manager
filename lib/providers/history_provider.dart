import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/history_entry.dart';
import 'core_providers.dart';

final historyListProvider = StreamProvider<List<HistoryEntry>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(historyRepositoryProvider).watchHistory(user.uid);
});
