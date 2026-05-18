import 'package:drift/drift.dart';

class FieldsTable extends Table {
  @override
  String get tableName => 'fields';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get areaText => text().nullable()();
  TextColumn get locationText => text().nullable()();
  TextColumn get ownership => text().withDefault(const Constant('owned'))();
  TextColumn get photoLocalPath => text().nullable()();
  TextColumn get photoCloudUrl => text().nullable()();
  RealColumn get rentAmount => real().nullable()();
  TextColumn get rentPeriod => text().nullable()();
  TextColumn get rentStartDate => text().nullable()();
  TextColumn get rentEndDate => text().nullable()();
  TextColumn get landlordName => text().nullable()();
  TextColumn get landlordPhone => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
