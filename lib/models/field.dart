class FarmField {
  final String id;
  final String userId;
  final String name;
  final String? areaText;
  final String? locationText;
  final String ownership;
  final String? photoLocalPath;
  final String? photoCloudUrl;
  final double? rentAmount;
  final String? rentPeriod;
  final String? rentStartDate;
  final String? rentEndDate;
  final String? landlordName;
  final String? landlordPhone;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const FarmField({
    required this.id,
    required this.userId,
    required this.name,
    this.areaText,
    this.locationText,
    required this.ownership,
    this.photoLocalPath,
    this.photoCloudUrl,
    this.rentAmount,
    this.rentPeriod,
    this.rentStartDate,
    this.rentEndDate,
    this.landlordName,
    this.landlordPhone,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  FarmField copyWith({
    String? id,
    String? userId,
    String? name,
    String? areaText,
    String? locationText,
    String? ownership,
    String? photoLocalPath,
    String? photoCloudUrl,
    double? rentAmount,
    String? rentPeriod,
    String? rentStartDate,
    String? rentEndDate,
    String? landlordName,
    String? landlordPhone,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      FarmField(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        areaText: areaText ?? this.areaText,
        locationText: locationText ?? this.locationText,
        ownership: ownership ?? this.ownership,
        photoLocalPath: photoLocalPath ?? this.photoLocalPath,
        photoCloudUrl: photoCloudUrl ?? this.photoCloudUrl,
        rentAmount: rentAmount ?? this.rentAmount,
        rentPeriod: rentPeriod ?? this.rentPeriod,
        rentStartDate: rentStartDate ?? this.rentStartDate,
        rentEndDate: rentEndDate ?? this.rentEndDate,
        landlordName: landlordName ?? this.landlordName,
        landlordPhone: landlordPhone ?? this.landlordPhone,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'name': name,
        'areaText': areaText,
        'locationText': locationText,
        'ownership': ownership,
        'photoCloudUrl': photoCloudUrl,
        'rentAmount': rentAmount,
        'rentPeriod': rentPeriod,
        'rentStartDate': rentStartDate,
        'rentEndDate': rentEndDate,
        'landlordName': landlordName,
        'landlordPhone': landlordPhone,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory FarmField.fromFirestore(Map<String, dynamic> m) => FarmField(
        id: m['id'] as String,
        userId: m['userId'] as String,
        name: m['name'] as String,
        areaText: m['areaText'] as String?,
        locationText: m['locationText'] as String?,
        ownership: m['ownership'] as String? ?? 'owned',
        photoLocalPath: null,
        photoCloudUrl: m['photoCloudUrl'] as String?,
        rentAmount: (m['rentAmount'] as num?)?.toDouble(),
        rentPeriod: m['rentPeriod'] as String?,
        rentStartDate: m['rentStartDate'] as String?,
        rentEndDate: m['rentEndDate'] as String?,
        landlordName: m['landlordName'] as String?,
        landlordPhone: m['landlordPhone'] as String?,
        notes: m['notes'] as String?,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}

abstract class FieldOwnership {
  static const owned = 'owned';
  static const rented = 'rented';
}

abstract class RentPeriod {
  static const month = 'month';
  static const year = 'year';
  static const total = 'total';
}
