import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:uuid/uuid.dart';
import '../models/field.dart';
import '../models/health_event.dart';
import '../models/reminder.dart';
import '../models/reproduction_event.dart';
import '../repositories/reminder_repository.dart';

class ReminderService {
  ReminderService(this._repo) {
    tzdata.initializeTimeZones();
  }

  final ReminderRepository _repo;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const _uuid = Uuid();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(init);
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    _initialized = true;
  }

  AndroidNotificationDetails get _details =>
      const AndroidNotificationDetails(
        'farm_reminders',
        'Rappels',
        channelDescription: 'Rappels pour les contrats, gestations, et vaccinations',
        importance: Importance.high,
        priority: Priority.high,
      );

  int _stableId(String linkedType, String linkedId, String category, int idx) {
    return ('$linkedType-$linkedId-$category-$idx').hashCode & 0x7fffffff;
  }

  Future<void> scheduleRentReminders(FarmField field) async {
    await init();
    await cancelForLinked(field.userId, ReminderLinkedType.field, field.id);
    if (field.ownership != FieldOwnership.rented || field.rentEndDate == null) {
      return;
    }
    final end = DateTime.tryParse(field.rentEndDate!);
    if (end == null) return;

    final daysOffsets = [30, 7, 0];
    final now = DateTime.now();
    for (var i = 0; i < daysOffsets.length; i++) {
      final offset = daysOffsets[i];
      final trigger = DateTime(end.year, end.month, end.day, 9)
          .subtract(Duration(days: offset));
      if (trigger.isBefore(now)) continue;
      final id = _stableId('field', field.id, 'rent_expiry', i);
      final body = offset == 0
          ? 'Le contrat de ${field.name} expire aujourd\'hui.'
          : 'Le contrat de ${field.name} expire dans $offset jours.${field.landlordName == null ? "" : " Contacter ${field.landlordName}${field.landlordPhone == null ? "" : " au ${field.landlordPhone}"}."}';
      await _plugin.zonedSchedule(
        id,
        'Contrat de location',
        body,
        tz.TZDateTime.from(trigger, tz.local),
        NotificationDetails(android: _details),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      await _repo.add(Reminder(
        id: _uuid.v4(),
        userId: field.userId,
        title: 'Contrat de location',
        body: body,
        triggerDate: trigger.toIso8601String(),
        category: ReminderCategory.rentExpiry,
        linkedType: ReminderLinkedType.field,
        linkedId: field.id,
        isDone: false,
        platformNotificationId: id,
        createdAt: '',
        updatedAt: '',
        syncStatus: 'pending',
      ));
    }
  }

  Future<void> schedulePregnancyReminder(
      ReproductionEvent event, String motherFarmId) async {
    if (event.eventType != ReproductionEventType.pregnancyConfirmed) return;
    if (event.dueDate == null) return;
    await init();
    final due = DateTime.tryParse(event.dueDate!);
    if (due == null) return;
    final trigger = DateTime(due.year, due.month, due.day, 9)
        .subtract(const Duration(days: 7));
    if (trigger.isBefore(DateTime.now())) return;
    final id = _stableId('animal', event.animalId, 'pregnancy_due', 0);
    final body = 'Mise bas prévue dans 7 jours pour $motherFarmId.';
    await _plugin.zonedSchedule(
      id,
      'Gestation',
      body,
      tz.TZDateTime.from(trigger, tz.local),
      NotificationDetails(android: _details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    await _repo.add(Reminder(
      id: _uuid.v4(),
      userId: event.userId,
      title: 'Gestation',
      body: body,
      triggerDate: trigger.toIso8601String(),
      category: ReminderCategory.pregnancyDue,
      linkedType: ReminderLinkedType.animal,
      linkedId: event.animalId,
      isDone: false,
      platformNotificationId: id,
      createdAt: '',
      updatedAt: '',
      syncStatus: 'pending',
    ));
  }

  Future<void> scheduleVaccinationReminder(
      HealthEvent event, String animalFarmId) async {
    if (event.eventType != HealthEventType.vaccination) return;
    if (event.nextDueDate == null) return;
    await init();
    final due = DateTime.tryParse(event.nextDueDate!);
    if (due == null) return;
    final trigger = DateTime(due.year, due.month, due.day, 9);
    if (trigger.isBefore(DateTime.now())) return;
    final id = _stableId('animal', event.animalId, 'vaccination_due', 0);
    final body = 'Vaccination à effectuer aujourd\'hui pour $animalFarmId.';
    await _plugin.zonedSchedule(
      id,
      'Vaccination',
      body,
      tz.TZDateTime.from(trigger, tz.local),
      NotificationDetails(android: _details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    await _repo.add(Reminder(
      id: _uuid.v4(),
      userId: event.userId,
      title: 'Vaccination',
      body: body,
      triggerDate: trigger.toIso8601String(),
      category: ReminderCategory.vaccinationDue,
      linkedType: ReminderLinkedType.animal,
      linkedId: event.animalId,
      isDone: false,
      platformNotificationId: id,
      createdAt: '',
      updatedAt: '',
      syncStatus: 'pending',
    ));
  }

  Future<void> cancelForLinked(
      String userId, String linkedType, String linkedId) async {
    await init();
    final existing = await _repo.getForLinked(userId, linkedType, linkedId);
    for (final r in existing) {
      if (r.platformNotificationId != null) {
        await _plugin.cancel(r.platformNotificationId!);
      }
    }
    await _repo.deleteForLinked(userId, linkedType, linkedId);
  }
}
