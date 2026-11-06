import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/src/paint_order.dart';
import 'package:css_box/src/table.dart' show RenderTableBand, RenderTableSlot;

// The test view is 800x600. A table at the top of a page that scrolls: a
// head cell that sticks to the top at [headZ], then 40 rows 40 tall, each
// cell a press that says which it is. The page presses where it is drawn,
// as an app's screen does: the pinned head is drawn out of its slot.
Widget _page(List<String> taps, {int headZ = 0, int lastZ = 0}) => Directionality(
  textDirection: TextDirection.ltr,
  child: PressWhereDrawn(
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StickyBlock(
            child: TableBox(
              children: [
                const TableBand(row: 0, rows: 1, child: SizedBox.expand()),
                TableSlot(
                  row: 0,
                  column: 0,
                  z: headZ,
                  child: Sticky(top: 0, child: _press('head', taps)),
                ),
                for (var r = 1; r <= 40; r++)
                  TableSlot(row: r, column: 0, z: r == 40 ? lastZ : 0, child: _press('row $r', taps)),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

Widget _press(String name, List<String> taps) => GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () => taps.add(name),
  child: SizedBox(key: ValueKey(name), width: 200, height: 40),
);

Future<void> _scroll(WidgetTester tester, double to) async {
  tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(to);
  await tester.pump();
}

List<int> _rowsPainted(WidgetTester tester) => [
  for (final c in childrenInPaintOrder(tester.renderObject(find.byType(TableBox))))
    if (c is RenderTableSlot) c.row,
];

void main() {
  testWidgets('a head cell at a z above the rows takes the press over the row scrolled under it, and paints last', (
    tester,
  ) async {
    final taps = <String>[];
    await tester.pumpWidget(_page(taps, headZ: 120));
    await _scroll(tester, 400);
    expect(tester.getTopLeft(find.byKey(const ValueKey('head'))).dy, 0);
    await tester.tapAt(const Offset(100, 20));
    expect(taps, ['head']);
    expect(_rowsPainted(tester).last, 0);
    expect(_rowsPainted(tester).first, 1);
  });

  testWidgets('NEGATIVE: at the rows\' own z the row held after it paints over it and takes the press', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(_page(taps));
    await _scroll(tester, 400);
    await tester.tapAt(const Offset(100, 20));
    expect(taps, ['row 10']);
    expect(_rowsPainted(tester), [for (var r = 0; r <= 40; r++) r]);
  });

  testWidgets('cells of one z keep the order held, and a band paints at 0 under a cell above it', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(_page(taps, headZ: 2, lastZ: 2));
    expect(_rowsPainted(tester), [for (var r = 1; r < 40; r++) r, 0, 40]);
    final kids = childrenInPaintOrder(tester.renderObject(find.byType(TableBox)));
    expect(kids.first, isA<RenderTableBand>());
  });

  testWidgets('a z that changes repaints the table in its new order', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(_page(taps));
    await _scroll(tester, 400);
    await tester.pumpWidget(_page(taps, headZ: 1));
    await tester.tapAt(const Offset(100, 20));
    expect(taps, ['head']);
  });
}
