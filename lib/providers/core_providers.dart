import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../database/app_database.dart';
import '../repositories/animal_repository.dart';
import '../repositories/crop_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/field_repository.dart';
import '../repositories/health_event_repository.dart';
import '../repositories/history_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/reproduction_event_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/species_repository.dart';
import '../services/farm_id_service.dart';
import '../services/firebase_service.dart';
import '../services/photo_service.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';

const _cloudinaryConfig = CloudinaryConfig(
  cloudName: 'dnrjr7gpw',
  uploadPreset: 'aewnsjth',
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService(ref.watch(firestoreProvider));
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(_cloudinaryConfig);
});

final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService(ImagePicker());
});

final farmIdServiceProvider = Provider<FarmIdService>((ref) {
  return FarmIdService(ref.watch(appDatabaseProvider));
});

// ─── Repositories ────────────────────────────────────────────────────────────

final speciesRepositoryProvider = Provider<SpeciesRepository>((ref) {
  return SpeciesRepository(ref.watch(appDatabaseProvider));
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(appDatabaseProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(appDatabaseProvider));
});

final animalRepositoryProvider = Provider<AnimalRepository>((ref) {
  return AnimalRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(expenseRepositoryProvider),
    ref.watch(historyRepositoryProvider),
    ref.watch(farmIdServiceProvider),
  );
});

final fieldRepositoryProvider = Provider<FieldRepository>((ref) {
  return FieldRepository(ref.watch(appDatabaseProvider));
});

final cropRepositoryProvider = Provider<CropRepository>((ref) {
  return CropRepository(ref.watch(appDatabaseProvider));
});

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(historyRepositoryProvider),
  );
});

final reproductionEventRepositoryProvider =
    Provider<ReproductionEventRepository>((ref) {
  return ReproductionEventRepository(ref.watch(appDatabaseProvider));
});

final healthEventRepositoryProvider = Provider<HealthEventRepository>((ref) {
  return HealthEventRepository(ref.watch(appDatabaseProvider));
});

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  return ReminderRepository(ref.watch(appDatabaseProvider));
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(ref.watch(reminderRepositoryProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});
