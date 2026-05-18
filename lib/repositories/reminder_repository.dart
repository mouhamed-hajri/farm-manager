import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/reminder.dart';

class ReminderRepository {
  ReminderRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Stream<List<Reminder>> watch(String userId) =>
      _db.watchReminders(userId).map(
            (rows) => rows.map((r) => r.toModel()).toList(),
          );

  Future<List<Reminder>> getForLinked(
      String userId, String linkedType, String linkedId) async {
    final rows = await _db.getRemindersForLinked(userId, linkedType, linkedId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<Reminder> add(Reminder reminder) async {
    final now = DateTime.now().toIso8601String();
    final toSave = reminder.copyWith(
      id: reminder.id.isEmpty ? _uuid.v4() : reminder.id,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
    );
    await _db.insertReminder(_toCompanion(toSave));
    return toSave;
  }

  Future<int> deleteForLinked(
          String userId, String linkedType, String linkedId) =>
      _db.deleteRemindersForLinked(userId, linkedType, linkedId);

  Future<List<Reminder>> getPending(String userId) async {
    final rows = await _db.getPendingReminders(userId);
    return rows.map((r) => r.toModel()).toList();
  }

  Future<void> markSynced(String id) => _db.markReminderSynced(id);

  RemindersTableCompanion _toCompanion(Reminder r) => RemindersTableCompanion(
        id: Value(r.id),
        userId: Value(r.userId),
        title: Value(r.title),
        body: Value(r.body),
        triggerDate: Value(r.triggerDate),
        category: Value(r.category),
        linkedType: Value(r.linkedType),
        linkedId: Value(r.linkedId),
        isDone: Value(r.isDone),
        platformNotificationId: Value(r.platformNotificationId),
        createdAt: Value(r.createdAt),
        updatedAt: Value(r.updatedAt),
        syncStatus: Value(r.syncStatus),
      );
}
