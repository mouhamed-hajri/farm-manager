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
import 'firebase_service.dart';
import 'storage_service.dart';

class SyncResult {
  final bool success;
  final int uploaded;
  final String? error;

  const SyncResult({required this.success, this.uploaded = 0, this.error});
}

class RestoreResult {
  final bool success;
  final int restoredAnimals;
  final int restoredExpenses;
  final int restoredHistory;
  final String? error;

  const RestoreResult({
    required this.success,
    this.restoredAnimals = 0,
    this.restoredExpenses = 0,
    this.restoredHistory = 0,
    this.error,
  });
}

class SyncService {
  SyncService({
    required this.db,
    required this.animalRepo,
    required this.expenseRepo,
    required this.historyRepo,
    required this.speciesRepo,
    required this.fieldRepo,
    required this.cropRepo,
    required this.saleRepo,
    required this.reproductionRepo,
    required this.healthRepo,
    required this.reminderRepo,
    required this.settingsRepo,
    required this.firebaseService,
    required this.storageService,
  });

  final AppDatabase db;
  final AnimalRepository animalRepo;
  final ExpenseRepository expenseRepo;
  final HistoryRepository historyRepo;
  final SpeciesRepository speciesRepo;
  final FieldRepository fieldRepo;
  final CropRepository cropRepo;
  final SaleRepository saleRepo;
  final ReproductionEventRepository reproductionRepo;
  final HealthEventRepository healthRepo;
  final ReminderRepository reminderRepo;
  final SettingsRepository settingsRepo;
  final FirebaseService firebaseService;
  final StorageService storageService;

  Future<SyncResult> syncPending(String userId) async {
    try {
      var uploaded = 0;

      // Species
      for (final s in await speciesRepo.getPending(userId)) {
        await firebaseService.uploadSpecies(s);
        await speciesRepo.markSynced(s.id);
        uploaded++;
      }

      // Animals (with photo upload)
      for (final animal in await animalRepo.getPendingAnimals(userId)) {
        var toUpload = animal;
        if (animal.photoLocalPath != null && animal.photoCloudUrl == null) {
          final url = await storageService.uploadAnimalPhoto(
            userId: userId,
            animalId: animal.id,
            localPath: animal.photoLocalPath!,
          );
          if (url != null) toUpload = animal.copyWith(photoCloudUrl: url);
        }
        await firebaseService.uploadAnimal(toUpload);
        await animalRepo.markSynced(animal.id);
        uploaded++;
      }

      // Fields
      for (final f in await fieldRepo.getPending(userId)) {
        await firebaseService.uploadField(f);
        await fieldRepo.markSynced(f.id);
        uploaded++;
      }

      // Crops
      for (final c in await cropRepo.getPending(userId)) {
        await firebaseService.uploadCrop(c);
        await cropRepo.markSynced(c.id);
        uploaded++;
      }

      // Expenses
      for (final e in await expenseRepo.getPendingExpenses(userId)) {
        await firebaseService.uploadExpense(e);
        await expenseRepo.markSynced(e.id);
        uploaded++;
      }

      // Sales
      for (final s in await saleRepo.getPending(userId)) {
        await firebaseService.uploadSale(s);
        await saleRepo.markSynced(s.id);
        uploaded++;
      }

      // Reproduction
      for (final r in await reproductionRepo.getPending(userId)) {
        await firebaseService.uploadReproductionEvent(r);
        await reproductionRepo.markSynced(r.id);
        uploaded++;
      }

      // Health
      for (final h in await healthRepo.getPending(userId)) {
        await firebaseService.uploadHealthEvent(h);
        await healthRepo.markSynced(h.id);
        uploaded++;
      }

      // Reminders
      for (final r in await reminderRepo.getPending(userId)) {
        await firebaseService.uploadReminder(r);
        await reminderRepo.markSynced(r.id);
        uploaded++;
      }

      // History
      for (final h in await historyRepo.getPendingHistory(userId)) {
        await firebaseService.uploadHistory(h);
        await historyRepo.markSynced(h.id);
        uploaded++;
      }

      // Counters
      final counters = await db.getAllCounters(userId);
      for (final c in counters) {
        await firebaseService.uploadCounter(
            c.userId, c.prefix, c.year, c.lastNumber);
      }

      if (uploaded > 0) {
        await firebaseService.updateLastBackupDate(userId);
      }

      return SyncResult(success: true, uploaded: uploaded);
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    }
  }

  Future<RestoreResult> restoreFromCloud(String userId) async {
    try {
      final species = await firebaseService.fetchAllSpecies(userId);
      final animals = await firebaseService.fetchAllAnimals(userId);
      final fields = await firebaseService.fetchAllFields(userId);
      final crops = await firebaseService.fetchAllCrops(userId);
      final expenses = await firebaseService.fetchAllExpenses(userId);
      final sales = await firebaseService.fetchAllSales(userId);
      final reproductionEvents =
          await firebaseService.fetchAllReproductionEvents(userId);
      final healthEvents = await firebaseService.fetchAllHealthEvents(userId);
      final reminders = await firebaseService.fetchAllReminders(userId);
      final history = await firebaseService.fetchAllHistory(userId);
      final counters = await firebaseService.fetchAllCounters(userId);
      final settings = await firebaseService.fetchSettings(userId);

      await db.restoreFromCloud(
        species: species,
        animals: animals,
        fields: fields,
        crops: crops,
        expenses: expenses,
        sales: sales,
        reproductionEvents: reproductionEvents,
        healthEvents: healthEvents,
        reminders: reminders,
        history: history,
        counterByPrefixYear: counters,
        settings: settings,
      );

      return RestoreResult(
        success: true,
        restoredAnimals: animals.length,
        restoredExpenses: expenses.length,
        restoredHistory: history.length,
      );
    } catch (e) {
      return RestoreResult(success: false, error: e.toString());
    }
  }
}
