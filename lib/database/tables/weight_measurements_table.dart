import 'package:drift/drift.dart';

class WeightMeasurementsTable extends Table {
  @override
  String get tableName => 'weight_measurements';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get animalId => text()();
  RealColumn get weight => real()();
  TextColumn get measurementDate => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
