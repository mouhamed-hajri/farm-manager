class Sale {
  final String id;
  final String userId;
  final String scope;
  final String? linkedAnimalId;
  final String? linkedCropId;
  final String? productName;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final String? buyerName;
  final String? buyerPhone;
  final String saleDate;
  final String? receiptPhotoLocalPath;
  final String? receiptPhotoCloudUrl;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const Sale({
    required this.id,
    required this.userId,
    required this.scope,
    this.linkedAnimalId,
    this.linkedCropId,
    this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    this.buyerName,
    this.buyerPhone,
    required this.saleDate,
    this.receiptPhotoLocalPath,
    this.receiptPhotoCloudUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  Sale copyWith({
    String? id,
    String? userId,
    String? scope,
    String? linkedAnimalId,
    String? linkedCropId,
    String? productName,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalPrice,
    String? buyerName,
    String? buyerPhone,
    String? saleDate,
    String? receiptPhotoLocalPath,
    String? receiptPhotoCloudUrl,
    String? notes,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) =>
      Sale(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        scope: scope ?? this.scope,
        linkedAnimalId: linkedAnimalId ?? this.linkedAnimalId,
        linkedCropId: linkedCropId ?? this.linkedCropId,
        productName: productName ?? this.productName,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        unitPrice: unitPrice ?? this.unitPrice,
        totalPrice: totalPrice ?? this.totalPrice,
        buyerName: buyerName ?? this.buyerName,
        buyerPhone: buyerPhone ?? this.buyerPhone,
        saleDate: saleDate ?? this.saleDate,
        receiptPhotoLocalPath: receiptPhotoLocalPath ?? this.receiptPhotoLocalPath,
        receiptPhotoCloudUrl: receiptPhotoCloudUrl ?? this.receiptPhotoCloudUrl,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'scope': scope,
        'linkedAnimalId': linkedAnimalId,
        'linkedCropId': linkedCropId,
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
        'buyerName': buyerName,
        'buyerPhone': buyerPhone,
        'saleDate': saleDate,
        'receiptPhotoCloudUrl': receiptPhotoCloudUrl,
        'notes': notes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Sale.fromFirestore(Map<String, dynamic> m) => Sale(
        id: m['id'] as String,
        userId: m['userId'] as String,
        scope: m['scope'] as String,
        linkedAnimalId: m['linkedAnimalId'] as String?,
        linkedCropId: m['linkedCropId'] as String?,
        productName: m['productName'] as String?,
        quantity: (m['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: m['unit'] as String? ?? 'piece',
        unitPrice: (m['unitPrice'] as num).toDouble(),
        totalPrice: (m['totalPrice'] as num).toDouble(),
        buyerName: m['buyerName'] as String?,
        buyerPhone: m['buyerPhone'] as String?,
        saleDate: m['saleDate'] as String,
        receiptPhotoLocalPath: null,
        receiptPhotoCloudUrl: m['receiptPhotoCloudUrl'] as String?,
        notes: m['notes'] as String?,
        createdAt: m['createdAt'] as String,
        updatedAt: m['updatedAt'] as String,
        syncStatus: 'synced',
      );
}

abstract class SaleScope {
  static const animal = 'animal';
  static const crop = 'crop';
  static const product = 'product';
  static const other = 'other';
}

abstract class SaleUnit {
  static const kg = 'kg';
  static const grandeCaisse = 'grande_caisse';
  static const petiteCaisse = 'petite_caisse';
  static const piece = 'piece';
  static const litre = 'litre';

  static const all = [kg, grandeCaisse, petiteCaisse, piece, litre];
}
