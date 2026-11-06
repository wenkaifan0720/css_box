import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// The test view is 800x600, and this page scrolls in it.
Widget _page(List<Widget> kids) => Directionality(
  textDirection: TextDirection.ltr,
  child: SingleChildScrollView(
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
  ),
);

void main() {
  group('a sticky box at scroll 0', () {
    testWidgets('is drawn down to its inset from the top of the view', (tester) async {
      final a = GlobalKey(), after = GlobalKey();
      await tester.pumpWidget(
        _page([
          const SizedBox(height: 16),
          Sticky(top: 28, child: SizedBox(key: a, height: 40)),
          SizedBox(key: after, height: 1000),
        ]),
      );
      expect(tester.getTopLeft(find.byKey(a)).dy, 28);
      // A paint, not a layout: nothing after it moves.
      expect(tester.getTopLeft(find.byKey(after)).dy, 56);
    });

    testWidgets('further down than its inset, is not moved', (tester) async {
      final a = GlobalKey();
      await tester.pumpWidget(
        _page([
          const SizedBox(height: 900),
          Sticky(top: 156, child: SizedBox(key: a, height: 40)),
          const SizedBox(height: 1000),
        ]),
      );
      expect(tester.getTopLeft(find.byKey(a)).dy, 900);
    });

    testWidgets('goes no further than its block, less its frame and its margin', (tester) async {
      final a = GlobalKey();
      await tester.pumpWidget(
        _page([
          StickyBlock(
            inset: const EdgeInsets.only(bottom: 4),
            child: SizedBox(
              height: 60,
              child: Column(
                children: [
                  Sticky(
                    top: 50,
                    margin: const EdgeInsets.only(bottom: 2),
                    child: SizedBox(key: a, height: 40),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 1000),
        ]),
      );
      expect(tester.getTopLeft(find.byKey(a)).dy, 14);
    });

    testWidgets('below the fold with a bottom inset, is drawn up as far as its block lets it', (tester) async {
      final a = GlobalKey();
      await tester.pumpWidget(
        _page([
          const SizedBox(height: 700),
          StickyBlock(
            child: SizedBox(
              height: 200,
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  Sticky(bottom: 8, child: SizedBox(key: a, height: 30)),
                ],
              ),
            ),
          ),
        ]),
      );
      expect(tester.getTopLeft(find.byKey(a)).dy, 700);
    });

    testWidgets('inside a port, is held to the port\'s edges', (tester) async {
      final a = GlobalKey();
      await tester.pumpWidget(
        _page([
          const SizedBox(height: 86),
          StickyPort(
            child: SizedBox(
              height: 60,
              child: StickyBlock(
                child: Column(
                  children: [Sticky(top: 8, child: SizedBox(key: a, height: 40))],
                ),
              ),
            ),
          ),
          const SizedBox(height: 1000),
        ]),
      );
      expect(tester.getTopLeft(find.byKey(a)).dy, 94);
    });

    testWidgets('is hit where it is drawn', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _page([
          const SizedBox(height: 16),
          Sticky(
            top: 100,
            child: GestureDetector(
              onTap: () => taps++,
              child: const SizedBox(height: 40, child: ColoredBox(color: Color(0xFF000000))),
            ),
          ),
          const SizedBox(height: 1000),
        ]),
      );
      await tester.tapAt(const Offset(10, 120));
      expect(taps, 1);
    });
  });

  group('an inset that is a share of the scrollport', () {
    Widget block(Widget sticky) => StickyBlock(
      inset: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: 400,
          child: Align(alignment: Alignment.topLeft, child: sticky),
        ),
      ),
    );

    testWidgets('left: 100% is a whole view across: the block stops the box at its right edge', (tester) async {
      final a = GlobalKey();
      await tester.pumpWidget(
        _page([
          block(Sticky(leftShare: 1, child: SizedBox(key: a, width: 300, height: 20))),
          const SizedBox(height: 1000),
        ]),
      );
      // The block's content box ends at 800 - 16; the box is 300 wide.
      expect(tester.getTopLeft(find.byKey(a)).dx, 484);
      expect(tester.getTopLeft(find.byKey(a)).dy, 0);
    });

    testWidgets('top: 50% is half the view down, and a length adds to it', (tester) async {
      final a = GlobalKey();
      await tester.pumpWidget(
        _page([
          block(Sticky(top: 10, topShare: 0.5, child: SizedBox(key: a, width: 300, height: 20))),
          const SizedBox(height: 1000),
        ]),
      );
      // The view is 600 tall: 10 + 300 down, within the 400px block.
      expect(tester.getTopLeft(find.byKey(a)).dy, 310);
      expect(tester.getTopLeft(find.byKey(a)).dx, 16);
    });
  });
}
