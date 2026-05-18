import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_settings.dart';
import 'core_providers.dart';

final settingsProvider = StreamProvider<UserSettings?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(settingsRepositoryProvider).watch(user.uid);
});
