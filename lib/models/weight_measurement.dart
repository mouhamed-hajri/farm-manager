class WeightMeasurement {
  final String id;
  final String userId;
  final String animalId;
  final double weight;
  final String measurementDate;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const WeightMeasurement({
    required this.id,
    required this.userId,
    required this.animalId,
    required this.weight,
    required this.measurementDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  WeightMeasurement copyWith({
    String? id,
    String? userId,
    String? animalId,
    double? weight,
    String? measurementDate,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      WeightMeasurement(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        animalId: animalId ?? this.animalId,
        weight: weight ?? this.weight,
        measurementDate: measurementDate ?? this.measurementDate,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'animalId': animalId,
        'weight': weight,
        'measurementDate': measurementDate,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory WeightMeasurement.fromFirestore(Map<String, dynamic> m) =>
      WeightMeasurement(
        id: m['id'] as String,
        userId: m['userId'] as String,
        animalId: m['animalId'] as String,
        weight: (m['weight'] as num).toDouble(),
        measurementDate: m['measurementDate'] as String,
        notes: m['notes'] as String?,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}
