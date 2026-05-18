import 'package:drift/drift.dart';

class ExpensesTable extends Table {
  @override
  String get tableName => 'expenses';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get scope => text().withDefault(const Constant('general'))();
  TextColumn get linkedAnimalId => text().nullable()();
  TextColumn get linkedSpeciesId => text().nullable()();
  TextColumn get linkedCropId => text().nullable()();
  TextColumn get linkedFieldId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get category => text()();
  TextColumn get date => text()();
  TextColumn get description => text().nullable()();
  TextColumn get receiptPhotoLocalPath => text().nullable()();
  TextColumn get receiptPhotoCloudUrl => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
