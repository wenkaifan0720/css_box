// InlineBox.placed: what is placed against a positioned inline box, whose
// padding box is the containing block of the `absolute` boxes inside it
// (CSS 2.1 10.1). Measured in Chrome (scratch probe-inline-cb*, the
// fixtures relative-inline-positioned n1 and inline-flow-placed): over a
// box a line breaks, the rectangle runs from its first piece's start and
// top to its last piece's end and bottom -- `left: 50%; width: 50%` is
// half of that -- and where the last piece ends before the first starts,
// it is nothing wide at the first's start.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
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

Future<RenderInlineFlow> lay(WidgetTester tester, double width, List<InlineNode> kids, {Key? boundary}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
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
  );
  return tester.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
}

void main() {
  const cb = ValueKey('cb');
  Rect placedRect(WidgetTester tester) => tester.getRect(find.byKey(cb));

  testWidgets("a split box's containing block runs from its first piece's start to its last one's end", (tester) async {
    // `aa ` is 0..48; the box's words `bb cc dd` break after `cc` in 144:
    // its first piece from 48 on the first line, its last `dd`, 0..32, on
    // the second -- which ends before the first starts: nothing wide.
    const box = InlineBox(
      placed: SizedBox.expand(key: cb),
      children: [InlineText('bb cc dd')],
    );
    var r = await lay(tester, 144, const [InlineText('aa '), box, InlineText(' e')]);
    var f = r.fragmentsOf(box);
    expect(f, hasLength(2));
    expect(f.last.right, lessThan(f.first.left));
    expect(placedRect(tester), Rect.fromLTRB(f.first.left, f.first.top, f.first.left, f.last.bottom));
    // In 112, `bb` alone is on the first line (from 48) and `cc dd` (0..80)
    // on the second: from 48 to 80, both lines down.
    r = await lay(tester, 112, const [InlineText('aa '), box, InlineText(' e')]);
    f = r.fragmentsOf(box);
    expect(f, hasLength(2));
    expect(f.last.right, greaterThan(f.first.left));
    expect(placedRect(tester), Rect.fromLTRB(f.first.left, f.first.top, f.last.right, f.last.bottom));
    // Out of the flow: the lines are what they are without it.
    final lines = r.lineBaselines;
    await lay(tester, 112, const [
      InlineText('aa '),
      InlineBox(children: [InlineText('bb cc dd')]),
      InlineText(' e'),
    ]);
    expect(tester.renderObject<RenderInlineFlow>(find.byType(InlineFlow)).lineBaselines, lines);
  });

  testWidgets('it is the padding box: the border off it, the padding in it; moved with the box', (tester) async {
    const box = InlineBox(
      padding: EdgeInsets.fromLTRB(7, 2, 5, 3),
      decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide(width: 1))),
      offset: Offset(3, -2),
      placed: SizedBox.expand(key: cb),
      children: [InlineText('bb')],
    );
    final r = await lay(tester, 200, const [InlineText('a '), box]);
    final f = r.fragmentsOf(box).single; // where it is painted, moved
    expect(placedRect(tester), f.deflate(1));
  });

  testWidgets('a box on no line is a point at the line start, as text-align puts it, at the top', (tester) async {
    // Nothing but the box and collapsed white space: no line (CSS 2.1
    // 9.4.2), the flow nothing tall (fixtures/relative-inline-empty).
    Future<void> at(TextAlign align) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: InlineFlow(
              font: font(16, 20),
              style: const TextStyle(fontSize: 16),
              textAlign: align,
              children: const [
                InlineText(' '),
                InlineBox(
                  offset: Offset(0, 4),
                  placed: Stack(
                    clipBehavior: Clip.none,
                    children: [Positioned(left: 0, top: 0, width: 24, height: 14, child: SizedBox(key: cb))],
                  ),
                  children: [InlineText(' ')],
                ),
                InlineText(' '),
              ],
            ),
          ),
        ),
      ),
    );
    await at(TextAlign.start);
    expect(tester.getSize(find.byType(InlineFlow)).height, 0);
    expect(placedRect(tester), const Rect.fromLTWH(0, 4, 24, 14));
    await at(TextAlign.center);
    expect(placedRect(tester), const Rect.fromLTWH(100, 4, 24, 14));
  });

  testWidgets('what is placed paints after the flow, over the words after the box (appendix E, step 8)', (
    tester,
  ) async {
    // The box `b` is 32..48 on the one line; a 40-wide square placed
    // against it at its end runs over ` cc` (48..96).
    final key = GlobalKey();
    await lay(tester, 200, const [
      InlineText('a '),
      InlineBox(
        placed: Stack(
          clipBehavior: Clip.none,
          children: [Positioned(left: 16, top: 0, width: 40, height: 10, child: ColoredBox(color: Color(0xFFFF0000)))],
        ),
        children: [InlineText('b')],
      ),
      InlineText(' cc'),
    ], boundary: key);
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData();
      final w = image.width;
      image.dispose();
      return (bytes!, w);
    });
    (int, int, int) rgb(int x, int y) {
      final i = (y * data!.$2 + x) * 4;
      return (data.$1.getUint8(i), data.$1.getUint8(i + 1), data.$1.getUint8(i + 2));
    }

    // The content area is 2..18 (half-leading 2): the square 2..12.
    expect(rgb(70, 8), (255, 0, 0), reason: 'over the `c`');
    expect(rgb(70, 16), (0, 0, 0), reason: 'the `c` under the square');
  });
}
