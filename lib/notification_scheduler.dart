import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_plan.dart';
import 'subscription.dart';

// The default database omits legacy ids such as "GMT" that Android's
// ZoneId.systemDefault() can return; an unknown id must not stop startup.
tz.Location resolveLocation(String id) {
  tzdata.initializeTimeZones();
  try {
    return tz.getLocation(id);
  } on tz.LocationNotFoundException {
    return tz.UTC;
  }
}

class NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void> _queue = Future.value();

  /// null until the user answers the permission prompt.
  final enabled = ValueNotifier<bool?>(null);
  final overLimit = ValueNotifier<bool>(false);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'billing',
      '請求日',
      channelDescription: 'サブスクの請求日のお知らせ',
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(resolveLocation(info.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notify'),
        // Asking inside initialize() would block startup until answered.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  Future<void> requestPermission() async {
    final android = _android;
    final granted = android != null
        ? await android.requestNotificationsPermission()
        : await _ios?.requestPermissions(alert: true, sound: true);
    enabled.value = granted ?? false;
    // iOS can answer the request with didGrant: 0 although the user has just
    // allowed it (its settings flip to enabled milliseconds later), so a
    // refusal is checked against the settings.
    if (granted != true) await refreshPermission();
  }

  /// Re-reads the OS setting, e.g. after the user changed it in Settings.
  /// An unanswered prompt (null) is left alone: the OS reports it as off.
  Future<void> refreshPermission() async {
    if (enabled.value == null) return;
    final android = _android;
    final on = android != null
        ? await android.areNotificationsEnabled()
        : (await _ios?.checkPermissions())?.isEnabled;
    if (on != null) enabled.value = on;
  }

  // cancelAll + renumbering is not atomic; overlapping runs would leave the
  // older plan's tail in the OS, so runs are queued.
  Future<void> reschedule(List<Subscription> subs) =>
      _queue = _queue.catchError((Object _) {}).then((_) => _run(subs));

  Future<void> _run(List<Subscription> subs) async {
    await _plugin.cancelAll();
    if (enabled.value != true) return;
    final (:plans, overLimit: over) = planNotifications(subs, DateTime.now());
    overLimit.value = over;
    for (var i = 0; i < plans.length; i++) {
      await _plugin.zonedSchedule(
        id: i,
        scheduledDate: tz.TZDateTime.from(plans[i].at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: '請求日のお知らせ',
        body: notificationBody(plans[i]),
        matchDateTimeComponents: switch (plans[i].repeat) {
          NotificationRepeat.monthly => DateTimeComponents.dayOfMonthAndTime,
          NotificationRepeat.yearly => DateTimeComponents.dateAndTime,
          NotificationRepeat.none => null,
        },
      );
    }
  }
}
