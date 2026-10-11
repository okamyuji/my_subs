import 'package:flutter_test/flutter_test.dart';

import '../tool/check_coverage.dart';

void main() {
  test('sums LF and LH across files', () {
    final lines = [
      'SF:a.dart',
      'LF:10',
      'LH:7',
      'end_of_record',
      'SF:b.dart',
      'LF:5',
      'LH:5',
      'end_of_record',
    ];
    expect(lcovTotals(lines), (15, 12));
  });

  test('returns zeros for empty input', () {
    expect(lcovTotals([]), (0, 0));
  });
}
