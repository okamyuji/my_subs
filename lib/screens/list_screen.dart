import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../billing.dart';
import '../presets.dart';
import '../store.dart';
import '../subscription.dart';
import 'form_screen.dart';

class ListScreen extends StatelessWidget {
  const ListScreen({
    super.key,
    required this.store,
    required this.presets,
    required this.today,
    required this.notificationsEnabled,
  });

  final SubscriptionStore store;
  final List<Preset> presets;
  final DateTime today;
  final ValueListenable<bool?> notificationsEnabled;

  void _open(BuildContext context, Subscription? initial) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FormScreen(
            store: store,
            presets: presets,
            today: today,
            initial: initial,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('サブスク')),
      floatingActionButton: FloatingActionButton(
        key: const Key('add'),
        onPressed: () => _open(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, notificationsEnabled]),
        builder: (context, _) {
          final subs = [...store.items]
            ..sort(
              (a, b) => nextBillingDate(
                a,
                today,
              ).compareTo(nextBillingDate(b, today)),
            );
          final monthly = monthlyTotal(subs, today);
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (notificationsEnabled.value == false)
                const ListTile(
                  leading: Icon(Icons.notifications_off),
                  title: Text('通知が無効です'),
                ),
              if (store.recoveredFromCorruption)
                const ListTile(
                  leading: Icon(Icons.warning),
                  title: Text('保存データを読めなかったため退避し、空の状態で始めました'),
                ),
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _Total(
                        label: '今月の支払額',
                        value: yen(thisMonthTotal(subs, today)),
                      ),
                      _Total(label: '月額換算', value: yen(monthly)),
                      _Total(label: '年額換算', value: yen(monthly * 12)),
                    ],
                  ),
                ),
              ),
              for (final s in subs)
                ListTile(
                  title: Text(s.name),
                  subtitle: Text(
                    [
                      isStarted(s, today)
                          ? '次回 ${_md(nextBillingDate(s, today))}'
                          : '${_md(s.firstBillingDate)}開始予定',
                      s.category.label,
                      intervalLabel(s.intervalMonths),
                    ].join(' ・ '),
                  ),
                  trailing: Text(yen(s.amountYen)),
                  onTap: () => _open(context, s),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _md(DateTime d) => '${d.month}/${d.day}';

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label),
      Text(value, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}
