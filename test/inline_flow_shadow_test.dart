// A box of ONE fragment in an InlineFlow is painted uncut, as a block's
// decoration is: an outer shadow falls outside its border box
// (css-backgrounds-3 7.1.1), and an `OuterShadow` is cut out of the box:
// nothing of it is seen through what the box paints over it. The flow
// paints each line in tree order, a box's decoration at
// its start (CSS 2.1 appendix E, 7.2.1): over the words before the box,
// under the words after it. A fragment of several is its slice of the
// strip, cut to its own border box, as before.
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

InlineFont font(double size, double lineHeight) => InlineFont(
  size: size,
  ascent: (size * 0.8).roundToDouble(),
  descent: (size * 0.2).roundToDouble(),
  lineHeight: lineHeight,
  xHeight: size * 0.8,
);

Future<(ByteData, int)> shoot(WidgetTester tester, double width, List<InlineNode> kids) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: width,
                child: InlineFlow(
                  font: font(16, 20),
                  style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
                  children: kids,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData();
    final w = image.width;
    image.dispose();
    return (bytes!, w);
  }))!;
}

void main() {
  // A crisp shadow 6px down: the box is 32..48 across (after `a `, Ahem's
  // 16px letters), its content area 13 over the baseline and 3 under it,
  // 20 in from the picture's corner.
  const shade = Color(0xFF000000);
  const cast = OuterShadow(
    shadows: [BoxShadow(color: shade, offset: Offset(0, 6))],
  );

  testWidgets('a box of one fragment casts its shadow outside its border box, cut out of it', (tester) async {
    final data = await shoot(tester, 300, const [
      InlineText('a '),
      InlineBox(padding: EdgeInsets.symmetric(horizontal: 8), decoration: cast),
      InlineText(' cc'),
    ]);
    (int, int, int) rgb(int x, int y) {
      final i = (y * data.$2 + x) * 4;
      return (data.$1.getUint8(i), data.$1.getUint8(i + 1), data.$1.getUint8(i + 2));
    }

    // The line's baseline is 15 down (a 20px line: the ascent 13 and half
    // the leading over it): the border box runs 2..18 down, the shadow
    // 8..24, 20 in.
    expect(rgb(20 + 40, 20 + 21), (0, 0, 0), reason: 'the shadow under the box, uncut');
    expect(rgb(20 + 40, 20 + 10), (255, 255, 255), reason: 'the box: the shadow is cut out of it');
    expect(rgb(20 + 40, 20 + 27), (255, 255, 255), reason: 'past the shadow');
  });

  testWidgets('a fragment of several is cut to its own box, the shadow with it', (tester) async {
    // Two words 96 wide in a flow of 100: the box breaks between them.
    final data = await shoot(tester, 100, const [
      InlineBox(decoration: cast, children: [InlineText('bbbb cccc')]),
    ]);
    (int, int, int) rgb(int x, int y) {
      final i = (y * data.$2 + x) * 4;
      return (data.$1.getUint8(i), data.$1.getUint8(i + 1), data.$1.getUint8(i + 2));
    }

    // The first fragment is 2..18 down on the first line, the second 22..38
    // on the next: between them, where the first's shadow would fall uncut
    // (8..24), is nothing.
    expect(rgb(20 + 30, 20 + 21), (255, 255, 255), reason: 'no shadow under the first fragment: it is cut to its box');
  });
}
