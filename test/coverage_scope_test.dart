import 'package:flutter_test/flutter_test.dart';
// Imported so lcov counts main.dart; files no test imports are invisible to
// the coverage gate.
import 'package:my_subs/main.dart' as app;

void main() {
  test('entry point is defined', () => expect(app.main, isA<Function>()));
}
