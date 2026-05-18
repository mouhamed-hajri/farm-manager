class Species {
  final String id;
  final String userId;
  final String nameFr;
  final String nameAr;
  final String iconEmoji;
  final String idPrefix;
  final bool isDefault;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const Species({
    required this.id,
    required this.userId,
    required this.nameFr,
    required this.nameAr,
    required this.iconEmoji,
    required this.idPrefix,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  Species copyWith({
    String? id,
    String? userId,
    String? nameFr,
    String? nameAr,
    String? iconEmoji,
    String? idPrefix,
    bool? isDefault,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      Species(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        nameFr: nameFr ?? this.nameFr,
        nameAr: nameAr ?? this.nameAr,
        iconEmoji: iconEmoji ?? this.iconEmoji,
        idPrefix: idPrefix ?? this.idPrefix,
        isDefault: isDefault ?? this.isDefault,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'nameFr': nameFr,
        'nameAr': nameAr,
        'iconEmoji': iconEmoji,
        'idPrefix': idPrefix,
        'isDefault': isDefault,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Species.fromFirestore(Map<String, dynamic> m) => Species(
        id: m['id'] as String,
        userId: m['userId'] as String,
        nameFr: m['nameFr'] as String,
        nameAr: m['nameAr'] as String,
        iconEmoji: m['iconEmoji'] as String? ?? '🐾',
        idPrefix: m['idPrefix'] as String,
        isDefault: m['isDefault'] as bool? ?? false,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}
