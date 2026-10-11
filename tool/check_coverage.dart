import 'dart:io';

(int, int) lcovTotals(List<String> lines) {
  var found = 0;
  var hit = 0;
  for (final line in lines) {
    if (line.startsWith('LF:')) found += int.parse(line.substring(3));
    if (line.startsWith('LH:')) hit += int.parse(line.substring(3));
  }
  return (found, hit);
}

void main(List<String> args) {
  final min = double.parse(args.isEmpty ? '80' : args.first);
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info がありません。flutter test --coverage を先に実行してください',
    );
    exit(1);
  }
  final (found, hit) = lcovTotals(file.readAsLinesSync());
  final pct = found == 0 ? 0.0 : hit * 100 / found;
  stdout.writeln(
    'line coverage: ${pct.toStringAsFixed(1)}% ($hit/$found), min $min%',
  );
  if (pct < min) exit(1);
}
