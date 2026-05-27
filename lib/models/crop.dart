import 'dart:convert';

class Crop {
  final String id;
  final String userId;
  final String nameFr;
  final String nameAr;
  final String iconEmoji;
  final String kind;
  final List<int> seasonMonths;
  final String? fieldId;
  final String? areaOrCountText;
  final String? photoLocalPath;
  final String? photoCloudUrl;
  final String? notes;
  final bool isDefault;
  final String status;
  final String lifecycle;
  final String? plantedDate;
  final int? treeCount;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const Crop({
    required this.id,
    required this.userId,
    required this.nameFr,
    required this.nameAr,
    required this.iconEmoji,
    required this.kind,
    required this.seasonMonths,
    this.fieldId,
    this.areaOrCountText,
    this.photoLocalPath,
    this.photoCloudUrl,
    this.notes,
    required this.isDefault,
    this.status = CropStatus.growing,
    this.lifecycle = CropLifecycle.perennial,
    this.plantedDate,
    this.treeCount,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  bool get isYearRound => seasonMonths.isEmpty || seasonMonths.length == 12;

  Crop copyWith({
    String? id,
    String? userId,
    String? nameFr,
    String? nameAr,
    String? iconEmoji,
    String? kind,
    List<int>? seasonMonths,
    String? fieldId,
    String? areaOrCountText,
    String? photoLocalPath,
    String? photoCloudUrl,
    String? notes,
    bool? isDefault,
    String? status,
    String? lifecycle,
    String? plantedDate,
    int? treeCount,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      Crop(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        nameFr: nameFr ?? this.nameFr,
        nameAr: nameAr ?? this.nameAr,
        iconEmoji: iconEmoji ?? this.iconEmoji,
        kind: kind ?? this.kind,
        seasonMonths: seasonMonths ?? this.seasonMonths,
        fieldId: fieldId ?? this.fieldId,
        areaOrCountText: areaOrCountText ?? this.areaOrCountText,
        photoLocalPath: photoLocalPath ?? this.photoLocalPath,
        photoCloudUrl: photoCloudUrl ?? this.photoCloudUrl,
        notes: notes ?? this.notes,
        isDefault: isDefault ?? this.isDefault,
        status: status ?? this.status,
        lifecycle: lifecycle ?? this.lifecycle,
        plantedDate: plantedDate ?? this.plantedDate,
        treeCount: treeCount ?? this.treeCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  String seasonMonthsJson() => jsonEncode(seasonMonths);

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'nameFr': nameFr,
        'nameAr': nameAr,
        'iconEmoji': iconEmoji,
        'kind': kind,
        'seasonMonths': seasonMonths,
        'fieldId': fieldId,
        'areaOrCountText': areaOrCountText,
        'photoCloudUrl': photoCloudUrl,
        'notes': notes,
        'isDefault': isDefault,
        'status': status,
        'lifecycle': lifecycle,
        'plantedDate': plantedDate,
        'treeCount': treeCount,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Crop.fromFirestore(Map<String, dynamic> m) => Crop(
        id: m['id'] as String,
        userId: m['userId'] as String,
        nameFr: m['nameFr'] as String,
        nameAr: m['nameAr'] as String,
        iconEmoji: m['iconEmoji'] as String? ?? '🌱',
        kind: m['kind'] as String? ?? 'crop',
        seasonMonths: (m['seasonMonths'] as List?)?.cast<int>() ?? const [],
        fieldId: m['fieldId'] as String?,
        areaOrCountText: m['areaOrCountText'] as String?,
        photoLocalPath: null,
        photoCloudUrl: m['photoCloudUrl'] as String?,
        notes: m['notes'] as String?,
        isDefault: m['isDefault'] as bool? ?? false,
        status: m['status'] as String? ?? CropStatus.growing,
        lifecycle: m['lifecycle'] as String? ?? CropLifecycle.perennial,
        plantedDate: m['plantedDate'] as String?,
        treeCount: (m['treeCount'] as num?)?.toInt(),
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );

  static List<int> parseSeasonMonthsJson(String json) {
    if (json.isEmpty) return const [];
    final decoded = jsonDecode(json);
    if (decoded is List) return decoded.cast<int>();
    return const [];
  }
}

abstract class CropKind {
  static const tree = 'tree';
  static const crop = 'crop';
  static const vegetable = 'vegetable';
  static const other = 'other';
}

abstract class CropLifecycle {
  static const perennial = 'perennial'; // trees, multi-year
  static const annual = 'annual';       // wheat, tomatoes, one cycle

  static const all = [perennial, annual];

  static String labelFr(String l) =>
      l == annual ? 'Annuelle' : 'Pérenne (arbres)';
}

abstract class CropStatus {
  static const growing = 'growing';
  static const harvested = 'harvested';
  static const lost = 'lost';

  static const all = [growing, harvested, lost];

  static String emoji(String s) {
    switch (s) {
      case harvested:
        return '✅';
      case lost:
        return '❌';
      default:
        return '🌱';
    }
  }

  static String labelFr(String s) {
    switch (s) {
      case harvested:
        return 'Récoltée';
      case lost:
        return 'Perdue';
      default:
        return 'En culture';
    }
  }
}
