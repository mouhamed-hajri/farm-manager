import '../database/app_database.dart';
import '../models/species.dart';
import '../repositories/animal_repository.dart';
import '../repositories/breed_repository.dart';
import '../repositories/crop_activity_repository.dart';
import '../repositories/crop_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/harvest_repository.dart';
import '../repositories/field_repository.dart';
import '../repositories/health_event_repository.dart';
import '../repositories/history_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/reproduction_event_repository.dart';
import '../repositories/sale_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/species_repository.dart';
import '../repositories/weight_measurement_repository.dart';
import 'firebase_service.dart';
import 'storage_service.dart';

class SyncResult {
  final bool success;
  final int uploaded;
  final String? error;

  const SyncResult({required this.success, this.uploaded = 0, this.error});

  bool get isPartialSuccess => success && error != null;
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
    required this.breedRepo,
    required this.expenseRepo,
    required this.historyRepo,
    required this.speciesRepo,
    required this.fieldRepo,
    required this.cropRepo,
    required this.cropActivityRepo,
    required this.harvestRepo,
    required this.saleRepo,
    required this.reproductionRepo,
    required this.healthRepo,
    required this.reminderRepo,
    required this.settingsRepo,
    required this.weightMeasurementRepo,
    required this.firebaseService,
    required this.storageService,
  });

  final AppDatabase db;
  final AnimalRepository animalRepo;
  final BreedRepository breedRepo;
  final ExpenseRepository expenseRepo;
  final HistoryRepository historyRepo;
  final SpeciesRepository speciesRepo;
  final FieldRepository fieldRepo;
  final CropRepository cropRepo;
  final CropActivityRepository cropActivityRepo;
  final HarvestRepository harvestRepo;
  final SaleRepository saleRepo;
  final ReproductionEventRepository reproductionRepo;
  final HealthEventRepository healthRepo;
  final ReminderRepository reminderRepo;
  final SettingsRepository settingsRepo;
  final WeightMeasurementRepository weightMeasurementRepo;
  final FirebaseService firebaseService;
  final StorageService storageService;

  Future<SyncResult> syncPending(String userId) async {
    var uploaded = 0;
    final errors = <String>[];

    // Helper: upload one entity; if it fails, log and continue — don't abort
    // the entire sync. The entity stays 'pending' and will retry next sync.
    Future<void> tryUpload(Future<void> Function() fn, String label) async {
      try {
        await fn();
        uploaded++;
      } catch (e) {
        errors.add('$label: $e');
      }
    }

    try {
      // Species
      for (final s in await speciesRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadSpecies(s);
          await speciesRepo.markSynced(s.id);
        }, 'species/${s.id}');
      }

      // Breeds
      for (final b in await breedRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadBreed(b);
          await breedRepo.markSynced(b.id);
        }, 'breed/${b.id}');
      }

      // Animals (with photo upload)
      for (final animal in await animalRepo.getPendingAnimals(userId)) {
        await tryUpload(() async {
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
        }, 'animal/${animal.id}');
      }

      // Fields
      for (final f in await fieldRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadField(f);
          await fieldRepo.markSynced(f.id);
        }, 'field/${f.id}');
      }

      // Crops
      for (final c in await cropRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadCrop(c);
          await cropRepo.markSynced(c.id);
        }, 'crop/${c.id}');
      }

      // Crop Activities
      for (final a in await cropActivityRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadCropActivity(a);
          await cropActivityRepo.markSynced(a.id);
        }, 'crop_activity/${a.id}');
      }

      // Harvests
      for (final h in await harvestRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadHarvest(h);
          await harvestRepo.markSynced(h.id);
        }, 'harvest/${h.id}');
      }

      // Expenses
      for (final e in await expenseRepo.getPendingExpenses(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadExpense(e);
          await expenseRepo.markSynced(e.id);
        }, 'expense/${e.id}');
      }

      // Sales
      for (final s in await saleRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadSale(s);
          await saleRepo.markSynced(s.id);
        }, 'sale/${s.id}');
      }

      // Reproduction
      for (final r in await reproductionRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadReproductionEvent(r);
          await reproductionRepo.markSynced(r.id);
        }, 'repro/${r.id}');
      }

      // Health
      for (final h in await healthRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadHealthEvent(h);
          await healthRepo.markSynced(h.id);
        }, 'health/${h.id}');
      }

      // Reminders
      for (final r in await reminderRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadReminder(r);
          await reminderRepo.markSynced(r.id);
        }, 'reminder/${r.id}');
      }

      // History
      for (final h in await historyRepo.getPendingHistory(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadHistory(h);
          await historyRepo.markSynced(h.id);
        }, 'history/${h.id}');
      }

      // Weight measurements
      for (final m in await weightMeasurementRepo.getPending(userId)) {
        await tryUpload(() async {
          await firebaseService.uploadWeightMeasurement(m);
          await weightMeasurementRepo.markSynced(m.id);
        }, 'weight/${m.id}');
      }

      // Counters (best-effort — not per-entity critical)
      try {
        final counters = await db.getAllCounters(userId);
        for (final c in counters) {
          await firebaseService.uploadCounter(
              c.userId, c.prefix, c.year, c.lastNumber);
        }
      } catch (e) {
        errors.add('counters: $e');
      }

      if (uploaded > 0) {
        try {
          await firebaseService.updateLastBackupDate(userId);
        } catch (_) {}
      }

      if (errors.isNotEmpty) {
        // Partial success: some entities failed but the rest are synced.
        return SyncResult(
          success: uploaded > 0 || errors.length < 3,
          uploaded: uploaded,
          error: '${errors.length} erreur(s) : ${errors.first}',
        );
      }
      return SyncResult(success: true, uploaded: uploaded);
    } catch (e) {
      return SyncResult(success: false, uploaded: uploaded, error: e.toString());
    }
  }

  /// Merges duplicate species (same name) into one. Older app versions could
  /// seed default categories locally AND then pull the same categories from
  /// the cloud — producing e.g. two "Moutons". For each duplicate group the
  /// oldest record is kept; animals and expenses are re-pointed to it and the
  /// extra copies are removed locally and from the cloud.
  Future<void> dedupeSpecies(String userId) async {
    final species = await speciesRepo.getSpecies(userId);
    final byName = <String, List<Species>>{};
    for (final s in species) {
      byName.putIfAbsent(s.nameFr.trim().toLowerCase(), () => []).add(s);
    }
    for (final group in byName.values) {
      if (group.length < 2) continue;
      group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final keeper = group.first;
      for (final loser in group.skip(1)) {
        await db.reassignAnimalsSpecies(userId, loser.id, keeper.id);
        await db.reassignExpensesSpecies(userId, loser.id, keeper.id);
        await db.deleteSpecies(loser.id);
        try {
          await firebaseService.deleteSpecies(userId, loser.id);
        } catch (_) {
          // Offline or already gone — local cleanup is what matters; the
          // cloud copy is harmless and will be merged again on next launch.
        }
      }
    }
  }

  Future<RestoreResult> restoreFromCloud(String userId) async {
    try {
      final species = await firebaseService.fetchAllSpecies(userId);
      final breeds = await firebaseService.fetchAllBreeds(userId);
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
      final weightMeasurements =
          await firebaseService.fetchAllWeightMeasurements(userId);
      final cropActivities = await firebaseService.fetchAllCropActivities(userId);
      final harvests = await firebaseService.fetchAllHarvests(userId);

      await db.restoreFromCloud(
        species: species,
        breeds: breeds,
        animals: animals,
        fields: fields,
        crops: crops,
        expenses: expenses,
        sales: sales,
        reproductionEvents: reproductionEvents,
        healthEvents: healthEvents,
        reminders: reminders,
        history: history,
        weightMeasurements: weightMeasurements,
        cropActivities: cropActivities,
        harvests: harvests,
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
