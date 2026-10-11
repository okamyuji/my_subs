import 'package:flutter_test/flutter_test.dart';
import 'package:my_subs/subscription.dart';

void main() {
  final sub = Subscription(
    id: '1',
    name: 'Video',
    category: Category.video,
    amountYen: 990,
    intervalMonths: 1,
    firstBillingDate: DateTime(2026, 1, 31),
    notifyDaysBefore: 1,
    memo: 'm',
  );

  test('round-trips through JSON', () {
    final back = Subscription.fromJson(sub.toJson());
    expect(back.toJson(), sub.toJson());
    expect(back.firstBillingDate, DateTime(2026, 1, 31));
  });

  test('keeps null notifyDaysBefore', () {
    final s = Subscription.fromJson({
      ...sub.toJson(),
      'notifyDaysBefore': null,
    });
    expect(s.notifyDaysBefore, isNull);
  });

  test('defaults missing memo to empty', () {
    final json = sub.toJson()..remove('memo');
    expect(Subscription.fromJson(json).memo, '');
  });

  test('stores the date without time', () {
    expect(sub.toJson()['firstBillingDate'], '2026-01-31');
  });

  test('throws on unknown category', () {
    expect(
      () => Subscription.fromJson({...sub.toJson(), 'category': 'x'}),
      throwsArgumentError,
    );
  });

  test('rejects values outside the allowed choices', () {
    for (final bad in [
      {'intervalMonths': 0},
      {'intervalMonths': 2},
      {'amountYen': 0},
      {'notifyDaysBefore': 2},
    ]) {
      expect(
        () => Subscription.fromJson({...sub.toJson(), ...bad}),
        throwsFormatException,
        reason: '$bad',
      );
    }
  });

  test('labels', () {
    expect(intervalLabel(1), '毎月');
    expect(intervalLabel(3), '3か月ごと');
    expect(intervalLabel(6), '半年ごと');
    expect(intervalLabel(12), '毎年');
    expect(notifyLabel(null), 'なし');
    expect(notifyLabel(0), '当日');
    expect(notifyLabel(3), '3日前');
    expect(Category.news.label, 'ニュース・書籍');
  });
}
