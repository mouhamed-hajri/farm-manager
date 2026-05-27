import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/animal.dart';
import '../models/breed.dart';
import '../models/crop.dart';
import '../models/crop_activity.dart';
import '../models/expense.dart';
import '../models/harvest.dart';
import '../models/field.dart';
import '../models/health_event.dart';
import '../models/history_entry.dart';
import '../models/reminder.dart';
import '../models/reproduction_event.dart';
import '../models/sale.dart';
import '../models/species.dart';
import '../models/user_settings.dart';
import '../models/weight_measurement.dart';

class FirebaseService {
  FirebaseService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _coll(String userId, String name) =>
      _firestore.collection('users').doc(userId).collection(name);

  DocumentReference<Map<String, dynamic>> _userDoc(String userId) =>
      _firestore.collection('users').doc(userId);

  // ─── User profile ─────────────────────────────────────────────────────────

  Future<String?> fetchUserPhone(String userId) async {
    final snap = await _userDoc(userId).get();
    final data = snap.data();
    return data?['phoneNumber'] as String?;
  }

  Future<void> updateUserPhone(String userId, String? phone) =>
      _userDoc(userId).set(
        {'phoneNumber': phone},
        SetOptions(merge: true),
      );

  // ─── Species ──────────────────────────────────────────────────────────────

  Future<void> uploadSpecies(Species s) =>
      _coll(s.userId, 'species').doc(s.id).set(s.toFirestore(), SetOptions(merge: true));

  Future<List<Species>> fetchAllSpecies(String userId) async {
    final snap = await _coll(userId, 'species').get();
    return snap.docs.map((d) => Species.fromFirestore(d.data())).toList();
  }

  Future<void> deleteSpecies(String userId, String id) =>
      _coll(userId, 'species').doc(id).delete();

  // ─── Breeds ───────────────────────────────────────────────────────────────

  Future<void> uploadBreed(Breed b) =>
      _coll(b.userId, 'breeds').doc(b.id).set(b.toFirestore(), SetOptions(merge: true));

  Future<List<Breed>> fetchAllBreeds(String userId) async {
    final snap = await _coll(userId, 'breeds').get();
    return snap.docs.map((d) => Breed.fromFirestore(d.data())).toList();
  }

  Future<void> deleteBreed(String userId, String id) =>
      _coll(userId, 'breeds').doc(id).delete();

  // ─── Weight Measurements ──────────────────────────────────────────────────

  Future<void> uploadWeightMeasurement(WeightMeasurement m) =>
      _coll(m.userId, 'weightMeasurements')
          .doc(m.id)
          .set(m.toFirestore(), SetOptions(merge: true));

  Future<List<WeightMeasurement>> fetchAllWeightMeasurements(
      String userId) async {
    final snap = await _coll(userId, 'weightMeasurements').get();
    return snap.docs
        .map((d) => WeightMeasurement.fromFirestore(d.data()))
        .toList();
  }

  Future<void> deleteWeightMeasurement(String userId, String id) =>
      _coll(userId, 'weightMeasurements').doc(id).delete();

  // ─── Animals ──────────────────────────────────────────────────────────────

  Future<void> uploadAnimal(Animal a) =>
      _coll(a.userId, 'animals').doc(a.id).set(a.toFirestore(), SetOptions(merge: true));

  Future<List<Animal>> fetchAllAnimals(String userId) async {
    final snap = await _coll(userId, 'animals').get();
    return snap.docs.map((d) => Animal.fromFirestore(d.data())).toList();
  }

  Future<void> deleteAnimal(String userId, String id) =>
      _coll(userId, 'animals').doc(id).delete();

  // ─── Fields ───────────────────────────────────────────────────────────────

  Future<void> uploadField(FarmField f) =>
      _coll(f.userId, 'fields').doc(f.id).set(f.toFirestore(), SetOptions(merge: true));

  Future<List<FarmField>> fetchAllFields(String userId) async {
    final snap = await _coll(userId, 'fields').get();
    return snap.docs.map((d) => FarmField.fromFirestore(d.data())).toList();
  }

  // ─── Crops ────────────────────────────────────────────────────────────────

  Future<void> uploadCrop(Crop c) =>
      _coll(c.userId, 'crops').doc(c.id).set(c.toFirestore(), SetOptions(merge: true));

  Future<List<Crop>> fetchAllCrops(String userId) async {
    final snap = await _coll(userId, 'crops').get();
    return snap.docs.map((d) => Crop.fromFirestore(d.data())).toList();
  }

  Future<void> deleteCrop(String userId, String id) =>
      _coll(userId, 'crops').doc(id).delete();

  // ─── Crop Activities ─────────────────────────────────────────────────────

  Future<void> uploadCropActivity(CropActivity a) => _coll(a.userId, 'cropActivities')
      .doc(a.id)
      .set(a.toFirestore(), SetOptions(merge: true));

  Future<List<CropActivity>> fetchAllCropActivities(String userId) async {
    final snap = await _coll(userId, 'cropActivities').get();
    return snap.docs.map((d) => CropActivity.fromFirestore(d.data())).toList();
  }

  Future<void> deleteCropActivity(String userId, String id) =>
      _coll(userId, 'cropActivities').doc(id).delete();

  // ─── Harvests ────────────────────────────────────────────────────────────

  Future<void> uploadHarvest(Harvest h) => _coll(h.userId, 'harvests')
      .doc(h.id)
      .set(h.toFirestore(), SetOptions(merge: true));

  Future<List<Harvest>> fetchAllHarvests(String userId) async {
    final snap = await _coll(userId, 'harvests').get();
    return snap.docs.map((d) => Harvest.fromFirestore(d.data())).toList();
  }

  Future<void> deleteHarvest(String userId, String id) =>
      _coll(userId, 'harvests').doc(id).delete();

  // ─── Expenses ─────────────────────────────────────────────────────────────

  Future<void> uploadExpense(Expense e) =>
      _coll(e.userId, 'expenses').doc(e.id).set(e.toFirestore(), SetOptions(merge: true));

  Future<List<Expense>> fetchAllExpenses(String userId) async {
    final snap = await _coll(userId, 'expenses').get();
    return snap.docs.map((d) => Expense.fromFirestore(d.data())).toList();
  }

  Future<void> deleteExpense(String userId, String id) =>
      _coll(userId, 'expenses').doc(id).delete();

  // ─── Sales ────────────────────────────────────────────────────────────────

  Future<void> uploadSale(Sale s) =>
      _coll(s.userId, 'sales').doc(s.id).set(s.toFirestore(), SetOptions(merge: true));

  Future<List<Sale>> fetchAllSales(String userId) async {
    final snap = await _coll(userId, 'sales').get();
    return snap.docs.map((d) => Sale.fromFirestore(d.data())).toList();
  }

  Future<void> deleteSale(String userId, String id) =>
      _coll(userId, 'sales').doc(id).delete();

  // ─── Reproduction events ──────────────────────────────────────────────────

  Future<void> uploadReproductionEvent(ReproductionEvent e) =>
      _coll(e.userId, 'reproduction_events')
          .doc(e.id)
          .set(e.toFirestore(), SetOptions(merge: true));

  Future<List<ReproductionEvent>> fetchAllReproductionEvents(String userId) async {
    final snap = await _coll(userId, 'reproduction_events').get();
    return snap.docs
        .map((d) => ReproductionEvent.fromFirestore(d.data()))
        .toList();
  }

  // ─── Health events ────────────────────────────────────────────────────────

  Future<void> uploadHealthEvent(HealthEvent h) =>
      _coll(h.userId, 'health_events').doc(h.id).set(h.toFirestore(), SetOptions(merge: true));

  Future<List<HealthEvent>> fetchAllHealthEvents(String userId) async {
    final snap = await _coll(userId, 'health_events').get();
    return snap.docs.map((d) => HealthEvent.fromFirestore(d.data())).toList();
  }

  // ─── Reminders ────────────────────────────────────────────────────────────

  Future<void> uploadReminder(Reminder r) =>
      _coll(r.userId, 'reminders').doc(r.id).set(r.toFirestore(), SetOptions(merge: true));

  Future<List<Reminder>> fetchAllReminders(String userId) async {
    final snap = await _coll(userId, 'reminders').get();
    return snap.docs.map((d) => Reminder.fromFirestore(d.data())).toList();
  }

  // ─── History ──────────────────────────────────────────────────────────────

  Future<void> uploadHistory(HistoryEntry entry) =>
      _coll(entry.userId, 'history').doc(entry.id).set(entry.toFirestore(), SetOptions(merge: true));

  Future<void> deleteHistory(String userId, String id) =>
      _coll(userId, 'history').doc(id).delete();

  Future<List<HistoryEntry>> fetchAllHistory(String userId) async {
    final snap = await _coll(userId, 'history').get();
    return snap.docs.map((d) => HistoryEntry.fromFirestore(d.data())).toList();
  }

  // ─── Counters ─────────────────────────────────────────────────────────────

  Future<void> uploadCounter(
      String userId, String prefix, int year, int lastNumber) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('counters')
        .doc('$prefix-$year')
        .set({'prefix': prefix, 'year': year, 'lastNumber': lastNumber},
            SetOptions(merge: true));
  }

  Future<Map<String, int>> fetchAllCounters(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('counters')
        .get();
    final result = <String, int>{};
    for (final d in snap.docs) {
      result[d.id] = (d.data()['lastNumber'] as num).toInt();
    }
    return result;
  }

  // ─── Settings ─────────────────────────────────────────────────────────────

  Future<void> uploadSettings(UserSettings s) async {
    await _firestore
        .collection('users')
        .doc(s.userId)
        .collection('settings')
        .doc('appSettings')
        .set(s.toFirestore(), SetOptions(merge: true));
  }

  Future<UserSettings?> fetchSettings(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('appSettings')
        .get();
    final data = doc.data();
    if (data == null) return null;
    return UserSettings.fromFirestore({...data, 'userId': userId});
  }

  Future<void> updateLastBackupDate(String userId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('appSettings')
        .set({'lastBackupDate': DateTime.now().toIso8601String()},
            SetOptions(merge: true));
  }

  Future<String?> getLastBackupDate(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('appSettings')
        .get();
    return doc.data()?['lastBackupDate'] as String?;
  }

  // Fast probe: does this user have ANY data in cloud? Used for auto-restore on
  // first login per device — checks each collection with limit 1 to avoid
  // pulling the whole dataset just to detect non-emptiness.
  Future<bool> hasAnyCloudData(String userId) async {
    for (final name in const [
      'animals',
      'fields',
      'crops',
      'expenses',
      'sales',
    ]) {
      final snap = await _coll(userId, name).limit(1).get();
      if (snap.docs.isNotEmpty) return true;
    }
    return false;
  }
}
