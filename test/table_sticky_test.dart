import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/src/table.dart' show RenderTableBox, RenderTableSlot;

// The test view is 800x600, and this page scrolls in it: 300 above the
// table, a head row 50 tall and twenty rows of 100 under it (the table 2050
// tall, from 300 to 2350 down the page), 1000 after it.
Widget _page(
  ScrollController c, {
  List<StickyRows> sticky = const [],
  Widget Function(Widget)? head,
  Key? headKey,
  Key? lastKey,
  VoidCallback? onHead,
  VoidCallback? onRow,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: SingleChildScrollView(
    controller: c,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 300),
        TableBox(
          width: 800,
          sticky: sticky,
          children: [
            TableSlot(
              row: 0,
              column: 0,
              child: (head ?? (w) => w)(
                GestureDetector(
                  onTap: onHead,
                  child: SizedBox(
                    key: headKey,
                    height: 50,
                    child: const ColoredBox(color: Color(0xFF0000FF)),
                  ),
                ),
              ),
            ),
            for (var i = 1; i <= 20; i++)
              TableSlot(
                row: i,
                column: 0,
                child: GestureDetector(
                  onTap: onRow,
                  child: SizedBox(
                    key: i == 20 ? lastKey : null,
                    height: 100,
                    child: const ColoredBox(color: Color(0xFFFF0000)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 1000),
      ],
    ),
  ),
);

void main() {
  group('the rows a table holds as the page scrolls (TableBox.sticky)', () {
    testWidgets('are drawn down to their inset, and go up with the table at its end', (tester) async {
      final c = ScrollController(), head = GlobalKey();
      await tester.pumpWidget(_page(c, sticky: const [StickyRows(top: 48)], headKey: head));
      expect(tester.getTopLeft(find.byKey(head)).dy, 300);
      c.jumpTo(1000);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(head)).dy, 48);
      // The table ends 48 down the window: the head goes up with it, its
      // foot at the table's.
      c.jumpTo(2302);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(head)).dy, -2);
    });

    testWidgets('are hit where they are drawn, and paint over the rows going by', (tester) async {
      final c = ScrollController();
      var heads = 0, rows = 0;
      await tester.pumpWidget(
        _page(c, sticky: const [StickyRows(top: 48)], onHead: () => heads++, onRow: () => rows++),
      );
      c.jumpTo(1000);
      await tester.pump();
      await tester.tapAt(const Offset(10, 60));
      expect((heads, rows), (1, 0));
      final table = tester.renderObject<RenderTableBox>(find.byType(TableBox));
      expect((table.paintOrder.last as RenderTableSlot).row, 0);
    });

    testWidgets('a bottom inset holds them up at the window\'s foot', (tester) async {
      final c = ScrollController(), last = GlobalKey();
      await tester.pumpWidget(_page(c, sticky: const [StickyRows(row: 20, bottom: 0)], lastKey: last));
      expect(tester.getTopLeft(find.byKey(last)).dy, 500);
    });

    testWidgets('NEGATIVE: rows with no inset, and a table that holds none, are drawn where they are laid out', (
      tester,
    ) async {
      final c = ScrollController(), head = GlobalKey();
      await tester.pumpWidget(_page(c, sticky: const [StickyRows()], headKey: head));
      c.jumpTo(1000);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(head)).dy, -700);
      await tester.pumpWidget(_page(c, headKey: head));
      expect(tester.getTopLeft(find.byKey(head)).dy, -700);
    });
  });

  group('a sticky box in a table cell (Sticky)', () {
    testWidgets('goes no further than the table, its block', (tester) async {
      final c = ScrollController(), head = GlobalKey();
      await tester.pumpWidget(
        _page(
          c,
          head: (w) => Sticky(top: 0, child: w),
          headKey: head,
        ),
      );
      c.jumpTo(1000);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(head)).dy, 0);
      c.jumpTo(2302);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(head)).dy, -2);
    });
  });
}
