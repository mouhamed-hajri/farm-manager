import 'package:drift/drift.dart';

class CropActivitiesTable extends Table {
  @override
  String get tableName => 'crop_activities';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get cropId => text()();
  TextColumn get activityType => text()();
  TextColumn get date => text()();
  TextColumn get description => text().nullable()();
  RealColumn get cost => real().nullable()();
  TextColumn get linkedExpenseId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
