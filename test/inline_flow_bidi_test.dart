// A right-to-left InlineFlow is ordered by UAX #9 over the paragraph's
// characters, and each inline box's start edge is its RIGHT one
// (css-writing-modes-4 2.4.2, css-break-3 5.4). The numbers are the
// algorithm's, under the test font -- every glyph, the space too, one em
// wide -- and what Chrome sets fixtures/inline-frame-pieces n3 by: an `rtl`
// paragraph of left-to-right words, `Mirror <code>logical start edge</code>
// layouts.`, the chip padded on its right on the first line and on its left
// on the second, and the full stop at the far left of the second.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

InlineFont font(double size, double lineHeight) => InlineFont(
  size: size,
  ascent: (size * 0.8).roundToDouble(),
  descent: (size * 0.2).roundToDouble(),
  lineHeight: lineHeight,
  xHeight: size * 0.8,
);

Future<RenderInlineFlow> lay(WidgetTester tester, double width, List<InlineNode> kids) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: InlineFlow(font: font(16, 20), style: const TextStyle(fontSize: 16), children: kids),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
}

void rects(List<Rect> got, List<List<double>> want) {
  expect(got.length, want.length, reason: '$got');
  for (var i = 0; i < want.length; i++) {
    final w = want[i];
    expect(
      [got[i].left, got[i].top, got[i].width, got[i].height],
      [for (final v in w) moreOrLessEquals(v, epsilon: 1e-6)],
      reason: 'fragment $i of $got',
    );
  }
}

void pieces(RenderInlineFlow r, List<(String, double, double, bool)> want) {
  final got = r.pieces;
  expect([for (final p in got) p.text], [for (final w in want) w.$1]);
  for (var i = 0; i < want.length; i++) {
    expect(
      [got[i].x, got[i].width, got[i].reversed],
      [moreOrLessEquals(want[i].$2, epsilon: 1e-6), moreOrLessEquals(want[i].$3, epsilon: 1e-6), want[i].$4],
      reason: 'piece ${want[i].$1}',
    );
  }
}

void main() {
  testWidgets('a box over two lines: its start edge on the right of the first, its end on the left of the last', (
    tester,
  ) async {
    // `ab ` then a box padded 4 on its left and 6 on its right round
    // `cd ef`, then ` g.`, 120 wide. The box OPENS with its right side
    // (6): the first line is `ab`, a space, 6 and `cd` -- 86 -- and `ef`
    // goes down. Set against the right edge, left to right as the words
    // read, the first fragment is `cd` and the 6 after it; the second is
    // the 4 before `ef` and `ef`, the box closing there.
    const box = InlineBox(padding: EdgeInsets.only(left: 4, right: 6), children: [InlineText('cd ef')]);
    final r = await lay(tester, 120, const [InlineText('ab '), box, InlineText(' g.')]);
    expect(r.size, const Size(120, 40));
    rects(r.fragmentsOf(box), [
      [82, 2, 38, 16],
      [52, 22, 36, 16],
    ]);
    // The full stop is a neutral between `g` and the paragraph's end: the
    // paragraph's direction, right to left, and at the far LEFT of the
    // second line -- a piece of its own, apart from `g`'s run.
    pieces(r, [
      ('ab ', 34, 48, false),
      ('cd', 82, 32, false),
      ('.', 36, 16, true),
      ('ef', 56, 32, false),
      (' g', 88, 32, false),
    ]);
  });

  testWidgets('a neutral a line ends on between two left-to-right words keeps their direction', (tester) async {
    // `ab - cd` in 80: `ab -` then `cd`. The paragraph resolves the `-`
    // between `ab` and `cd` left to right (UAX #9 N1), wherever the line
    // breaks -- one line alone would have put it at the line's end, the
    // paragraph's direction, and at the far left.
    final r = await lay(tester, 80, const [InlineText('ab - cd')]);
    pieces(r, [('ab -', 16, 64, false), ('cd', 48, 32, false)]);
  });

  testWidgets('neutrals ending the paragraph are one run right to left, its text in logical order', (tester) async {
    // `ab . .` in 200: `ab` left to right; the space after it and all
    // after that right to left, reversed to the left of `ab`. The four are
    // one piece, set from its logical text by a right-to-left painter.
    final r = await lay(tester, 200, const [InlineText('ab . .')]);
    pieces(r, [(' . .', 104, 64, true), ('ab', 168, 32, false)]);
  });

  testWidgets('a box that opens and closes on one line is framed on both sides, as left to right', (tester) async {
    const box = InlineBox(padding: EdgeInsets.only(left: 4, right: 6), children: [InlineText('cd')]);
    final r = await lay(tester, 200, const [InlineText('ab '), box, InlineText(' e')]);
    // `ab `, 4, `cd`, 6, ` e`: 122 of 200, from 78.
    rects(r.fragmentsOf(box), [
      [126, 2, 42, 16],
    ]);
  });
}
