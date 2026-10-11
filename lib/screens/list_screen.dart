import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../billing.dart';
import '../calendar_sync.dart';
import '../notification_plan.dart';
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
    required this.notificationsOverLimit,
    this.calendar,
  });

  final SubscriptionStore store;
  final List<Preset> presets;
  final DateTime today;
  final ValueListenable<bool?> notificationsEnabled;
  final ValueListenable<bool> notificationsOverLimit;
  final CalendarSync? calendar;

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
      appBar: AppBar(
        title: const Text('サブスク'),
        actions: [
          if (calendar case final calendar?) _CalendarSwitch(calendar, store),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add'),
        onPressed: () => _open(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          store,
          notificationsEnabled,
          notificationsOverLimit,
          ?calendar?.failed,
        ]),
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
              if (notificationsOverLimit.value)
                const ListTile(
                  leading: Icon(Icons.notification_important),
                  title: Text('通知の上限（$notificationCap件）を超えたため、一部の通知を予約できていません'),
                ),
              if (calendar?.failed.value ?? false)
                const ListTile(
                  leading: Icon(Icons.event_busy),
                  title: Text('カレンダーに登録できませんでした'),
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
      Expanded(child: Text(label)),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    ],
  );
}

class _CalendarSwitch extends StatelessWidget {
  const _CalendarSwitch(this.calendar, this.store);

  final CalendarSync calendar;
  final SubscriptionStore store;

  Future<void> _toggle(BuildContext context, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await calendar.setEnabled(on, store.items)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('カレンダーへのアクセスが許可されていません')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: calendar.enabled,
    builder: (context, on, _) => Row(
      children: [
        const Text('カレンダー'),
        Semantics(
          label: 'カレンダーにも登録',
          child: Switch(
            key: const Key('calendarSync'),
            value: on,
            onChanged: (v) => _toggle(context, v),
          ),
        ),
      ],
    ),
  );
}
