import 'billing.dart';
import 'subscription.dart';

class PlannedNotification {
  const PlannedNotification({
    required this.at,
    required this.billingDate,
    required this.sub,
  });

  final DateTime at;
  final DateTime billingDate;
  final Subscription sub;
}

// cap stays under iOS's 64 pending-notification limit; iOS keeps only the
// 64 most recently scheduled and drops the rest without an error.
List<PlannedNotification> planNotifications(
  List<Subscription> subs,
  DateTime now, {
  int perSub = 3,
  int cap = 60,
}) {
  final plans = <PlannedNotification>[];
  for (final s in subs) {
    final days = s.notifyDaysBefore;
    if (days == null) continue;
    for (final d in upcomingBillingDates(s, now).take(perSub)) {
      final at = DateTime(d.year, d.month, d.day - days, 9);
      if (at.isAfter(now)) {
        plans.add(PlannedNotification(at: at, billingDate: d, sub: s));
      }
    }
  }
  plans.sort((a, b) => a.at.compareTo(b.at));
  return plans.take(cap).toList();
}

String notificationBody(PlannedNotification p) =>
    '${p.sub.name}の請求日です（${p.billingDate.month}/${p.billingDate.day}、${yen(p.sub.amountYen)}）';
