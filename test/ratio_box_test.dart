// css-sizing-4 4.3: a ratio box is never shorter than what is in it, and
// the line around it has to hear that height before it lays anything out.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/src/ratio.dart' show RenderRatioBox;

void main() {
  testWidgets('the ratio decides the height where the content is shorter', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 120,
            child: RatioBox(aspectRatio: 2, child: SizedBox(key: const ValueKey('kid'), height: 10)),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(RatioBox)).height, 60);
  });

  testWidgets('the content floors it where the content is taller', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 120,
            child: RatioBox(aspectRatio: 2, child: SizedBox(key: const ValueKey('kid'), height: 100)),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(RatioBox)).height, 100);
  });

  testWidgets('the floor stops at its cap', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 40, child: RatioBox(aspectRatio: 2, maxFloor: 30, child: SizedBox(height: 60))),
        ),
      ),
    );
    expect(tester.getSize(find.byType(RatioBox)).height, 30);
  });

  testWidgets('a width it is only OFFERED is not a width it takes', (tester) async {
    // css-sizing-3 5.1: a box that is not stretched is `width: auto` in a
    // slot that only caps it, and `auto` there is shrink-to-fit. The empty
    // ratio box of `fixtures/grid-ratio-stretch-which` d5 is 0x0 in its
    // 100x100 area at `place-self: start`, the way Chrome draws it.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            height: 100,
            child: Align(
              alignment: Alignment.topLeft,
              child: RatioBox(aspectRatio: 2, child: ColoredBox(color: Color(0xFF000000))),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(RatioBox)), Size.zero);
  });

  testWidgets('and a width it is HELD to, it fills', (tester) async {
    // The same box stretched: the slot hands it 100 tight and the ratio
    // reads the depth off it.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            child: RatioBox(aspectRatio: 2, child: ColoredBox(color: Color(0xFF000000))),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(RatioBox)), const Size(100, 50));
  });

  testWidgets('offered a width, its content is what it asks for', (tester) async {
    // Shrink-to-fit is the content's max-content width, not nothing: the
    // 40-wide child holds the box open to 40, and the ratio takes 20 off it.
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            height: 100,
            child: Align(
              alignment: Alignment.topLeft,
              child: RatioBox(aspectRatio: 2, child: SizedBox(width: 40)),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(RatioBox)), const Size(40, 20));
  });

  testWidgets('it answers that floored height when it is MEASURED', (tester) async {
    // The row asks how tall the card would be before it lays it out; hearing
    // 60 there is what made the card spill into the row below.
    final box = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 120, child: RatioBox(aspectRatio: 2, child: SizedBox(height: 100))),
                SizedBox(key: box, width: 40),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(box)).height, 100);
  });

  // A column measuring how wide its child wants to be asks it how tall it is
  // with no width given, then how wide at that height (Flutter's
  // `RenderFlex`). A phone pricing page has a devices picture at
  // `width: 100%` with a ratio in a shrink-to-fit card, and it came out 0x0.
  Widget card(Widget picture) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 343,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShrinkWidth(
              spill: true,
              spillAlign: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [picture],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('at an indefinite width it is as wide as its content wants, and as tall as that gives', (tester) async {
    await tester.pumpWidget(card(const RatioBox(aspectRatio: 2, child: SizedBox(width: 200))));
    expect(tester.getSize(find.byType(RatioBox)), const Size(200, 100));
  });

  testWidgets('measured at the height it comes to by itself, its narrowest is its content\'s', (tester) async {
    // css-sizing-3 5.2.2: a picture at `width: 100%` has no min-content, so
    // the card shrinks to its room. Read from the height the column asked
    // it at, through the ratio, its narrowest was its widest, 400, and the
    // picture hung out of the card.
    await tester.pumpWidget(
      card(
        const RatioBox(
          aspectRatio: 1.5,
          child: Compressible(natural: 400, naturalHeight: 266, child: SizedBox.expand()),
        ),
      ),
    );
    expect(tester.getSize(find.byType(RatioBox)).width, 343);
    expect(tester.getSize(find.byType(RatioBox)).height, closeTo(343 / 1.5, 0.01));
  });

  test('a height it is asked at that is not its own is the ratio\'s, and an empty box is still nothing', () {
    // NEGATIVE: a row that stretches an empty box to 100 still hears 200,
    // and one with content hears the ratio at any height but its own.
    final empty = RenderRatioBox(2);
    expect(empty.getMaxIntrinsicHeight(double.infinity), 0);
    expect(empty.getMaxIntrinsicWidth(100), 200);
    expect(empty.getMinIntrinsicWidth(100), 200);
    final full = RenderRatioBox(
      1.5,
      RenderConstrainedBox(additionalConstraints: const BoxConstraints.tightFor(width: 400)),
    );
    expect(full.getMaxIntrinsicHeight(double.infinity), closeTo(400 / 1.5, 0.01));
    expect(full.getMinIntrinsicWidth(100), 150);
    expect(full.getMaxIntrinsicWidth(100), 150);
  });
}
