import 'package:flutter/material.dart';

import '../billing.dart';
import '../store.dart';
import '../subscription.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.store, required this.today});

  final SubscriptionStore store;
  final DateTime today;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late var _month = DateTime(widget.today.year, widget.today.month);
  int? _selected;

  void _move(int delta) => setState(() {
    _month = DateTime(_month.year, _month.month + delta);
    _selected = null;
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('請求カレンダー')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final byDay = billingsByDay(
            widget.store.items,
            _month.year,
            _month.month,
          );
          // DateTime.weekday is 1 (Mon) .. 7 (Sun); the grid starts on Sunday.
          final leading = DateTime(_month.year, _month.month, 1).weekday % 7;
          final days = DateTime(_month.year, _month.month + 1, 0).day;
          return ListView(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    key: const Key('prev'),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: '前の月',
                    onPressed: () => _move(-1),
                  ),
                  Text(
                    '${_month.year}年${_month.month}月',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    key: const Key('next'),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: '次の月',
                    onPressed: () => _move(1),
                  ),
                ],
              ),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final w in const ['日', '月', '火', '水', '木', '金', '土'])
                    Center(child: Text(w)),
                  for (var i = 0; i < leading; i++) const SizedBox.shrink(),
                  for (var d = 1; d <= days; d++)
                    InkWell(
                      key: Key('day-$d'),
                      onTap: () => setState(() => _selected = d),
                      child: Container(
                        decoration: d == _selected
                            ? BoxDecoration(
                                color: scheme.primaryContainer,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$d'),
                            if (byDay.containsKey(d))
                              Container(
                                key: Key('dot-$d'),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(),
              for (final s in byDay[_selected] ?? const <Subscription>[])
                ListTile(title: Text(s.name), trailing: Text(yen(s.amountYen))),
            ],
          );
        },
      ),
    );
  }
}
