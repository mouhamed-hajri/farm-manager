import 'package:drift/drift.dart';

class SettingsTable extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get userId => text()();
  TextColumn get language => text().withDefault(const Constant('fr'))();
  TextColumn get currency => text().withDefault(const Constant('TND'))();
  TextColumn get mode => text().withDefault(const Constant('simple'))();
  TextColumn get lastBackupDate => text().nullable()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {userId};
}
