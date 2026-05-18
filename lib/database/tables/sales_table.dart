import 'package:drift/drift.dart';

class SalesTable extends Table {
  @override
  String get tableName => 'sales';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get scope => text()();
  TextColumn get linkedAnimalId => text().nullable()();
  TextColumn get linkedCropId => text().nullable()();
  TextColumn get productName => text().nullable()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unit => text().withDefault(const Constant('piece'))();
  RealColumn get unitPrice => real()();
  RealColumn get totalPrice => real()();
  TextColumn get buyerName => text().nullable()();
  TextColumn get buyerPhone => text().nullable()();
  TextColumn get saleDate => text()();
  TextColumn get receiptPhotoLocalPath => text().nullable()();
  TextColumn get receiptPhotoCloudUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
