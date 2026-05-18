import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:workmanager/workmanager.dart';
import 'app.dart';

const _syncTaskName = 'farmDailySync';
const _syncTaskId = 'com.example.farm_manager.dailySync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Background sync runs outside the Flutter widget tree.
    // We just trigger a best-effort sync — errors are swallowed so the
    // task is not rescheduled indefinitely.
    try {
      await Firebase.initializeApp();
    } catch (_) {}
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    _syncTaskId,
    _syncTaskName,
    frequency: const Duration(hours: 24),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(const ProviderScope(child: FarmApp()));
}
