import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'notification_scheduler.dart';
import 'presets.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final scheduler = NotificationScheduler();
  await scheduler.init();
  final store = SubscriptionStore(
    SharedPreferencesAsync(),
    onChanged: scheduler.reschedule,
  );
  final presets = await loadPresets(rootBundle);
  await store.load();
  runApp(
    MySubsApp(
      store: store,
      presets: presets,
      notificationsEnabled: scheduler.enabled,
      notificationsOverLimit: scheduler.overLimit,
      onResume: () async {
        await scheduler.refreshPermission();
        await scheduler.reschedule(store.items);
      },
    ),
  );
  // Not awaited before runApp: the prompt would hold the first frame until
  // the user answers it.
  unawaited(
    scheduler.requestPermission().then(
      (_) => scheduler.reschedule(store.items),
    ),
  );
}
