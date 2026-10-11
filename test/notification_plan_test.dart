import 'package:flutter_test/flutter_test.dart';
import 'package:my_subs/notification_plan.dart';
import 'package:my_subs/subscription.dart';

Subscription sub(String id, DateTime first, int? days) => Subscription(
  id: id,
  name: id,
  category: Category.other,
  amountYen: 1200,
  intervalMonths: 1,
  firstBillingDate: first,
  notifyDaysBefore: days,
);

void main() {
  final now = DateTime(2026, 10, 11, 12);

  test('plans next three billings at 9:00 N days before', () {
    final plans = planNotifications([sub('a', DateTime(2026, 1, 20), 1)], now);
    expect(plans.map((p) => p.at), [
      DateTime(2026, 10, 19, 9),
      DateTime(2026, 11, 19, 9),
      DateTime(2026, 12, 19, 9),
    ]);
    expect(plans.first.billingDate, DateTime(2026, 10, 20));
  });

  test('skips times already past', () {
    // Billing 10/12 with a 1-day lead fires 10/11 9:00, before now (12:00).
    final plans = planNotifications([sub('a', DateTime(2026, 1, 12), 1)], now);
    expect(plans.first.at, DateTime(2026, 11, 11, 9));
    expect(plans, hasLength(2));
  });

  test('keeps a time later today', () {
    final early = DateTime(2026, 10, 11, 8);
    final plans = planNotifications([
      sub('a', DateTime(2026, 1, 11), 0),
    ], early);
    expect(plans.first.at, DateTime(2026, 10, 11, 9));
  });

  test('ignores subscriptions without notification', () {
    expect(
      planNotifications([sub('a', DateTime(2026, 1, 20), null)], now),
      isEmpty,
    );
  });

  test('caps at 60 sorted by time', () {
    final subs = [
      for (var i = 0; i < 30; i++) sub('s$i', DateTime(2026, 1, 1 + i % 28), 0),
    ];
    final plans = planNotifications(subs, now);
    expect(plans, hasLength(60));
    for (var i = 1; i < plans.length; i++) {
      expect(plans[i].at.isBefore(plans[i - 1].at), isFalse);
    }
    expect(plans.last.at.isBefore(DateTime(2027, 1, 1)), isTrue);
  });

  test('body names the service, date and amount', () {
    final p = planNotifications([
      sub('Video', DateTime(2026, 1, 20), 1),
    ], now).first;
    expect(notificationBody(p), 'Videoの請求日です（10/20、¥1,200）');
  });
}
