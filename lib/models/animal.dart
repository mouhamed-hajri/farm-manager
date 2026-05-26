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
  // Finance fields
  final String? financeOwnerId;
  final String? financeMode;
  final String? birthEventId;
  final String? weaningDate;
  final double? valuationAmount;
  final bool isBreeder;
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
    this.financeOwnerId,
    this.financeMode,
    this.birthEventId,
    this.weaningDate,
    this.valuationAmount,
    this.isBreeder = false,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  String get displayName => nickname?.isNotEmpty == true ? nickname! : farmId;

  // Effective finance owner — falls back to own id if field not yet set.
  String get effectiveFinanceOwnerId => financeOwnerId ?? id;

  // Effective finance mode — falls back to 'self'.
  String get effectiveFinanceMode => financeMode ?? AnimalFinanceMode.self;

  bool get isFinanceCenter =>
      effectiveFinanceMode != AnimalFinanceMode.countedUnderMother;

  bool get isCountedUnderMother =>
      effectiveFinanceMode == AnimalFinanceMode.countedUnderMother;

  // Human-readable age from birthDate (ISO yyyy-MM-dd). Null if no birthDate.
  String? get ageLabel {
    if (birthDate == null) return null;
    final birth = DateTime.tryParse(birthDate!);
    if (birth == null) return null;
    final now = DateTime.now();
    if (birth.isAfter(now)) return null;
    var years = now.year - birth.year;
    var months = now.month - birth.month;
    var days = now.day - birth.day;
    if (days < 0) {
      months -= 1;
      days += DateTime(now.year, now.month, 0).day;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years <= 0 && months <= 0) {
      return '${days}j';
    }
    if (years <= 0) {
      return '$months mois';
    }
    final yLabel = years == 1 ? '1 an' : '$years ans';
    if (months == 0) return yLabel;
    return '$yLabel $months mois';
  }

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
    String? financeOwnerId,
    String? financeMode,
    String? birthEventId,
    String? weaningDate,
    double? valuationAmount,
    bool? isBreeder,
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
      financeOwnerId: financeOwnerId ?? this.financeOwnerId,
      financeMode: financeMode ?? this.financeMode,
      birthEventId: birthEventId ?? this.birthEventId,
      weaningDate: weaningDate ?? this.weaningDate,
      valuationAmount: valuationAmount ?? this.valuationAmount,
      isBreeder: isBreeder ?? this.isBreeder,
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
        'financeOwnerId': effectiveFinanceOwnerId,
        'financeMode': effectiveFinanceMode,
        'birthEventId': birthEventId,
        'weaningDate': weaningDate,
        'valuationAmount': valuationAmount,
        'isBreeder': isBreeder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Animal.fromFirestore(Map<String, dynamic> map) {
    final gender = map['gender'] as String? ?? 'male';
    final motherId = map['motherId'] as String?;
    final id = map['id'] as String;
    final computedMode = _defaultFinanceMode(gender, motherId);
    final computedOwner = (gender == 'male' && motherId != null) ? motherId : id;
    return Animal(
      id: id,
      userId: map['userId'] as String,
      speciesId: map['speciesId'] as String,
      farmId: map['farmId'] as String,
      nickname: map['nickname'] as String?,
      gender: gender,
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
      motherId: motherId,
      fatherId: map['fatherId'] as String?,
      deathDate: map['deathDate'] as String?,
      deathCause: map['deathCause'] as String?,
      deathNotes: map['deathNotes'] as String?,
      notes: map['notes'] as String?,
      financeOwnerId: map['financeOwnerId'] as String? ?? computedOwner,
      financeMode: map['financeMode'] as String? ?? computedMode,
      birthEventId: map['birthEventId'] as String?,
      weaningDate: map['weaningDate'] as String?,
      valuationAmount: (map['valuationAmount'] as num?)?.toDouble(),
      isBreeder: map['isBreeder'] as bool? ?? false,
      createdAt: map['createdAt'] as String,
      updatedAt: map['updatedAt'] as String,
      syncStatus: 'synced',
    );
  }
}

String _defaultFinanceMode(String gender, String? motherId) {
  if (motherId != null) return AnimalFinanceMode.countedUnderMother;
  return AnimalFinanceMode.self;
}

abstract class AnimalFinanceMode {
  static const self = 'self';
  static const countedUnderMother = 'counted_under_mother';
  static const independentFemaleCenter = 'independent_female_center';
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
