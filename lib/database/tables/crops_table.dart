import 'package:drift/drift.dart';

class CropsTable extends Table {
  @override
  String get tableName => 'crops';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get nameFr => text()();
  TextColumn get nameAr => text()();
  TextColumn get iconEmoji => text().withDefault(const Constant('🌱'))();
  TextColumn get kind => text().withDefault(const Constant('crop'))();
  TextColumn get seasonMonths => text().withDefault(const Constant('[]'))();
  TextColumn get fieldId => text().nullable()();
  TextColumn get areaOrCountText => text().nullable()();
  TextColumn get photoLocalPath => text().nullable()();
  TextColumn get photoCloudUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get status =>
      text().withDefault(const Constant('growing'))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
