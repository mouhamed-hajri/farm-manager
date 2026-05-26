import 'package:drift/drift.dart';

class BreedsTable extends Table {
  @override
  String get tableName => 'breeds';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get speciesId => text()();
  TextColumn get name => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
