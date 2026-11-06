import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A NUMBER'S LINE IS CUT DOWN ONTO BLINK'S 1/64 GRID, A LENGTH'S ROUNDED
// ([RenderLineBox.height]). Three lines of text under a forced strut, the
// LineBox told the line as `line-height: <number>` is ([LineBox.height]) or
// as the length the product comes to ([LineBox.lineHeight]): the box is
// three of the line either way, and only the grid step differs.
Widget _lines({required double size, double? height, double? lineHeight}) {
  final share = height ?? lineHeight! / size;
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        child: LineBox(
          key: const Key('l'),
          height: height,
          lineHeight: lineHeight,
          child: Text(
            'a\nb\nc',
            style: TextStyle(fontSize: size, height: share, leadingDistribution: ui.TextLeadingDistribution.even),
            strutStyle: StrutStyle(
              fontSize: size,
              height: share,
              leading: 0,
              leadingDistribution: ui.TextLeadingDistribution.even,
              forceStrutHeight: true,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  double tall(WidgetTester t) => t.getSize(find.byKey(const Key('l'))).height;

  testWidgets('a fluid size times a number is cut down onto the grid, where its product as a length rounds', (
    tester,
  ) async {
    // `clamp(22px, 0.227vw + 21.274px, 24px)` at 390, `line-height: 1.25`:
    // the size goes onto the grid rounded (22.15625), and 1.25 of it is
    // 27.6953125, cut down to 27.6875 -- Chrome's line. The product as a
    // length, 27.699, rounds to 27.703125.
    const size = 390 * 0.00227 + 21.274;
    await tester.pumpWidget(_lines(size: size, height: 1.25));
    expect(tall(tester), 3 * 27.6875);
    await tester.pumpWidget(_lines(size: size, lineHeight: size * 1.25));
    expect(tall(tester), 3 * 27.703125);
  });

  testWidgets('each step is in floats, as Blink works it', (tester) async {
    // 4/3 at 15px: the percentage is 133.333328 in a float, 15 times it
    // over 100 is 19.9999992, and the line 19.984375 -- a 64th short of 20.
    await tester.pumpWidget(_lines(size: 15, height: 4 / 3));
    expect(tall(tester), 3 * 19.984375);
    // 1.5 at 14.4px: the size onto the grid ROUNDED, 14.40625, so 21.609375
    // where the size cut down would make it 21.578125.
    await tester.pumpWidget(_lines(size: 14.4, height: 1.5));
    expect(tall(tester), 3 * 21.609375);
  });

  testWidgets('the size is the text\'s, and follows it', (tester) async {
    await tester.pumpWidget(_lines(size: 16, height: 1.25));
    expect(tall(tester), 60);
    await tester.pumpWidget(_lines(size: 24, height: 1.25));
    expect(tall(tester), 90);
  });

  testWidgets('a child that is not a paragraph is left alone', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: LineBox(key: Key('l'), height: 1.25, child: SizedBox(width: 10, height: 33)),
        ),
      ),
    );
    expect(tall(tester), 33);
  });
}
