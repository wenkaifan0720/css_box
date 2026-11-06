// A LineClamp asked its height answers where its layout ends it -- at the
// box holding the cut -- and the same after its layout as before.
//
// The clamp's layout tells the blocks inside their budgets. Asked dry, it
// passed the question to what it holds, which answered the whole: what
// follows the cut too, and after the layout each block at its budget. An
// a profile card's two-line clamp laid out 46 tall then answered 72,
// and the grid round the cards, measuring again after a frame, grew them
// 212 -> 248.
import 'package:css_box/css_box.dart';
import 'package:css_box/src/ellipsis.dart' show RenderLineClamp;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 10px wide at 10px; on 2.0 lines each
// line is 20 tall, and a 100px column holds ten characters a line.
const _style = TextStyle(fontSize: 10, height: 2);
const _two = 'aaaa bbbb cccc dddd';

/// Under a clamp of [lines]: a block holding [first] (built at [own] lines
/// where that is set), then a paragraph of one line -- in a box that lets
/// them spill past the height the clamp is handed, as the lowering writes
/// a block's flow (`SpillHeight`).
Widget _clamp({int lines = 2, String first = _two, int? own}) => LineClamp(
  lines: lines,
  child: OverflowBox(
    alignment: Alignment.topLeft,
    minHeight: 0,
    maxHeight: double.infinity,
    fit: OverflowBoxFit.deferToChild,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClampedBlock(
          child: BlockEllipsis(
            textOverflow: true,
            child: LineBox(
              child: Text(first, maxLines: own, overflow: own == null ? null : TextOverflow.ellipsis, style: _style),
            ),
          ),
        ),
        const BlockEllipsis(
          textOverflow: true,
          child: LineBox(
            child: Text('eeee', maxLines: 2, overflow: TextOverflow.ellipsis, style: _style),
          ),
        ),
      ],
    ),
  ),
);

Widget _at100(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 100, child: child),
  ),
);

/// The clamp in a row an `IntrinsicHeight` stretches to what it asks, as a
/// grid sizes a row of cards.
Widget _row(Widget clamp) => _at100(
  IntrinsicHeight(
    key: const Key('grid'),
    child: Row(
      key: const Key('row'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: clamp),
        const SizedBox(width: 0),
      ],
    ),
  ),
);

void main() {
  testWidgets('a clamp answers the height it is laid out at, before its layout and after', (t) async {
    await t.pumpWidget(_at100(_AskFirst(child: _clamp())));
    final ask = t.renderObject<_RenderAskFirst>(find.byType(_AskFirst));
    final box = t.renderObject<RenderLineClamp>(find.byType(LineClamp));
    // The first paragraph's two lines; the line after them is the overflow.
    expect(box.size.height, 40);
    expect(ask.dry, 40);
    expect(ask.intrinsic, 40);
    expect(box.getDryLayout(const BoxConstraints.tightFor(width: 100)).height, 40);
    expect(box.getMinIntrinsicHeight(100), 40);
    expect(box.getMaxIntrinsicHeight(100), 40);
  });

  testWidgets('laid out again, an unchanged clamp keeps its height', (t) async {
    // The card's shape: the first paragraph built at one line, its
    // text two, handed the clamp's two -- laid out at two lines.
    for (final own in [null, 1]) {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(_row(_clamp(own: own)));
      final first = t.getSize(find.byKey(const Key('row'))).height;
      expect(first, 40, reason: 'own $own');
      // A post-frame pass: the grid lays its row out again.
      t.renderObject<RenderBox>(find.byKey(const Key('grid'))).markNeedsLayout();
      await t.pump();
      expect(t.getSize(find.byKey(const Key('row'))).height, first, reason: 'own $own');
      expect(t.getSize(find.byType(LineClamp)).height, 40, reason: 'own $own');
    }
  });

  testWidgets('the walk to the cut goes through padding, a spill, a link and a clip', (t) async {
    // an inbox thread title: the clamped block in a `Press` (a
    // semantics node, a mouse region, a gesture detector), and the block
    // closing on its padding.
    final clamp = LineClamp(
      lines: 2,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          fit: OverflowBoxFit.deferToChild,
          child: Semantics(
            link: true,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {},
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ClampedBlock(
                      bottom: 3,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: ClipRect(
                          child: BlockEllipsis(
                            textOverflow: true,
                            child: LineBox(child: Text('$_two eeee', style: _style)),
                          ),
                        ),
                      ),
                    ),
                    const BlockEllipsis(
                      child: LineBox(child: Text('ffff', style: _style)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpWidget(_at100(_AskFirst(child: clamp)));
    final ask = t.renderObject<_RenderAskFirst>(find.byType(_AskFirst));
    final box = t.renderObject<RenderLineClamp>(find.byType(LineClamp));
    // 4 over the two kept lines of three, and the block's 3 under them.
    expect(box.size.height, 47);
    expect(ask.dry, 47);
    expect(ask.intrinsic, 47);
    expect(box.getDryLayout(const BoxConstraints(maxWidth: 100)).height, 47);
  });

  testWidgets('NEGATIVE: a clamp that cuts nothing answers what it holds', (t) async {
    await t.pumpWidget(_at100(_AskFirst(child: _clamp(lines: 4))));
    final ask = t.renderObject<_RenderAskFirst>(find.byType(_AskFirst));
    final box = t.renderObject<RenderLineClamp>(find.byType(LineClamp));
    expect(box.size.height, 60);
    expect(ask.dry, 60);
    expect(box.getDryLayout(const BoxConstraints.tightFor(width: 100)).height, 60);
    expect(box.getMaxIntrinsicHeight(100), 60);
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
