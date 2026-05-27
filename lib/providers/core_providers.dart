import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../database/app_database.dart';
import '../models/animal.dart';
import '../models/female_rating.dart';
import '../models/health_event.dart';
import '../models/reproduction_event.dart';
import '../models/weight_measurement.dart';
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
import '../services/farm_id_service.dart';
import '../services/female_rating_service.dart';
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

final breedRepositoryProvider = Provider<BreedRepository>((ref) {
  return BreedRepository(ref.watch(appDatabaseProvider));
});

final weightMeasurementRepositoryProvider =
    Provider<WeightMeasurementRepository>((ref) {
  return WeightMeasurementRepository(ref.watch(appDatabaseProvider));
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(firebaseServiceProvider),
  );
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
    ref.watch(firebaseServiceProvider),
    ref.watch(reproductionEventRepositoryProvider),
  );
});

final fieldRepositoryProvider = Provider<FieldRepository>((ref) {
  return FieldRepository(ref.watch(appDatabaseProvider));
});

final cropRepositoryProvider = Provider<CropRepository>((ref) {
  return CropRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(historyRepositoryProvider),
  );
});

final cropActivityRepositoryProvider =
    Provider<CropActivityRepository>((ref) {
  return CropActivityRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(expenseRepositoryProvider),
    ref.watch(historyRepositoryProvider),
  );
});

final harvestRepositoryProvider = Provider<HarvestRepository>((ref) {
  return HarvestRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(saleRepositoryProvider),
    ref.watch(historyRepositoryProvider),
  );
});

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(historyRepositoryProvider),
    ref.watch(reproductionEventRepositoryProvider),
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

// ─── Female Rating Providers ──────────────────────────────────────────────────

/// Rating for a single female. Reload on demand with ref.invalidate().
final femaleRatingProvider =
    FutureProvider.autoDispose.family<FemaleRating?, String>((ref, animalId) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return null;
  final userId = user.uid;

  final animalRepo = ref.read(animalRepositoryProvider);
  final reproRepo = ref.read(reproductionEventRepositoryProvider);
  final weightRepo = ref.read(weightMeasurementRepositoryProvider);
  final healthRepo = ref.read(healthEventRepositoryProvider);

  final female = await animalRepo.getById(animalId);
  if (female == null || female.gender != AnimalGender.female) return null;

  final events = await reproRepo.getForAnimal(userId, animalId);
  final offspring = await animalRepo.getByMotherId(userId, animalId);
  final allUserRepro = await reproRepo.getAllForUser(userId);
  final speciesFemales = (await animalRepo.getBySpecies(userId, female.speciesId))
      .where((a) => a.gender == AnimalGender.female)
      .toList();
  final healthEvents = await healthRepo.getForAnimal(userId, animalId);

  // Weight measurements per offspring (parallel)
  final weightsList = await Future.wait(
    offspring.map((o) => weightRepo.getForAnimal(userId, o.id)),
  );
  final weightsByOffspring = <String, List<WeightMeasurement>>{
    for (var i = 0; i < offspring.length; i++) offspring[i].id: weightsList[i],
  };

  // Build peers events map: filter allUserRepro by animalId for each peer
  final peersEvents = <String, List<ReproductionEvent>>{
    for (final peer in speciesFemales)
      peer.id: allUserRepro.where((e) => e.animalId == peer.id).toList(),
  };
  peersEvents[female.id] = events;

  final endDate = female.deathDate != null
      ? DateTime.parse(female.deathDate!)
      : DateTime.now();

  return FemaleRatingService.compute(
    female: female,
    endDate: endDate,
    events: events,
    offspring: offspring,
    weightsByOffspring: weightsByOffspring,
    speciesPeers: speciesFemales,
    peersEvents: peersEvents,
    healthEvents: healthEvents,
  );
});

/// Ratings for ALL females — used by the ranking screen. Loads in bulk (no N+1 queries).
final femaleRankingProvider =
    FutureProvider.autoDispose.family<List<(Animal, FemaleRating?)>, String>(
        (ref, userId) async {
  final animalRepo = ref.read(animalRepositoryProvider);
  final reproRepo = ref.read(reproductionEventRepositoryProvider);
  final weightRepo = ref.read(weightMeasurementRepositoryProvider);
  final healthRepo = ref.read(healthEventRepositoryProvider);

  final allAnimals = await animalRepo.getAll(userId);
  final allFemales =
      allAnimals.where((a) => a.gender == AnimalGender.female).toList();

  final allRepro = await reproRepo.getAllForUser(userId);
  final allWeights = await weightRepo.getAll(userId);
  final allHealth = await healthRepo.getAllForUser(userId);

  // Group weights by animalId (sorted by date)
  final weightsByAnimal = <String, List<WeightMeasurement>>{};
  for (final w in allWeights) {
    weightsByAnimal.putIfAbsent(w.animalId, () => []).add(w);
  }
  for (final list in weightsByAnimal.values) {
    list.sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
  }

  // Group health events and repro events by animalId
  final healthByAnimal = <String, List<HealthEvent>>{};
  for (final h in allHealth) {
    healthByAnimal.putIfAbsent(h.animalId, () => []).add(h);
  }
  final reproByAnimal = <String, List<ReproductionEvent>>{};
  for (final e in allRepro) {
    reproByAnimal.putIfAbsent(e.animalId, () => []).add(e);
  }

  final results = <(Animal, FemaleRating?)>[];
  for (final female in allFemales) {
    final offspring =
        allAnimals.where((a) => a.motherId == female.id).toList();
    final weightsByOffspring = <String, List<WeightMeasurement>>{
      for (final o in offspring)
        o.id: weightsByAnimal[o.id] ?? const [],
    };
    final speciesPeers = allFemales
        .where((a) => a.speciesId == female.speciesId)
        .toList();
    final peersEvents = <String, List<ReproductionEvent>>{
      for (final p in speciesPeers)
        p.id: reproByAnimal[p.id] ?? const [],
    };
    final endDate = female.deathDate != null
        ? DateTime.parse(female.deathDate!)
        : DateTime.now();

    final rating = FemaleRatingService.compute(
      female: female,
      endDate: endDate,
      events: reproByAnimal[female.id] ?? const [],
      offspring: offspring,
      weightsByOffspring: weightsByOffspring,
      speciesPeers: speciesPeers,
      peersEvents: peersEvents,
      healthEvents: healthByAnimal[female.id] ?? const [],
    );
    results.add((female, rating));
  }

  // Rated first (composite desc), unrated last
  results.sort((a, b) {
    final ra = a.$2?.composite;
    final rb = b.$2?.composite;
    if (ra == null && rb == null) return 0;
    if (ra == null) return 1;
    if (rb == null) return -1;
    return rb.compareTo(ra);
  });

  return results;
});
