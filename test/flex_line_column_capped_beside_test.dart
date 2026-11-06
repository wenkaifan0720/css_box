// BESIDE THE ONE ITEM THAT GROWS AND SHRINKS TO NOTHING, ITEMS OF A LENGTH
// THAT NEVER CHANGES STAND AT IT (css-flexbox-1 9.7 step 2, 4.5;
// css-sizing-3 5.1). A column whose height is its content's is that clamped
// by its `max-height`; an item of `flex-shrink: 0` and a stated length that
// does not grow is frozen at that length, so the one item that may give way
// gives all of it, down to nothing at `min-height: 0`.
// `fixtures/flex-column-capped-grower` n3: a body of `flex: 1 1 auto;
// min-height: 0` round 300 under a heading of `height: 40px; flex-shrink: 0`
// in a column of `max-height: 200px` -- Chrome stands the
// body 160 tall at 40. The lowerer wrote it a css_box line (`FlexLine`, told
// the cap); the stock pass now writes it as it writes the one item alone
// (`lossy_flex.dart`, `_cappedGrowerL`): an `IntrinsicHeight` round a
// `Column` of the heading's `SizedBox` and the body `Expanded`, under the
// ceiling's `ConstrainedBox`. This pins the two to the engine's numbers and
// to each other: alone and stretched in a row css_box keeps beside a box
// deeper or shallower than the column, the content under and over the
// ceiling, two headings a gap apart, at several widths -- the boxes, the
// column's baseline (the heading's text), its intrinsic heights and its dry
// layout.
// NEGATIVE: a heading that may shrink gives its share of the overflow by its
// base (9.7 step 4c), which the `Column` does not: there the two part, and
// the stock pass keeps the line.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _cap = 200.0;

/// The body round [content]: a box that may be laid out shallower than
/// what it holds, which hangs out of it, clipped.
Widget _body(double content) => ColoredBox(
  key: const ValueKey('b'),
  color: const Color(0xFF336699),
  child: ClipRect(
    child: OverflowBox(
      minHeight: 0,
      maxHeight: double.infinity,
      fit: OverflowBoxFit.deferToChild,
      alignment: Alignment.topLeft,
      child: SizedBox(height: content),
    ),
  ),
);

/// A heading: a word on a baseline in a box the cell holds at its length.
Widget _heading(String key) => ColoredBox(
  key: ValueKey(key),
  color: const Color(0xFF993366),
  child: const Text('Tab', style: TextStyle(fontSize: 14, height: 1)),
);

typedef _Shape = ({List<double> heads, double gap, double content, bool headsShrink});

/// css_box's column, as the lowerer writes it.
Widget _line(_Shape s) => ConstrainedBox(
  key: const ValueKey('c'),
  constraints: const BoxConstraints(maxHeight: _cap),
  child: FlexLine(
    direction: Axis.vertical,
    maxExtent: _cap,
    spacing: s.gap,
    children: [
      for (var i = 0; i < s.heads.length; i++)
        FlexCell(shrink: s.headsShrink ? 1 : 0, mainSize: s.heads[i], child: _heading('h$i')),
      FlexCell(grow: 1, min: 0, child: _body(s.content)),
    ],
  ),
);

/// The stock pass's spelling.
Widget _stock(_Shape s) => ConstrainedBox(
  key: const ValueKey('c'),
  constraints: const BoxConstraints(maxHeight: _cap),
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: _cap),
    child: IntrinsicHeight(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: s.gap,
        children: [
          for (var i = 0; i < s.heads.length; i++) SizedBox(height: s.heads[i], child: _heading('h$i')),
          Expanded(child: _body(s.content)),
        ],
      ),
    ),
  ),
);

Widget _alone(Widget column, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: column),
  ),
);

/// The column in a row css_box keeps, beside a box [side] deep: stretched
/// to the line's depth, which its ceiling clamps.
Widget _inRow(Widget column, double width, double side) => _alone(
  FlexLine(
    key: const ValueKey('row'),
    children: [
      FlexCell(grow: 1, crossMax: _cap, child: column),
      SizedBox(key: const ValueKey('s'), width: 50, height: side),
    ],
  ),
  width,
);

T _guarded<T>(T Function() ask) {
  final was = RenderObject.debugCheckingIntrinsics;
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return ask();
  } finally {
    RenderObject.debugCheckingIntrinsics = was;
  }
}

Future<Map<String, Object?>> _read(WidgetTester t, Widget page, List<String> keys, double width) async {
  await t.pumpWidget(page);
  final c = t.renderObject<RenderBox>(find.byKey(const ValueKey('c')));
  return {
    for (final k in keys) k: t.getRect(find.byKey(ValueKey(k))),
    'baseline': _guarded(() => c.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true)),
    // At the width the line is handed: the stock pass writes a stretched
    // column bare where its width is tight, as on each page here, and in an
    // `IntrinsicWidth` where it is not (`lossy_flex.dart`, `crossWrapped`).
    'dryBaseline': c.getDryBaseline(BoxConstraints.tightFor(width: width), TextBaseline.alphabetic),
    'dry': c.getDryLayout(BoxConstraints.tightFor(width: width)),
    'dryTight': c.getDryLayout(BoxConstraints.tightFor(width: width, height: 120)),
    'minH': c.getMinIntrinsicHeight(width),
    'maxH': c.getMaxIntrinsicHeight(width),
  };
}

void main() {
  for (final width in const [400.0, 300.0, 120.0]) {
    for (final content in const [100.0, 300.0]) {
      for (final (heads, gap) in const [
        ([40.0], 0.0),
        ([40.0, 20.0], 8.0),
      ]) {
        final s = (heads: heads, gap: gap, content: content, headsShrink: false);
        final held = heads.fold(0.0, (a, b) => a + b) + gap * heads.length;
        final keys = ['c', for (var i = 0; i < heads.length; i++) 'h$i', 'b'];
        testWidgets('alone: heads $heads a gap of $gap apart, content $content, $width wide', (t) async {
          final css = await _read(t, _alone(_line(s), width), keys, width);
          // The engine's numbers: the heads at their lengths, the body what
          // they leave of the column, its content clamped by the ceiling.
          final column = (held + content).clamp(0.0, _cap);
          expect(css['c'], Rect.fromLTWH(0, 0, width, column));
          expect(css['h0'], Rect.fromLTWH(0, 0, width, heads.first));
          expect(css['b'], Rect.fromLTWH(0, held, width, column - held));
          if (heads.length == 1 && content == 300) expect((css['b']! as Rect).height, 160);
          final stock = await _read(t, _alone(_stock(s), width), keys, width);
          for (final k in css.keys) {
            expect(stock[k], css[k], reason: k);
          }
        });
        for (final side in const [50.0, 150.0, 180.0, 260.0]) {
          testWidgets('in a row beside $side: heads $heads a gap of $gap apart, content $content, $width wide', (
            t,
          ) async {
            final rowKeys = ['row', 's', ...keys];
            final css = await _read(t, _inRow(_line(s), width, side), rowKeys, width);
            final depth = [held + content, side].reduce((a, b) => a > b ? a : b).clamp(0.0, _cap);
            expect((css['c']! as Rect).height, depth);
            expect((css['b']! as Rect).height, depth - held);
            final stock = await _read(t, _inRow(_stock(s), width, side), rowKeys, width);
            for (final k in css.keys) {
              expect(stock[k], css[k], reason: k);
            }
          });
        }
      }
    }
    testWidgets('NEGATIVE: a heading that may shrink gives its share of the overflow, $width wide', (t) async {
      const s = (heads: [40.0], gap: 0.0, content: 300.0, headsShrink: true);
      final css = await _read(t, _alone(_line(s), width), const ['c', 'h0', 'b'], width);
      expect((css['h0']! as Rect).height, lessThan(40));
      final stock = await _read(t, _alone(_stock(s), width), const ['c', 'h0', 'b'], width);
      expect(stock['h0'], isNot(css['h0']));
    });
  }
}
