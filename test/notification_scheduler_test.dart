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
  // Canned answers for permission queries, by method name.
  final replies = <String, Object?>{};

  setUp(() {
    pending.clear();
    methods.clear();
    replies.clear();
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
          return replies[call.method];
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

  group('permission', () {
    // iOS answered didGrant: 0 to the request although the user had just
    // allowed it; its settings flipped to enabled milliseconds later.
    test('trusts the OS settings when iOS reports a stale refusal', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      replies['requestPermissions'] = false;
      replies['checkPermissions'] = {'isEnabled': true};
      final scheduler = NotificationScheduler();
      await scheduler.requestPermission();
      expect(scheduler.enabled.value, isTrue);
    });

    test('stays off when the OS settings agree', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      IOSFlutterLocalNotificationsPlugin.registerWith();
      replies['requestPermissions'] = false;
      replies['checkPermissions'] = {'isEnabled': false};
      final scheduler = NotificationScheduler();
      await scheduler.requestPermission();
      expect(scheduler.enabled.value, isFalse);
    });

    test('no answer at all counts as off', () async {
      final scheduler = NotificationScheduler();
      await scheduler.requestPermission();
      expect(scheduler.enabled.value, isFalse);
    });

    test('does not re-read when the request was granted', () async {
      replies['requestNotificationsPermission'] = true;
      final scheduler = NotificationScheduler();
      await scheduler.requestPermission();
      expect(scheduler.enabled.value, isTrue);
      expect(methods, ['requestNotificationsPermission']);
    });

    test('picks up a change made in the system settings', () async {
      final scheduler = NotificationScheduler()..enabled.value = false;
      replies['areNotificationsEnabled'] = true;
      await scheduler.refreshPermission();
      expect(scheduler.enabled.value, isTrue);
    });

    test('keeps the last answer when the OS gives none', () async {
      final scheduler = NotificationScheduler()..enabled.value = true;
      await scheduler.refreshPermission();
      expect(scheduler.enabled.value, isTrue);
    });

    test('leaves an unanswered prompt alone', () async {
      final scheduler = NotificationScheduler();
      await scheduler.refreshPermission();
      expect(scheduler.enabled.value, isNull);
      expect(methods, isEmpty);
    });
  });

  test('only cancels when notifications are not enabled', () async {
    final scheduler = NotificationScheduler()..enabled.value = false;
    await scheduler.reschedule([monthly]);
    expect(methods, ['cancelAll']);
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
