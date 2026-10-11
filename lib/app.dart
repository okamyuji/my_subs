import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
    required this.notificationsOverLimit,
    this.clock = DateTime.now,
    this.onResume,
  });

  final SubscriptionStore store;
  final List<Preset> presets;
  final ValueListenable<bool?> notificationsEnabled;
  final ValueListenable<bool> notificationsOverLimit;
  final DateTime Function() clock;

  /// Called when the app returns to the foreground, e.g. to reschedule.
  final Future<void> Function()? onResume;

  @override
  State<MySubsApp> createState() => _MySubsAppState();
}

class _MySubsAppState extends State<MySubsApp> {
  var _tab = 0;

  // `today` is read in build, so a resume after midnight must rebuild; a
  // future start also becomes a calendar repeat only on the next reschedule.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        setState(() {});
        widget.onResume?.call();
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.clock();
    final screens = [
      ListScreen(
        store: widget.store,
        presets: widget.presets,
        today: today,
        notificationsEnabled: widget.notificationsEnabled,
        notificationsOverLimit: widget.notificationsOverLimit,
      ),
      CalendarScreen(store: widget.store, today: today),
      AnalysisScreen(store: widget.store, today: today),
    ];
    return MaterialApp(
      title: 'my_subs',
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
