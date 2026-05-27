import 'package:drift/drift.dart';

class HarvestsTable extends Table {
  @override
  String get tableName => 'harvests';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get cropId => text()();
  TextColumn get harvestDate => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  RealColumn get pricePerUnit => real().nullable()();
  RealColumn get totalPrice => real().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get linkedSaleId => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
