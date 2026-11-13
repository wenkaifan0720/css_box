// A BOX THAT REACHES PAST A FORCED STRUT IS ASKED AS IT IS LAID OUT. A line
// of nothing but atomic inlines on a forced strut answered the strut's own
// line before layout, whatever stood on it (`linebox.dart`, `_boxesOnly`),
// while laid out it reads the line off the boxes Skia placed (`_exact`),
// which on a line of a fractional height comes to more where a box reaches
// past the strut. A pricing page's gradient label is an inline-block on a
// 25.59375px forced line, holding text of its own the text scale raises:
// laid out the line came to 31 at 1.3, asked it answered 25.6, and the column
// the label stood in, measured by its line, overflowed by 5.4. Now a line a
// box reaches past is read off a dry paragraph the same way, asked or dry.
// NEGATIVE: a box that stays inside the strut leaves the strut's line,
// asked or laid out (and so does a box Skia lets hang out of a strut it
// draws at its own whole height: `linebox_forced_strut_dry_test.dart`).
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font's ascent is 0.75em and its descent 0.25em. The line's strut
// is 13.9224px on 25.6: its baseline 16.28 down. The box is the same text
// on the same strut, 25.59375 tall, so unscaled it stands on the line's own
// baseline; scaled, its strut grows and its baseline moves down in it, and
// the box reaches over the line.
const _body = TextStyle(fontSize: 16, height: 1.6, letterSpacing: 0.32, leadingDistribution: TextLeadingDistribution.even);
const _solid = TextStyle(fontSize: 16, height: 1, letterSpacing: 0.32, leadingDistribution: TextLeadingDistribution.even);
const _strut = StrutStyle(fontSize: 13.9224, height: 25.6 / 13.9224, leading: 0, forceStrutHeight: true);
const _line = ValueKey('line');
const _after = ValueKey('after');

Widget _label(Widget box) => LineBox(
  key: _line,
  keepWords: false,
  lineHeight: 25.59375,
  ascent: 18,
  child: Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: '​', style: TextStyle(letterSpacing: 0)),
        WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: box),
      ],
    ),
    softWrap: false,
    style: _solid,
    strutStyle: _strut,
    textScaler: TextScaler.noScaling,
  ),
);

const _scaledBox = SizedBox(
  height: 25.59375,
  child: Text('Agent', softWrap: false, style: _body, strutStyle: _strut),
);

Widget _page(Widget line, double scale) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 300,
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              line,
              Container(key: _after, height: 10, color: const Color(0xFF000000)),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final scale in const [1.3, 2.0]) {
    testWidgets('a box its text scale raises past the strut: the line asked is the line laid out, at $scale', (t) async {
      await t.pumpWidget(_page(_label(_scaledBox), scale));
      expect(t.takeException(), isNull);
      final line = t.renderObject<RenderBox>(find.byKey(_line));
      final laid = line.size.height;
      // The box reaches over the strut, and the line laid out holds it.
      expect(laid, greaterThan(25.6 + 2));
      expect(line.getMaxIntrinsicHeight(300), moreOrLessEquals(laid, epsilon: 1e-6));
      expect(line.getMinIntrinsicHeight(300), moreOrLessEquals(laid, epsilon: 1e-6));
      expect(line.getDryLayout(const BoxConstraints(maxWidth: 300)).height, moreOrLessEquals(laid, epsilon: 1e-6));
      // What stands under it stands under all of it.
      expect(t.getRect(find.byKey(_after)).top, moreOrLessEquals(laid, epsilon: 1e-6));
    });
  }

  testWidgets('NEGATIVE: a box that stays inside the strut leaves the strut\'s line, asked or laid out', (t) async {
    // Half the line's height, standing on its baseline: 12.8 over it where
    // the strut keeps 18.
    const inside = SizedBox(
      height: 12.8,
      child: Text('Agent', softWrap: false, style: TextStyle(fontSize: 8, height: 1.6), strutStyle: StrutStyle(fontSize: 8, height: 1.6, leading: 0, forceStrutHeight: true)),
    );
    await t.pumpWidget(_page(_label(inside), 1.0));
    expect(t.takeException(), isNull);
    final line = t.renderObject<RenderBox>(find.byKey(_line));
    expect(line.size.height, moreOrLessEquals(25.59375, epsilon: 1e-6));
    expect(line.getMaxIntrinsicHeight(300), moreOrLessEquals(25.59375, epsilon: 1e-6));
    expect(t.getRect(find.byKey(_after)).top, moreOrLessEquals(25.59375, epsilon: 1e-6));
  });
}
