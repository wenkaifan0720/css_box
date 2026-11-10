import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A LINE OF NOTHING BUT A BOX, ON A FORCED STRUT, IS THE STRUT'S HEIGHT ASKED
// AS LAID OUT. Skia sets a line on a strut with `forceStrutHeight` at the
// strut's ascent and descent, and a box reaching past them hangs out of the
// line. Asked before layout, `LineBox` worked the line out as CSS does
// (2.1 10.8), from the box's own halves, which are Skia's: a glyph's
// unrounded ascent where Blink rounds it and floors the half-leading. A
// feature table's check icon, `vertical-align: -4px` on a 32px line, reached
// 0.73px over the strut and every row measured by an `IntrinsicHeight`
// stood that much taller than its line (fixtures/inline-shifted-icon-forced-line).
//
// The test font's ascent is 0.75em and its descent 0.25em. The icon is a
// 24px glyph on a 32px line, its leading split even: 22 over its baseline,
// 10 under. The strut is 16px on a 32px line: 20 over, 12 under. The box
// asks 22 over the line's baseline, 2 over the strut's.
const _icon = TextStyle(fontSize: 24, height: 32 / 24, leadingDistribution: TextLeadingDistribution.even);

StrutStyle _strut({required bool force}) => StrutStyle(
  fontSize: 16,
  height: 2,
  leading: 0,
  leadingDistribution: TextLeadingDistribution.even,
  forceStrutHeight: force,
);

Widget _line({required bool force}) => LineBox(
  key: const Key('l'),
  lineHeight: 32,
  ascent: 20,
  child: Text.rich(
    TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Text('x', style: _icon, strutStyle: _strut(force: false)),
        ),
      ],
    ),
    strutStyle: _strut(force: force),
  ),
);

Widget _page(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 100,
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Flexible(child: child)],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('on a forced strut the line is the strut\'s, asked or laid out', (tester) async {
    await tester.pumpWidget(_page(_line(force: true)));
    final line = tester.renderObject<RenderBox>(find.byKey(const Key('l')));
    expect(line.size.height, 32);
    expect(line.getMaxIntrinsicHeight(100), 32);
    expect(line.getMinIntrinsicHeight(100), 32);
    expect(line.getDryLayout(const BoxConstraints(maxWidth: 100)).height, 32);
    expect(line.getDryBaseline(const BoxConstraints(maxWidth: 100), TextBaseline.alphabetic), 20);
    // The `IntrinsicHeight` round it is the line.
    expect(tester.getSize(find.byType(IntrinsicHeight)).height, 32);
  });

  testWidgets('NEGATIVE: on a strut that is a minimum the box stretches the line, asked or laid out', (tester) async {
    // 22 over the baseline and the strut's 12 under it (CSS 2.1 10.8).
    await tester.pumpWidget(_page(_line(force: false)));
    final line = tester.renderObject<RenderBox>(find.byKey(const Key('l')));
    expect(line.size.height, 34);
    expect(line.getMaxIntrinsicHeight(100), 34);
    expect(line.getMinIntrinsicHeight(100), 34);
    expect(tester.getSize(find.byType(IntrinsicHeight)).height, 34);
  });
}
