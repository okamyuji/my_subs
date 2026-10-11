import 'dart:math';

import 'subscription.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Always clamp from the first billing day so 1/31 -> 2/28 -> 3/31, not 3/28.
DateTime billingDate(Subscription s, int k) {
  final first = s.firstBillingDate;
  final monthIndex = first.month - 1 + k * s.intervalMonths;
  final year = first.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, min(first.day, lastDay));
}

Iterable<DateTime> upcomingBillingDates(Subscription s, DateTime today) sync* {
  final t = dateOnly(today);
  var k = 0;
  while (billingDate(s, k).isBefore(t)) {
    k++;
  }
  while (true) {
    yield billingDate(s, k++);
  }
}

DateTime nextBillingDate(Subscription s, DateTime today) =>
    upcomingBillingDates(s, today).first;

bool isStarted(Subscription s, DateTime today) =>
    !s.firstBillingDate.isAfter(dateOnly(today));

List<DateTime> billingDatesInMonth(Subscription s, int year, int month) {
  final monthEnd = DateTime(year, month + 1, 0);
  final dates = <DateTime>[];
  for (var k = 0; ; k++) {
    final d = billingDate(s, k);
    if (d.isAfter(monthEnd)) return dates;
    if (d.year == year && d.month == month) dates.add(d);
  }
}

int thisMonthTotal(List<Subscription> subs, DateTime today) => subs.fold(
  0,
  (sum, s) =>
      sum +
      s.amountYen * billingDatesInMonth(s, today.year, today.month).length,
);

double monthlyTotal(List<Subscription> subs, DateTime today) => subs
    .where((s) => isStarted(s, today))
    .fold(0.0, (sum, s) => sum + s.amountYen / s.intervalMonths);

List<(Category, double)> categoryTotals(
  List<Subscription> subs,
  DateTime today,
) {
  final totals = <Category, double>{};
  for (final s in subs.where((s) => isStarted(s, today))) {
    totals[s.category] =
        (totals[s.category] ?? 0) + s.amountYen / s.intervalMonths;
  }
  // List.sort is not guaranteed stable, so break ties by enum order.
  return [for (final e in totals.entries) (e.key, e.value)]..sort((a, b) {
    final byValue = b.$2.compareTo(a.$2);
    return byValue != 0 ? byValue : a.$1.index.compareTo(b.$1.index);
  });
}

Map<int, List<Subscription>> billingsByDay(
  List<Subscription> subs,
  int year,
  int month,
) {
  final byDay = <int, List<Subscription>>{};
  for (final s in subs) {
    for (final d in billingDatesInMonth(s, year, month)) {
      (byDay[d.day] ??= []).add(s);
    }
  }
  return byDay;
}

String yen(num value) =>
    '¥${value.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
