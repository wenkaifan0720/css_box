import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/src/table.dart' show RenderTableBand;

// CSS 2.1 17.5.1: a column's background "covers exactly the full area of all
// cells that originate in the column, even if they span outside the column".
// A row with no cell in a coloured column, a slot a cell from another column
// spans into, and the border-spacing between cells are not painted by it.

const _grey = Color(0xFFEEEEEE);

Widget _table(List<Widget> children, {Size spacing = Size.zero}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: TableBox(fixed: true, width: 300, spacing: spacing, children: children),
  ),
);

Widget _cell(int row, int column, {int colSpan = 1, double h = 20}) => TableSlot(
  row: row,
  column: column,
  colSpan: colSpan,
  align: TableAlign.top,
  child: SizedBox(height: h),
);

Widget _column(Key key, int column, {int columns = 1}) => TableBand(
  key: key,
  column: column,
  columns: columns,
  child: const ColoredBox(color: _grey),
);

RenderTableBand _band(WidgetTester tester, Key key) => tester.renderObject<RenderTableBand>(find.byKey(key));

void main() {
  testWidgets('a column background paints under the cells that start in it, not over an empty slot', (tester) async {
    final grey = GlobalKey();
    // Three columns of 100. Row 0 is whole; row 1 holds one cell, in column
    // 0 (a section's heading); row 2 is whole again.
    await tester.pumpWidget(
      _table([
        _column(grey, 1),
        for (var c = 0; c < 3; c++) _cell(0, c),
        _cell(1, 0, h: 30),
        for (var c = 0; c < 3; c++) _cell(2, c),
      ]),
    );
    final band = _band(tester, grey);
    expect(band.size, const Size(100, 70));
    expect(band.under, const [Rect.fromLTWH(0, 0, 100, 20), Rect.fromLTWH(0, 50, 100, 20)]);
    expect(
      band,
      paints..clipPath(
        pathMatcher: isPathThat(includes: const [Offset(50, 10), Offset(50, 60)], excludes: const [Offset(50, 35)]),
      ),
    );
  });

  testWidgets('a column paints the whole of a cell that starts in it and spans out of it', (tester) async {
    final first = GlobalKey(), second = GlobalKey();
    // Row 1's cell starts in column 0 and spans all three: column 0's
    // background covers it whole, column 1's none of it.
    await tester.pumpWidget(
      _table([_column(first, 0), _column(second, 1), for (var c = 0; c < 3; c++) _cell(0, c), _cell(1, 0, colSpan: 3)]),
    );
    final a = _band(tester, first), b = _band(tester, second);
    // The box stays the column, as a `<col>` measures; the paint covers the
    // cell it spans out to.
    expect(a.size, const Size(100, 40));
    expect(a.under, const [Rect.fromLTWH(0, 0, 100, 20), Rect.fromLTWH(0, 20, 300, 20)]);
    expect(
      a,
      paints
        ..clipPath()
        ..transform()
        ..rect(rect: const Rect.fromLTWH(0, 0, 100, 40), color: _grey),
    );
    expect(tester.getTopLeft(find.byKey(first)), Offset.zero);
    expect(b.size, const Size(100, 40));
    expect(b.under, const [Rect.fromLTWH(0, 0, 100, 20)]);
  });

  testWidgets('a column background leaves the border-spacing between its cells', (tester) async {
    final grey = GlobalKey();
    await tester.pumpWidget(_table(spacing: const Size(0, 4), [_column(grey, 0), _cell(0, 0), _cell(1, 0)]));
    final band = _band(tester, grey);
    expect(band.under, const [Rect.fromLTWH(0, 0, 300, 20), Rect.fromLTWH(0, 24, 300, 20)]);
  });

  testWidgets('a column of a row with no cells at all paints nothing there', (tester) async {
    final grey = GlobalKey();
    // A spacer row: a row band 64 tall and no cell.
    await tester.pumpWidget(
      _table([
        _column(grey, 1),
        _cell(0, 0),
        _cell(0, 1),
        const TableBand(row: 1, rows: 1, height: 64, child: SizedBox()),
        _cell(2, 0),
        _cell(2, 1),
      ]),
    );
    final band = _band(tester, grey);
    expect(band.under, const [Rect.fromLTWH(0, 0, 150, 20), Rect.fromLTWH(0, 84, 150, 20)]);
  });

  testWidgets('NEGATIVE: a column its cells fill paints as laid out, without a clip', (tester) async {
    final grey = GlobalKey();
    await tester.pumpWidget(
      _table([
        _column(grey, 1),
        for (var r = 0; r < 3; r++)
          for (var c = 0; c < 3; c++) _cell(r, c),
      ]),
    );
    final band = _band(tester, grey);
    expect(band.under, isNull);
    expect(band.size, const Size(100, 60));
    expect(band, isNot(paints..clipPath()));
    expect(band, paints..rect(rect: const Rect.fromLTWH(0, 0, 100, 60), color: _grey));
  });

  testWidgets('NEGATIVE: a row band, and a column filled by a cell spanning down it, keep their whole box', (
    tester,
  ) async {
    final row = GlobalKey(), grey = GlobalKey();
    await tester.pumpWidget(
      _table([
        TableBand(
          key: row,
          row: 1,
          rows: 1,
          child: const ColoredBox(color: _grey),
        ),
        _column(grey, 1),
        _cell(0, 0),
        const TableSlot(row: 0, column: 1, rowSpan: 2, align: TableAlign.top, child: SizedBox(height: 10)),
        _cell(1, 0),
      ]),
    );
    expect(_band(tester, row).under, isNull);
    expect(_band(tester, grey).under, isNull);
    expect(_band(tester, row).size, const Size(300, 20));
  });
}
