import 'package:flutter_test/flutter_test.dart';
import 'package:my_subs/notification_plan.dart';
import 'package:my_subs/subscription.dart';

Subscription sub(String id, DateTime first, int? days, {int interval = 1}) =>
    Subscription(
      id: id,
      name: id,
      category: Category.other,
      amountYen: 1200,
      intervalMonths: interval,
      firstBillingDate: first,
      notifyDaysBefore: days,
    );

void main() {
  final now = DateTime(2026, 10, 11, 12);

  test('monthly billing on day 1-28 repeats monthly from the next fire', () {
    final plans = planNotifications([
      sub('a', DateTime(2026, 1, 20), 1),
    ], now).plans;
    expect(plans, hasLength(1));
    expect(plans.single.repeat, NotificationRepeat.monthly);
    expect(plans.single.at, DateTime(2026, 10, 19, 9));
  });

  test('monthly next fire skips a time already past today', () {
    final plans = planNotifications([
      sub('a', DateTime(2026, 1, 12), 1),
    ], now).plans;
    expect(plans.single.at, DateTime(2026, 11, 11, 9));
  });

  test('month-end monthly billing becomes 12 yearly repeats', () {
    final plans = planNotifications([
      sub('a', DateTime(2026, 1, 31), 1),
    ], now).plans;
    expect(plans, hasLength(12));
    expect(plans.every((p) => p.repeat == NotificationRepeat.yearly), isTrue);
    expect(plans.map((p) => p.at).take(5), [
      DateTime(2026, 10, 30, 9),
      DateTime(2026, 11, 29, 9),
      DateTime(2026, 12, 30, 9),
      DateTime(2027, 1, 30, 9),
      DateTime(2027, 2, 27, 9),
    ]);
  });

  test('a lead time crossing into the previous month uses yearly repeats', () {
    final plans = planNotifications([
      sub('a', DateTime(2026, 1, 1), 1),
    ], now).plans;
    expect(plans, hasLength(12));
    expect(plans.first.at, DateTime(2026, 10, 31, 9));
  });

  test('quarterly, half-yearly and yearly repeat once per billing month', () {
    int count(int interval) => planNotifications([
      sub('a', DateTime(2026, 1, 15), 0, interval: interval),
    ], now).plans.length;
    expect([count(3), count(6), count(12)], [4, 2, 1]);
  });

  test('a yearly repeat on Feb 29 moves to Feb 28', () {
    final plans = planNotifications([
      sub('a', DateTime(2024, 2, 29), 0, interval: 12),
    ], DateTime(2027, 3, 1)).plans;
    expect(plans.single.at, DateTime(2028, 2, 28, 9));
  });

  test('future start schedules three one-shot notifications', () {
    final plans = planNotifications([
      sub('a', DateTime(2026, 12, 5), 1),
    ], now).plans;
    expect(plans.map((p) => p.repeat).toSet(), {NotificationRepeat.none});
    expect(plans.map((p) => p.at), [
      DateTime(2026, 12, 4, 9),
      DateTime(2027, 1, 4, 9),
      DateTime(2027, 2, 4, 9),
    ]);
  });

  test('ignores subscriptions without notification', () {
    final result = planNotifications([
      sub('a', DateTime(2026, 1, 20), null),
    ], now);
    expect(result.plans, isEmpty);
    expect(result.overLimit, isFalse);
  });

  test('sorts by first fire and caps at 60', () {
    final subs = [
      for (var i = 0; i < 6; i++) sub('s$i', DateTime(2026, 1, 31), i % 3),
    ];
    final result = planNotifications(subs, now);
    expect(result.plans, hasLength(notificationCap));
    expect(result.overLimit, isTrue);
    for (var i = 1; i < result.plans.length; i++) {
      expect(result.plans[i].at.isBefore(result.plans[i - 1].at), isFalse);
    }
  });

  test('body names the service, lead time and amount', () {
    expect(
      notificationBody(sub('Video', DateTime(2026, 1, 20), 1)),
      'Videoの請求日は明日です（¥1,200）',
    );
    expect(
      notificationBody(sub('Video', DateTime(2026, 1, 20), 0)),
      'Videoの請求日は今日です（¥1,200）',
    );
    expect(
      notificationBody(sub('Video', DateTime(2026, 1, 20), 3)),
      'Videoの請求日は3日後です（¥1,200）',
    );
  });
}
