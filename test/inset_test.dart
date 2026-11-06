import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

Widget _in(double room, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: room, child: child),
  ),
);

void main() {
  _roomTests();
  group('an inset that is a share of the width the box is offered', () {
    testWidgets('takes the share off what the child is given, on every side', (tester) async {
      final box = GlobalKey(), inner = GlobalKey();
      await tester.pumpWidget(
        _in(
          400,
          Inset(
            key: box,
            insets: EdgeInsets.zero,
            // `padding: 10%` -- a share of the WIDTH at the top as well.
            shares: const EdgeInsets.all(0.1),
            child: SizedBox(key: inner, height: 30),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(inner)).width, 320);
      expect(tester.getSize(find.byKey(box)), const Size(400, 110));
      expect(tester.getTopLeft(find.byKey(inner)).dx, 40);
      expect(tester.getTopLeft(find.byKey(inner)).dy, 40);
    });

    testWidgets('adds the share to the length beside it', (tester) async {
      final inner = GlobalKey();
      await tester.pumpWidget(
        _in(
          422,
          Inset(
            // `margin: calc(50% - 195px)`: a 390px bar centred in the page,
            // whatever the page comes to.
            insets: const EdgeInsets.symmetric(horizontal: -195),
            shares: const EdgeInsets.symmetric(horizontal: 0.5),
            child: SizedBox(key: inner, height: 8),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(inner)).width, 390);
      expect(tester.getTopLeft(find.byKey(inner)).dx, 16);
    });

    testWidgets('sizes a box from its own width, which is what padding-top: 56.25% is for', (tester) async {
      final box = GlobalKey();
      await tester.pumpWidget(
        _in(
          320,
          Inset(
            key: box,
            insets: EdgeInsets.zero,
            shares: const EdgeInsets.only(top: 0.5625),
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(box)), const Size(320, 180));
    });

    testWidgets('beside a stated border-box height, the larger of the two', (tester) async {
      final box = GlobalKey(), inner = GlobalKey();
      Widget page(double room) => _in(
        room,
        Inset(
          key: box,
          insets: const EdgeInsets.only(top: 4),
          // `height: 120px; padding-top: 25%; border-top: 4px`.
          shares: const EdgeInsets.only(top: 0.25),
          height: 120,
          child: SizedBox(key: inner, height: 500),
        ),
      );
      await tester.pumpWidget(page(400));
      expect(tester.getSize(find.byKey(box)), const Size(400, 120));
      expect(tester.getSize(find.byKey(inner)).height, 16);
      expect(tester.getTopLeft(find.byKey(inner)).dy, 104);
      await tester.pumpWidget(page(600));
      expect(tester.getSize(find.byKey(box)), const Size(600, 154));
      expect(tester.getSize(find.byKey(inner)).height, 0);
      final render = tester.renderObject<RenderBox>(find.byKey(box));
      expect(render.getMinIntrinsicHeight(400), 120);
      expect(render.getMaxIntrinsicHeight(800), 204);
    });

    testWidgets('offered no width at all, comes to nothing', (tester) async {
      final box = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Inset(
              key: box,
              insets: const EdgeInsets.all(4),
              shares: const EdgeInsets.all(0.25),
              child: const SizedBox(width: 60, height: 10),
            ),
          ),
        ),
      );
      // The room is the screen's, not unbounded, so the share is a share of
      // it; what matters is that an intrinsic measurement of the same box
      // leaves the share out.
      final render = tester.renderObject<RenderBox>(find.byKey(box));
      expect(render.getMaxIntrinsicWidth(double.infinity), 68);
      expect(render.getMinIntrinsicHeight(200), 10 + 8 + 100);
    });
  });
}

void _roomTests() {
  // A forum's header: `margin: 0 calc(50% - 195px); padding: 0 calc(-50% +
  // 195px)` -- 390 wide in any block, its content the block's width up to
  // 390, and the padding floored at nothing past that.
  Widget header(double block) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: block,
        height: 40,
        child: Inset(
          insets: EdgeInsets.zero,
          room: true,
          child: Inset(
            insets: const EdgeInsets.symmetric(horizontal: -195),
            shares: const EdgeInsets.symmetric(horizontal: 0.5),
            child: ColoredBox(
              key: const Key('border'),
              color: const Color(0xFF000000),
              child: Inset(
                insets: const EdgeInsets.symmetric(horizontal: 195),
                shares: const EdgeInsets.symmetric(horizontal: -0.5),
                least: EdgeInsets.zero,
                ofRoom: true,
                child: const SizedBox.expand(key: Key('content')),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  testWidgets('a share of the room above, floored', (tester) async {
    await tester.pumpWidget(header(300));
    expect(tester.getSize(find.byKey(const Key('border'))).width, 390);
    expect(tester.getSize(find.byKey(const Key('content'))).width, 300);
    expect(tester.getTopLeft(find.byKey(const Key('content'))).dx, tester.getTopLeft(find.byType(SizedBox).first).dx);
    await tester.pumpWidget(header(500));
    expect(tester.getSize(find.byKey(const Key('border'))).width, 390);
    expect(tester.getSize(find.byKey(const Key('content'))).width, 390);
  });
}
