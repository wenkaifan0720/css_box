// A COMPRESSIBLE PICTURE in `Tracks` (css-sizing-3 5.2.2): a share in a
// replaced item's width or cap is of nothing in its min-content
// contribution, so it asks an `auto` column for nothing and grows it only
// as far as the grid has room. A product site's hero (fixtures/grid-item-pct-cap-
// placed): a `width: 1920px; max-width: 100%` picture in a centring grid
// as wide as the page, each item built as the lowerer states it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

Widget _grid({required bool compressible, double width = 1920}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 1408,
      child: Tracks(
        key: const ValueKey('grid'),
        align: CellAlign.center,
        justify: CellAlign.center,
        children: [
          TrackCell(
            width: width,
            maxWidthFraction: 1,
            compressible: compressible,
            child: FractionalConstraints(
              maxFactor: 1,
              compressible: true,
              child: SizedBox(
                key: const ValueKey('pic'),
                width: width,
                child: const AspectRatio(
                  aspectRatio: 1024 / 572,
                  child: ColoredBox(color: Color(0xFF4488CC)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

/// A window wider than the grid, as the page's is.
Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view
    ..physicalSize = const Size(2000, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
}

void main() {
  testWidgets('p1 the picture is held to the grid, its height down its ratio', (tester) async {
    await _pump(tester, _grid(compressible: true));
    final pic = tester.getRect(find.byKey(const ValueKey('pic')));
    expect(pic.left, 0);
    expect(pic.width, 1408);
    expect(pic.height, closeTo(1408 * 572 / 1024, 1e-9));
  });

  testWidgets('its least width is nothing, what it wants its length', (tester) async {
    await _pump(tester, _grid(compressible: true));
    final grid = tester.renderObject<RenderBox>(find.byKey(const ValueKey('grid')));
    expect(grid.getMinIntrinsicWidth(double.infinity), 0);
    expect(grid.getMaxIntrinsicWidth(double.infinity), 1920);
  });

  testWidgets('NEGATIVE: a box that is no picture floors its column at its length', (tester) async {
    await _pump(tester, _grid(compressible: false));
    final grid = tester.renderObject<RenderBox>(find.byKey(const ValueKey('grid')));
    expect(grid.getMinIntrinsicWidth(double.infinity), 1920);
  });

  testWidgets('n1 NEGATIVE: a picture narrower than the grid is its length, centred', (tester) async {
    await _pump(tester, _grid(compressible: true, width: 200));
    final pic = tester.getRect(find.byKey(const ValueKey('pic')));
    expect(pic.width, 200);
    expect(pic.left, (1408 - 200) / 2);
  });
}
