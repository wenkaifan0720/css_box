// InlineMark: the point an out-of-flow box came out of a line at, which is
// its static position across (CSS 2.1 10.3.7) -- only the lines know it.
// It takes no room and is no soft wrap opportunity (css-text-3 5.1), and a
// point that ends a line stays on it, at the end of its words: the space
// before it hangs (4.1.3). Measured in Chrome, `fixtures/inline-flow-placed`
// n1: a `top: 0` box after `messages are ` in a relative span the line
// breaks after stands at the end of `are`, where the span's first piece
// ends too.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

InlineFont font(double size, double lineHeight) => InlineFont(
  size: size,
  ascent: (size * 0.8).roundToDouble(),
  descent: (size * 0.2).roundToDouble(),
  lineHeight: lineHeight,
  xHeight: size * 0.8,
);

const _point = ValueKey('point');
const _badge = ValueKey('badge');

Future<RenderInlineFlow> lay(WidgetTester tester, double width, List<InlineNode> kids) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SpotScope(
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
  );
  return tester.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
}

void main() {
  testWidgets('a point that ends a line stays on it, at the end of its words', (tester) async {
    // `aa bb ` is 96 of 112, and `cc` does not fit after it: the break
    // before the point is taken after it, and the space before it hangs --
    // the point is at the end of `bb`, 80 in.
    final r = await lay(tester, 112, const [
      InlineText('aa bb '),
      InlineMark(child: SizedBox.shrink(key: _point)),
      InlineText('cc'),
    ]);
    expect(r.lineBaselines, hasLength(2));
    expect(tester.getTopLeft(find.byKey(_point)), const Offset(80, 0));
  });

  testWidgets('a point is no break opportunity', (tester) async {
    // `aabb` is one word, 64 in 48: it overflows its one line whole.
    final r = await lay(tester, 48, const [
      InlineText('aa'),
      InlineMark(child: SizedBox.shrink(key: _point)),
      InlineText('bb'),
    ]);
    expect(r.lineBaselines, hasLength(1));
    expect(tester.getTopLeft(find.byKey(_point)), const Offset(32, 0));
  });

  testWidgets('it stands at the top of its line, and takes no room', (tester) async {
    final without = await lay(tester, 112, const [InlineText('aa bb cc dd')]);
    final lines = without.lineBaselines, size = without.size;
    final r = await lay(tester, 112, const [
      InlineText('aa bb cc '),
      InlineMark(child: SizedBox.shrink(key: _point)),
      InlineText('dd'),
    ]);
    expect(r.lineBaselines, lines);
    expect(r.size, size);
    // `aa bb cc` breaks after `bb `: the point is on the second line,
    // after `cc `.
    expect(tester.getTopLeft(find.byKey(_point)), const Offset(48, 20));
  });

  testWidgets('a shift in what is placed against the box finds it', (tester) async {
    // The span `bb cc ` from 48 breaks after `bb `; `top: 0` is its first
    // piece's top -- its content area, 2 under the line's top, half the
    // leading of 20 over 16 -- and across the box stands where it came
    // out: after `cc ` on the second line, 48 in.
    await lay(tester, 112, const [
      InlineText('aa '),
      InlineBox(
        placed: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              child: SpotShift(id: 1, across: true, down: false, child: SizedBox(key: _badge, width: 8, height: 8)),
            ),
          ],
        ),
        children: [
          InlineText('bb cc '),
          InlineMark(child: SpotMark(id: 1)),
          InlineText('dd'),
        ],
      ),
      InlineText(' ee'),
    ]);
    expect(tester.getTopLeft(find.byKey(_badge)), const Offset(48, 2));
  });

  testWidgets('NEGATIVE: a flow of nothing but a point is no line; the point is where one would start', (tester) async {
    final r = await lay(tester, 112, const [InlineMark(child: SizedBox.shrink(key: _point))]);
    expect(r.lineBaselines, isEmpty);
    expect(r.size.height, 0);
    expect(tester.getTopLeft(find.byKey(_point)), Offset.zero);
  });
}
