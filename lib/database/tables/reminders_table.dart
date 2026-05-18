import 'package:drift/drift.dart';

class RemindersTable extends Table {
  @override
  String get tableName => 'reminders';

  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get triggerDate => text()();
  TextColumn get category => text()();
  TextColumn get linkedType => text().nullable()();
  TextColumn get linkedId => text().nullable()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get platformNotificationId => integer().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
