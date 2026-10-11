import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_subs/store.dart';
import 'package:my_subs/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Subscription sub(String id, {int amount = 100}) => Subscription(
  id: id,
  name: id,
  category: Category.other,
  amountYen: amount,
  intervalMonths: 1,
  firstBillingDate: DateTime(2026, 1, 1),
);

String _json(Map<String, Object?> m) => jsonEncode(m);

void main() {
  late SharedPreferencesAsync prefs;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  test('starts empty and persists upserts across instances', () async {
    final store = SubscriptionStore(prefs);
    await store.load();
    expect(store.items, isEmpty);
    await store.upsert(sub('a'));
    await store.upsert(sub('a', amount: 200));
    final reloaded = SubscriptionStore(prefs);
    await reloaded.load();
    expect(reloaded.items.single.amountYen, 200);
    expect(reloaded.recoveredFromCorruption, isFalse);
  });

  test('delete removes the item and notifies', () async {
    var notified = 0;
    final changed = <int>[];
    final store = SubscriptionStore(
      prefs,
      onChanged: (items) async => changed.add(items.length),
    )..addListener(() => notified++);
    await store.load();
    await store.upsert(sub('a'));
    await store.delete('a');
    expect(store.items, isEmpty);
    expect(notified, 3);
    expect(changed, [0, 1, 0]);
  });

  test('backs up corrupt data and starts empty', () async {
    await prefs.setString(SubscriptionStore.key, '{not json');
    final store = SubscriptionStore(prefs);
    await store.load();
    expect(store.items, isEmpty);
    expect(store.recoveredFromCorruption, isTrue);
    expect(await prefs.getString(SubscriptionStore.corruptKey), '{not json');
    expect(await prefs.getString(SubscriptionStore.key), isNull);
  });

  test('treats out-of-range values as corrupt', () async {
    final bad = {...sub('a').toJson(), 'intervalMonths': 0};
    await prefs.setString(SubscriptionStore.key, '[${_json(bad)}]');
    final store = SubscriptionStore(prefs);
    await store.load();
    expect(store.recoveredFromCorruption, isTrue);
    expect(store.items, isEmpty);
  });

  test('keeps an earlier corrupt backup', () async {
    await prefs.setString(SubscriptionStore.key, 'first');
    await SubscriptionStore(prefs).load();
    await prefs.setString(SubscriptionStore.key, 'second');
    await SubscriptionStore(prefs).load();
    final backups = <String?>[
      for (final k in await prefs.getKeys())
        if (k.startsWith(SubscriptionStore.corruptKey))
          await prefs.getString(k),
    ];
    expect(backups, unorderedEquals(['first', 'second']));
  });

  test('treats wrong shape as corrupt', () async {
    await prefs.setString(SubscriptionStore.key, '[{"id":1}]');
    final store = SubscriptionStore(prefs);
    await store.load();
    expect(store.recoveredFromCorruption, isTrue);
  });
}
