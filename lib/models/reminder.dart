class Reminder {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String triggerDate;
  final String category;
  final String? linkedType;
  final String? linkedId;
  final bool isDone;
  final int? platformNotificationId;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.triggerDate,
    required this.category,
    this.linkedType,
    this.linkedId,
    required this.isDone,
    this.platformNotificationId,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  Reminder copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? triggerDate,
    String? category,
    String? linkedType,
    String? linkedId,
    bool? isDone,
    int? platformNotificationId,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      Reminder(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        body: body ?? this.body,
        triggerDate: triggerDate ?? this.triggerDate,
        category: category ?? this.category,
        linkedType: linkedType ?? this.linkedType,
        linkedId: linkedId ?? this.linkedId,
        isDone: isDone ?? this.isDone,
        platformNotificationId: platformNotificationId ?? this.platformNotificationId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'triggerDate': triggerDate,
        'category': category,
        'linkedType': linkedType,
        'linkedId': linkedId,
        'isDone': isDone,
        'platformNotificationId': platformNotificationId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Reminder.fromFirestore(Map<String, dynamic> m) => Reminder(
        id: m['id'] as String,
        userId: m['userId'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        triggerDate: m['triggerDate'] as String,
        category: m['category'] as String,
        linkedType: m['linkedType'] as String?,
        linkedId: m['linkedId'] as String?,
        isDone: m['isDone'] as bool? ?? false,
        platformNotificationId: m['platformNotificationId'] as int?,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}

abstract class ReminderCategory {
  static const rentExpiry = 'rent_expiry';
  static const pregnancyDue = 'pregnancy_due';
  static const vaccinationDue = 'vaccination_due';
}

abstract class ReminderLinkedType {
  static const field = 'field';
  static const animal = 'animal';
}
