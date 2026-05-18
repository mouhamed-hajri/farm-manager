class HistoryEntry {
  final String id;
  final String userId;
  final String actionType;
  final String title;
  final String? description;
  final String? relatedType;
  final String? relatedId;
  final String date;
  final String createdAt;
  final String syncStatus;

  const HistoryEntry({
    required this.id,
    required this.userId,
    required this.actionType,
    required this.title,
    this.description,
    this.relatedType,
    this.relatedId,
    required this.date,
    required this.createdAt,
    required this.syncStatus,
  });

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'actionType': actionType,
        'title': title,
        'description': description,
        'relatedType': relatedType,
        'relatedId': relatedId,
        'date': date,
        'createdAt': createdAt,
      };

  factory HistoryEntry.fromFirestore(Map<String, dynamic> map) => HistoryEntry(
        id: map['id'] as String,
        userId: map['userId'] as String,
        actionType: map['actionType'] as String,
        title: map['title'] as String,
        description: map['description'] as String?,
        relatedType: map['relatedType'] as String?,
        relatedId: map['relatedId'] as String?,
        date: map['date'] as String,
        createdAt: map['createdAt'] as String,
        syncStatus: 'synced',
      );
}

abstract class ActionType {
  static const sheepBought = 'sheep_bought';
  static const sheepSold = 'sheep_sold';
  static const sheepDead = 'sheep_dead';
  static const expenseAdded = 'expense_added';
  static const incomeAdded = 'income_added';
  static const backupCompleted = 'backup_completed';
  static const restoreCompleted = 'restore_completed';
}
