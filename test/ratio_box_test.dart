// css-sizing-4 4.3: a ratio box is never shorter than what is in it, and
// the line around it has to hear that height before it lays anything out.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

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
}
