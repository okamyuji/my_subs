import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_subs/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('add, view, edit and delete a subscription', (tester) async {
    await SharedPreferencesAsync().clear();
    await app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name')), 'E2E動画');
    await tester.enterText(find.byKey(const Key('amount')), '1200');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('E2E動画'), findsOneWidget);
    // This month, monthly equivalent and the row itself.
    expect(find.text('¥1,200'), findsNWidgets(3));
    expect(find.text('¥14,400'), findsOneWidget);

    await tester.tap(find.text('カレンダー'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('dot-${DateTime.now().day}')), findsOneWidget);

    await tester.tap(find.text('分析'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.tap(find.text('一覧'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('E2E動画'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '1500');
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('¥1,500'), findsNWidgets(3));
    expect(find.text('¥18,000'), findsOneWidget);

    await tester.tap(find.text('E2E動画'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();
    expect(find.text('E2E動画'), findsNothing);
  });
}
