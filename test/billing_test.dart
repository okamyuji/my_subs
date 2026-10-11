import 'package:flutter_test/flutter_test.dart';
import 'package:my_subs/billing.dart';
import 'package:my_subs/subscription.dart';

Subscription sub(
  DateTime first, {
  int amount = 1000,
  int interval = 1,
  Category cat = Category.other,
  String id = 'x',
}) => Subscription(
  id: id,
  name: id,
  category: cat,
  amountYen: amount,
  intervalMonths: interval,
  firstBillingDate: first,
);

void main() {
  group('billingDate', () {
    test('clamps the 31st to month end', () {
      final s = sub(DateTime(2026, 1, 31));
      expect(billingDate(s, 1), DateTime(2026, 2, 28));
      expect(billingDate(s, 3), DateTime(2026, 4, 30));
    });
    test('does not carry clamping', () {
      expect(billingDate(sub(DateTime(2026, 1, 31)), 2), DateTime(2026, 3, 31));
    });
    test('uses Feb 29 in leap years', () {
      expect(billingDate(sub(DateTime(2028, 1, 30)), 1), DateTime(2028, 2, 29));
    });
    test('crosses the year with 12-month interval', () {
      expect(
        billingDate(sub(DateTime(2025, 11, 15), interval: 12), 1),
        DateTime(2026, 11, 15),
      );
    });
    test('crosses December with 3-month interval', () {
      expect(
        billingDate(sub(DateTime(2025, 11, 15), interval: 3), 1),
        DateTime(2026, 2, 15),
      );
    });
  });

  group('next billing', () {
    final s = sub(DateTime(2026, 1, 10));
    test('includes today', () {
      expect(
        nextBillingDate(s, DateTime(2026, 3, 10, 23, 59)),
        DateTime(2026, 3, 10),
      );
    });
    test('moves past today', () {
      expect(nextBillingDate(s, DateTime(2026, 3, 11)), DateTime(2026, 4, 10));
    });
    test('is the first date for a future start', () {
      expect(
        nextBillingDate(sub(DateTime(2026, 12, 1)), DateTime(2026, 3, 11)),
        DateTime(2026, 12, 1),
      );
    });
    test('upcoming yields in order', () {
      expect(upcomingBillingDates(s, DateTime(2026, 3, 11)).take(2).toList(), [
        DateTime(2026, 4, 10),
        DateTime(2026, 5, 10),
      ]);
    });
  });

  group('totals', () {
    final today = DateTime(2026, 10, 11);
    final monthly = sub(
      DateTime(2026, 1, 5),
      amount: 1000,
      cat: Category.video,
      id: 'm',
    );
    final yearly = sub(
      DateTime(2025, 6, 1),
      amount: 12000,
      interval: 12,
      cat: Category.cloud,
      id: 'y',
    );
    final futureThisMonth = sub(
      DateTime(2026, 10, 25),
      amount: 500,
      cat: Category.video,
      id: 'f1',
    );
    final futureNextMonth = sub(DateTime(2026, 11, 1), amount: 700, id: 'f2');
    final all = [monthly, yearly, futureThisMonth, futureNextMonth];

    test('this month counts actual billings including a first billing', () {
      expect(thisMonthTotal(all, today), 1000 + 500);
    });
    test('this month is zero with no billings', () {
      expect(thisMonthTotal([yearly], today), 0);
    });
    test('future start: monthly total excludes not-started items', () {
      expect(monthlyTotal(all, today), 1000 + 1000);
    });
    test('isStarted is inclusive of today', () {
      expect(
        isStarted(sub(DateTime(2026, 10, 11)), DateTime(2026, 10, 11, 8)),
        isTrue,
      );
      expect(isStarted(sub(DateTime(2026, 10, 12)), today), isFalse);
    });
    test('category totals are sorted descending and skip not-started', () {
      final big = sub(
        DateTime(2026, 1, 1),
        amount: 3000,
        cat: Category.music,
        id: 'b',
      );
      expect(categoryTotals([...all, big], today), [
        (Category.music, 3000.0),
        (Category.video, 1000.0),
        (Category.cloud, 1000.0),
      ]);
    });
    test('billingsByDay groups by day of month', () {
      final byDay = billingsByDay(all, 2026, 10);
      expect(byDay.keys.toSet(), {5, 25});
      expect(byDay[25]!.single.id, 'f1');
    });
    test('billingDatesInMonth is empty before the first billing', () {
      expect(billingDatesInMonth(futureNextMonth, 2026, 10), isEmpty);
    });
  });

  test('yen formats with separators and rounds', () {
    expect(yen(0), '¥0');
    expect(yen(999), '¥999');
    expect(yen(1000), '¥1,000');
    expect(yen(1234567), '¥1,234,567');
    expect(yen(83.5), '¥84');
  });
}
