class UserSettings {
  final String userId;
  final String language;
  final String currency;
  final String mode;
  final String? lastBackupDate;
  final String updatedAt;
  final String syncStatus;

  const UserSettings({
    required this.userId,
    required this.language,
    required this.currency,
    required this.mode,
    this.lastBackupDate,
    required this.updatedAt,
    required this.syncStatus,
  });

  bool get isSimpleMode => mode == AppMode.simple;

  UserSettings copyWith({
    String? userId,
    String? language,
    String? currency,
    String? mode,
    String? lastBackupDate,
    String? updatedAt,
    String? syncStatus,
  }) =>
      UserSettings(
        userId: userId ?? this.userId,
        language: language ?? this.language,
        currency: currency ?? this.currency,
        mode: mode ?? this.mode,
        lastBackupDate: lastBackupDate ?? this.lastBackupDate,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'language': language,
        'currency': currency,
        'mode': mode,
        'lastBackupDate': lastBackupDate,
        'updatedAt': updatedAt,
      };

  factory UserSettings.fromFirestore(Map<String, dynamic> m) => UserSettings(
        userId: m['userId'] as String,
        language: m['language'] as String? ?? 'fr',
        currency: m['currency'] as String? ?? 'TND',
        mode: m['mode'] as String? ?? 'simple',
        lastBackupDate: m['lastBackupDate'] as String?,
        updatedAt: m['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
        syncStatus: 'synced',
      );

  factory UserSettings.defaults(String userId) => UserSettings(
        userId: userId,
        language: 'fr',
        currency: 'TND',
        mode: AppMode.simple,
        updatedAt: DateTime.now().toIso8601String(),
        syncStatus: 'pending',
      );
}

abstract class AppMode {
  static const simple = 'simple';
  static const advanced = 'advanced';
}
