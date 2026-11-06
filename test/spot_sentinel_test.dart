// AN EMPTY SENTINEL OF NO HEIGHT PINNED ACROSS A STACK STANDS NOWHERE. A
// `position: absolute` box of nothing, at its static position across and
// pinned across its containing block (CSS 2.1 10.3.7, 10.6.4), is as wide as
// the block and of no height: it paints nothing, nothing hits it, and a box
// of no area is seen by no one. A product site's and a docs site's sentinels are
// written `Align(heightFactor: 1)` round an `OverflowBox` round
// `IntrinsicWidth(SizedBox.shrink())`, in a `SpotShift` that moves them across
// to the static position a `SpotArea` marks. The tidy (`tidy.dart`,
// `_unspotted`, `_noHeight`) takes the shift off -- and the area and the
// scope nothing else reads -- and the sentinel stands at the pin's corner.
// This pins the page with and without them to the same boxes, the sentinel
// of no height in both, nothing hit at any point, at several widths.
// NEGATIVE: pinned at its top and its bottom, the stack hands the sentinel
// its height, and the shift moves a box of an area: the two pages part.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';

Widget _sentinel() => const Align(
  key: ValueKey('s'),
  alignment: Alignment.topLeft,
  heightFactor: 1,
  child: OverflowBox(
    maxWidth: double.infinity,
    fit: OverflowBoxFit.deferToChild,
    alignment: AlignmentDirectional.topStart,
    child: IntrinsicWidth(child: SizedBox.shrink(key: ValueKey('e'))),
  ),
);

const _a = ColoredBox(key: ValueKey('a'), color: Color(0xFF336699), child: SizedBox(height: 50));
const _b = ColoredBox(key: ValueKey('b'), color: Color(0xFF993366), child: SizedBox(height: 30));

/// The page as the exact pass writes it: the area marked, the sentinel
/// shifted across to it -- and [down] it, where its top is the flow's too.
Widget _spotted(double width, {required bool tight, bool down = false}) => _page(
  width,
  SpotScope(
    child: Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 24, top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _a,
              SpotArea(id: 1, child: _b),
            ],
          ),
        ),
        Positioned(
          left: 0,
          top: tight || down ? 0 : 10,
          right: 0,
          bottom: tight ? 0 : null,
          child: SpotShift(id: 1, across: true, down: down, child: _sentinel()),
        ),
      ],
    ),
  ),
);

/// The page as the stock pass writes it: no shift, no area, no scope.
Widget _plain(double width, {required bool tight, bool down = false}) => _page(
  width,
  Stack(
    clipBehavior: Clip.none,
    fit: StackFit.passthrough,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 24, top: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_a, _b]),
      ),
      Positioned(left: 0, top: tight || down ? 0 : 10, right: 0, bottom: tight ? 0 : null, child: _sentinel()),
    ],
  ),
);

Widget _page(double width, Widget body) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: body),
  ),
);

const _keys = ['a', 'b', 's', 'e'];

Future<Map<String, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(ValueKey(k)))};
}

/// The render boxes a tap at [p] reaches, by type, deepest first.
List<Type> _hits(WidgetTester t, Offset p) {
  final result = HitTestResult();
  t.binding.hitTestInView(result, p, t.view.viewId);
  return [for (final e in result.path) e.target.runtimeType];
}

void main() {
  for (final width in const [400.0, 300.0, 120.0]) {
    for (final down in const [false, true]) {
      testWidgets(
        'a sentinel of no height, $width wide${down ? ', moved down too' : ''}: the same boxes, nothing of it seen or hit',
        (t) async {
          final spotted = await _rects(t, _spotted(width, tight: false, down: down));
          // Across the stack at its top, at 10 down and at the area's top --
          // over the first box, the second and the room beside them: a tap
          // anywhere on the sentinel's line reaches what is under it, and
          // nothing of the sentinel.
          final points = [
            for (final y in const [0.0, 10.0, 58.0, 70.0]) ...[Offset(1, y), Offset(30, y), Offset(width - 1, y)],
          ];
          final spottedHits = [for (final p in points) _hits(t, p)];
          final plain = await _rects(t, _plain(width, tight: false, down: down));
          for (final k in const ['a', 'b']) {
            expect(plain[k], spotted[k], reason: k);
          }
          // The shift moved it across to the area (and down to it); in
          // either place it is a line of no height across the stack, and its
          // content a point.
          expect(spotted['s'], Rect.fromLTWH(24, down ? 58 : 10, width, 0));
          expect(plain['s'], Rect.fromLTWH(0, down ? 0 : 10, width, 0));
          expect(spotted['e']!.isEmpty && plain['e']!.isEmpty, isTrue);
          final plainHits = [for (final p in points) _hits(t, p)];
          for (var i = 0; i < points.length; i++) {
            expect(plainHits[i].where((x) => x == RenderSpotArea || x == RenderSpotShift), isEmpty);
            expect(
              spottedHits[i].where((x) => x != RenderSpotArea && x != RenderSpotShift).toList(),
              plainHits[i],
              reason: '${points[i]}',
            );
            expect(spottedHits[i].contains(RenderSpotShift), isFalse, reason: '${points[i]}');
          }
        },
      );
    }
    testWidgets('NEGATIVE: pinned top and bottom, $width wide, the sentinel has an area and the shift moves it', (
      t,
    ) async {
      final spotted = await _rects(t, _spotted(width, tight: true));
      final plain = await _rects(t, _plain(width, tight: true));
      expect(spotted['s']!.height, greaterThan(0));
      expect(spotted['s'], isNot(plain['s']));
    });
  }
}
