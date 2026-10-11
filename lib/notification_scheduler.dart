import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_plan.dart';
import 'subscription.dart';

class NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();

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
    tzdata.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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

  Future<void> reschedule(List<Subscription> subs) async {
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
        body: notificationBody(plans[i].sub),
        matchDateTimeComponents: switch (plans[i].repeat) {
          NotificationRepeat.monthly => DateTimeComponents.dayOfMonthAndTime,
          NotificationRepeat.yearly => DateTimeComponents.dateAndTime,
          NotificationRepeat.none => null,
        },
      );
    }
  }
}
