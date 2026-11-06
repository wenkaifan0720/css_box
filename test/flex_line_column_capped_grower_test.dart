// A COLUMN CLAMPED BY ITS OWN CEILING ROUND ONE ITEM THAT GROWS AND SHRINKS
// TO NOTHING IS THAT ITEM, ALL OF IT (css-sizing-3 5.1; css-flexbox-1 9.4
// step 11, 9.7, 4.5). A column whose height is its content's is that clamped
// by its `max-height`, and stretched across a row the line's depth clamped
// the same way; its one item grows into a column deeper than its content
// and, at `min-height: 0` or clipped, shrinks into one shallower. A docs site's
// code sandboxes are each a column of `max-height: 406px` round a body of
// `flex-grow: 1; min-height: 0`, an editor and a preview side by side in a
// row css_box keeps (`fixtures/flex-column-capped-grower`). The lowerer
// (`lossy_flex.dart`, `_cappedGrowerL`) writes the column as an
// `IntrinsicHeight` round a `Column` of the item `Expanded`, under the
// ceiling's `ConstrainedBox`, and tidy prints the `Column` of one `Expanded`
// as a `SizedBox.expand`: handed a height tight it is all of it, handed a
// ceiling it is its content tightened into the ceiling, and asked its height
// it answers its content, which the ceiling clamps. This pins css_box's
// column and the two stock spellings to the same boxes, alone and stretched
// in a row beside a box deeper or shallower than the column, the content
// under and over the ceiling, at several widths.
// NEGATIVE: an automatic floor, which holds the item at its content past the
// ceiling (n1); an item that does not grow, which a stretch deeper than its
// content leaves at it (n2): there the spellings part, and the lowerer keeps
// css_box's line.
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _cap = 200.0;

/// The body round [content] of code: a box that may be laid out shallower
/// than what it holds, which hangs out of it, clipped.
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

/// css_box's column: `display: flex; flex-direction: column; max-height:
/// 200px` round the body.
Widget _line(FlexCell body) => ConstrainedBox(
  key: const ValueKey('c'),
  constraints: const BoxConstraints(maxHeight: _cap),
  child: FlexLine(direction: Axis.vertical, maxExtent: _cap, children: [body]),
);

/// The lowerer's `Column` of the body `Expanded`, in an `IntrinsicHeight`.
Widget _column(double content) => ConstrainedBox(
  key: const ValueKey('c'),
  constraints: const BoxConstraints(maxHeight: _cap),
  child: IntrinsicHeight(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: _body(content))],
    ),
  ),
);

/// The same as tidy prints it.
Widget _expand(double content) => ConstrainedBox(
  key: const ValueKey('c'),
  constraints: const BoxConstraints(maxHeight: _cap),
  child: IntrinsicHeight(child: SizedBox.expand(child: _body(content))),
);

/// The column alone, [width] wide, offered all the height there is.
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

Future<List<Rect>> _rects(WidgetTester t, Widget w, List<String> keys) async {
  await t.pumpWidget(w);
  return [for (final k in keys) t.getRect(find.byKey(ValueKey(k)))];
}

FlexCell _grower(double content) => FlexCell(grow: 1, min: 0, child: _body(content));

void main() {
  for (final width in const [400.0, 300.0, 120.0]) {
    for (final content in const [100.0, 300.0]) {
      testWidgets('p1, p2: alone, content $content, $width wide', (t) async {
        final css = await _rects(t, _alone(_line(_grower(content)), width), const ['c', 'b']);
        expect(css, [for (var i = 0; i < 2; i++) Rect.fromLTWH(0, 0, width, content < _cap ? content : _cap)]);
        expect(await _rects(t, _alone(_column(content), width), const ['c', 'b']), css);
        expect(await _rects(t, _alone(_expand(content), width), const ['c', 'b']), css);
      });
      testWidgets('p5: clipped, no floor, content $content, $width wide', (t) async {
        final css = await _rects(t, _alone(_line(FlexCell(grow: 1, clips: true, child: _body(content))), width), const [
          'c',
          'b',
        ]);
        expect(await _rects(t, _alone(_expand(content), width), const ['c', 'b']), css);
      });
      for (final side in const [50.0, 150.0, 180.0, 260.0]) {
        testWidgets('p3, p4: in a row beside $side, content $content, $width wide', (t) async {
          const keys = ['row', 'c', 'b', 's'];
          final css = await _rects(t, _inRow(_line(_grower(content)), width, side), keys);
          // The line is the deeper of the column's content and the side,
          // the column that clamped (the side may hang past it).
          final depth = [content, side].reduce((a, b) => a > b ? a : b).clamp(0.0, _cap);
          expect(css[1].height, depth);
          expect(css[2].height, depth);
          expect(await _rects(t, _inRow(_column(content), width, side), keys), css);
          expect(await _rects(t, _inRow(_expand(content), width, side), keys), css);
        });
      }
    }
    testWidgets('n1: NEGATIVE, an automatic floor holds the item past the ceiling, $width wide', (t) async {
      final css = await _rects(t, _alone(_line(FlexCell(grow: 1, child: _body(300))), width), const ['c', 'b']);
      expect(css, [Rect.fromLTWH(0, 0, width, _cap), Rect.fromLTWH(0, 0, width, 300)]);
      expect(await _rects(t, _alone(_expand(300), width), const ['c', 'b']), isNot(css));
    });
    testWidgets('n2: NEGATIVE, an item that does not grow stays its content in a deeper stretch, $width wide', (
      t,
    ) async {
      const keys = ['row', 'c', 'b', 's'];
      final css = await _rects(t, _inRow(_line(FlexCell(min: 0, child: _body(100))), width, 180), keys);
      expect(css[1].height, 180);
      expect(css[2].height, 100);
      expect(await _rects(t, _inRow(_expand(100), width, 180), keys), isNot(css));
    });
  }
}
