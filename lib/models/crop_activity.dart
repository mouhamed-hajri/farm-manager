class CropActivity {
  final String id;
  final String userId;
  final String cropId;
  final String activityType;
  final String date;
  final String? description;
  final double? cost;
  final String? linkedExpenseId;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const CropActivity({
    required this.id,
    required this.userId,
    required this.cropId,
    required this.activityType,
    required this.date,
    this.description,
    this.cost,
    this.linkedExpenseId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  CropActivity copyWith({
    String? id,
    String? userId,
    String? cropId,
    String? activityType,
    String? date,
    String? description,
    double? cost,
    String? linkedExpenseId,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      CropActivity(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        cropId: cropId ?? this.cropId,
        activityType: activityType ?? this.activityType,
        date: date ?? this.date,
        description: description ?? this.description,
        cost: cost ?? this.cost,
        linkedExpenseId: linkedExpenseId ?? this.linkedExpenseId,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'cropId': cropId,
        'activityType': activityType,
        'date': date,
        'description': description,
        'cost': cost,
        'linkedExpenseId': linkedExpenseId,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory CropActivity.fromFirestore(Map<String, dynamic> m) => CropActivity(
        id: m['id'] as String,
        userId: m['userId'] as String,
        cropId: m['cropId'] as String,
        activityType: m['activityType'] as String,
        date: m['date'] as String,
        description: m['description'] as String?,
        cost: (m['cost'] as num?)?.toDouble(),
        linkedExpenseId: m['linkedExpenseId'] as String?,
        notes: m['notes'] as String?,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}

abstract class CropActivityType {
  static const planted = 'planted';
  static const watered = 'watered';
  static const fertilized = 'fertilized';
  static const treated = 'treated';
  static const pruned = 'pruned';
  static const other = 'other';

  static const all = [planted, watered, fertilized, treated, pruned, other];

  static String emoji(String t) {
    switch (t) {
      case planted:
        return '🌱';
      case watered:
        return '💧';
      case fertilized:
        return '🌿';
      case treated:
        return '🐛';
      case pruned:
        return '✂️';
      default:
        return '📝';
    }
  }

  static String labelFr(String t) {
    switch (t) {
      case planted:
        return 'Planté';
      case watered:
        return 'Irrigué';
      case fertilized:
        return 'Engrais';
      case treated:
        return 'Traitement';
      case pruned:
        return 'Taille';
      default:
        return 'Autre';
    }
  }

  static String expenseCategoryFor(String t) {
    switch (t) {
      case watered:
        return 'water';
      case fertilized:
        return 'fertilizer';
      case treated:
        return 'pesticide';
      case planted:
        return 'seeds';
      default:
        return 'other';
    }
  }
}
