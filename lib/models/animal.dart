class Animal {
  final String id;
  final String userId;
  final String speciesId;
  final String farmId;
  final String? nickname;
  final String gender;
  final String? breed;
  final String? color;
  final String? birthDate;
  final double? weight;
  final String healthStatus;
  final String status;
  final String? purchaseDate;
  final double? purchasePrice;
  final String? sellerName;
  final String? sellerPhone;
  final String? purchaseLocation;
  final String? photoLocalPath;
  final String? photoCloudUrl;
  final String? motherId;
  final String? fatherId;
  final String? deathDate;
  final String? deathCause;
  final String? deathNotes;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const Animal({
    required this.id,
    required this.userId,
    required this.speciesId,
    required this.farmId,
    this.nickname,
    required this.gender,
    this.breed,
    this.color,
    this.birthDate,
    this.weight,
    required this.healthStatus,
    required this.status,
    this.purchaseDate,
    this.purchasePrice,
    this.sellerName,
    this.sellerPhone,
    this.purchaseLocation,
    this.photoLocalPath,
    this.photoCloudUrl,
    this.motherId,
    this.fatherId,
    this.deathDate,
    this.deathCause,
    this.deathNotes,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  String get displayName => nickname?.isNotEmpty == true ? nickname! : farmId;

  Animal copyWith({
    String? id,
    String? userId,
    String? speciesId,
    String? farmId,
    String? nickname,
    String? gender,
    String? breed,
    String? color,
    String? birthDate,
    double? weight,
    String? healthStatus,
    String? status,
    String? purchaseDate,
    double? purchasePrice,
    String? sellerName,
    String? sellerPhone,
    String? purchaseLocation,
    String? photoLocalPath,
    String? photoCloudUrl,
    String? motherId,
    String? fatherId,
    String? deathDate,
    String? deathCause,
    String? deathNotes,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) {
    return Animal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      speciesId: speciesId ?? this.speciesId,
      farmId: farmId ?? this.farmId,
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      breed: breed ?? this.breed,
      color: color ?? this.color,
      birthDate: birthDate ?? this.birthDate,
      weight: weight ?? this.weight,
      healthStatus: healthStatus ?? this.healthStatus,
      status: status ?? this.status,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellerName: sellerName ?? this.sellerName,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      purchaseLocation: purchaseLocation ?? this.purchaseLocation,
      photoLocalPath: photoLocalPath ?? this.photoLocalPath,
      photoCloudUrl: photoCloudUrl ?? this.photoCloudUrl,
      motherId: motherId ?? this.motherId,
      fatherId: fatherId ?? this.fatherId,
      deathDate: deathDate ?? this.deathDate,
      deathCause: deathCause ?? this.deathCause,
      deathNotes: deathNotes ?? this.deathNotes,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'speciesId': speciesId,
        'farmId': farmId,
        'nickname': nickname,
        'gender': gender,
        'breed': breed,
        'color': color,
        'birthDate': birthDate,
        'weight': weight,
        'healthStatus': healthStatus,
        'status': status,
        'purchaseDate': purchaseDate,
        'purchasePrice': purchasePrice,
        'sellerName': sellerName,
        'sellerPhone': sellerPhone,
        'purchaseLocation': purchaseLocation,
        'photoCloudUrl': photoCloudUrl,
        'motherId': motherId,
        'fatherId': fatherId,
        'deathDate': deathDate,
        'deathCause': deathCause,
        'deathNotes': deathNotes,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Animal.fromFirestore(Map<String, dynamic> map) => Animal(
        id: map['id'] as String,
        userId: map['userId'] as String,
        speciesId: map['speciesId'] as String,
        farmId: map['farmId'] as String,
        nickname: map['nickname'] as String?,
        gender: map['gender'] as String,
        breed: map['breed'] as String?,
        color: map['color'] as String?,
        birthDate: map['birthDate'] as String?,
        weight: (map['weight'] as num?)?.toDouble(),
        healthStatus: map['healthStatus'] as String? ?? 'healthy',
        status: map['status'] as String? ?? 'active',
        purchaseDate: map['purchaseDate'] as String?,
        purchasePrice: (map['purchasePrice'] as num?)?.toDouble(),
        sellerName: map['sellerName'] as String?,
        sellerPhone: map['sellerPhone'] as String?,
        purchaseLocation: map['purchaseLocation'] as String?,
        photoLocalPath: null,
        photoCloudUrl: map['photoCloudUrl'] as String?,
        motherId: map['motherId'] as String?,
        fatherId: map['fatherId'] as String?,
        deathDate: map['deathDate'] as String?,
        deathCause: map['deathCause'] as String?,
        deathNotes: map['deathNotes'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['createdAt'] as String,
        updatedAt: map['updatedAt'] as String,
        syncStatus: 'synced',
      );
}

abstract class AnimalGender {
  static const male = 'male';
  static const female = 'female';
}

abstract class HealthStatus {
  static const healthy = 'healthy';
  static const sick = 'sick';
  static const pregnant = 'pregnant';
}

abstract class AnimalStatus {
  static const active = 'active';
  static const sold = 'sold';
  static const dead = 'dead';
}

abstract class SyncStatus {
  static const pending = 'pending';
  static const synced = 'synced';
  static const failed = 'failed';
}
