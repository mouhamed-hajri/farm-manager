class Breed {
  final String id;
  final String userId;
  final String speciesId;
  final String name;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const Breed({
    required this.id,
    required this.userId,
    required this.speciesId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  Breed copyWith({
    String? id,
    String? userId,
    String? speciesId,
    String? name,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      Breed(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        speciesId: speciesId ?? this.speciesId,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'speciesId': speciesId,
        'name': name,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Breed.fromFirestore(Map<String, dynamic> m) => Breed(
        id: m['id'] as String,
        userId: m['userId'] as String,
        speciesId: m['speciesId'] as String,
        name: m['name'] as String,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}
