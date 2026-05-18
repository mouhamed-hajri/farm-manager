import 'package:drift/drift.dart';

class ReproductionEventsTable extends Table {
  @override
  String get tableName => 'reproduction_events';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get animalId => text()();
  TextColumn get eventType => text()();
  TextColumn get partnerId => text().nullable()();
  TextColumn get eventDate => text()();
  TextColumn get dueDate => text().nullable()();
  IntColumn get offspringCount => integer().nullable()();
  TextColumn get pregnancyGroupId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
