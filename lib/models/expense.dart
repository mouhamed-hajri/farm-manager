class Expense {
  final String id;
  final String userId;
  final String scope;
  final String? linkedAnimalId;
  final String? linkedSpeciesId;
  final String? linkedCropId;
  final String? linkedFieldId;
  final double amount;
  final String category;
  final String date;
  final String? description;
  final String? receiptPhotoLocalPath;
  final String? receiptPhotoCloudUrl;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;

  const Expense({
    required this.id,
    required this.userId,
    required this.scope,
    this.linkedAnimalId,
    this.linkedSpeciesId,
    this.linkedCropId,
    this.linkedFieldId,
    required this.amount,
    required this.category,
    required this.date,
    this.description,
    this.receiptPhotoLocalPath,
    this.receiptPhotoCloudUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
  });

  Expense copyWith({
    String? id,
    String? userId,
    String? scope,
    String? linkedAnimalId,
    String? linkedSpeciesId,
    String? linkedCropId,
    String? linkedFieldId,
    double? amount,
    String? category,
    String? date,
    String? description,
    String? receiptPhotoLocalPath,
    String? receiptPhotoCloudUrl,
    String? createdAt,
    String? updatedAt,
    String? syncStatus,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      scope: scope ?? this.scope,
      linkedAnimalId: linkedAnimalId ?? this.linkedAnimalId,
      linkedSpeciesId: linkedSpeciesId ?? this.linkedSpeciesId,
      linkedCropId: linkedCropId ?? this.linkedCropId,
      linkedFieldId: linkedFieldId ?? this.linkedFieldId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      description: description ?? this.description,
      receiptPhotoLocalPath: receiptPhotoLocalPath ?? this.receiptPhotoLocalPath,
      receiptPhotoCloudUrl: receiptPhotoCloudUrl ?? this.receiptPhotoCloudUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'userId': userId,
        'scope': scope,
        'linkedAnimalId': linkedAnimalId,
        'linkedSpeciesId': linkedSpeciesId,
        'linkedCropId': linkedCropId,
        'linkedFieldId': linkedFieldId,
        'amount': amount,
        'category': category,
        'date': date,
        'description': description,
        'receiptPhotoCloudUrl': receiptPhotoCloudUrl,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Expense.fromFirestore(Map<String, dynamic> map) => Expense(
        id: map['id'] as String,
        userId: map['userId'] as String,
        scope: map['scope'] as String? ?? 'general',
        linkedAnimalId: map['linkedAnimalId'] as String?,
        linkedSpeciesId: map['linkedSpeciesId'] as String?,
        linkedCropId: map['linkedCropId'] as String?,
        linkedFieldId: map['linkedFieldId'] as String?,
        amount: (map['amount'] as num).toDouble(),
        category: map['category'] as String,
        date: map['date'] as String,
        description: map['description'] as String?,
        receiptPhotoLocalPath: null,
        receiptPhotoCloudUrl: map['receiptPhotoCloudUrl'] as String?,
        createdAt: map['createdAt'] as String,
        updatedAt: map['updatedAt'] as String,
        syncStatus: 'synced',
      );
}

abstract class ExpenseScope {
  static const animal = 'animal';
  static const crop = 'crop';
  static const field = 'field';
  static const general = 'general';

  static const all = [animal, crop, field, general];
}

abstract class AnimalExpenseCategory {
  static const food = 'food';
  static const medicine = 'medicine';
  static const veterinary = 'veterinary';
  static const vaccination = 'vaccination';
  static const transport = 'transport';
  static const workerSalary = 'worker_salary';
  static const other = 'other';

  static const all = [
    food,
    medicine,
    veterinary,
    vaccination,
    transport,
    workerSalary,
    other,
  ];
}

abstract class CropExpenseCategory {
  static const seeds = 'seeds';
  static const fertilizer = 'fertilizer';
  static const water = 'water';
  static const pesticide = 'pesticide';
  static const workerSalary = 'worker_salary';
  static const transport = 'transport';
  static const equipment = 'equipment';
  static const other = 'other';

  static const all = [
    seeds,
    fertilizer,
    water,
    pesticide,
    workerSalary,
    transport,
    equipment,
    other,
  ];
}

abstract class FieldExpenseCategory {
  static const rentPayment = 'rent_payment';
  static const maintenance = 'maintenance';
  static const other = 'other';

  static const all = [rentPayment, maintenance, other];
}

abstract class GeneralExpenseCategory {
  static const fuel = 'fuel';
  static const tools = 'tools';
  static const repair = 'repair';
  static const electricity = 'electricity';
  static const rent = 'rent';
  static const other = 'other';

  static const all = [fuel, tools, repair, electricity, rent, other];
}

List<String> categoriesForScope(String scope) {
  switch (scope) {
    case ExpenseScope.animal:
      return AnimalExpenseCategory.all;
    case ExpenseScope.crop:
      return CropExpenseCategory.all;
    case ExpenseScope.field:
      return FieldExpenseCategory.all;
    case ExpenseScope.general:
    default:
      return GeneralExpenseCategory.all;
  }
}
