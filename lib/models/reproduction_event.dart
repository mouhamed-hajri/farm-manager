class ReproductionEvent {
  final String id;
  final String userId;
  final String animalId;
  final String eventType;
  final String? partnerId;
  final String eventDate;
  final String? dueDate;
  final int? offspringCount;
  final String? pregnancyGroupId;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const ReproductionEvent({
    required this.id,
    required this.userId,
    required this.animalId,
    required this.eventType,
    this.partnerId,
    required this.eventDate,
    this.dueDate,
    this.offspringCount,
    this.pregnancyGroupId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  ReproductionEvent copyWith({
    String? id,
    String? userId,
    String? animalId,
    String? eventType,
    String? partnerId,
    String? eventDate,
    String? dueDate,
    int? offspringCount,
    String? pregnancyGroupId,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      ReproductionEvent(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        animalId: animalId ?? this.animalId,
        eventType: eventType ?? this.eventType,
        partnerId: partnerId ?? this.partnerId,
        eventDate: eventDate ?? this.eventDate,
        dueDate: dueDate ?? this.dueDate,
        offspringCount: offspringCount ?? this.offspringCount,
        pregnancyGroupId: pregnancyGroupId ?? this.pregnancyGroupId,
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
        'partnerId': partnerId,
        'eventDate': eventDate,
        'dueDate': dueDate,
        'offspringCount': offspringCount,
        'pregnancyGroupId': pregnancyGroupId,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory ReproductionEvent.fromFirestore(Map<String, dynamic> m) =>
      ReproductionEvent(
        id: m['id'] as String,
        userId: m['userId'] as String,
        animalId: m['animalId'] as String,
        eventType: m['eventType'] as String,
        partnerId: m['partnerId'] as String?,
        eventDate: m['eventDate'] as String,
        dueDate: m['dueDate'] as String?,
        offspringCount: m['offspringCount'] as int?,
        pregnancyGroupId: m['pregnancyGroupId'] as String?,
        notes: m['notes'] as String?,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}

abstract class ReproductionEventType {
  static const mating = 'mating';
  static const matingFailed = 'mating_failed';
  static const pregnancyConfirmed = 'pregnancy_confirmed';
  static const pregnancyLoss = 'pregnancy_loss';
  static const birth = 'birth';
  static const cycleCanceled = 'cycle_canceled';
}
