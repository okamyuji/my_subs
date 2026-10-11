import 'package:device_calendar_plus_platform_interface/device_calendar_plus_platform_interface.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_subs/calendar_sync.dart';
import 'package:my_subs/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fake_calendar_platform.dart';

Subscription sub(
  String name,
  DateTime first, {
  int interval = 1,
  int? notify = 1,
  int amount = 1200,
}) => Subscription(
  id: name,
  name: name,
  category: Category.video,
  amountYen: amount,
  intervalMonths: interval,
  firstBillingDate: first,
  notifyDaysBefore: notify,
);

void main() {
  String rules(Subscription s) => calendarEntries(s)
      .map((e) => '${e.start.month}/${e.start.day} ${e.rule.toRruleString()}')
      .join(' | ');

  group('calendarEntries', () {
    test('a day up to 28 repeats on that day of the month', () {
      final [e] = calendarEntries(sub('Video', DateTime(2026, 10, 11)));
      expect(e.title, '請求日: Video');
      expect(e.start, DateTime(2026, 10, 11, 9));
      expect(e.rule.toRruleString(), 'FREQ=MONTHLY;BYMONTHDAY=11');
      expect(e.reminder, const Duration(days: 1));
    });

    test('day 28 every 3 months is still one monthly series', () {
      expect(
        rules(sub('A', DateTime(2026, 1, 28), interval: 3)),
        '1/28 FREQ=MONTHLY;INTERVAL=3;BYMONTHDAY=28',
      );
    });

    // Android's calendar ignores BYSETPOS, so a month-end day becomes one
    // yearly series per billing month, February on its last day.
    test('day 29 monthly is twelve yearly series', () {
      final r = rules(sub('A', DateTime(2026, 1, 29)));
      expect(r.split(' | '), hasLength(12));
      expect(
        r,
        startsWith(
          '1/29 FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=29 | '
          '2/28 FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=-1 | '
          '3/29 FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=29',
        ),
      );
    });

    test('day 31 every 3 months follows the clamped billing days', () {
      expect(
        rules(sub('A', DateTime(2026, 1, 31), interval: 3)),
        '1/31 FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=31 | '
        '4/30 FREQ=YEARLY;BYMONTH=4;BYMONTHDAY=30 | '
        '7/31 FREQ=YEARLY;BYMONTH=7;BYMONTHDAY=31 | '
        '10/31 FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=31',
      );
    });

    // Android expanded a February series starting on the 29th only in leap
    // years; starting it on the 28th of that year expands every year.
    test('a yearly February 29 starts on February 28', () {
      expect(
        rules(sub('A', DateTime(2024, 2, 29), interval: 12)),
        '2/28 FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=-1',
      );
    });

    test('no notification means no reminder; same day means zero lead', () {
      expect(
        calendarEntries(sub('A', DateTime(2026, 1, 5), notify: null))
            .single
            .reminder,
        isNull,
      );
      expect(
        calendarEntries(sub('A', DateTime(2026, 1, 30), notify: 0))
            .map((e) => e.reminder)
            .toSet(),
        {Duration.zero},
      );
    });

    test('the title never carries the amount', () {
      final [e] = calendarEntries(
        sub('Video', DateTime(2026, 1, 5), amount: 98765),
      );
      expect(e.title, isNot(contains('98')));
      expect(e.title, isNot(contains('¥')));
    });
  });

  group('CalendarSync', () {
    late FakeCalendarPlatform platform;
    late CalendarSync sync;
    final subs = [
      sub('Video', DateTime(2026, 10, 11)),
      sub('Music', DateTime(2026, 1, 31), interval: 3, notify: null),
    ];

    setUp(() {
      platform = FakeCalendarPlatform();
      DeviceCalendarPlusPlatform.instance = platform;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      sync = CalendarSync(SharedPreferencesAsync());
    });

    test(
      'enabling creates one local my_subs calendar with an event per item',
      () async {
        expect(await sync.setEnabled(true, subs), isTrue);
        expect(sync.enabled.value, isTrue);
        expect(platform.calendars.map((c) => (c['name'], c['accountType'])), [
          ('my_subs', 'LOCAL'),
        ]);
        final id = platform.calendars.single['id'];
        expect(platform.events, [
          (
            calendarId: id,
            title: '請求日: Video',
            start: DateTime(2026, 10, 11, 9),
            end: DateTime(2026, 10, 11, 9, 15),
            rrule: 'FREQ=MONTHLY;BYMONTHDAY=11',
            reminders: '1440',
          ),
          for (final (m, d) in [(1, 31), (4, 30), (7, 31), (10, 31)])
            (
              calendarId: id,
              title: '請求日: Music',
              start: DateTime(2026, m, d, 9),
              end: DateTime(2026, m, d, 9, 15),
              rrule: 'FREQ=YEARLY;BYMONTH=$m;BYMONTHDAY=$d',
              reminders: null,
            ),
        ]);
        expect(
          await SharedPreferencesAsync().getBool(CalendarSync.key),
          isTrue,
        );
      },
    );

    test('a refused permission leaves it off and writes nothing', () async {
      platform.permission = 'denied';
      expect(await sync.setEnabled(true, subs), isFalse);
      expect(sync.enabled.value, isFalse);
      expect(platform.calendars, isEmpty);
      expect(await SharedPreferencesAsync().getBool(CalendarSync.key), isNull);
    });

    test(
      'write-only or unanswered access is not enough to turn it on',
      () async {
        // Replacing the calendar needs to list and delete, which needs full access.
        for (final status in ['writeOnly', 'notDetermined', 'restricted']) {
          platform.permission = status;
          expect(await sync.setEnabled(true, subs), isFalse, reason: status);
        }
        expect(platform.calendars, isEmpty);
      },
    );

    test('a sync replaces only its own local calendar', () async {
      platform.calendars.addAll([
        calendarMap('g1', 'my_subs', 'com.google'),
        calendarMap('p1', 'Personal', 'LOCAL'),
      ]);
      await sync.setEnabled(true, subs);
      final firstId = platform.calendars.last['id'];
      await sync.sync([subs.first]);
      expect(platform.calendars.map((c) => c['id']), contains('g1'));
      expect(platform.calendars.map((c) => c['id']), contains('p1'));
      expect(platform.calendars.map((c) => c['id']), isNot(contains(firstId)));
      expect(platform.events.map((e) => e.title), ['請求日: Video']);
    });

    test('disabling removes the calendar and remembers it', () async {
      await sync.setEnabled(true, subs);
      expect(await sync.setEnabled(false, subs), isTrue);
      expect(platform.calendars, isEmpty);
      expect(await SharedPreferencesAsync().getBool(CalendarSync.key), isFalse);
      expect(sync.ownsReminders, isFalse);
    });

    test('a sync while off touches nothing', () async {
      await sync.sync(subs);
      expect(platform.calls, isEmpty);
    });

    test('turning it off without access is not a failure', () async {
      await sync.setEnabled(true, subs);
      platform.permission = 'denied';
      await sync.setEnabled(false, subs);
      expect(sync.failed.value, isFalse);
    });

    test('changes fires on the switch and on failure', () async {
      var fired = 0;
      sync.changes.addListener(() => fired++);
      await sync.setEnabled(true, subs);
      expect(fired, 1);
      sync.failed.value = true;
      expect(fired, 2);
    });

    test('load restores the saved switch', () async {
      await SharedPreferencesAsync().setBool(CalendarSync.key, true);
      await sync.load();
      expect(sync.enabled.value, isTrue);
    });

    test('a revoked permission skips the sync without throwing', () async {
      await sync.setEnabled(true, subs);
      platform.permission = 'denied';
      platform.calls.clear();
      await sync.sync(subs);
      expect(platform.calls, ['hasPermissions']);
      // Reported, so the app's own notifications take over again.
      expect(sync.failed.value, isTrue);
      expect(sync.ownsReminders, isFalse);
    });

    test(
      'a failed write is reported and cleared by the next good sync',
      () async {
        await sync.setEnabled(true, subs);
        platform.failCreateEvent = true;
        await sync.sync(subs);
        expect(sync.failed.value, isTrue);
        expect(sync.ownsReminders, isFalse);
        platform.failCreateEvent = false;
        await sync.sync(subs);
        expect(sync.failed.value, isFalse);
        expect(sync.ownsReminders, isTrue);
      },
    );

    test('overlapping syncs leave only the latest plan', () async {
      await sync.setEnabled(true, subs);
      platform.delay = const Duration(milliseconds: 5);
      await Future.wait([
        sync.sync(subs),
        sync.sync([subs.first]),
      ]);
      expect(platform.calendars, hasLength(1));
      expect(platform.events.map((e) => e.title), ['請求日: Video']);
    });
  });

  test('the switch exists only on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(calendarSyncSupported(), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(calendarSyncSupported(), isTrue);
    debugDefaultTargetPlatformOverride = null;
  });
}
