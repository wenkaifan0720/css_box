import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// A table asked its size dry (an intrinsic height, a dry layout) asks a
/// cell its dry baseline only where the cell stands on its row's baseline:
/// a top, middle or bottom cell, or one that spans rows, is placed by its
/// height alone (CSS 2.1 17.5.3), and the baseline the pass asked of it was
/// never read. A market table's 510 middle-aligned cells were each asked
/// theirs, down every box in them, at every dry pass: 6 of a layout's 12
/// seconds.

Widget _loose(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: child),
);

Widget _slot(
  String id, {
  required int row,
  required int column,
  required TableAlign align,
  double w = 40,
  double h = 20,
  double b = 14,
  int rowSpan = 1,
}) => TableSlot(
  row: row,
  column: column,
  rowSpan: rowSpan,
  align: align,
  child: TableShift(
    child: _Counted(id: id, w: w, h: h, b: b),
  ),
);

RenderBox _table(WidgetTester tester) => tester.renderObject<RenderBox>(find.byType(TableBox));

void main() {
  setUp(_RenderCounted.asked.clear);

  testWidgets('a table asked its size dry asks no cell a baseline its row does not stand on', (tester) async {
    await tester.pumpWidget(
      _loose(
        TableBox(
          children: [
            _slot('top', row: 0, column: 0, align: TableAlign.top),
            _slot('middle', row: 0, column: 1, align: TableAlign.middle, h: 30),
            _slot('bottom', row: 1, column: 0, align: TableAlign.bottom),
            // Standing on a baseline, but over two rows: the rows take its height.
            _slot('spans', row: 1, column: 1, align: TableAlign.baseline, rowSpan: 2, h: 50),
            _slot('middle2', row: 2, column: 0, align: TableAlign.middle),
          ],
        ),
      ),
    );
    _RenderCounted.asked.clear();
    final table = _table(tester);
    table.getDryLayout(const BoxConstraints(maxWidth: 400));
    table.getMinIntrinsicHeight(300);
    table.getMaxIntrinsicHeight(200);
    expect(_RenderCounted.asked, isEmpty);
  });

  testWidgets('a table of top, middle and bottom cells comes to the same size dry as laid out', (tester) async {
    for (final room in [70.0, 400.0]) {
      await tester.pumpWidget(
        _loose(
          SizedBox(
            width: room,
            child: Align(
              alignment: Alignment.topLeft,
              child: TableBox(
                spacing: const Size(2, 3),
                children: [
                  _slot('top', row: 0, column: 0, align: TableAlign.top, h: 12),
                  _slot('middle', row: 0, column: 1, align: TableAlign.middle, w: 60, h: 30),
                  _slot('bottom', row: 1, column: 0, align: TableAlign.bottom, h: 25),
                  _slot('spans', row: 1, column: 1, align: TableAlign.baseline, rowSpan: 2, h: 50, b: 40),
                  _slot('middle2', row: 2, column: 0, align: TableAlign.middle, h: 8),
                ],
              ),
            ),
          ),
        ),
      );
      final table = _table(tester);
      expect(table.getDryLayout(table.constraints), table.size, reason: 'room $room');
      expect(table.getMinIntrinsicHeight(table.size.width), table.size.height, reason: 'room $room');
    }
    // At 400: columns 40 and 60 and three spacings, 106 across. Rows 30, 32
    // and 15: the cell over the last two is 50, which the 25 and 8 they hold
    // and a spacing leave 14 short, shared out 7 to each.
    Offset at(String id) => tester.getTopLeft(find.byWidgetPredicate((w) => w is _Counted && w.id == id));
    expect(_table(tester).size, const Size(106, 89));
    // The bottom cell sits at its row's foot, the short middle one in the
    // middle of its row.
    expect(at('bottom').dy, 3 + 30 + 3 + (32 - 25));
    expect(at('middle2').dy, 3 + 30 + 3 + 32 + 3 + (15 - 8) / 2);
  });

  testWidgets('NEGATIVE: a row that stands on a baseline still asks its cells theirs, dry', (tester) async {
    await tester.pumpWidget(
      _loose(
        TableBox(
          children: [
            // Deepest baseline 16 and longest tail 16: the row is 32, taller than
            // either cell, and only the baselines say so.
            _slot('a', row: 0, column: 0, align: TableAlign.baseline, h: 20, b: 4),
            _slot('b', row: 0, column: 1, align: TableAlign.baseline, h: 20, b: 16),
            _slot('beside', row: 0, column: 2, align: TableAlign.middle, h: 20),
          ],
        ),
      ),
    );
    final table = _table(tester);
    expect(table.size.height, 32);
    _RenderCounted.asked.clear();
    expect(table.getDryLayout(const BoxConstraints(maxWidth: 500)).height, 32);
    expect(table.getMinIntrinsicHeight(500), 32);
    expect(_RenderCounted.asked.keys, containsAll(<String>['a', 'b']));
    expect(tester.getTopLeft(find.byWidgetPredicate((w) => w is _Counted && w.id == 'a')).dy, 12);
  });

  testWidgets('a middle cell in a row whose other cells stand on a baseline is not asked its own', (tester) async {
    await tester.pumpWidget(
      _loose(
        TableBox(
          children: [
            _slot('a', row: 0, column: 0, align: TableAlign.baseline, h: 20, b: 4),
            _slot('b', row: 0, column: 1, align: TableAlign.baseline, h: 20, b: 16),
            _slot('beside', row: 0, column: 2, align: TableAlign.middle, h: 20),
          ],
        ),
      ),
    );
    _RenderCounted.asked.clear();
    _table(tester).getDryLayout(const BoxConstraints(maxWidth: 500));
    expect(_RenderCounted.asked.keys.toSet(), {'a', 'b'});
  });
}

class _Counted extends LeafRenderObjectWidget {
  const _Counted({required this.id, required this.w, required this.h, required this.b});

  final String id;
  final double w, h, b;

  @override
  _RenderCounted createRenderObject(BuildContext context) => _RenderCounted(id, w, h, b);

  @override
  void updateRenderObject(BuildContext context, _RenderCounted renderObject) => renderObject
    ..id = id
    ..w = w
    ..h = h
    ..b = b
    ..markNeedsLayout();
}

/// A box [w] by [h] whose baseline is [b] down, which counts each time it is
/// asked that baseline dry.
class _RenderCounted extends RenderBox {
  _RenderCounted(this.id, this.w, this.h, this.b);

  static final asked = <String, int>{};

  String id;
  double w, h, b;

  @override
  double computeMinIntrinsicWidth(double height) => w;

  @override
  double computeMaxIntrinsicWidth(double height) => w;

  @override
  double computeMinIntrinsicHeight(double width) => h;

  @override
  double computeMaxIntrinsicHeight(double width) => h;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size(w, h));

  @override
  void performLayout() => size = constraints.constrain(Size(w, h));

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) {
    asked[id] = (asked[id] ?? 0) + 1;
    return b;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => b;
}
