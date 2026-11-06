import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 1);

Future<void> _pump(WidgetTester t, Widget child) {
  t.view.physicalSize = const Size(800, 600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  return t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

Rect _at(WidgetTester t, Key k) => t.getRect(find.byKey(k));

void main() {
  const top = Key('top'), grid = Key('grid'), under = Key('under'), next = Key('next');

  testWidgets('captions go over and under the table box, as wide as it, in the order they came', (tester) async {
    await _pump(
      tester,
      TableCaptions(
        above: const [SizedBox(key: top, height: 10)],
        table: const SizedBox(key: grid, width: 100, height: 40),
        below: const [
          SizedBox(key: under, height: 6),
          SizedBox(key: next, height: 4),
        ],
      ),
    );
    expect(_at(tester, top), const Rect.fromLTWH(0, 0, 100, 10));
    expect(_at(tester, grid), const Rect.fromLTWH(0, 10, 100, 40));
    expect(_at(tester, under), const Rect.fromLTWH(0, 50, 100, 6));
    expect(_at(tester, next), const Rect.fromLTWH(0, 56, 100, 4));
    expect(tester.getSize(find.byType(TableCaptions)), const Size(100, 60));
  });

  testWidgets('a caption widens the table to its min-content, and its max-content widens nothing', (tester) async {
    // Shrink-to-fit: 'aaaa bbbb' is 90 at max-content and 40 at min: it
    // wraps at the table's 60.
    await _pump(
      tester,
      IntrinsicWidth(
        child: TableCaptions(
          above: const [Text('aaaa bbbb', key: top, style: _style)],
          table: const SizedBox(key: grid, width: 60, height: 20),
        ),
      ),
    );
    expect(_at(tester, top), const Rect.fromLTWH(0, 0, 60, 20));
    expect(_at(tester, grid), const Rect.fromLTWH(0, 20, 60, 20));
    // 'aaaaaaaaaa' cannot break: the table box fills the 100 it asks.
    for (final shrink in [true, false]) {
      final captioned = TableCaptions(
        below: const [Text('aaaaaaaaaa bb', key: under, style: _style)],
        table: const SizedBox(key: grid, width: 60, height: 20),
      );
      await _pump(tester, shrink ? IntrinsicWidth(child: captioned) : captioned);
      expect(_at(tester, grid), const Rect.fromLTWH(0, 0, 100, 20), reason: 'shrink $shrink');
      expect(_at(tester, under), const Rect.fromLTWH(0, 20, 100, 20), reason: 'shrink $shrink');
    }
  });

  testWidgets('the baseline is the table box\'s, where the captions over it put it', (tester) async {
    await _pump(
      tester,
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text('x', key: next, style: _style),
          TableCaptions(
            above: const [SizedBox(height: 30)],
            table: const Text('grid', key: grid, style: _style),
          ),
        ],
      ),
    );
    // The row stands both on the table's baseline, 30 down: the word
    // beside it comes down as far as the captions put the grid.
    expect(_at(tester, grid).top, 30);
    expect(_at(tester, next).top, 30);
  });
}
