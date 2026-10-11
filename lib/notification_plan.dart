import 'billing.dart';
import 'subscription.dart';

/// How the OS repeats a scheduled notification after its first fire.
enum NotificationRepeat { none, monthly, yearly }

// Stays under iOS's 64 pending-notification limit; iOS keeps only the 64
// most recently scheduled and drops the rest without an error.
const notificationCap = 60;

class PlannedNotification {
  const PlannedNotification({
    required this.at,
    required this.sub,
    required this.repeat,
  });

  final DateTime at;
  final Subscription sub;
  final NotificationRepeat repeat;
}

DateTime _notifyAt(DateTime billing, int days) =>
    DateTime(billing.year, billing.month, billing.day - days, 9);

// A yearly calendar repeat on Feb 29 would fire only in leap years.
DateTime _yearlySafe(DateTime at, DateTime now) {
  if (at.month != 2 || at.day != 29) return at;
  final moved = DateTime(at.year, 2, 28, 9);
  return moved.isAfter(now) ? moved : DateTime(at.year + 1, 2, 28, 9);
}

List<PlannedNotification> _planOne(Subscription s, int days, DateTime now) {
  final upcoming = upcomingBillingDates(
    s,
    now,
  ).map((d) => _notifyAt(d, days)).where((at) => at.isAfter(now));
  PlannedNotification plan(DateTime at, NotificationRepeat repeat) =>
      PlannedNotification(at: at, sub: s, repeat: repeat);

  // iOS calendar repeats cannot carry a start date, so they would also fire
  // before the first billing; future starts stay one-shot until they begin.
  if (_notifyAt(s.firstBillingDate, days).isAfter(now)) {
    return [
      for (final at in upcoming.take(3)) plan(at, NotificationRepeat.none),
    ];
  }
  final day = s.firstBillingDate.day;
  if (s.intervalMonths == 1 && day <= 28 && day - days >= 1) {
    return [plan(upcoming.first, NotificationRepeat.monthly)];
  }
  return [
    for (final at in upcoming.take(12 ~/ s.intervalMonths))
      plan(_yearlySafe(at, now), NotificationRepeat.yearly),
  ];
}

({List<PlannedNotification> plans, bool overLimit}) planNotifications(
  List<Subscription> subs,
  DateTime now,
) {
  final plans = [
    for (final s in subs)
      if (s.notifyDaysBefore case final days?) ..._planOne(s, days, now),
  ]..sort((a, b) => a.at.compareTo(b.at));
  return (
    plans: plans.take(notificationCap).toList(),
    overLimit: plans.length > notificationCap,
  );
}

String notificationBody(PlannedNotification p) {
  final s = p.sub;
  // A yearly repeat firing in February is one day off in leap years, so it
  // must not claim an exact lead time.
  if (p.repeat == NotificationRepeat.yearly && p.at.month == 2) {
    return '${s.name}の請求日が近づいています（${yen(s.amountYen)}）';
  }
  final when = switch (s.notifyDaysBefore) {
    0 => '今日',
    1 => '明日',
    final days => '$days日後',
  };
  return '${s.name}の請求日は$whenです（${yen(s.amountYen)}）';
}
