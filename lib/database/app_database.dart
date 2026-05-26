import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../models/animal.dart';
import '../models/breed.dart';
import '../models/expense.dart';
import '../models/history_entry.dart';
import '../models/species.dart';
import '../models/field.dart';
import '../models/crop.dart';
import '../models/sale.dart';
import '../models/reproduction_event.dart';
import '../models/health_event.dart';
import '../models/reminder.dart';
import '../models/user_settings.dart';
import '../models/weight_measurement.dart';
import 'tables/animals_table.dart';
import 'tables/breeds_table.dart';
import 'tables/expenses_table.dart';
import 'tables/history_table.dart';
import 'tables/species_table.dart';
import 'tables/farm_id_counters_table.dart';
import 'tables/fields_table.dart';
import 'tables/crops_table.dart';
import 'tables/sales_table.dart';
import 'tables/reproduction_events_table.dart';
import 'tables/health_events_table.dart';
import 'tables/reminders_table.dart';
import 'tables/settings_table.dart';
import 'tables/weight_measurements_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  AnimalsTable,
  BreedsTable,
  ExpensesTable,
  HistoryTable,
  SpeciesTable,
  FarmIdCountersTable,
  FieldsTable,
  CropsTable,
  SalesTable,
  ReproductionEventsTable,
  HealthEventsTable,
  RemindersTable,
  SettingsTable,
  WeightMeasurementsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            for (final table in allTables) {
              await m.deleteTable(table.actualTableName);
            }
            await m.createAll();
            return;
          }
          if (from < 3) {
            await m.addColumn(animalsTable, animalsTable.financeOwnerId);
            await m.addColumn(animalsTable, animalsTable.financeMode);
            await m.addColumn(animalsTable, animalsTable.birthEventId);
            await customStatement('''
              UPDATE animals SET
                finance_owner_id = CASE
                  WHEN gender = 'male' AND mother_id IS NOT NULL THEN mother_id
                  ELSE id
                END,
                finance_mode = CASE
                  WHEN gender = 'male' AND mother_id IS NOT NULL THEN 'counted_under_mother'
                  WHEN gender = 'female' AND mother_id IS NOT NULL THEN 'independent_female_center'
                  ELSE 'self'
                END
              WHERE finance_owner_id IS NULL
            ''');
          }
          if (from < 4) {
            await m.createTable(breedsTable);
          }
          if (from < 5) {
            await m.createTable(weightMeasurementsTable);
          }
          if (from < 6) {
            await m.addColumn(animalsTable, animalsTable.weaningDate);
            await m.addColumn(animalsTable, animalsTable.valuationAmount);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'farm_manager_db');
  }

  // ─── Species ───────────────────────────────────────────────────────────────

  Stream<List<SpeciesTableData>> watchSpecies(String userId) =>
      (select(speciesTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.asc(t.nameFr)]))
          .watch();

  Future<List<SpeciesTableData>> getSpecies(String userId) =>
      (select(speciesTable)..where((t) => t.userId.equals(userId))).get();

  Future<SpeciesTableData?> getSpeciesById(String id) =>
      (select(speciesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertSpecies(SpeciesTableCompanion entry) =>
      into(speciesTable).insert(entry);

  Future<bool> updateSpecies(SpeciesTableCompanion entry) =>
      update(speciesTable).replace(entry);

  Future<int> deleteSpecies(String id) =>
      (delete(speciesTable)..where((t) => t.id.equals(id))).go();

  Future<List<SpeciesTableData>> getPendingSpecies(String userId) =>
      (select(speciesTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markSpeciesSynced(String id) async {
    await (update(speciesTable)..where((t) => t.id.equals(id))).write(
      const SpeciesTableCompanion(syncStatus: Value('synced')),
    );
  }

  // ─── Breeds ────────────────────────────────────────────────────────────────

  Stream<List<BreedsTableData>> watchBreeds(String userId, String speciesId) =>
      (select(breedsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.speciesId.equals(speciesId))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<List<BreedsTableData>> getBreeds(String userId, String speciesId) =>
      (select(breedsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.speciesId.equals(speciesId))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  Future<int> insertBreed(BreedsTableCompanion entry) =>
      into(breedsTable).insert(entry);

  Future<int> deleteBreed(String id) =>
      (delete(breedsTable)..where((t) => t.id.equals(id))).go();

  Future<List<BreedsTableData>> getPendingBreeds(String userId) =>
      (select(breedsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markBreedSynced(String id) async {
    await (update(breedsTable)..where((t) => t.id.equals(id))).write(
      const BreedsTableCompanion(syncStatus: Value('synced')),
    );
  }

  Future<List<BreedsTableData>> getAllBreeds(String userId) =>
      (select(breedsTable)..where((t) => t.userId.equals(userId))).get();

  // ─── Weight Measurements ──────────────────────────────────────────────────

  Stream<List<WeightMeasurementsTableData>> watchWeightMeasurementsForAnimal(
          String userId, String animalId) =>
      (select(weightMeasurementsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.animalId.equals(animalId))
            ..orderBy([(t) => OrderingTerm.asc(t.measurementDate)]))
          .watch();

  Future<List<WeightMeasurementsTableData>> getAllWeightMeasurements(
          String userId) =>
      (select(weightMeasurementsTable)
            ..where((t) => t.userId.equals(userId)))
          .get();

  Future<int> insertWeightMeasurement(
          WeightMeasurementsTableCompanion entry) =>
      into(weightMeasurementsTable).insertOnConflictUpdate(entry);

  Future<int> deleteWeightMeasurement(String id) =>
      (delete(weightMeasurementsTable)..where((t) => t.id.equals(id))).go();

  Future<List<WeightMeasurementsTableData>> getPendingWeightMeasurements(
          String userId) =>
      (select(weightMeasurementsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markWeightMeasurementSynced(String id) async {
    await (update(weightMeasurementsTable)..where((t) => t.id.equals(id)))
        .write(
      const WeightMeasurementsTableCompanion(syncStatus: Value('synced')),
    );
  }

  // ─── Farm ID Counters ──────────────────────────────────────────────────────

  Future<FarmIdCountersTableData?> getCounter(
          String userId, String prefix, int year) =>
      (select(farmIdCountersTable)
            ..where((t) =>
                t.userId.equals(userId) &
                t.prefix.equals(prefix) &
                t.year.equals(year)))
          .getSingleOrNull();

  Future<void> upsertCounter(FarmIdCountersTableCompanion entry) async {
    await into(farmIdCountersTable).insertOnConflictUpdate(entry);
  }

  Future<List<FarmIdCountersTableData>> getAllCounters(String userId) =>
      (select(farmIdCountersTable)..where((t) => t.userId.equals(userId))).get();

  // ─── Animals ───────────────────────────────────────────────────────────────

  Stream<List<AnimalsTableData>> watchAllAnimals(String userId) =>
      (select(animalsTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Stream<List<AnimalsTableData>> watchAnimalsBySpecies(
          String userId, String speciesId) =>
      (select(animalsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.speciesId.equals(speciesId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<List<AnimalsTableData>> getAnimalsBySpecies(
          String userId, String speciesId) =>
      (select(animalsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.speciesId.equals(speciesId)))
          .get();

  Future<AnimalsTableData?> getAnimalById(String id) =>
      (select(animalsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertAnimal(AnimalsTableCompanion entry) =>
      into(animalsTable).insert(entry);

  Future<bool> updateAnimal(AnimalsTableCompanion entry) =>
      update(animalsTable).replace(entry);

  Future<int> deleteAnimal(String id) =>
      (delete(animalsTable)..where((t) => t.id.equals(id))).go();

  /// Re-points every animal of [fromSpeciesId] to [toSpeciesId]. Used when
  /// merging duplicate species so no animal is left orphaned.
  Future<void> reassignAnimalsSpecies(
      String userId, String fromSpeciesId, String toSpeciesId) async {
    await (update(animalsTable)
          ..where((t) =>
              t.userId.equals(userId) & t.speciesId.equals(fromSpeciesId)))
        .write(AnimalsTableCompanion(
      speciesId: Value(toSpeciesId),
      syncStatus: const Value('pending'),
    ));
  }

  Future<List<AnimalsTableData>> getAnimalsByFinanceOwner(
          String userId, String ownerId) =>
      (select(animalsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.financeOwnerId.equals(ownerId)))
          .get();

  Future<List<AnimalsTableData>> getAnimalsByMotherId(
          String userId, String motherId) =>
      (select(animalsTable)
            ..where(
                (t) => t.userId.equals(userId) & t.motherId.equals(motherId)))
          .get();

  Future<List<AnimalsTableData>> getAnimalsByBirthEventId(
          String userId, String birthEventId) =>
      (select(animalsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.birthEventId.equals(birthEventId)))
          .get();

  Future<List<AnimalsTableData>> getMalesForSpecies(
          String userId, String speciesId) =>
      (select(animalsTable)
            ..where((t) =>
                t.userId.equals(userId) &
                t.speciesId.equals(speciesId) &
                t.gender.equals('male'))
            ..orderBy([(t) => OrderingTerm.asc(t.birthDate)]))
          .get();

  Future<List<AnimalsTableData>> getPendingAnimals(String userId) =>
      (select(animalsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markAnimalSynced(String id) async {
    await (update(animalsTable)..where((t) => t.id.equals(id))).write(
      const AnimalsTableCompanion(syncStatus: Value('synced')),
    );
  }

  // ─── Fields ────────────────────────────────────────────────────────────────

  Stream<List<FieldsTableData>> watchFields(String userId) =>
      (select(fieldsTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<FieldsTableData?> getFieldById(String id) =>
      (select(fieldsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertField(FieldsTableCompanion entry) =>
      into(fieldsTable).insert(entry);

  Future<bool> updateField(FieldsTableCompanion entry) =>
      update(fieldsTable).replace(entry);

  Future<int> deleteField(String id) =>
      (delete(fieldsTable)..where((t) => t.id.equals(id))).go();

  Future<List<FieldsTableData>> getPendingFields(String userId) =>
      (select(fieldsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markFieldSynced(String id) async {
    await (update(fieldsTable)..where((t) => t.id.equals(id))).write(
      const FieldsTableCompanion(syncStatus: Value('synced')),
    );
  }

  // ─── Crops ─────────────────────────────────────────────────────────────────

  Stream<List<CropsTableData>> watchCrops(String userId) =>
      (select(cropsTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.asc(t.nameFr)]))
          .watch();

  Future<List<CropsTableData>> getCrops(String userId) =>
      (select(cropsTable)..where((t) => t.userId.equals(userId))).get();

  Future<CropsTableData?> getCropById(String id) =>
      (select(cropsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertCrop(CropsTableCompanion entry) =>
      into(cropsTable).insert(entry);

  Future<bool> updateCrop(CropsTableCompanion entry) =>
      update(cropsTable).replace(entry);

  Future<int> deleteCrop(String id) =>
      (delete(cropsTable)..where((t) => t.id.equals(id))).go();

  Future<List<CropsTableData>> getPendingCrops(String userId) =>
      (select(cropsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markCropSynced(String id) async {
    await (update(cropsTable)..where((t) => t.id.equals(id))).write(
      const CropsTableCompanion(syncStatus: Value('synced')),
    );
  }

  // ─── Expenses ──────────────────────────────────────────────────────────────

  Stream<List<ExpensesTableData>> watchAllExpenses(String userId) =>
      (select(expensesTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Stream<List<ExpensesTableData>> watchExpensesForAnimal(
          String userId, String animalId) =>
      (select(expensesTable)
            ..where((t) =>
                t.userId.equals(userId) &
                t.linkedAnimalId.equals(animalId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Stream<List<ExpensesTableData>> watchExpensesForCrop(
          String userId, String cropId) =>
      (select(expensesTable)
            ..where((t) =>
                t.userId.equals(userId) & t.linkedCropId.equals(cropId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Stream<List<ExpensesTableData>> watchExpensesForField(
          String userId, String fieldId) =>
      (select(expensesTable)
            ..where((t) =>
                t.userId.equals(userId) & t.linkedFieldId.equals(fieldId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Future<List<ExpensesTableData>> getExpensesForAnimal(
          String userId, String animalId) =>
      (select(expensesTable)
            ..where((t) =>
                t.userId.equals(userId) & t.linkedAnimalId.equals(animalId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<int> insertExpense(ExpensesTableCompanion entry) =>
      into(expensesTable).insert(entry);

  Future<bool> updateExpense(ExpensesTableCompanion entry) =>
      update(expensesTable).replace(entry);

  Future<int> deleteExpense(String id) =>
      (delete(expensesTable)..where((t) => t.id.equals(id))).go();

  /// Deletes all expenses linked to [animalId] and returns their IDs so the
  /// caller can also remove them from Firestore.
  Future<List<String>> deleteExpensesForAnimal(
      String userId, String animalId) async {
    final rows = await (select(expensesTable)
          ..where((t) =>
              t.userId.equals(userId) & t.linkedAnimalId.equals(animalId)))
        .get();
    final ids = rows.map((r) => r.id).toList();
    await (delete(expensesTable)
          ..where((t) =>
              t.userId.equals(userId) & t.linkedAnimalId.equals(animalId)))
        .go();
    return ids;
  }

  /// Deletes all sales linked to [animalId] and returns their IDs so the
  /// caller can also remove them from Firestore.
  Future<List<String>> deleteSalesForAnimal(
      String userId, String animalId) async {
    final rows = await (select(salesTable)
          ..where((t) =>
              t.userId.equals(userId) & t.linkedAnimalId.equals(animalId)))
        .get();
    final ids = rows.map((r) => r.id).toList();
    await (delete(salesTable)
          ..where((t) =>
              t.userId.equals(userId) & t.linkedAnimalId.equals(animalId)))
        .go();
    return ids;
  }

  /// Re-points every expense linked to [fromSpeciesId] to [toSpeciesId]. Used
  /// when merging duplicate species.
  Future<void> reassignExpensesSpecies(
      String userId, String fromSpeciesId, String toSpeciesId) async {
    await (update(expensesTable)
          ..where((t) =>
              t.userId.equals(userId) &
              t.linkedSpeciesId.equals(fromSpeciesId)))
        .write(ExpensesTableCompanion(
      linkedSpeciesId: Value(toSpeciesId),
      syncStatus: const Value('pending'),
    ));
  }

  Future<List<ExpensesTableData>> getPendingExpenses(String userId) =>
      (select(expensesTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markExpenseSynced(String id) async {
    await (update(expensesTable)..where((t) => t.id.equals(id))).write(
      const ExpensesTableCompanion(syncStatus: Value('synced')),
    );
  }

  // ─── Sales ─────────────────────────────────────────────────────────────────

  Stream<List<SalesTableData>> watchAllSales(String userId) =>
      (select(salesTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.saleDate)]))
          .watch();

  Stream<List<SalesTableData>> watchSalesForAnimal(
          String userId, String animalId) =>
      (select(salesTable)
            ..where((t) =>
                t.userId.equals(userId) & t.linkedAnimalId.equals(animalId))
            ..orderBy([(t) => OrderingTerm.desc(t.saleDate)]))
          .watch();

  Future<SalesTableData?> getSaleForAnimal(
          String userId, String animalId) async {
    final results = await (select(salesTable)
          ..where((t) =>
              t.userId.equals(userId) & t.linkedAnimalId.equals(animalId))
          ..limit(1))
        .get();
    return results.isEmpty ? null : results.first;
  }

  Stream<List<SalesTableData>> watchSalesForCrop(
          String userId, String cropId) =>
      (select(salesTable)
            ..where((t) =>
                t.userId.equals(userId) & t.linkedCropId.equals(cropId))
            ..orderBy([(t) => OrderingTerm.desc(t.saleDate)]))
          .watch();

  Future<List<SalesTableData>> getSalesForAnimal(
          String userId, String animalId) =>
      (select(salesTable)
            ..where((t) =>
                t.userId.equals(userId) & t.linkedAnimalId.equals(animalId))
            ..orderBy([(t) => OrderingTerm.desc(t.saleDate)]))
          .get();

  Future<int> insertSale(SalesTableCompanion entry) =>
      into(salesTable).insert(entry);

  Future<bool> updateSale(SalesTableCompanion entry) =>
      update(salesTable).replace(entry);

  Future<int> deleteSale(String id) =>
      (delete(salesTable)..where((t) => t.id.equals(id))).go();

  Future<List<SalesTableData>> getPendingSales(String userId) =>
      (select(salesTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markSaleSynced(String id) async {
    await (update(salesTable)..where((t) => t.id.equals(id))).write(
      const SalesTableCompanion(syncStatus: Value('synced')),
    );
  }

  // ─── Reproduction events ───────────────────────────────────────────────────

  Future<List<ReproductionEventsTableData>> getAllReproductionForAnimal(
          String userId, String animalId) =>
      (select(reproductionEventsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.animalId.equals(animalId)))
          .get();

  Stream<List<ReproductionEventsTableData>> watchReproductionForAnimal(
          String userId, String animalId) =>
      (select(reproductionEventsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.animalId.equals(animalId))
            ..orderBy([(t) => OrderingTerm.desc(t.eventDate)]))
          .watch();

  Future<int> insertReproductionEvent(ReproductionEventsTableCompanion entry) =>
      into(reproductionEventsTable).insert(entry);

  Future<int> deleteReproductionEvent(String id) =>
      (delete(reproductionEventsTable)..where((t) => t.id.equals(id))).go();

  Future<List<ReproductionEventsTableData>> getPendingReproductionEvents(
          String userId) =>
      (select(reproductionEventsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markReproductionEventSynced(String id) async {
    await (update(reproductionEventsTable)..where((t) => t.id.equals(id)))
        .write(
      const ReproductionEventsTableCompanion(syncStatus: Value('synced')),
    );
  }

  // ─── Health events ─────────────────────────────────────────────────────────

  Stream<List<HealthEventsTableData>> watchHealthForAnimal(
          String userId, String animalId) =>
      (select(healthEventsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.animalId.equals(animalId))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .watch();

  Future<int> insertHealthEvent(HealthEventsTableCompanion entry) =>
      into(healthEventsTable).insert(entry);

  Future<int> deleteHealthEvent(String id) =>
      (delete(healthEventsTable)..where((t) => t.id.equals(id))).go();

  Future<List<HealthEventsTableData>> getPendingHealthEvents(String userId) =>
      (select(healthEventsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markHealthEventSynced(String id) async {
    await (update(healthEventsTable)..where((t) => t.id.equals(id))).write(
      const HealthEventsTableCompanion(syncStatus: Value('synced')),
    );
  }

  // One-shot health events for an animal (used by rating provider)
  Future<List<HealthEventsTableData>> getHealthEventsForAnimal(
          String userId, String animalId) =>
      (select(healthEventsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.animalId.equals(animalId))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

  // One-shot weight measurements for an animal (used by rating provider)
  Future<List<WeightMeasurementsTableData>> getWeightMeasurementsForAnimalOnce(
          String userId, String animalId) =>
      (select(weightMeasurementsTable)
            ..where((t) =>
                t.userId.equals(userId) & t.animalId.equals(animalId))
            ..orderBy([(t) => OrderingTerm.asc(t.measurementDate)]))
          .get();

  // All reproduction events for a user — used to build peer portée map
  Future<List<ReproductionEventsTableData>> getAllReproductionEventsForUser(
          String userId) =>
      (select(reproductionEventsTable)
            ..where((t) => t.userId.equals(userId)))
          .get();

  // All animals for a user — used by ranking screen
  Future<List<AnimalsTableData>> getAllAnimals(String userId) =>
      (select(animalsTable)..where((t) => t.userId.equals(userId))).get();

  // All health events for a user — used by ranking screen
  Future<List<HealthEventsTableData>> getAllHealthEventsForUser(
          String userId) =>
      (select(healthEventsTable)..where((t) => t.userId.equals(userId))).get();

  // ─── Reminders ─────────────────────────────────────────────────────────────

  Stream<List<RemindersTableData>> watchReminders(String userId) =>
      (select(remindersTable)
            ..where((t) => t.userId.equals(userId) & t.isDone.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.triggerDate)]))
          .watch();

  Future<List<RemindersTableData>> getRemindersForLinked(
          String userId, String linkedType, String linkedId) =>
      (select(remindersTable)
            ..where((t) =>
                t.userId.equals(userId) &
                t.linkedType.equals(linkedType) &
                t.linkedId.equals(linkedId)))
          .get();

  Future<int> insertReminder(RemindersTableCompanion entry) =>
      into(remindersTable).insert(entry);

  Future<int> deleteReminder(String id) =>
      (delete(remindersTable)..where((t) => t.id.equals(id))).go();

  Future<int> deleteRemindersForLinked(
          String userId, String linkedType, String linkedId) =>
      (delete(remindersTable)
            ..where((t) =>
                t.userId.equals(userId) &
                t.linkedType.equals(linkedType) &
                t.linkedId.equals(linkedId)))
          .go();

  Future<List<RemindersTableData>> getPendingReminders(String userId) =>
      (select(remindersTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markReminderSynced(String id) async {
    await (update(remindersTable)..where((t) => t.id.equals(id))).write(
      const RemindersTableCompanion(syncStatus: Value('synced')),
    );
  }

  // ─── Settings ──────────────────────────────────────────────────────────────

  Stream<SettingsTableData?> watchSettings(String userId) =>
      (select(settingsTable)..where((t) => t.userId.equals(userId)))
          .watchSingleOrNull();

  Future<SettingsTableData?> getSettings(String userId) =>
      (select(settingsTable)..where((t) => t.userId.equals(userId)))
          .getSingleOrNull();

  Future<void> upsertSettings(SettingsTableCompanion entry) async {
    await into(settingsTable).insertOnConflictUpdate(entry);
  }

  // ─── History ───────────────────────────────────────────────────────────────

  Stream<List<HistoryTableData>> watchHistory(String userId) =>
      (select(historyTable)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(50))
          .watch();

  Future<int> insertHistory(HistoryTableCompanion entry) =>
      into(historyTable).insert(entry);

  Future<List<HistoryTableData>> getPendingHistory(String userId) =>
      (select(historyTable)
            ..where((t) =>
                t.userId.equals(userId) & t.syncStatus.equals('pending')))
          .get();

  Future<void> markHistorySynced(String id) async {
    await (update(historyTable)..where((t) => t.id.equals(id))).write(
      const HistoryTableCompanion(syncStatus: Value('synced')),
    );
  }

  // ─── Bulk restore ──────────────────────────────────────────────────────────

  Future<void> restoreFromCloud({
    required List<Species> species,
    required List<Breed> breeds,
    required List<Animal> animals,
    required List<FarmField> fields,
    required List<Crop> crops,
    required List<Expense> expenses,
    required List<Sale> sales,
    required List<ReproductionEvent> reproductionEvents,
    required List<HealthEvent> healthEvents,
    required List<Reminder> reminders,
    required List<HistoryEntry> history,
    required List<WeightMeasurement> weightMeasurements,
    required Map<String, dynamic>? counterByPrefixYear, // map "PREFIX-YEAR" -> int
    required UserSettings? settings,
  }) async {
    await transaction(() async {
      for (final s in species) {
        await into(speciesTable).insertOnConflictUpdate(_speciesToCompanion(s));
      }
      for (final b in breeds) {
        await into(breedsTable).insertOnConflictUpdate(_breedToCompanion(b));
      }
      for (final a in animals) {
        await into(animalsTable).insertOnConflictUpdate(_animalToCompanion(a));
      }
      for (final f in fields) {
        await into(fieldsTable).insertOnConflictUpdate(_fieldToCompanion(f));
      }
      for (final c in crops) {
        await into(cropsTable).insertOnConflictUpdate(_cropToCompanion(c));
      }
      for (final e in expenses) {
        await into(expensesTable).insertOnConflictUpdate(_expenseToCompanion(e));
      }
      for (final s in sales) {
        await into(salesTable).insertOnConflictUpdate(_saleToCompanion(s));
      }
      for (final r in reproductionEvents) {
        await into(reproductionEventsTable)
            .insertOnConflictUpdate(_reproToCompanion(r));
      }
      for (final h in healthEvents) {
        await into(healthEventsTable).insertOnConflictUpdate(_healthToCompanion(h));
      }
      for (final r in reminders) {
        await into(remindersTable).insertOnConflictUpdate(_reminderToCompanion(r));
      }
      for (final m in weightMeasurements) {
        await into(weightMeasurementsTable).insertOnConflictUpdate(
          WeightMeasurementsTableCompanion(
            id: Value(m.id),
            userId: Value(m.userId),
            animalId: Value(m.animalId),
            weight: Value(m.weight),
            measurementDate: Value(m.measurementDate),
            notes: Value(m.notes),
            createdAt: Value(m.createdAt),
            updatedAt: Value(m.updatedAt),
            syncStatus: const Value('synced'),
          ),
        );
      }
      for (final h in history) {
        await into(historyTable).insertOnConflictUpdate(
          HistoryTableCompanion(
            id: Value(h.id),
            userId: Value(h.userId),
            actionType: Value(h.actionType),
            title: Value(h.title),
            description: Value(h.description),
            relatedType: Value(h.relatedType),
            relatedId: Value(h.relatedId),
            date: Value(h.date),
            createdAt: Value(h.createdAt),
            syncStatus: const Value('synced'),
          ),
        );
      }
      if (counterByPrefixYear != null) {
        for (final entry in counterByPrefixYear.entries) {
          final parts = entry.key.split('-');
          if (parts.length != 2) continue;
          final prefix = parts[0];
          final year = int.tryParse(parts[1]);
          if (year == null) continue;
          await into(farmIdCountersTable).insertOnConflictUpdate(
            FarmIdCountersTableCompanion(
              userId: Value(animals.isNotEmpty
                  ? animals.first.userId
                  : (species.isNotEmpty ? species.first.userId : '')),
              prefix: Value(prefix),
              year: Value(year),
              lastNumber: Value((entry.value as num).toInt()),
              syncStatus: const Value('synced'),
            ),
          );
        }
      }
      if (settings != null) {
        await into(settingsTable).insertOnConflictUpdate(
          SettingsTableCompanion(
            userId: Value(settings.userId),
            language: Value(settings.language),
            currency: Value(settings.currency),
            mode: Value(settings.mode),
            lastBackupDate: Value(settings.lastBackupDate),
            updatedAt: Value(settings.updatedAt),
            syncStatus: const Value('synced'),
          ),
        );
      }
    });
  }

  // ─── Helpers / aggregates ──────────────────────────────────────────────────

  Future<int> countAnimalsBySpecies(String userId, String speciesId,
      {String? status}) async {
    final countExp = animalsTable.id.count();
    final query = selectOnly(animalsTable)..addColumns([countExp]);
    final base = animalsTable.userId.equals(userId) &
        animalsTable.speciesId.equals(speciesId);
    query.where(status == null ? base : base & animalsTable.status.equals(status));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<double> sumExpensesInRange(String userId, DateTime start, DateTime end,
      {String? scope, String? linkedSpeciesId}) async {
    final sumExp = expensesTable.amount.sum();
    final query = selectOnly(expensesTable)..addColumns([sumExp]);
    final base = expensesTable.userId.equals(userId) &
        expensesTable.date.isBiggerOrEqualValue(_dateOnly(start)) &
        expensesTable.date.isSmallerOrEqualValue(_dateOnly(end));
    var where = base;
    if (scope != null) where = where & expensesTable.scope.equals(scope);
    if (linkedSpeciesId != null) {
      where = where & expensesTable.linkedSpeciesId.equals(linkedSpeciesId);
    }
    query.where(where);
    final row = await query.getSingle();
    return row.read(sumExp) ?? 0.0;
  }

  Future<double> sumSalesInRange(String userId, DateTime start, DateTime end,
      {String? scope}) async {
    final sumExp = salesTable.totalPrice.sum();
    final query = selectOnly(salesTable)..addColumns([sumExp]);
    final base = salesTable.userId.equals(userId) &
        salesTable.saleDate.isBiggerOrEqualValue(_dateOnly(start)) &
        salesTable.saleDate.isSmallerOrEqualValue(_dateOnly(end));
    query.where(scope == null ? base : base & salesTable.scope.equals(scope));
    final row = await query.getSingle();
    return row.read(sumExp) ?? 0.0;
  }

  Future<int> countPendingSync(String userId) async {
    final a = await getPendingAnimals(userId);
    final e = await getPendingExpenses(userId);
    final s = await getPendingSales(userId);
    final sp = await getPendingSpecies(userId);
    final f = await getPendingFields(userId);
    final c = await getPendingCrops(userId);
    final r = await getPendingReproductionEvents(userId);
    final h = await getPendingHealthEvents(userId);
    final rm = await getPendingReminders(userId);
    final hi = await getPendingHistory(userId);
    final br = await getPendingBreeds(userId);
    final wm = await getPendingWeightMeasurements(userId);

    return a.length +
        e.length +
        s.length +
        sp.length +
        f.length +
        c.length +
        r.length +
        h.length +
        rm.length +
        hi.length +
        br.length +
        wm.length;
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ─── Companion builders for restore ────────────────────────────────────────

  BreedsTableCompanion _breedToCompanion(Breed b) => BreedsTableCompanion(
        id: Value(b.id),
        userId: Value(b.userId),
        speciesId: Value(b.speciesId),
        name: Value(b.name),
        createdAt: Value(b.createdAt),
        updatedAt: Value(b.updatedAt),
        syncStatus: const Value('synced'),
      );

  SpeciesTableCompanion _speciesToCompanion(Species s) => SpeciesTableCompanion(
        id: Value(s.id),
        userId: Value(s.userId),
        nameFr: Value(s.nameFr),
        nameAr: Value(s.nameAr),
        iconEmoji: Value(s.iconEmoji),
        idPrefix: Value(s.idPrefix),
        isDefault: Value(s.isDefault),
        createdAt: Value(s.createdAt),
        updatedAt: Value(s.updatedAt),
        syncStatus: const Value('synced'),
      );

  AnimalsTableCompanion _animalToCompanion(Animal a) => AnimalsTableCompanion(
        id: Value(a.id),
        userId: Value(a.userId),
        speciesId: Value(a.speciesId),
        farmId: Value(a.farmId),
        nickname: Value(a.nickname),
        gender: Value(a.gender),
        breed: Value(a.breed),
        color: Value(a.color),
        birthDate: Value(a.birthDate),
        weight: Value(a.weight),
        healthStatus: Value(a.healthStatus),
        status: Value(a.status),
        purchaseDate: Value(a.purchaseDate),
        purchasePrice: Value(a.purchasePrice),
        sellerName: Value(a.sellerName),
        sellerPhone: Value(a.sellerPhone),
        purchaseLocation: Value(a.purchaseLocation),
        photoLocalPath: const Value(null),
        photoCloudUrl: Value(a.photoCloudUrl),
        motherId: Value(a.motherId),
        fatherId: Value(a.fatherId),
        deathDate: Value(a.deathDate),
        deathCause: Value(a.deathCause),
        deathNotes: Value(a.deathNotes),
        notes: Value(a.notes),
        financeOwnerId: Value(a.effectiveFinanceOwnerId),
        financeMode: Value(a.effectiveFinanceMode),
        birthEventId: Value(a.birthEventId),
        createdAt: Value(a.createdAt),
        updatedAt: Value(a.updatedAt),
        syncStatus: const Value('synced'),
      );

  FieldsTableCompanion _fieldToCompanion(FarmField f) => FieldsTableCompanion(
        id: Value(f.id),
        userId: Value(f.userId),
        name: Value(f.name),
        areaText: Value(f.areaText),
        locationText: Value(f.locationText),
        ownership: Value(f.ownership),
        photoLocalPath: const Value(null),
        photoCloudUrl: Value(f.photoCloudUrl),
        rentAmount: Value(f.rentAmount),
        rentPeriod: Value(f.rentPeriod),
        rentStartDate: Value(f.rentStartDate),
        rentEndDate: Value(f.rentEndDate),
        landlordName: Value(f.landlordName),
        landlordPhone: Value(f.landlordPhone),
        notes: Value(f.notes),
        createdAt: Value(f.createdAt),
        updatedAt: Value(f.updatedAt),
        syncStatus: const Value('synced'),
      );

  CropsTableCompanion _cropToCompanion(Crop c) => CropsTableCompanion(
        id: Value(c.id),
        userId: Value(c.userId),
        nameFr: Value(c.nameFr),
        nameAr: Value(c.nameAr),
        iconEmoji: Value(c.iconEmoji),
        kind: Value(c.kind),
        seasonMonths: Value(c.seasonMonthsJson()),
        fieldId: Value(c.fieldId),
        areaOrCountText: Value(c.areaOrCountText),
        photoLocalPath: const Value(null),
        photoCloudUrl: Value(c.photoCloudUrl),
        notes: Value(c.notes),
        isDefault: Value(c.isDefault),
        createdAt: Value(c.createdAt),
        updatedAt: Value(c.updatedAt),
        syncStatus: const Value('synced'),
      );

  ExpensesTableCompanion _expenseToCompanion(Expense e) =>
      ExpensesTableCompanion(
        id: Value(e.id),
        userId: Value(e.userId),
        scope: Value(e.scope),
        linkedAnimalId: Value(e.linkedAnimalId),
        linkedSpeciesId: Value(e.linkedSpeciesId),
        linkedCropId: Value(e.linkedCropId),
        linkedFieldId: Value(e.linkedFieldId),
        amount: Value(e.amount),
        category: Value(e.category),
        date: Value(e.date),
        description: Value(e.description),
        receiptPhotoLocalPath: const Value(null),
        receiptPhotoCloudUrl: Value(e.receiptPhotoCloudUrl),
        createdAt: Value(e.createdAt),
        updatedAt: Value(e.updatedAt),
        syncStatus: const Value('synced'),
      );

  SalesTableCompanion _saleToCompanion(Sale s) => SalesTableCompanion(
        id: Value(s.id),
        userId: Value(s.userId),
        scope: Value(s.scope),
        linkedAnimalId: Value(s.linkedAnimalId),
        linkedCropId: Value(s.linkedCropId),
        productName: Value(s.productName),
        quantity: Value(s.quantity),
        unit: Value(s.unit),
        unitPrice: Value(s.unitPrice),
        totalPrice: Value(s.totalPrice),
        buyerName: Value(s.buyerName),
        buyerPhone: Value(s.buyerPhone),
        saleDate: Value(s.saleDate),
        receiptPhotoLocalPath: const Value(null),
        receiptPhotoCloudUrl: Value(s.receiptPhotoCloudUrl),
        notes: Value(s.notes),
        createdAt: Value(s.createdAt),
        updatedAt: Value(s.updatedAt),
        syncStatus: const Value('synced'),
      );

  ReproductionEventsTableCompanion _reproToCompanion(ReproductionEvent e) =>
      ReproductionEventsTableCompanion(
        id: Value(e.id),
        userId: Value(e.userId),
        animalId: Value(e.animalId),
        eventType: Value(e.eventType),
        partnerId: Value(e.partnerId),
        eventDate: Value(e.eventDate),
        dueDate: Value(e.dueDate),
        offspringCount: Value(e.offspringCount),
        pregnancyGroupId: Value(e.pregnancyGroupId),
        notes: Value(e.notes),
        createdAt: Value(e.createdAt),
        updatedAt: Value(e.updatedAt),
        syncStatus: const Value('synced'),
      );

  HealthEventsTableCompanion _healthToCompanion(HealthEvent h) =>
      HealthEventsTableCompanion(
        id: Value(h.id),
        userId: Value(h.userId),
        animalId: Value(h.animalId),
        eventType: Value(h.eventType),
        description: Value(h.description),
        date: Value(h.date),
        vetName: Value(h.vetName),
        nextDueDate: Value(h.nextDueDate),
        notes: Value(h.notes),
        createdAt: Value(h.createdAt),
        updatedAt: Value(h.updatedAt),
        syncStatus: const Value('synced'),
      );

  RemindersTableCompanion _reminderToCompanion(Reminder r) =>
      RemindersTableCompanion(
        id: Value(r.id),
        userId: Value(r.userId),
        title: Value(r.title),
        body: Value(r.body),
        triggerDate: Value(r.triggerDate),
        category: Value(r.category),
        linkedType: Value(r.linkedType),
        linkedId: Value(r.linkedId),
        isDone: Value(r.isDone),
        platformNotificationId: Value(r.platformNotificationId),
        createdAt: Value(r.createdAt),
        updatedAt: Value(r.updatedAt),
        syncStatus: const Value('synced'),
      );
}

// ─── Extension helpers ─────────────────────────────────────────────────────

extension BreedDataExt on BreedsTableData {
  Breed toModel() => Breed(
        id: id,
        userId: userId,
        speciesId: speciesId,
        name: name,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension WeightMeasurementDataExt on WeightMeasurementsTableData {
  WeightMeasurement toModel() => WeightMeasurement(
        id: id,
        userId: userId,
        animalId: animalId,
        weight: weight,
        measurementDate: measurementDate,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension SpeciesDataExt on SpeciesTableData {
  Species toModel() => Species(
        id: id,
        userId: userId,
        nameFr: nameFr,
        nameAr: nameAr,
        iconEmoji: iconEmoji,
        idPrefix: idPrefix,
        isDefault: isDefault,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension AnimalDataExt on AnimalsTableData {
  Animal toModel() => Animal(
        id: id,
        userId: userId,
        speciesId: speciesId,
        farmId: farmId,
        nickname: nickname,
        gender: gender,
        breed: breed,
        color: color,
        birthDate: birthDate,
        weight: weight,
        healthStatus: healthStatus,
        status: status,
        purchaseDate: purchaseDate,
        purchasePrice: purchasePrice,
        sellerName: sellerName,
        sellerPhone: sellerPhone,
        purchaseLocation: purchaseLocation,
        photoLocalPath: photoLocalPath,
        photoCloudUrl: photoCloudUrl,
        motherId: motherId,
        fatherId: fatherId,
        deathDate: deathDate,
        deathCause: deathCause,
        deathNotes: deathNotes,
        notes: notes,
        financeOwnerId: financeOwnerId ?? id,
        financeMode: financeMode,
        birthEventId: birthEventId,
        weaningDate: weaningDate,
        valuationAmount: valuationAmount,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension FieldDataExt on FieldsTableData {
  FarmField toModel() => FarmField(
        id: id,
        userId: userId,
        name: name,
        areaText: areaText,
        locationText: locationText,
        ownership: ownership,
        photoLocalPath: photoLocalPath,
        photoCloudUrl: photoCloudUrl,
        rentAmount: rentAmount,
        rentPeriod: rentPeriod,
        rentStartDate: rentStartDate,
        rentEndDate: rentEndDate,
        landlordName: landlordName,
        landlordPhone: landlordPhone,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension CropDataExt on CropsTableData {
  Crop toModel() => Crop(
        id: id,
        userId: userId,
        nameFr: nameFr,
        nameAr: nameAr,
        iconEmoji: iconEmoji,
        kind: kind,
        seasonMonths: Crop.parseSeasonMonthsJson(seasonMonths),
        fieldId: fieldId,
        areaOrCountText: areaOrCountText,
        photoLocalPath: photoLocalPath,
        photoCloudUrl: photoCloudUrl,
        notes: notes,
        isDefault: isDefault,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension ExpenseDataExt on ExpensesTableData {
  Expense toModel() => Expense(
        id: id,
        userId: userId,
        scope: scope,
        linkedAnimalId: linkedAnimalId,
        linkedSpeciesId: linkedSpeciesId,
        linkedCropId: linkedCropId,
        linkedFieldId: linkedFieldId,
        amount: amount,
        category: category,
        date: date,
        description: description,
        receiptPhotoLocalPath: receiptPhotoLocalPath,
        receiptPhotoCloudUrl: receiptPhotoCloudUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension SaleDataExt on SalesTableData {
  Sale toModel() => Sale(
        id: id,
        userId: userId,
        scope: scope,
        linkedAnimalId: linkedAnimalId,
        linkedCropId: linkedCropId,
        productName: productName,
        quantity: quantity,
        unit: unit,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
        buyerName: buyerName,
        buyerPhone: buyerPhone,
        saleDate: saleDate,
        receiptPhotoLocalPath: receiptPhotoLocalPath,
        receiptPhotoCloudUrl: receiptPhotoCloudUrl,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension ReproductionEventDataExt on ReproductionEventsTableData {
  ReproductionEvent toModel() => ReproductionEvent(
        id: id,
        userId: userId,
        animalId: animalId,
        eventType: eventType,
        partnerId: partnerId,
        eventDate: eventDate,
        dueDate: dueDate,
        offspringCount: offspringCount,
        pregnancyGroupId: pregnancyGroupId,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension HealthEventDataExt on HealthEventsTableData {
  HealthEvent toModel() => HealthEvent(
        id: id,
        userId: userId,
        animalId: animalId,
        eventType: eventType,
        description: description,
        date: date,
        vetName: vetName,
        nextDueDate: nextDueDate,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension ReminderDataExt on RemindersTableData {
  Reminder toModel() => Reminder(
        id: id,
        userId: userId,
        title: title,
        body: body,
        triggerDate: triggerDate,
        category: category,
        linkedType: linkedType,
        linkedId: linkedId,
        isDone: isDone,
        platformNotificationId: platformNotificationId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension SettingsDataExt on SettingsTableData {
  UserSettings toModel() => UserSettings(
        userId: userId,
        language: language,
        currency: currency,
        mode: mode,
        lastBackupDate: lastBackupDate,
        updatedAt: updatedAt,
        syncStatus: syncStatus,
      );
}

extension HistoryDataExt on HistoryTableData {
  HistoryEntry toModel() => HistoryEntry(
        id: id,
        userId: userId,
        actionType: actionType,
        title: title,
        description: description,
        relatedType: relatedType,
        relatedId: relatedId,
        date: date,
        createdAt: createdAt,
        syncStatus: syncStatus,
      );
}
