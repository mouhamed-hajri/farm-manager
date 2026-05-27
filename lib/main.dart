import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'app.dart';
import 'database/app_database.dart';
import 'repositories/animal_repository.dart';
import 'repositories/crop_activity_repository.dart';
import 'repositories/crop_repository.dart';
import 'repositories/expense_repository.dart';
import 'repositories/harvest_repository.dart';
import 'repositories/field_repository.dart';
import 'repositories/health_event_repository.dart';
import 'repositories/history_repository.dart';
import 'repositories/reminder_repository.dart';
import 'repositories/reproduction_event_repository.dart';
import 'repositories/sale_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/breed_repository.dart';
import 'repositories/species_repository.dart';
import 'repositories/weight_measurement_repository.dart';
import 'services/farm_id_service.dart';
import 'services/firebase_service.dart';
import 'services/storage_service.dart';
import 'services/sync_service.dart';

const _syncTaskName = 'farmDailySync';
const _syncTaskId = 'com.example.farm_manager.dailySync';

// Mirrors the Cloudinary config in core_providers.dart. Kept in sync manually —
// the background isolate can't read providers, so we duplicate the constants.
const _kCloudinaryConfig = CloudinaryConfig(
  cloudName: 'dnrjr7gpw',
  uploadPreset: 'aewnsjth',
);

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      await Firebase.initializeApp();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Not signed in on this device — nothing to upload.
        return true;
      }
      final db = AppDatabase();
      try {
        final speciesRepo = SpeciesRepository(db);
        final firebaseSvc = FirebaseService(FirebaseFirestore.instance);
        final historyRepo = HistoryRepository(db, firebaseSvc);
        final expenseRepo = ExpenseRepository(db);
        final farmIdSvc = FarmIdService(db);
        final reproRepo = ReproductionEventRepository(db);
        final animalRepo =
            AnimalRepository(db, expenseRepo, historyRepo, farmIdSvc, firebaseSvc, reproRepo);
        final fieldRepo = FieldRepository(db);
        final cropRepo = CropRepository(db, historyRepo);
        final saleRepo = SaleRepository(db, historyRepo, reproRepo);
        final cropActivityRepo =
            CropActivityRepository(db, expenseRepo, historyRepo);
        final harvestRepo = HarvestRepository(db, saleRepo, historyRepo);
        final healthRepo = HealthEventRepository(db);
        final reminderRepo = ReminderRepository(db);
        final breedRepo = BreedRepository(db);
        final weightMeasurementRepo = WeightMeasurementRepository(db);
        final settingsRepo = SettingsRepository(db);
        final storageSvc = StorageService(_kCloudinaryConfig);
        final syncSvc = SyncService(
          db: db,
          animalRepo: animalRepo,
          breedRepo: breedRepo,
          expenseRepo: expenseRepo,
          historyRepo: historyRepo,
          speciesRepo: speciesRepo,
          fieldRepo: fieldRepo,
          cropRepo: cropRepo,
          cropActivityRepo: cropActivityRepo,
          harvestRepo: harvestRepo,
          saleRepo: saleRepo,
          reproductionRepo: reproRepo,
          healthRepo: healthRepo,
          reminderRepo: reminderRepo,
          settingsRepo: settingsRepo,
          weightMeasurementRepo: weightMeasurementRepo,
          firebaseService: firebaseSvc,
          storageService: storageSvc,
        );
        await syncSvc.syncPending(user.uid);
      } finally {
        await db.close();
      }
      return true;
    } catch (_) {
      // Return false → WorkManager will retry per its policy.
      return false;
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Firebase.initializeApp();

  tzdata.initializeTimeZones();
  final notif = FlutterLocalNotificationsPlugin();
  await notif.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await notif
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    _syncTaskId,
    _syncTaskName,
    frequency: const Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(const ProviderScope(child: FarmApp()));
}
