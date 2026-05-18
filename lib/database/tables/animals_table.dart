import 'package:drift/drift.dart';

class AnimalsTable extends Table {
  @override
  String get tableName => 'animals';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get speciesId => text()();
  TextColumn get farmId => text()();
  TextColumn get nickname => text().nullable()();
  TextColumn get gender => text()();
  TextColumn get breed => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get birthDate => text().nullable()();
  RealColumn get weight => real().nullable()();
  TextColumn get healthStatus => text().withDefault(const Constant('healthy'))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get purchaseDate => text().nullable()();
  RealColumn get purchasePrice => real().nullable()();
  TextColumn get sellerName => text().nullable()();
  TextColumn get sellerPhone => text().nullable()();
  TextColumn get purchaseLocation => text().nullable()();
  TextColumn get photoLocalPath => text().nullable()();
  TextColumn get photoCloudUrl => text().nullable()();
  TextColumn get motherId => text().nullable()();
  TextColumn get fatherId => text().nullable()();
  TextColumn get deathDate => text().nullable()();
  TextColumn get deathCause => text().nullable()();
  TextColumn get deathNotes => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
