class Harvest {
  final String id;
  final String userId;
  final String cropId;
  final String harvestDate;
  final double quantity;
  final String unit;
  final double? pricePerUnit;
  final double? totalPrice;
  final String? notes;
  final String? linkedSaleId;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const Harvest({
    required this.id,
    required this.userId,
    required this.cropId,
    required this.harvestDate,
    required this.quantity,
    required this.unit,
    this.pricePerUnit,
    this.totalPrice,
    this.notes,
    this.linkedSaleId,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  Harvest copyWith({
    String? id,
    String? userId,
    String? cropId,
    String? harvestDate,
    double? quantity,
    String? unit,
    double? pricePerUnit,
    double? totalPrice,
    String? notes,
    String? linkedSaleId,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      Harvest(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        cropId: cropId ?? this.cropId,
        harvestDate: harvestDate ?? this.harvestDate,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        pricePerUnit: pricePerUnit ?? this.pricePerUnit,
        totalPrice: totalPrice ?? this.totalPrice,
        notes: notes ?? this.notes,
        linkedSaleId: linkedSaleId ?? this.linkedSaleId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  /// Convert quantity to kilograms when possible. Returns null for non-mass units.
  double? get quantityInKg {
    switch (unit) {
      case HarvestUnit.kg:
        return quantity;
      case HarvestUnit.quintal:
        return quantity * 100.0;
      default:
        return null;
    }
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'cropId': cropId,
        'harvestDate': harvestDate,
        'quantity': quantity,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'totalPrice': totalPrice,
        'notes': notes,
        'linkedSaleId': linkedSaleId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Harvest.fromFirestore(Map<String, dynamic> m) => Harvest(
        id: m['id'] as String,
        userId: m['userId'] as String,
        cropId: m['cropId'] as String,
        harvestDate: m['harvestDate'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unit: m['unit'] as String,
        pricePerUnit: (m['pricePerUnit'] as num?)?.toDouble(),
        totalPrice: (m['totalPrice'] as num?)?.toDouble(),
        notes: m['notes'] as String?,
        linkedSaleId: m['linkedSaleId'] as String?,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}

abstract class HarvestUnit {
  static const kg = 'kg';
  static const quintal = 'quintal';
  static const sac = 'sac';
  static const caisse = 'caisse';
  static const piece = 'piece';
  static const litre = 'litre';

  static const all = [kg, quintal, sac, caisse, piece, litre];

  static String labelFr(String u) {
    switch (u) {
      case kg:
        return 'kg';
      case quintal:
        return 'quintal';
      case sac:
        return 'sac';
      case caisse:
        return 'caisse';
      case piece:
        return 'pièce';
      case litre:
        return 'litre';
      default:
        return u;
    }
  }
}
