import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/user_settings.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<UserSettings?> watch(String userId) => _db
      .watchSettings(userId)
      .map((row) => row?.toModel());

  Future<UserSettings> getOrCreate(String userId) async {
    final existing = await _db.getSettings(userId);
    if (existing != null) return existing.toModel();
    final defaults = UserSettings.defaults(userId);
    await _db.upsertSettings(SettingsTableCompanion(
      userId: Value(defaults.userId),
      language: Value(defaults.language),
      currency: Value(defaults.currency),
      mode: Value(defaults.mode),
      updatedAt: Value(defaults.updatedAt),
      syncStatus: Value(defaults.syncStatus),
    ));
    return defaults;
  }

  Future<void> save(UserSettings settings) async {
    final updated = settings.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
      syncStatus: 'pending',
    );
    await _db.upsertSettings(SettingsTableCompanion(
      userId: Value(updated.userId),
      language: Value(updated.language),
      currency: Value(updated.currency),
      mode: Value(updated.mode),
      lastBackupDate: Value(updated.lastBackupDate),
      updatedAt: Value(updated.updatedAt),
      syncStatus: Value(updated.syncStatus),
    ));
  }
}
