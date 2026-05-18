import 'package:drift/drift.dart';

class FarmIdCountersTable extends Table {
  @override
  String get tableName => 'farm_id_counters';

  TextColumn get userId => text()();
  TextColumn get prefix => text()();
  IntColumn get year => integer()();
  IntColumn get lastNumber => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {userId, prefix, year};
}
