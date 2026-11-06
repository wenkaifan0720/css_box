// A GAPPED WRAP ASKED ITS LENGTH ALONG ITS RUNS COUNTS ITS GAPS. A
// wrapping flex container's max-content main size is its items' end to end
// with the gaps between them (css-flexbox-1 9.9.1, css-align-3 8.1).
// `RenderWrap.computeMaxIntrinsicWidth` leaves its `spacing` out, so a
// gapped `Wrap` under an `IntrinsicWidth` stood a gap per item too narrow
// and broke its last item onto a run of its own: a rating row's note,
// 32px past the stars, dropped a line and the page under it 50px.
// `GapWrap` answers what it lays out on one run at, and asks and answers
// everything else as `RenderWrap` does.
//
// NEGATIVE: no gap, one child, and a gapped wrap laid out under a width
// nothing measures: each the stock `Wrap`'s answer and layout.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Three boxes of [widths] and 20 deep, keyed `0`, `1`, `2`, in a stock
/// [Wrap] or a [GapWrap].
Widget _wrap(
  bool gap, {
  double spacing = 10,
  List<double> widths = const [50, 60, 40],
  Axis direction = Axis.horizontal,
}) {
  final children = [
    for (final (i, w) in widths.indexed)
      SizedBox(
        key: ValueKey('$i'),
        width: direction == Axis.horizontal ? w : 20,
        height: direction == Axis.horizontal ? 20 : w,
      ),
  ];
  return gap
      ? GapWrap(key: const ValueKey('wrap'), direction: direction, spacing: spacing, runSpacing: 4, children: children)
      : Wrap(key: const ValueKey('wrap'), direction: direction, spacing: spacing, runSpacing: 4, children: children);
}

Widget _page(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

RenderBox _box(WidgetTester tester) => tester.renderObject<RenderBox>(find.byKey(const ValueKey('wrap')));

Offset _at(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(ValueKey(key)));

void main() {
  testWidgets('its greatest width counts the gaps between its children', (tester) async {
    await tester.pumpWidget(_page(_wrap(false)));
    expect(_box(tester).getMaxIntrinsicWidth(double.infinity), 150);
    await tester.pumpWidget(_page(_wrap(true)));
    expect(_box(tester), isA<RenderGapWrap>());
    expect(_box(tester).getMaxIntrinsicWidth(double.infinity), 170);
  });

  testWidgets('under an IntrinsicWidth it stands on one run, where a Wrap breaks', (tester) async {
    await tester.pumpWidget(_page(IntrinsicWidth(child: _wrap(false))));
    expect(_box(tester).size, const Size(150, 44));
    expect(_at(tester, '2'), const Offset(0, 24));
    await tester.pumpWidget(_page(IntrinsicWidth(child: _wrap(true))));
    expect(_box(tester).size, const Size(170, 20));
    expect(_at(tester, '2'), const Offset(130, 0));
  });

  testWidgets('every other answer is a Wrap\'s', (tester) async {
    for (final gap in [false, true]) {
      await tester.pumpWidget(_page(_wrap(gap)));
      final r = _box(tester);
      expect(r.getMinIntrinsicWidth(double.infinity), 60, reason: 'gap $gap');
      expect(r.getMinIntrinsicHeight(170), 20, reason: 'gap $gap');
      expect(r.getMaxIntrinsicHeight(170), 20, reason: 'gap $gap');
      expect(r.getMaxIntrinsicHeight(120), 44, reason: 'gap $gap');
      expect(r.getMaxIntrinsicHeight(100), 68, reason: 'gap $gap');
      expect(r.getDryLayout(const BoxConstraints(maxWidth: 120)), const Size(120, 44), reason: 'gap $gap');
    }
  });

  testWidgets('a vertical one counts them down, and its widths are a Wrap\'s', (tester) async {
    await tester.pumpWidget(_page(_wrap(false, direction: Axis.vertical)));
    expect(_box(tester).getMaxIntrinsicHeight(double.infinity), 150);
    expect(_box(tester).getMaxIntrinsicWidth(170), 20);
    await tester.pumpWidget(_page(_wrap(true, direction: Axis.vertical)));
    expect(_box(tester).getMaxIntrinsicHeight(double.infinity), 170);
    expect(_box(tester).getMaxIntrinsicWidth(170), 20);
  });

  testWidgets('a new spacing is asked again', (tester) async {
    await tester.pumpWidget(_page(_wrap(true)));
    expect(_box(tester).getMaxIntrinsicWidth(double.infinity), 170);
    await tester.pumpWidget(_page(_wrap(true, spacing: 32)));
    expect(_box(tester).getMaxIntrinsicWidth(double.infinity), 214);
  });

  testWidgets('NEGATIVE: no gap is a Wrap', (tester) async {
    await tester.pumpWidget(_page(IntrinsicWidth(child: _wrap(true, spacing: 0))));
    expect(_box(tester).getMaxIntrinsicWidth(double.infinity), 150);
    expect(_box(tester).size, const Size(150, 20));
  });

  testWidgets('NEGATIVE: one child has no gap', (tester) async {
    await tester.pumpWidget(_page(_wrap(true, widths: const [50])));
    expect(_box(tester).getMaxIntrinsicWidth(double.infinity), 50);
  });

  testWidgets('NEGATIVE: laid out under a width nothing measures, it breaks where a Wrap does', (tester) async {
    for (final width in [400.0, 170.0, 169.0, 100.0, 30.0]) {
      final got = <Offset>[], want = <Offset>[];
      for (final (gap, into) in [(false, want), (true, got)]) {
        await tester.pumpWidget(
          _page(
            SizedBox(
              width: width,
              child: Align(alignment: Alignment.topLeft, child: _wrap(gap)),
            ),
          ),
        );
        into.addAll([
          for (final k in ['0', '1', '2']) _at(tester, k),
        ]);
        into.add(Offset(_box(tester).size.width, _box(tester).size.height));
      }
      expect(got, want, reason: 'at $width');
    }
  });
}
