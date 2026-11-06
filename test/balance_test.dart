import 'package:css_box/css_box.dart';
import 'package:css_box/src/balance.dart' show RenderBalance;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A column that places its items across (`align-items: center`) hands
  // each a loose width: the test font's glyphs are 10 square at 10px.
  Widget page(String text, double room) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: room,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Balance(
              child: Text(text, key: const Key('t'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ),
    ),
  );

  group('a room under the longest run of a line box', () {
    // `cccc dddd` holds together, 90 wide in a room of 50, and hangs out of
    // it: the greedy lines are `aa bb` / `cccc dddd`, as Chrome's are.
    Widget narrow(Key key) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 50,
          child: Balance(
            key: key,
            child: const LineBox(keepWords: true, child: Text('aa bb cccc\u00A0dddd', style: TextStyle(fontSize: 10))),
          ),
        ),
      ),
    );

    testWidgets('keeps the greedy line count', (tester) async {
      const key = Key('b');
      await tester.pumpWidget(narrow(key));
      expect(tester.getSize(find.byKey(key)).height, 20);
      final p = tester.renderObject<RenderParagraph>(find.byType(RichText));
      expect(p.text.toPlainText(), isNot(contains('aa\n')));
    });

    testWidgets('answers the dry layout it lays out', (tester) async {
      const key = Key('b');
      await tester.pumpWidget(narrow(key));
      final box = tester.renderObject<RenderBox>(find.byKey(key));
      expect(box.getDryLayout(const BoxConstraints(maxWidth: 50)).height, box.size.height);
    });
  });

  group('a span written twice in a paragraph is two places', () {
    // A `<wbr>`'s zero-width space, as the lowering writes it: one const span,
    // twice, between the runs of `up-to-date`.
    const wbr = TextSpan(text: '\u200B', style: TextStyle(letterSpacing: 0));
    const source = TextSpan(
      children: [
        TextSpan(text: 'clear, up-'),
        wbr,
        TextSpan(text: 'to-'),
        wbr,
        TextSpan(text: 'date docs'),
      ],
    );
    final text = source.toPlainText();
    final opp = RenderBalance.opportunities(text);
    final atSecond = opp.indexWhere((o) => o.$1 == text.lastIndexOf('\u200B')) + 1;
    final atFirst = opp.indexWhere((o) => o.$1 == text.indexOf('\u200B')) + 1;

    test('a break at the second leaves the first where it stood', () {
      final broken = RenderBalance.brokenOn(source, opp, [opp.length, atSecond, 0]);
      expect(broken.toPlainText(), 'clear, up-\u200Bto-\n\u200Bdate docs');
    });

    test('a break at the first leaves the second where it stood', () {
      final broken = RenderBalance.brokenOn(source, opp, [opp.length, atFirst, 0]);
      expect(broken.toPlainText(), 'clear, up-\n\u200Bto-\u200Bdate docs');
    });

    test('every leaf keeps its style, an empty one is passed over', () {
      const twice = TextSpan(
        children: [
          TextSpan(text: ''),
          TextSpan(text: 'aa bb', style: TextStyle(fontSize: 11)),
          TextSpan(text: ' cc', style: TextStyle(fontSize: 12)),
        ],
      );
      final t = twice.toPlainText();
      final o = RenderBalance.opportunities(t);
      final broken = RenderBalance.brokenOn(twice, o, [o.length, 1, 0]);
      expect(broken.toPlainText(), 'aa\nbb cc');
      final kids = broken.children!.cast<TextSpan>();
      expect(kids.map((k) => k.text), ['', 'aa\nbb', ' cc']);
      expect(kids.map((k) => k.style?.fontSize), [null, 11, 12]);
    });

    testWidgets('a pretty paragraph takes the lines the greedy one does', (tester) async {
      // Greedy at 170, the test font 10 wide a glyph and the space between the
      // runs nothing: `aaaaaaaa up-to-date` / `zzz`, one short word last; the
      // re-break moves `date` down and the line count stays.
      const words = TextSpan(
        children: [
          TextSpan(text: 'aaaaaaaa up-'),
          wbr,
          TextSpan(text: 'to-'),
          wbr,
          TextSpan(text: 'dt zzz'),
        ],
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              child: Pretty(
                child: Text.rich(words, key: Key('t'), style: TextStyle(fontSize: 10)),
              ),
            ),
          ),
        ),
      );
      final p = tester.renderObject<RenderParagraph>(find.byKey(const Key('t')));
      final greedy = TextPainter(
        text: TextSpan(style: const TextStyle(fontSize: 10), children: [words]),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 200);
      final count = greedy.computeLineMetrics().length;
      greedy.dispose();
      expect(p.size.height, count * 10);
      expect(p.text.toPlainText().split('\n').length, lessThanOrEqualTo(count));
    });
  });

  testWidgets('a balanced paragraph that wraps fills its loose room, as the greedy one does', (tester) async {
    await tester.pumpWidget(page('aaa bbb ccc ddd eee', 150));
    expect(tester.getSize(find.byType(Balance)).width, 150);
    // Balanced all the same: two lines, the longer 110 where greedy is 150.
    final p = tester.renderObject<RenderParagraph>(find.byKey(const Key('t')));
    expect('\n'.allMatches(p.text.toPlainText()).length, 1);
    expect(p.getMaxIntrinsicWidth(double.infinity), 110);
  });

  testWidgets('a balanced paragraph that does not wrap is its own width', (tester) async {
    await tester.pumpWidget(page('aaa bbb', 150));
    expect(tester.getSize(find.byType(Balance)).width, 70);
  });

  testWidgets('its least width is its longest word, and its greatest its greedy line', (tester) async {
    await tester.pumpWidget(page('aaa bbb ccc ddd eee', 150));
    final b = tester.renderObject<RenderBox>(find.byType(Balance));
    expect(b.getMinIntrinsicWidth(double.infinity), 30);
    expect(b.getMaxIntrinsicWidth(double.infinity), 190);
  });
}
