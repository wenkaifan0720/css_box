// AN AUTO-REPEAT OF A TRACK SIZED BY A MATH FUNCTION. `repeat(auto-fill, ..)`
// repeats a <fixed-size> (css-grid-1 7.2.3.1), and a <fixed-breadth> is any
// <length-percentage>: `min()`, `max()`, `clamp()` and `calc()` of lengths
// and shares are fixed. A course site's footer is `repeat(auto-fill,
// minmax(min(240px, 100%), 1fr))`, its store badges `minmax(min(112px,
// 100%), 1fr)`: read as no fixed size, the template was `none` and every
// item stood in one implicit column (fixtures/grid-auto-repeat-math-track).
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [n] items 10px deep in a grid of [columns], [width] wide, [gap] apart.
Widget _grid(List<TrackSize> columns, double width, double gap, int n) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Tracks(
        columns: columns,
        spacing: gap,
        children: [
          for (var i = 0; i < n; i++)
            TrackCell(
              height: 10,
              child: ColoredBox(key: ValueKey(i), color: const Color(0xFF000000)),
            ),
        ],
      ),
    ),
  ),
);

Rect _box(WidgetTester t, int i) => t.getRect(find.byKey(ValueKey(i)));

void _wide(WidgetTester t) {
  t.view.physicalSize = const Size(2000, 600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('min(240px, 100%) repeats as 240 does: three columns of 280 in 1000 at a gap of 80', (t) async {
    _wide(t);
    await t.pumpWidget(
      _grid(
        const [
          TrackSize.fill([
            TrackSize.between(TrackSize.least(TrackSize.fixed(240), TrackSize.fraction(1)), TrackSize.flex(1)),
          ]),
        ],
        1000,
        80,
        4,
      ),
    );
    expect([for (var i = 0; i < 4; i++) _box(t, i).left], [0, 360, 720, 0]);
    expect(_box(t, 0).width, 280);
    expect(_box(t, 3).top, 10, reason: 'the fourth on a row of its own');
  });

  testWidgets('a calc() minimum repeats at what it comes to: calc(50px + 10%) is 110 of 600, four columns', (t) async {
    _wide(t);
    await t.pumpWidget(
      _grid(
        const [
          TrackSize.fill([TrackSize.between(TrackSize.affine(50, 0.1), TrackSize.flex(1))]),
        ],
        600,
        20,
        4,
      ),
    );
    expect([for (var i = 0; i < 4; i++) _box(t, i).left], [0, 155, 310, 465]);
  });

  testWidgets('NEGATIVE: min(240px, 100%) of a 200px grid is 200, one column', (t) async {
    _wide(t);
    await t.pumpWidget(
      _grid(
        const [
          TrackSize.fill([
            TrackSize.between(TrackSize.least(TrackSize.fixed(240), TrackSize.fraction(1)), TrackSize.flex(1)),
          ]),
        ],
        200,
        80,
        2,
      ),
    );
    expect(_box(t, 0).width, 200);
    expect(_box(t, 1).top, 10);
  });
}
