import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'presets.dart';
import 'screens/analysis_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/list_screen.dart';
import 'store.dart';

class MySubsApp extends StatefulWidget {
  const MySubsApp({
    super.key,
    required this.store,
    required this.presets,
    required this.notificationsEnabled,
    this.clock = DateTime.now,
  });

  final SubscriptionStore store;
  final List<Preset> presets;
  final ValueListenable<bool?> notificationsEnabled;
  final DateTime Function() clock;

  @override
  State<MySubsApp> createState() => _MySubsAppState();
}

class _MySubsAppState extends State<MySubsApp> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final today = widget.clock();
    final screens = [
      ListScreen(
        store: widget.store,
        presets: widget.presets,
        today: today,
        notificationsEnabled: widget.notificationsEnabled,
      ),
      CalendarScreen(store: widget.store, today: today),
      AnalysisScreen(store: widget.store, today: today),
    ];
    return MaterialApp(
      title: 'my_subs',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: Scaffold(
        body: screens[_tab],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.list), label: '一覧'),
            NavigationDestination(
              icon: Icon(Icons.calendar_month),
              label: 'カレンダー',
            ),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: '分析'),
          ],
        ),
      ),
    );
  }
}
