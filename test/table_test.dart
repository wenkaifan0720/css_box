import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// [room] across, OFFERED: a table in a block flow shrinks to fit in it
/// (CSS 2.1 17.5.2). A tight width means something else -- see [_given].
Widget _in(double room, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: room,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  ),
);

/// [width] across, GIVEN: what a box that already worked the table's width
/// out hands it -- a `width: 100%` table in a stretching column.
Widget _given(double width, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  ),
);

/// No width at all: what a table is offered where its parent shrinks to fit.
Widget _loose(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

Widget _cell(
  Key key, {
  required int row,
  required int column,
  double w = 40,
  double h = 20,
  int rowSpan = 1,
  int colSpan = 1,
  TableAlign align = TableAlign.top,
  double? width,
}) => TableSlot(
  row: row,
  column: column,
  rowSpan: rowSpan,
  colSpan: colSpan,
  align: align,
  width: width,
  child: TableShift(
    child: SizedBox(key: key, width: w, height: h),
  ),
);

void main() {
  testWidgets('right to left the first column is the rightmost', (tester) async {
    // CSS 2.1 17.5: a table's columns run in its `direction`. With spacing,
    // so the mirror is across the whole table and not the grid alone.
    final a = GlobalKey(), b = GlobalKey(), band = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: TableBox(
              spacing: const Size(4, 2),
              children: [
                TableBand(column: 0, columns: 1, child: SizedBox(key: band)),
                _cell(a, row: 0, column: 0, w: 40, width: 100),
                _cell(b, row: 0, column: 1, w: 30),
              ],
            ),
          ),
        ),
      ),
    );
    final ra = tester.getRect(find.byKey(a)), rb = tester.getRect(find.byKey(b));
    // The first column's right edge is the table's less the spacing, and
    // the second column ends a spacing before the first starts.
    expect(tester.getTopRight(find.ancestor(of: find.byKey(a), matching: find.byType(TableSlot))).dx, 296);
    expect(rb.left, lessThan(ra.left));
    expect(tester.getRect(find.byKey(band)).right, 296);
  });

  testWidgets('a column is as wide as the widest thing in it', (tester) async {
    final a = GlobalKey(), b = GlobalKey(), c = GlobalKey(), d = GlobalKey();
    await tester.pumpWidget(
      _in(
        500,
        TableBox(
          children: [
            _cell(a, row: 0, column: 0, w: 40),
            _cell(b, row: 0, column: 1, w: 120),
            _cell(c, row: 1, column: 0, w: 90),
            _cell(d, row: 1, column: 1, w: 30),
          ],
        ),
      ),
    );
    // 90 and 120 are the columns' max-content widths, and the table is as
    // wide as they come to -- narrower than the room it was offered.
    expect(tester.getSize(find.byKey(a)).width, 90);
    expect(tester.getSize(find.byKey(b)).width, 120);
    expect(tester.getTopLeft(find.byKey(b)).dx, 90);
  });

  testWidgets('a width the table is given is shared out among its columns', (tester) async {
    final a = GlobalKey(), b = GlobalKey();
    await tester.pumpWidget(
      _given(
        500,
        TableBox(
          children: [
            _cell(a, row: 0, column: 0, w: 40),
            _cell(b, row: 0, column: 1, w: 120),
            _cell(GlobalKey(), row: 1, column: 0, w: 90),
            _cell(GlobalKey(), row: 1, column: 1, w: 30),
          ],
        ),
      ),
    );
    // Not room to shrink into: the 290 the columns' max-content widths (90
    // and 120) leave of 500 goes to them in proportion to those widths
    // (css-tables-3 3.9.3), as a `width: 100%` table's does.
    expect(tester.getSize(find.byType(TableBox)).width, 500);
    expect(tester.getSize(find.byKey(a)).width, closeTo(500 * 90 / 210, 1e-9));
    expect(tester.getTopLeft(find.byKey(b)).dx, closeTo(500 * 90 / 210, 1e-9));
  });

  testWidgets('a row is as tall as its tallest cell, and every cell fills it', (tester) async {
    final a = GlobalKey(), b = GlobalKey(), cellA = GlobalKey();
    await tester.pumpWidget(
      _in(
        500,
        TableBox(
          children: [
            TableSlot(
              key: cellA,
              row: 0,
              column: 0,
              align: TableAlign.top,
              child: TableShift(child: SizedBox(key: a, width: 40, height: 20)),
            ),
            _cell(b, row: 0, column: 1, w: 40, h: 60),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(cellA)).height, 60);
    expect(tester.getTopLeft(find.byKey(a)).dy, 0);
  });

  testWidgets('a bottom-aligned cell puts its content at the foot of the row', (tester) async {
    final a = GlobalKey(), b = GlobalKey();
    await tester.pumpWidget(
      _in(
        500,
        TableBox(
          children: [
            _cell(a, row: 0, column: 0, h: 20, align: TableAlign.bottom),
            _cell(b, row: 0, column: 1, h: 60),
          ],
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(a)).dy, 40);
  });

  testWidgets('cells that share a baseline stand on the lowest of them', (tester) async {
    final a = GlobalKey(), b = GlobalKey();
    await tester.pumpWidget(
      _in(
        500,
        TableBox(
          children: [
            TableSlot(
              row: 0,
              column: 0,
              child: TableShift(child: _Stands(key: a, h: 20, b: 14)),
            ),
            TableSlot(
              row: 0,
              column: 1,
              child: TableShift(child: _Stands(key: b, h: 40, b: 30)),
            ),
          ],
        ),
      ),
    );
    // The row's baseline is 30; the shallower cell's content drops 16 to
    // meet it, and the row is as tall as 30 plus the deepest tail (10).
    expect(tester.getTopLeft(find.byKey(a)).dy, 16);
    expect(tester.getTopLeft(find.byKey(b)).dy, 0);
    expect(tester.getSize(find.byType(TableBox)).height, 40);
  });

  testWidgets('border-spacing sits between the cells and around them', (tester) async {
    final a = GlobalKey(), b = GlobalKey();
    await tester.pumpWidget(
      _in(
        500,
        TableBox(
          spacing: const Size(6, 3),
          children: [_cell(a, row: 0, column: 0, w: 40), _cell(b, row: 0, column: 1, w: 40)],
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(a)), const Offset(6, 3));
    expect(tester.getTopLeft(find.byKey(b)).dx, 6 + 40 + 6);
  });

  testWidgets('a fixed layout shares what the sized columns leave', (tester) async {
    final a = GlobalKey(), b = GlobalKey();
    await tester.pumpWidget(
      _in(
        500,
        TableBox(
          fixed: true,
          width: 300,
          children: [_cell(a, row: 0, column: 0, w: 10, width: 120), _cell(b, row: 0, column: 1, w: 10)],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(a)).width, 120);
    expect(tester.getSize(find.byKey(b)).width, 180);
  });

  testWidgets('a band is drawn over the tracks it covers', (tester) async {
    final row = GlobalKey();
    await tester.pumpWidget(
      _in(
        500,
        TableBox(
          children: [
            TableBand(row: 0, rows: 1, child: SizedBox.expand(key: row)),
            _cell(GlobalKey(), row: 0, column: 0, w: 80, h: 24),
            _cell(GlobalKey(), row: 1, column: 0, w: 80, h: 10),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(row)), const Size(80, 24));
    expect(tester.getTopLeft(find.byKey(row)).dy, 0);
  });

  testWidgets('a table no narrower than its columns overflows a width that is too small', (tester) async {
    final a = GlobalKey();
    await tester.pumpWidget(_in(500, TableBox(width: 50, children: [_cell(a, row: 0, column: 0, w: 120)])));
    expect(tester.getSize(find.byKey(a)).width, 120);
  });

  testWidgets('a cell that spans rows lengthens them only where they are short', (tester) async {
    final tall = GlobalKey(), short = GlobalKey();
    await tester.pumpWidget(
      _in(
        500,
        TableBox(
          children: [
            _cell(tall, row: 0, column: 0, rowSpan: 2, h: 100),
            _cell(short, row: 0, column: 1, h: 20),
            _cell(GlobalKey(), row: 1, column: 1, h: 20),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byType(TableBox)).height, 100);
  });

  testWidgets('a stated width is what a shrink-to-fit parent asks the table for', (tester) async {
    final a = GlobalKey();
    // The table is inside a box that sizes itself to the table's intrinsic
    // width. A table that answered its GRID's width there would come out at
    // 120 whatever the markup said, which is how a `width: 500px` table ended
    // up 175px wide.
    await tester.pumpWidget(
      _loose(IntrinsicWidth(child: TableBox(width: 500, children: [_cell(a, row: 0, column: 0, w: 120)]))),
    );
    expect(tester.getSize(find.byType(TableBox)).width, 500);
    expect(tester.getSize(find.byKey(a)).width, 500);
  });

  testWidgets('a cell that spans columns widens them only when they cannot hold it', (tester) async {
    final wide = GlobalKey(), a = GlobalKey(), b = GlobalKey();
    await tester.pumpWidget(
      _loose(
        TableBox(
          children: [
            _cell(wide, row: 0, column: 0, colSpan: 2, w: 200),
            _cell(a, row: 1, column: 0, w: 40),
            _cell(b, row: 1, column: 1, w: 60),
          ],
        ),
      ),
    );
    // 200 over two columns that want 40 and 60: the 100 of surplus is shared
    // in proportion to what they already are (css-tables-3 8.2).
    expect(tester.getSize(find.byType(TableBox)).width, 200);
    expect(tester.getSize(find.byKey(a)).width, 80);
    expect(tester.getSize(find.byKey(b)).width, 120);
  });

  testWidgets('a table too narrow for the widths its columns state squeezes them (fixtures/table-col-width-squeezed)', (
    tester,
  ) async {
    // A price-table site's price table: `<col>`s that state more than its width
    // leaves beside the name column. A stated width is no floor
    // (css-tables-3 3.9.1); short of the stated widths, every column is the
    // same mix of its min-content width and its stated one (3.9.3), so the
    // stated columns give up what the table is short and the name column
    // keeps its content.
    final a = GlobalKey(), name = GlobalKey();
    Widget table(double width) => TableBox(
      width: width,
      children: [
        for (var i = 0; i < 3; i++) TableBand(column: i, columns: 1, width: 100, child: const SizedBox()),
        _cell(a, row: 0, column: 0, w: 0),
        _cell(GlobalKey(), row: 0, column: 1, w: 0),
        _cell(GlobalKey(), row: 0, column: 2, w: 0),
        _cell(name, row: 0, column: 3, w: 238),
      ],
    );
    double col(GlobalKey k) => tester.getSize(find.ancestor(of: find.byKey(k), matching: find.byType(TableSlot))).width;
    await tester.pumpWidget(_in(1000, table(500)));
    expect(tester.getSize(find.byType(TableBox)).width, 500);
    expect(col(a), closeTo(262 / 3, 1e-9));
    expect(col(name), 238);
    // Asked its widths, the table is its stated width, not its grid's.
    await tester.pumpWidget(_loose(IntrinsicWidth(child: table(500))));
    expect(tester.getSize(find.byType(TableBox)).width, 500);
    // NEGATIVE: at the stated widths exactly, and past them, every stated
    // column is its width; what is left goes to the one that states none.
    await tester.pumpWidget(_in(1000, table(538)));
    expect(col(a), 100);
    expect(col(name), 238);
    await tester.pumpWidget(_in(1000, table(700)));
    expect(col(a), 100);
    expect(col(name), 400);
    // A cell's own `width` asks the same as a `<col>`'s.
    await tester.pumpWidget(
      _in(
        1000,
        TableBox(
          width: 500,
          children: [
            _cell(a, row: 0, column: 0, w: 0, width: 100),
            _cell(GlobalKey(), row: 0, column: 1, w: 0, width: 100),
            _cell(GlobalKey(), row: 0, column: 2, w: 0, width: 100),
            _cell(name, row: 0, column: 3, w: 238),
          ],
        ),
      ),
    );
    expect(col(a), closeTo(262 / 3, 1e-9));
    expect(col(name), 238);
  });
}

/// A box of a stated height that stands on a stated baseline.
class _Stands extends LeafRenderObjectWidget {
  const _Stands({super.key, required this.h, required this.b});

  final double h, b;

  @override
  _RenderStands createRenderObject(BuildContext context) => _RenderStands(h, b);

  @override
  void updateRenderObject(BuildContext context, _RenderStands renderObject) => renderObject
    ..h = h
    ..b = b;
}

class _RenderStands extends RenderBox {
  _RenderStands(this.h, this.b);

  double h, b;

  @override
  void performLayout() =>
      size = constraints.constrain(Size(constraints.maxWidth.isFinite ? constraints.maxWidth : 20, h));

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size(constraints.maxWidth.isFinite ? constraints.maxWidth : 20, h));

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => b;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => b;
}
