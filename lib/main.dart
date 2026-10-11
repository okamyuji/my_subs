import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'calendar_sync.dart';
import 'notification_scheduler.dart';
import 'presets.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = SharedPreferencesAsync();
  final calendar = calendarSyncSupported() ? CalendarSync(prefs) : null;
  await calendar?.load();
  final scheduler = NotificationScheduler(
    suppressed: () => calendar?.ownsReminders ?? false,
  );
  await scheduler.init();
  final store = SubscriptionStore(
    prefs,
    onChanged: (subs) async {
      await scheduler.reschedule(subs);
      await calendar?.sync(subs);
    },
  );
  final presets = await loadPresets(rootBundle);
  await store.load();
  // Switching calendar sync, or its failing, hands the reminders over.
  calendar?.changes.addListener(() => scheduler.reschedule(store.items));
  runApp(
    MySubsApp(
      store: store,
      presets: presets,
      notificationsEnabled: scheduler.enabled,
      notificationsOverLimit: scheduler.overLimit,
      onResume: () => scheduler.reschedule(store.items),
      calendar: calendar,
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
