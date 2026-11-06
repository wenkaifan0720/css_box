// The README's Dart is real code: each ```dart block of ../README.md is in
// lib/snippets.dart (white space aside), which the analyzer checks and
// snippets_test.dart pumps.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _space = RegExp(r'\s');

String _squeezed(String s) => s.replaceAll(_space, '');

List<String> _dartBlocks(String markdown) => [
  for (final m in RegExp(
    r'```dart\n(.*?)```',
    dotAll: true,
  ).allMatches(markdown))
    m[1]!,
];

void main() {
  final readme = File('../README.md').readAsStringSync();
  final snippets = _squeezed(File('lib/snippets.dart').readAsStringSync());

  test('every Dart block of the README is in lib/snippets.dart', () {
    final blocks = _dartBlocks(readme);
    expect(blocks.length, greaterThanOrEqualTo(40));
    for (final block in blocks) {
      expect(snippets.contains(_squeezed(block)), isTrue, reason: block);
    }
  });

  test('NEGATIVE: a block that differs from its snippet is caught', () {
    final block = _dartBlocks(readme).first;
    expect(snippets.contains(_squeezed('$block;extra')), isFalse);
  });
}
