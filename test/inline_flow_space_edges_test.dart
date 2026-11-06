// A collapsible space after another collapsible space is removed "even one
// outside the boundary of the inline containing that space" (css-text-3
// 4.1.1): the edges of boxes between the two -- their padding, border and
// margin included -- do not keep it. Measured in Chrome
// (fixtures/inline-flow-space-edges; relative-inline-empty n1, a relative
// span of white space alone between two words, is a point after the
// first word's space).
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RenderInlineFlow> lay(WidgetTester tester, List<InlineNode> kids) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          child: InlineFlow(
            font: const InlineFont(size: 16, ascent: 13, descent: 3, lineHeight: 20, xHeight: 12.8),
            style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
            children: kids,
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
}

/// Where [word]'s first glyph stands: the piece it is in -- a run's words
/// and spaces on one line are one piece -- and the glyphs before it there,
/// each 16 wide in the test face.
double xOf(RenderInlineFlow r, String word) {
  final p = r.pieces.firstWhere((p) => p.text.contains(word));
  return p.x + p.text.indexOf(word) * 16;
}

void main() {
  // The test face is 16px a glyph, the space too: `a ` is 0..32.
  const k = ValueKey('k');

  testWidgets('a box of white space alone between two spaces is a point after the first', (tester) async {
    final r = await lay(tester, const [
      InlineText('a '),
      InlineBox(key: k, children: [InlineText(' '), InlineText(' ')]),
      InlineText(' b'),
    ]);
    expect(r.boxRects[k]!.left, 32);
    expect(r.boxRects[k]!.width, 0);
    expect(xOf(r, 'b'), 32);
  });

  testWidgets('a padded box opening on a space after a space: its space is gone', (tester) async {
    final r = await lay(tester, const [
      InlineText('a '),
      InlineBox(key: k, padding: EdgeInsets.symmetric(horizontal: 6), children: [InlineText(' b')]),
      InlineText(' c'),
    ]);
    // `b` right inside the padding, the box 6 + 16 + 6 wide, and the
    // space before `c` kept: it follows a word.
    expect(xOf(r, 'b'), 38);
    expect(r.boxRects[k]!.width, 28);
    expect(xOf(r, 'c'), 76);
  });

  testWidgets('one box closing on a space and the next opening on one', (tester) async {
    final r = await lay(tester, const [
      InlineBox(children: [InlineText('a ')]),
      InlineBox(padding: EdgeInsets.symmetric(horizontal: 6), children: [InlineText(' b')]),
    ]);
    expect(xOf(r, 'b'), 38);
  });

  testWidgets('NEGATIVE: a preserved space takes nothing away, both stay', (tester) async {
    final r = await lay(tester, const [
      InlineText('a'),
      InlineBox(whiteSpace: WhiteSpace.preWrap, children: [InlineText(' ')]),
      InlineText(' b'),
    ]);
    expect(xOf(r, 'b'), 48);
  });

  testWidgets('NEGATIVE: an atomic inline between: the space after it stays', (tester) async {
    final r = await lay(tester, const [
      InlineText('a '),
      InlineAtom(child: SizedBox(width: 10, height: 10)),
      InlineText(' b'),
    ]);
    expect(xOf(r, 'b'), 58);
  });
}
