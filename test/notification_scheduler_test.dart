import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_subs/notification_scheduler.dart';
import 'package:my_subs/subscription.dart';
import 'package:timezone/timezone.dart' as tz;

Subscription sub(String name, DateTime first, {int? days = 1}) => Subscription(
  id: name,
  name: name,
  category: Category.other,
  amountYen: 100,
  intervalMonths: 1,
  firstBillingDate: first,
  notifyDaysBefore: days,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  // Mirrors what the OS holds: cancelAll empties it, zonedSchedule adds.
  final pending = <int, Map<Object?, Object?>>{};
  final methods = <String>[];

  setUp(() {
    pending.clear();
    methods.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          await Future<void>.delayed(const Duration(milliseconds: 2));
          if (call.method == 'cancelAll') pending.clear();
          if (call.method == 'zonedSchedule') {
            final args = call.arguments as Map<Object?, Object?>;
            pending[args['id']! as int] = args;
          }
          return null;
        });
    tz.setLocalLocation(resolveLocation('Asia/Tokyo'));
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  final now = DateTime.now();
  final monthly = sub('monthly', DateTime(now.year - 1, 1, 20));
  final monthEnd = sub('monthEnd', DateTime(now.year - 1, 1, 31));
  final future = sub('future', now.add(const Duration(days: 40)));

  test('resolves zones missing from the default database', () {
    expect(resolveLocation('GMT').name, 'GMT');
    expect(resolveLocation('Asia/Calcutta').name, 'Asia/Calcutta');
  });

  test('falls back to UTC for an unknown zone id', () {
    expect(resolveLocation('Nowhere/Zone'), tz.UTC);
  });

  test('only cancels when notifications are not enabled', () async {
    final scheduler = NotificationScheduler()..enabled.value = false;
    await scheduler.reschedule([monthly]);
    expect(methods, ['cancelAll']);
  });

  test('only cancels while the calendar owns the reminders', () async {
    var calendarOn = true;
    final scheduler = NotificationScheduler(suppressed: () => calendarOn)
      ..enabled.value = true
      ..overLimit.value = true;
    await scheduler.reschedule([monthly]);
    expect(methods, ['cancelAll']);
    expect(pending, isEmpty);
    expect(scheduler.overLimit.value, isFalse);
    calendarOn = false;
    await scheduler.reschedule([monthly]);
    expect(pending, hasLength(1));
  });

  test('maps repeats to calendar components and numbers ids from 0', () async {
    final scheduler = NotificationScheduler()..enabled.value = true;
    await scheduler.reschedule([monthly, monthEnd, future]);
    expect(methods.first, 'cancelAll');
    expect(pending.keys.toList()..sort(), List.generate(16, (i) => i));
    final matches = pending.values.map((a) => a['matchDateTimeComponents']);
    expect(
      matches.where((m) => m == DateTimeComponents.dayOfMonthAndTime.index),
      hasLength(1),
    );
    expect(
      matches.where((m) => m == DateTimeComponents.dateAndTime.index),
      hasLength(12),
    );
    expect(matches.where((m) => m == null), hasLength(3));
    expect(scheduler.overLimit.value, isFalse);
  });

  test('overlapping reschedules leave only the latest plan', () async {
    final scheduler = NotificationScheduler()..enabled.value = true;
    final first = scheduler.reschedule([monthly, monthEnd, future]);
    final second = scheduler.reschedule([monthly]);
    await Future.wait([first, second]);
    expect(pending, hasLength(1));
    expect(pending.values.single['body'], contains('monthly'));
  });

  test('flags plans beyond the cap', () async {
    final scheduler = NotificationScheduler()..enabled.value = true;
    await scheduler.reschedule([
      for (var i = 0; i < 6; i++) sub('e$i', DateTime(now.year - 1, 1, 31)),
    ]);
    expect(scheduler.overLimit.value, isTrue);
    expect(pending, hasLength(60));
  });
}
