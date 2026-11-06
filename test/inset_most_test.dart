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
  // fixtures/flex-item-pct-padding-calc: `padding-left: min(48px, 10%)`, a
  // tenth of the width up to 48px -- the two cross at 480.
  for (final (room, left) in [(360.0, 36.0), (480.0, 48.0), (736.0, 48.0)]) {
    testWidgets('min(48px, 10%) of $room is $left', (tester) async {
      final inner = GlobalKey();
      await tester.pumpWidget(
        _in(
          room,
          Inset(
            insets: EdgeInsets.zero,
            shares: const EdgeInsets.only(left: 0.1),
            most: const EdgeInsets.only(
              left: 48,
              right: double.infinity,
              top: double.infinity,
              bottom: double.infinity,
            ),
            child: SizedBox(key: inner, height: 10),
          ),
        ),
      );
      expect(tester.getTopLeft(find.byKey(inner)).dx, closeTo(left, 1e-9));
      expect(tester.getSize(find.byKey(inner)).width, closeTo(room - left, 1e-9));
    });
  }

  testWidgets('the floor wins where it crosses the cap', (tester) async {
    // `min(8px, 10% - 60px)` under the padding's floor at nothing: a
    // share that comes to less than nothing under 600, capped at 8 past
    // 680, and nothing between the cap and the floor is lost.
    final inner = GlobalKey();
    Widget at(double room) => _in(
      room,
      Inset(
        insets: const EdgeInsets.only(left: -60),
        shares: const EdgeInsets.only(left: 0.1),
        least: EdgeInsets.zero,
        most: const EdgeInsets.only(left: 8, right: double.infinity, top: double.infinity, bottom: double.infinity),
        child: SizedBox(key: inner, height: 10),
      ),
    );
    await tester.pumpWidget(at(400));
    expect(tester.getTopLeft(find.byKey(inner)).dx, 0);
    await tester.pumpWidget(at(650));
    expect(tester.getTopLeft(find.byKey(inner)).dx, closeTo(5, 1e-9));
    await tester.pumpWidget(at(760));
    expect(tester.getTopLeft(find.byKey(inner)).dx, 8);
  });

  testWidgets('asked with no width, the share is nothing and so is the cap it is under', (tester) async {
    final box = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: IntrinsicWidth(
            child: Inset(
              key: box,
              insets: EdgeInsets.zero,
              shares: const EdgeInsets.only(left: 0.1),
              most: const EdgeInsets.only(
                left: 48,
                right: double.infinity,
                top: double.infinity,
                bottom: double.infinity,
              ),
              child: const SizedBox(width: 80, height: 10),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(box)).width, 80);
  });

  // fixtures/flex-item-pct-padding-calc n1: `padding-left: min(10%, 30% -
  // 100px)`, the smaller of two shares of the same row, floored at nothing
  // as a padding is. They cross at 500: under it the second binds -- and
  // comes to nothing under 333.33 -- and over it the first.
  for (final (room, left) in [(300.0, 0.0), (400.0, 20.0), (500.0, 50.0), (736.0, 73.6)]) {
    testWidgets('min(10%, 30% - 100px) of $room is $left', (tester) async {
      final inner = GlobalKey();
      await tester.pumpWidget(
        _in(
          room,
          Inset(
            insets: EdgeInsets.zero,
            shares: const EdgeInsets.only(left: 0.1),
            least: EdgeInsets.zero,
            most: const EdgeInsets.fromLTRB(-100, double.infinity, double.infinity, double.infinity),
            mostShares: const EdgeInsets.only(left: 0.3),
            child: SizedBox(key: inner, height: 10),
          ),
        ),
      );
      expect(tester.getTopLeft(find.byKey(inner)).dx, closeTo(left, 1e-9));
    });
  }

  testWidgets('NEGATIVE: a cap share of nothing leaves the cap its length', (tester) async {
    final inner = GlobalKey();
    await tester.pumpWidget(
      _in(
        736,
        Inset(
          insets: EdgeInsets.zero,
          shares: const EdgeInsets.only(left: 0.1),
          most: const EdgeInsets.fromLTRB(48, double.infinity, double.infinity, double.infinity),
          child: SizedBox(key: inner, height: 10),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(inner)).dx, 48);
  });
}
