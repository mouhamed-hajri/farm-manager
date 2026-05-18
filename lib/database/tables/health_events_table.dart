import 'package:drift/drift.dart';

class HealthEventsTable extends Table {
  @override
  String get tableName => 'health_events';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get animalId => text()();
  TextColumn get eventType => text()();
  TextColumn get description => text()();
  TextColumn get date => text()();
  TextColumn get vetName => text().nullable()();
  TextColumn get nextDueDate => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
