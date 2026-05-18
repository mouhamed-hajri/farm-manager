class HealthEvent {
  final String id;
  final String userId;
  final String animalId;
  final String eventType;
  final String description;
  final String date;
  final String? vetName;
  final String? nextDueDate;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const HealthEvent({
    required this.id,
    required this.userId,
    required this.animalId,
    required this.eventType,
    required this.description,
    required this.date,
    this.vetName,
    this.nextDueDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  HealthEvent copyWith({
    String? id,
    String? userId,
    String? animalId,
    String? eventType,
    String? description,
    String? date,
    String? vetName,
    String? nextDueDate,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      HealthEvent(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        animalId: animalId ?? this.animalId,
        eventType: eventType ?? this.eventType,
        description: description ?? this.description,
        date: date ?? this.date,
        vetName: vetName ?? this.vetName,
        nextDueDate: nextDueDate ?? this.nextDueDate,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'animalId': animalId,
        'eventType': eventType,
        'description': description,
        'date': date,
        'vetName': vetName,
        'nextDueDate': nextDueDate,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory HealthEvent.fromFirestore(Map<String, dynamic> m) => HealthEvent(
        id: m['id'] as String,
        userId: m['userId'] as String,
        animalId: m['animalId'] as String,
        eventType: m['eventType'] as String,
        description: m['description'] as String,
        date: m['date'] as String,
        vetName: m['vetName'] as String?,
        nextDueDate: m['nextDueDate'] as String?,
        notes: m['notes'] as String?,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}

abstract class HealthEventType {
  static const treatment = 'treatment';
  static const vaccination = 'vaccination';
  static const illness = 'illness';
  static const recovery = 'recovery';
}
