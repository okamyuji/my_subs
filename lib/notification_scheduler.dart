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
  NotificationScheduler({bool Function()? suppressed})
    : _suppressed = suppressed ?? (() => false);

  /// True while calendar sync owns the reminders; both would fire at once.
  final bool Function() _suppressed;
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

  Future<void> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted = android != null
        ? await android.requestNotificationsPermission()
        : await ios?.requestPermissions(alert: true, sound: true);
    enabled.value = granted ?? false;
  }

  // cancelAll + renumbering is not atomic; overlapping runs would leave the
  // older plan's tail in the OS, so runs are queued.
  Future<void> reschedule(List<Subscription> subs) =>
      _queue = _queue.catchError((Object _) {}).then((_) => _run(subs));

  Future<void> _run(List<Subscription> subs) async {
    await _plugin.cancelAll();
    if (_suppressed()) {
      overLimit.value = false;
      return;
    }
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
