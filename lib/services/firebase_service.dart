import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/animal.dart';
import '../models/crop.dart';
import '../models/expense.dart';
import '../models/field.dart';
import '../models/health_event.dart';
import '../models/history_entry.dart';
import '../models/reminder.dart';
import '../models/reproduction_event.dart';
import '../models/sale.dart';
import '../models/species.dart';
import '../models/user_settings.dart';

class FirebaseService {
  FirebaseService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _coll(String userId, String name) =>
      _firestore.collection('users').doc(userId).collection(name);

  // ─── Species ──────────────────────────────────────────────────────────────

  Future<void> uploadSpecies(Species s) =>
      _coll(s.userId, 'species').doc(s.id).set(s.toFirestore(), SetOptions(merge: true));

  Future<List<Species>> fetchAllSpecies(String userId) async {
    final snap = await _coll(userId, 'species').get();
    return snap.docs.map((d) => Species.fromFirestore(d.data())).toList();
  }

  // ─── Animals ──────────────────────────────────────────────────────────────

  Future<void> uploadAnimal(Animal a) =>
      _coll(a.userId, 'animals').doc(a.id).set(a.toFirestore(), SetOptions(merge: true));

  Future<List<Animal>> fetchAllAnimals(String userId) async {
    final snap = await _coll(userId, 'animals').get();
    return snap.docs.map((d) => Animal.fromFirestore(d.data())).toList();
  }

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

  // ─── Expenses ─────────────────────────────────────────────────────────────

  Future<void> uploadExpense(Expense e) =>
      _coll(e.userId, 'expenses').doc(e.id).set(e.toFirestore(), SetOptions(merge: true));

  Future<List<Expense>> fetchAllExpenses(String userId) async {
    final snap = await _coll(userId, 'expenses').get();
    return snap.docs.map((d) => Expense.fromFirestore(d.data())).toList();
  }

  // ─── Sales ────────────────────────────────────────────────────────────────

  Future<void> uploadSale(Sale s) =>
      _coll(s.userId, 'sales').doc(s.id).set(s.toFirestore(), SetOptions(merge: true));

  Future<List<Sale>> fetchAllSales(String userId) async {
    final snap = await _coll(userId, 'sales').get();
    return snap.docs.map((d) => Sale.fromFirestore(d.data())).toList();
  }

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
}
