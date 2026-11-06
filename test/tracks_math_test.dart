// A TRACK OF `min()`, `max()` OR `clamp()` over lengths and shares of the
// grid's own width is one size, as an affine one is (css-values-4 10.2,
// css-grid-1 7.2.1): a docs site's tutorial is a column of `clamp(360px, 33%,
// 50%)` beside a `1fr`, a course site's leadership page `min()`s of the window
// and a fixed width. Each width here is the expression worked by hand.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A grid of [columns], one 10px-deep item in each, [width] wide.
Widget _grid(List<TrackSize> columns, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Tracks(
        columns: columns,
        children: [
          for (var i = 0; i < columns.length; i++)
            TrackCell(
              column: i,
              height: 10,
              child: ColoredBox(key: ValueKey(i), color: const Color(0xFF000000)),
            ),
        ],
      ),
    ),
  ),
);

/// The width of item [i]'s box.
double _width(WidgetTester t, int i) => t.getSize(find.byKey(ValueKey(i))).width;

/// A window wide enough for every grid here: the test's own is 800.
void _wide(WidgetTester t) {
  t.view.physicalSize = const Size(2000, 600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  // The docs site: `clamp(360px, 33%, 50%) 1fr` is the larger of 360 and a third
  // of the grid, the half never reached.
  const docs = [
    TrackSize.clamp(TrackSize.fixed(360), TrackSize.fraction(0.33), TrackSize.fraction(0.5)),
    TrackSize.flex(1),
  ];

  testWidgets('clamp(360px, 33%, 50%) is 360 until a third of the grid is more', (t) async {
    _wide(t);
    for (final (w, first) in [(400.0, 360.0), (1000.0, 360.0), (1440.0, 475.2)]) {
      await t.pumpWidget(_grid(docs, w));
      expect(_width(t, 0), closeTo(first, 1e-9), reason: 'at $w');
      expect(_width(t, 1), closeTo(w - first, 1e-9), reason: 'at $w');
    }
  });

  testWidgets('min() is the smaller, max() the larger, a sum of shares and lengths on either side', (t) async {
    _wide(t);
    const least = [TrackSize.least(TrackSize.fixed(200), TrackSize.affine(10, 0.5)), TrackSize.flex(1)];
    for (final (w, first) in [(300.0, 160.0), (600.0, 200.0)]) {
      await t.pumpWidget(_grid(least, w));
      expect(_width(t, 0), closeTo(first, 1e-9), reason: 'min() at $w');
    }
    const most = [TrackSize.most(TrackSize.fraction(0.2), TrackSize.fixed(170)), TrackSize.flex(1)];
    for (final (w, first) in [(600.0, 170.0), (1000.0, 200.0)]) {
      await t.pumpWidget(_grid(most, w));
      expect(_width(t, 0), closeTo(first, 1e-9), reason: 'max() at $w');
    }
  });

  testWidgets('a clamp whose floor passes its ceiling is its floor', (t) async {
    _wide(t);
    // At 400 the ceiling is 200 and the floor 360: CSS's clamp() takes the
    // floor (css-values-4 10.2, "MIN wins"), and the grid overflows.
    const over = [TrackSize.clamp(TrackSize.fixed(360), TrackSize.fraction(0.9), TrackSize.fraction(0.5))];
    await t.pumpWidget(_grid(over, 400));
    expect(_width(t, 0), 360);
  });

  // NEGATIVE: with no width to take a share of -- the grid measured for
  // its content -- the track is what a bare percentage is there: its items'
  // own (css-grid-1 7.2.1), and not the expression read with the share left
  // out.
  testWidgets('NEGATIVE: measured for its content, it is a percentage track', (t) async {
    Widget measured(TrackSize track) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: IntrinsicWidth(
          child: Tracks(
            columns: [track],
            children: [TrackCell(column: 0, child: SizedBox(key: const ValueKey(0), width: 50, height: 10))],
          ),
        ),
      ),
    );
    await t.pumpWidget(measured(const TrackSize.fraction(0.5)));
    final share = t.getSize(find.byType(Tracks)).width;
    await t.pumpWidget(
      measured(const TrackSize.clamp(TrackSize.fixed(100), TrackSize.fraction(0.5), TrackSize.fixed(300))),
    );
    expect(t.getSize(find.byType(Tracks)).width, share);
  });
}
