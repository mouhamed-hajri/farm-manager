import 'package:drift/drift.dart';

class SpeciesTable extends Table {
  @override
  String get tableName => 'species';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get nameFr => text()();
  TextColumn get nameAr => text()();
  TextColumn get iconEmoji => text().withDefault(const Constant('🐾'))();
  TextColumn get idPrefix => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
