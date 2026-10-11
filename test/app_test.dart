import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_subs/app.dart';
import 'package:my_subs/presets.dart';
import 'package:my_subs/store.dart';
import 'package:my_subs/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final today = DateTime(2026, 10, 11);

Future<SubscriptionStore> pumpApp(
  WidgetTester tester, {
  List<Subscription> initial = const [],
  bool? notifications = true,
  bool overLimit = false,
  List<Preset> presets = const [],
  String? savedRaw,
  DateTime Function()? clock,
  Future<void> Function()? onResume,
  Future<void> Function(List<Subscription>)? onChanged,
  Size size = const Size(1080, 2400),
}) async {
  // Phone-sized surface (Pixel 8); the default 800x600 pushes the calendar's
  // day list below the fold.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  if (savedRaw != null) {
    await SharedPreferencesAsync().setString(SubscriptionStore.key, savedRaw);
  }
  final store = SubscriptionStore(
    SharedPreferencesAsync(),
    onChanged: onChanged,
  );
  await store.load();
  for (final s in initial) {
    await store.upsert(s);
  }
  await tester.pumpWidget(
    MySubsApp(
      store: store,
      presets: presets,
      notificationsEnabled: ValueNotifier(notifications),
      notificationsOverLimit: ValueNotifier(overLimit),
      clock: clock ?? () => today,
      onResume: onResume,
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Subscription sub(
  String name,
  int amount,
  DateTime first, {
  Category cat = Category.video,
}) => Subscription(
  id: name,
  name: name,
  category: cat,
  amountYen: amount,
  intervalMonths: 1,
  firstBillingDate: first,
);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

void main() {
  testWidgets('add form validates and saves', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('名前を入力してください'), findsOneWidget);
    expect(find.text('1以上の整数を入力してください'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('name')), 'Music');
    await tester.enterText(find.byKey(const Key('amount')), '0');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('1以上の整数を入力してください'), findsOneWidget);
    expect(store.items, isEmpty);

    await tester.enterText(find.byKey(const Key('amount')), '980');
    await tester.tap(find.text('音楽'));
    await tester.tap(find.text('毎年'));
    await tester.tap(find.text('3日前'));
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    final s = store.items.single;
    expect(
      (s.name, s.amountYen, s.category, s.intervalMonths, s.notifyDaysBefore),
      ('Music', 980, Category.music, 12, 3),
    );
    expect(sameDay(s.firstBillingDate, today), isTrue);
    expect(find.text('Music'), findsOneWidget);
  });

  testWidgets('date picker uses Japanese and updates the first billing date', (
    tester,
  ) async {
    final store = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('初回請求日'));
    await tester.pumpAndSettle();
    expect(find.text('キャンセル'), findsOneWidget);
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('2026/10/20'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('name')), 'X');
    await tester.enterText(find.byKey(const Key('amount')), '1');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(store.items.single.firstBillingDate, DateTime(2026, 10, 20));
  });

  testWidgets('a double tap on save adds one item and stays on the list', (
    tester,
  ) async {
    final store = await pumpApp(
      tester,
      onChanged: (items) => items.isEmpty
          ? Future.value()
          : Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.tap(find.byKey(const Key('add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'Twice');
    await tester.enterText(find.byKey(const Key('amount')), '500');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.byKey(const Key('save')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));
    expect(find.byKey(const Key('add')), findsOneWidget);
  });

  testWidgets('rejects a blank name and caps the amount at 9 digits', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), '   ');
    await tester.enterText(find.byKey(const Key('amount')), '1234567890');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('名前を入力してください'), findsOneWidget);
    expect(find.text('123456789'), findsOneWidget);
  });

  testWidgets('totals fit a 320dp screen at 200% text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(
      tester,
      size: const Size(840, 1680),
      initial: [sub('Big', 999999999, DateTime(2026, 1, 5))],
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('カレンダー'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('preset chip fills name, category and interval', (tester) async {
    final store = await pumpApp(
      tester,
      presets: const [
        Preset(name: 'Cloud X', category: Category.cloud, intervalMonths: 12),
      ],
    );
    await tester.tap(find.byKey(const Key('add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preset-Cloud X')));
    await tester.enterText(find.byKey(const Key('amount')), '1300');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    final s = store.items.single;
    expect(
      (s.name, s.category, s.intervalMonths),
      ('Cloud X', Category.cloud, 12),
    );
  });

  testWidgets('list shows totals, future start label and banner', (
    tester,
  ) async {
    await pumpApp(
      tester,
      notifications: false,
      initial: [
        sub('A', 1000, DateTime(2026, 1, 5)),
        sub('B', 500, DateTime(2026, 10, 25)),
      ],
    );
    expect(find.text('通知が無効です'), findsOneWidget);
    expect(find.text('¥1,500'), findsOneWidget);
    expect(find.text('¥12,000'), findsOneWidget);
    expect(find.textContaining('10/25開始予定'), findsOneWidget);
    expect(find.textContaining('次回 11/5'), findsOneWidget);
  });

  testWidgets('no banner while permission is unanswered', (tester) async {
    await pumpApp(tester, notifications: null);
    expect(find.text('通知が無効です'), findsNothing);
    expect(find.textContaining('通知の上限'), findsNothing);
  });

  testWidgets('refreshes today and reschedules when the app resumes', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 31, 23, 59);
    var resumed = 0;
    await pumpApp(
      tester,
      initial: [sub('A', 1000, DateTime(2026, 1, 31))],
      clock: () => now,
      onResume: () async => resumed++,
    );
    expect(find.textContaining('次回 10/31'), findsOneWidget);
    now = DateTime(2026, 11, 1, 0, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.textContaining('次回 11/30'), findsOneWidget);
    expect(resumed, 1);
  });

  testWidgets('tells the user when saved data was unreadable', (tester) async {
    await pumpApp(tester, savedRaw: '{broken');
    expect(find.textContaining('保存データを読めなかったため退避'), findsOneWidget);
  });

  testWidgets('warns when notifications exceed the limit', (tester) async {
    await pumpApp(tester, overLimit: true);
    expect(find.textContaining('通知の上限（60件）'), findsOneWidget);
  });

  testWidgets('edit and delete with confirmation', (tester) async {
    final store = await pumpApp(
      tester,
      initial: [sub('A', 1000, DateTime(2026, 1, 5))],
    );
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '1100');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(store.items.single.amountYen, 1100);
    expect(store.items.single.id, 'A');

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(store.items, hasLength(1));
    await tester.tap(find.byKey(const Key('delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(store.items, isEmpty);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('calendar marks billing days and moves months', (tester) async {
    await pumpApp(tester, initial: [sub('A', 1000, DateTime(2026, 1, 31))]);
    await tester.tap(find.text('カレンダー'));
    await tester.pumpAndSettle();
    expect(find.text('2026年10月'), findsOneWidget);
    expect(find.byKey(const Key('dot-31')), findsOneWidget);
    expect(find.byKey(const Key('dot-30')), findsNothing);
    await tester.tap(find.byKey(const Key('day-31')));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    await tester.tap(find.byKey(const Key('next')));
    await tester.pumpAndSettle();
    expect(find.text('2026年11月'), findsOneWidget);
    expect(find.byKey(const Key('dot-30')), findsOneWidget);
    expect(find.text('A'), findsNothing);
    await tester.tap(find.byKey(const Key('prev')));
    await tester.tap(find.byKey(const Key('prev')));
    await tester.pumpAndSettle();
    expect(find.text('2026年9月'), findsOneWidget);
  });

  testWidgets('analysis shows bars per category', (tester) async {
    await pumpApp(
      tester,
      initial: [
        sub('A', 3000, DateTime(2026, 1, 5), cat: Category.music),
        sub('B', 1000, DateTime(2026, 1, 5)),
      ],
    );
    await tester.tap(find.text('分析'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    expect(find.text('音楽'), findsOneWidget);
    expect(find.text('¥3,000（75%）'), findsOneWidget);
    expect(find.text('¥1,000（25%）'), findsOneWidget);
  });

  testWidgets('analysis empty state', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('分析'));
    await tester.pumpAndSettle();
    expect(find.text('登録がありません'), findsOneWidget);
  });
}
