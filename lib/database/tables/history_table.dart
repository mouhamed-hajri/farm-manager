import 'package:drift/drift.dart';

class HistoryTable extends Table {
  @override
  String get tableName => 'history';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get actionType => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get relatedType => text().nullable()();
  TextColumn get relatedId => text().nullable()();
  TextColumn get date => text()();
  TextColumn get createdAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
