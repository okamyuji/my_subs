import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'billing.dart';
import 'subscription.dart';

const calendarName = 'my_subs';

// Android's CalendarContract.ACCOUNT_TYPE_LOCAL: a calendar tied to no
// account, so it never syncs off the device.
const _localAccountType = 'LOCAL';

/// Force-stopping the app on Android cancels its notification alarms until it
/// is opened again; reminders owned by the calendar provider survive that.
/// iOS has no such stop, and its calendars may live in iCloud, so the switch
/// is Android only.
bool calendarSyncSupported() => defaultTargetPlatform == TargetPlatform.android;

typedef CalendarEntry = ({
  String title,
  DateTime start,
  RecurrenceRule rule,
  Duration? reminder,
});

/// Recurring entries at 9:00 on each billing day. Only the name goes in:
/// other apps with calendar access can read these events.
List<CalendarEntry> calendarEntries(Subscription s) {
  final title = '請求日: ${s.name}';
  final reminder = switch (s.notifyDaysBefore) {
    null => null,
    final days => Duration(days: days),
  };
  DateTime at9(DateTime d) => DateTime(d.year, d.month, d.day, 9);
  final day = s.firstBillingDate.day;
  if (day <= 28) {
    return [
      (
        title: title,
        start: at9(s.firstBillingDate),
        rule: MonthlyRecurrence(interval: s.intervalMonths, daysOfMonth: [day]),
        reminder: reminder,
      ),
    ];
  }
  // Android's calendar ignores BYSETPOS (it expanded 28,29,30,31;BYSETPOS=-1
  // into all four days), so billingDate's month-end clamping is spelled out
  // as one yearly series per billing month. Only February varies by year;
  // a February series starting on the 29th expanded only in leap years, so
  // it starts on the 28th of that year instead.
  return [
    for (var k = 0; k < 12 ~/ s.intervalMonths; k++)
      if (billingDate(s, k) case final d)
        (
          title: title,
          start: at9(d.month == 2 ? DateTime(d.year, 2, 28) : d),
          rule: YearlyRecurrence(
            months: [d.month],
            daysOfMonth: [d.month == 2 ? -1 : d.day],
          ),
          reminder: reminder,
        ),
  ];
}

class CalendarSync {
  CalendarSync(this._prefs);

  static const key = 'calendar_sync_v1';

  final SharedPreferencesAsync _prefs;
  final _calendar = DeviceCalendar.instance;
  Future<void> _queue = Future.value();

  final enabled = ValueNotifier<bool>(false);
  final failed = ValueNotifier<bool>(false);

  /// True when the calendar carries the reminders, so the app's own
  /// notifications can stand down; a failed sync hands them back.
  bool get ownsReminders => enabled.value && !failed.value;

  /// Fires when [ownsReminders] may have changed.
  Listenable get changes => Listenable.merge([enabled, failed]);

  Future<void> load() async {
    enabled.value = await _prefs.getBool(key) ?? false;
  }

  /// Returns false when calendar access is refused; the switch stays off.
  Future<bool> setEnabled(bool on, List<Subscription> subs) async {
    if (on &&
        await _calendar.requestPermissions() !=
            CalendarPermissionStatus.granted) {
      return false;
    }
    enabled.value = on;
    await _prefs.setBool(key, on);
    await _enqueue(subs);
    return true;
  }

  Future<void> sync(List<Subscription> subs) =>
      enabled.value ? _enqueue(subs) : Future.value();

  // Delete-and-recreate is not atomic; overlapping runs would leave two
  // calendars, so runs are queued.
  Future<void> _enqueue(List<Subscription> subs) =>
      _queue = _queue.catchError((Object _) {}).then((_) => _run(subs));

  Future<void> _run(List<Subscription> subs) async {
    // Access revoked in system settings: nothing can be written, and a save
    // must not fail because of it. Reported only while on.
    if (await _calendar.hasPermissions() != CalendarPermissionStatus.granted) {
      failed.value = enabled.value;
      return;
    }
    try {
      for (final c in await _calendar.listCalendars()) {
        if (c.name == calendarName && c.accountType == _localAccountType) {
          await _calendar.deleteCalendar(c.id);
        }
      }
      if (enabled.value) {
        final id = await _calendar.createCalendar(name: calendarName);
        for (final e in subs.expand(calendarEntries)) {
          await _calendar.createEvent(
            calendarId: id,
            title: e.title,
            startDate: e.start,
            endDate: e.start.add(const Duration(minutes: 15)),
            recurrenceRule: e.rule,
            reminders: e.reminder == null ? null : [e.reminder!],
          );
        }
      }
      failed.value = false;
    } catch (e) {
      // The subscription itself is already saved; the list shows a banner.
      debugPrint('calendar sync failed: $e');
      failed.value = true;
    }
  }
}
