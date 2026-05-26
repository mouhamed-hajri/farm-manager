import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';
import 'core_providers.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    db: ref.watch(appDatabaseProvider),
    animalRepo: ref.watch(animalRepositoryProvider),
    breedRepo: ref.watch(breedRepositoryProvider),
    expenseRepo: ref.watch(expenseRepositoryProvider),
    historyRepo: ref.watch(historyRepositoryProvider),
    speciesRepo: ref.watch(speciesRepositoryProvider),
    fieldRepo: ref.watch(fieldRepositoryProvider),
    cropRepo: ref.watch(cropRepositoryProvider),
    saleRepo: ref.watch(saleRepositoryProvider),
    reproductionRepo: ref.watch(reproductionEventRepositoryProvider),
    healthRepo: ref.watch(healthEventRepositoryProvider),
    reminderRepo: ref.watch(reminderRepositoryProvider),
    settingsRepo: ref.watch(settingsRepositoryProvider),
    weightMeasurementRepo: ref.watch(weightMeasurementRepositoryProvider),
    firebaseService: ref.watch(firebaseServiceProvider),
    storageService: ref.watch(storageServiceProvider),
  );
});

final syncStateProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final int pendingCount;
  final int lastUploadedCount;
  final String? errorMessage;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastUploadedCount = 0,
    this.errorMessage,
  });

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    int? lastUploadedCount,
    String? errorMessage,
  }) =>
      SyncState(
        status: status ?? this.status,
        pendingCount: pendingCount ?? this.pendingCount,
        lastUploadedCount: lastUploadedCount ?? this.lastUploadedCount,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier(this._ref) : super(const SyncState());

  final Ref _ref;

  Future<void> sync() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    state = state.copyWith(status: SyncStatus.syncing);

    final result = await _ref.read(syncServiceProvider).syncPending(user.uid);

    if (result.success) {
      state = state.copyWith(
        status: SyncStatus.success,
        lastUploadedCount: result.uploaded,
        pendingCount: 0,
        errorMessage: null,
      );
    } else {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: result.error,
      );
    }
  }

  Future<RestoreResult> restore() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      return const RestoreResult(success: false, error: 'not_logged_in');
    }

    state = state.copyWith(status: SyncStatus.syncing);

    final result =
        await _ref.read(syncServiceProvider).restoreFromCloud(user.uid);

    state = state.copyWith(
      status: result.success ? SyncStatus.success : SyncStatus.error,
      errorMessage: result.success ? null : result.error,
    );

    return result;
  }

  /// Merges any duplicate animal categories left by older app versions.
  Future<void> dedupeSpecies() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    await _ref.read(syncServiceProvider).dedupeSpecies(user.uid);
  }

  Future<void> refreshPendingCount() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    final count =
        await _ref.read(appDatabaseProvider).countPendingSync(user.uid);
    state = state.copyWith(pendingCount: count);
  }
}
