import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// The test font draws every glyph 14px wide at 14px, so a 140px column
// holds ten characters a line and these paragraphs break where they say.
const _three = 'aaaa bbbb cccc dddd eeee ffff';
const _two = 'gggg hhhh iiii jjjj';

Widget _page(int lines) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 140, child: _clamp(lines)),
  ),
);

/// Two paragraphs under a clamp of [lines]: three lines, padded, then two.
Widget _clamp(int lines) => LineClamp(
  lines: lines,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ClampedBlock(
        key: const Key('first'),
        bottom: 4,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: BlockEllipsis(child: const Text(_three, key: Key('p1'))),
        ),
      ),
      ClampedBlock(
        key: const Key('second'),
        child: BlockEllipsis(child: const Text(_two, key: Key('p2'))),
      ),
    ],
  ),
);

void main() {
  double heightOf(WidgetTester t, Key k) => t.getSize(find.byKey(k)).height;
  // The cut paragraph keeps every line laid out, so its height is three.
  double lineHeight(WidgetTester t) => heightOf(t, const Key('p1')) / 3;

  testWidgets('cuts the paragraph holding the Nth line, closes it on its padding, and ends the block there', (
    tester,
  ) async {
    await tester.pumpWidget(_page(2));
    final line = lineHeight(tester);
    // The paragraph keeps every line laid out (its overflow); the
    // BlockEllipsis round it is the two lines kept.
    expect(tester.getSize(find.byType(BlockEllipsis).first).height, moreOrLessEquals(2 * line, epsilon: 0.01));
    expect(heightOf(tester, const Key('first')), moreOrLessEquals(2 * line + 4, epsilon: 0.01));
    // What follows is laid out below the block, one unbroken line each:
    // its overflow.
    expect(heightOf(tester, const Key('second')), moreOrLessEquals(line, epsilon: 0.01));
    expect(tester.getSize(find.byType(LineClamp)).height, moreOrLessEquals(2 * line + 4, epsilon: 0.01));
    final p = tester.renderObject<RenderParagraph>(find.byKey(const Key('p1')));
    expect(p.text.toPlainText(), contains('…'));
  });

  testWidgets('a line in the second paragraph: the first is whole, the second is cut', (tester) async {
    await tester.pumpWidget(_page(4));
    final line = lineHeight(tester);
    expect(heightOf(tester, const Key('first')), moreOrLessEquals(3 * line + 4, epsilon: 0.01));
    expect(heightOf(tester, const Key('second')), moreOrLessEquals(line, epsilon: 0.01));
    expect(tester.getSize(find.byType(LineClamp)).height, moreOrLessEquals(4 * line + 4, epsilon: 0.01));
  });

  testWidgets('the Nth line is the first paragraph\'s last: nothing is cut', (tester) async {
    await tester.pumpWidget(_page(3));
    final line = lineHeight(tester);
    expect(heightOf(tester, const Key('first')), moreOrLessEquals(3 * line + 4, epsilon: 0.01));
    // Past the clamp all the same: one line.
    expect(heightOf(tester, const Key('second')), moreOrLessEquals(line, epsilon: 0.01));
    expect(tester.getSize(find.byType(LineClamp)).height, moreOrLessEquals(3 * line + 4, epsilon: 0.01));
    final p = tester.renderObject<RenderParagraph>(find.byKey(const Key('p1')));
    expect(p.text.toPlainText(), isNot(contains('…')));
  });

  testWidgets('fewer lines than the clamp: nothing is cut', (tester) async {
    await tester.pumpWidget(_page(10));
    final line = lineHeight(tester);
    expect(heightOf(tester, const Key('second')), moreOrLessEquals(2 * line, epsilon: 0.01));
    expect(tester.getSize(find.byType(LineClamp)).height, moreOrLessEquals(5 * line + 4, epsilon: 0.01));
    final p = tester.renderObject<RenderParagraph>(find.byKey(const Key('p1')));
    expect(p.text.toPlainText(), isNot(contains('…')));
  });

  testWidgets('a clamp that moves lets the cut paragraph go again', (tester) async {
    await tester.pumpWidget(_page(2));
    await tester.pumpWidget(_page(10));
    final line = lineHeight(tester);
    expect(heightOf(tester, const Key('first')), moreOrLessEquals(3 * line + 4, epsilon: 0.01));
    expect(heightOf(tester, const Key('second')), moreOrLessEquals(2 * line, epsilon: 0.01));
  });

  // A CLAMPED BLOCK IS ITS KEPT LINES BEFORE ITS FIRST LAYOUT TOO: a box
  // that measures what it holds before laying it out is answered the lines
  // the clamp will keep, not the whole paragraph.
  Widget at140(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 140, child: child),
    ),
  );
  Widget one(int lines, String text) => LineClamp(
    key: const Key('clamp'),
    lines: lines,
    child: ClampedBlock(
      child: BlockEllipsis(child: Text(text, key: const Key('p1'))),
    ),
  );

  testWidgets('asked before its first layout, a clamped block answers the lines it will keep', (tester) async {
    // One paragraph of three lines under a clamp of two.
    await tester.pumpWidget(at140(_AskFirst(child: one(2, _three))));
    final line = lineHeight(tester);
    final ask = tester.renderObject<_RenderAskFirst>(find.byType(_AskFirst));
    expect(ask.intrinsic, moreOrLessEquals(2 * line, epsilon: 0.01));
    expect(ask.dry, moreOrLessEquals(2 * line, epsilon: 0.01));
    expect(heightOf(tester, const Key('clamp')), moreOrLessEquals(2 * line, epsilon: 0.01));
    // A row stretched to what an `IntrinsicHeight` asks it, as a grid
    // sizes a row of cards, is the two lines.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      at140(
        IntrinsicHeight(
          child: Row(
            key: const Key('row'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: one(2, _three)),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
    expect(heightOf(tester, const Key('row')), moreOrLessEquals(2 * line, epsilon: 0.01));
    // The Nth line in the second paragraph: the first is whole and the
    // second is handed the one line left.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(at140(_AskFirst(child: _clamp(4))));
    final ask4 = tester.renderObject<_RenderAskFirst>(find.byType(_AskFirst));
    expect(ask4.intrinsic, moreOrLessEquals(4 * line + 4, epsilon: 0.01));
    expect(ask4.dry, moreOrLessEquals(4 * line + 4, epsilon: 0.01));
    expect(tester.getSize(find.byType(LineClamp)).height, moreOrLessEquals(4 * line + 4, epsilon: 0.01));
    // Past the cut a paragraph is asked as one unbroken line, and the clamp
    // is asked where its layout ends it: at the box holding the cut, two
    // lines and the padding. Before, it answered what it holds -- what
    // follows the cut too: its one unbroken line, 3 lines and the padding.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(at140(_AskFirst(child: _clamp(2))));
    final ask2 = tester.renderObject<_RenderAskFirst>(find.byType(_AskFirst));
    expect(ask2.dry, moreOrLessEquals(2 * line + 4, epsilon: 0.01));
    expect(ask2.intrinsic, moreOrLessEquals(2 * line + 4, epsilon: 0.01));
    expect(tester.getSize(find.byType(LineClamp)).height, moreOrLessEquals(2 * line + 4, epsilon: 0.01));
  });

  testWidgets('NEGATIVE: a paragraph the clamp leaves whole, or with no clamp round it, answers as it always has', (
    tester,
  ) async {
    await tester.pumpWidget(_page(2));
    final line = lineHeight(tester);
    // Two lines under a clamp of four: whole.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(at140(_AskFirst(child: one(4, _two))));
    var ask = tester.renderObject<_RenderAskFirst>(find.byType(_AskFirst));
    expect(ask.intrinsic, moreOrLessEquals(2 * line, epsilon: 0.01));
    expect(ask.dry, moreOrLessEquals(2 * line, epsilon: 0.01));
    // No clamp round it: the paragraph's own lines, and its own maxLines.
    for (final (text, lines) in [
      (const Text(_three), 3),
      (const Text(_three, maxLines: 2, overflow: TextOverflow.ellipsis), 2),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(at140(_AskFirst(child: BlockEllipsis(child: text))));
      ask = tester.renderObject<_RenderAskFirst>(find.byType(_AskFirst));
      expect(ask.intrinsic, moreOrLessEquals(lines * line, epsilon: 0.01));
      expect(ask.dry, moreOrLessEquals(lines * line, epsilon: 0.01));
    }
  });
}

/// Asks its child's height -- intrinsic and dry -- BEFORE laying it out, as
/// a grid sizing its rows does, and keeps what it was answered.
class _AskFirst extends SingleChildRenderObjectWidget {
  const _AskFirst({super.child});

  @override
  _RenderAskFirst createRenderObject(BuildContext context) => _RenderAskFirst();
}

class _RenderAskFirst extends RenderProxyBox {
  double? intrinsic, dry;

  @override
  void performLayout() {
    final c = child!;
    intrinsic = c.getMaxIntrinsicHeight(constraints.maxWidth);
    dry = c.getDryLayout(constraints.loosen()).height;
    c.layout(constraints, parentUsesSize: true);
    size = c.size;
  }
}
