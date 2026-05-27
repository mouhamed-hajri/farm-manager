export interface Animal {
  id: string;
  userId: string;
  speciesId: string;
  farmId: string;
  nickname?: string;
  gender: 'male' | 'female';
  breed?: string;
  color?: string;
  birthDate?: string;
  weight?: number;
  healthStatus: string;
  status: 'active' | 'sold' | 'dead';
  purchaseDate?: string;
  purchasePrice?: number;
  sellerName?: string;
  sellerPhone?: string;
  purchaseLocation?: string;
  photoCloudUrl?: string;
  motherId?: string;
  fatherId?: string;
  deathDate?: string;
  deathCause?: string;
  deathNotes?: string;
  notes?: string;
  financeOwnerId?: string;
  financeMode?: string;
  birthEventId?: string;
  weaningDate?: string;
  valuationAmount?: number;
  isBreeder: boolean;
  createdAt: string;
  updatedAt: string;
  syncStatus: string;
}

export interface Species {
  id: string;
  userId: string;
  nameFr: string;
  nameAr: string;
  iconEmoji: string;
  idPrefix: string;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
  syncStatus: string;
}

export interface Breed {
  id: string;
  userId: string;
  speciesId: string;
  name: string;
  createdAt: string;
  updatedAt: string;
  syncStatus: string;
}

export interface Expense {
  id: string;
  userId: string;
  scope: string;
  linkedAnimalId?: string;
  linkedSpeciesId?: string;
  linkedCropId?: string;
  linkedFieldId?: string;
  amount: number;
  category: string;
  date: string;
  description?: string;
  receiptPhotoCloudUrl?: string;
  createdAt: string;
  updatedAt: string;
  syncStatus: string;
}

export interface Sale {
  id: string;
  userId: string;
  scope: string;
  linkedAnimalId?: string;
  linkedCropId?: string;
  productName?: string;
  quantity: number;
  unit: string;
  unitPrice: number;
  totalPrice: number;
  buyerName?: string;
  buyerPhone?: string;
  saleDate: string;
  receiptPhotoCloudUrl?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
  syncStatus: string;
}

export interface FarmField {
  id: string;
  userId: string;
  name: string;
  areaText?: string;
  locationText?: string;
  ownership: string;
  photoCloudUrl?: string;
  rentAmount?: number;
  rentPeriod?: string;
  rentStartDate?: string;
  rentEndDate?: string;
  landlordName?: string;
  landlordPhone?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
  syncStatus: string;
}

export interface Crop {
  id: string;
  userId: string;
  nameFr: string;
  nameAr: string;
  iconEmoji: string;
  kind: string;
  seasonMonths: number[];
  fieldId?: string;
  areaOrCountText?: string;
  photoCloudUrl?: string;
  notes?: string;
  isDefault: boolean;
  createdAt: string;
  updatedAt: string;
  syncStatus: string;
}

export interface HistoryEntry {
  id: string;
  userId: string;
  actionType: string;
  title: string;
  description?: string;
  relatedType?: string;
  relatedId?: string;
  date: string;
  createdAt: string;
  syncStatus: string;
}

export interface WeightMeasurement {
  id: string;
  userId: string;
  animalId: string;
  weight: number;
  measurementDate: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
  syncStatus: string;
}

export interface HealthEvent {
  id: string;
  userId: string;
  animalId: string;
  eventType: string;
  description: string;
  date: string;
  vetName?: string;
  nextDueDate?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
  syncStatus: string;
}

export interface ReproductionEvent {
  id: string;
  userId: string;
  animalId: string;
  eventType: string;
  partnerId?: string;
  eventDate: string;
  dueDate?: string;
  offspringCount?: number;
  pregnancyGroupId?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
  syncStatus: string;
}
