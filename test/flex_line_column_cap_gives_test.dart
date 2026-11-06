// A COLUMN OF NO HEIGHT OF ITS OWN UNDER A CAP IS A LINE WHERE AN ITEM MAY
// GIVE WAY (css-flexbox-1 9.2 step 4, 9.7, 4.5; css-sizing-3 5.1). Its
// length is its content's clamped by its `max-height`, and where the content
// outgrows the cap each item that may shrink gives way into it, down to its
// floor -- nothing for one at `min-height: 0` or clipped. A docs site's code
// sandboxes are each a column of `max-height: 406px` round a body of
// `flex-grow: 1; min-height: 0` (`fixtures/flex-column-capped-grower`). The
// lowerer wrote such a column as a `Column` in a `Spill` under the cap's
// `ConstrainedBox` -- its items at their content under no ceiling, the cap
// clamping only the column after -- and now writes it a `FlexBox` told the
// cap (`lower.dart`, `capGives`), which css_box's `FlexLine` lays out by 9.7
// against `maxExtent`. This pins the line to Chrome's boxes and the old
// spelling apart from them, the content under and over the cap, at several
// widths: p2, the body round 300 in a column of 200, is 200 (Chrome 200, the
// `Column` 300); p5, clipped, the same; n3, under a 40px heading that does
// not shrink, 160 (Chrome 160, the `Column` 300).
// NEGATIVE: an automatic floor, which holds the body at its content past the
// cap (n1: Chrome 300), and a body of `flex-shrink: 0`: there the two
// spellings agree, and the lowerer leaves the `Column`; and content under the
// cap, where nothing gives way.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _cap = 200.0;

/// The body round [content]: a block that may be laid out shallower than
/// what it holds, which hangs out of it.
Widget _body(double content) => ColoredBox(
  key: const ValueKey('b'),
  color: const Color(0xFF336699),
  child: OverflowBox(
    minHeight: 0,
    maxHeight: double.infinity,
    fit: OverflowBoxFit.deferToChild,
    alignment: Alignment.topLeft,
    child: SizedBox(height: content),
  ),
);

const _heading = SizedBox(key: ValueKey('h'), height: 40);

/// The column as the lowerer now writes it: a line told the cap.
Widget _line(List<Widget> cells, double width) => SizedBox(
  width: width,
  child: ConstrainedBox(
    key: const ValueKey('c'),
    constraints: const BoxConstraints(maxHeight: _cap),
    child: FlexLine(direction: Axis.vertical, maxExtent: _cap, children: cells),
  ),
);

/// The column as the lowerer wrote it: a `Column` in a `Spill`, the cap only
/// clamping it.
Widget _spilled(List<Widget> items, double width) => SizedBox(
  width: width,
  child: ConstrainedBox(
    key: const ValueKey('c'),
    constraints: const BoxConstraints(maxHeight: _cap),
    child: Spill(
      axis: Axis.vertical,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
    ),
  ),
);

Widget _page(Widget column) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: column),
);

Future<Map<String, Rect>> _rects(WidgetTester t, Widget w, List<String> keys) async {
  await t.pumpWidget(_page(w));
  return {for (final k in keys) k: t.getRect(find.byKey(ValueKey(k)))};
}

void main() {
  for (final width in const [400.0, 300.0, 120.0]) {
    for (final content in const [100.0, 300.0]) {
      final over = content > _cap;
      testWidgets('p2: a body of no floor in the cap, content $content, $width wide', (t) async {
        final line = await _rects(t, _line([FlexCell(grow: 1, min: 0, child: _body(content))], width), const [
          'c',
          'b',
        ]);
        expect(line['c'], Rect.fromLTWH(0, 0, width, over ? _cap : content));
        expect(line['b'], Rect.fromLTWH(0, 0, width, over ? _cap : content));
        final spilled = await _rects(t, _spilled([_body(content)], width), const ['c', 'b']);
        expect(spilled['c'], line['c']);
        // Over the cap the `Column` left the body at its content.
        if (over) {
          expect(spilled['b'], Rect.fromLTWH(0, 0, width, content));
        } else {
          expect(spilled, line);
        }
      });
      testWidgets('p5: a clipped body, content $content, $width wide', (t) async {
        final line = await _rects(
          t,
          _line([FlexCell(grow: 1, clips: true, child: ClipRect(child: _body(content)))], width),
          const ['c', 'b'],
        );
        expect(line['b'], Rect.fromLTWH(0, 0, width, over ? _cap : content));
        final spilled = await _rects(t, _spilled([ClipRect(child: _body(content))], width), const ['c', 'b']);
        expect(spilled['b']!.height, content);
      });
      testWidgets('n3: a body under a heading that holds, content $content, $width wide', (t) async {
        final line = await _rects(
          t,
          _line([const FlexCell(shrink: 0, child: _heading), FlexCell(grow: 1, min: 0, child: _body(content))], width),
          const ['c', 'h', 'b'],
        );
        final left = over ? _cap - 40 : content;
        expect(line['h'], Rect.fromLTWH(0, 0, width, 40));
        expect(line['b'], Rect.fromLTWH(0, 40, width, left));
        expect(line['c']!.height, (40 + content).clamp(0, _cap));
        final spilled = await _rects(t, _spilled([_heading, _body(content)], width), const ['c', 'h', 'b']);
        expect(spilled['b'], Rect.fromLTWH(0, 40, width, content));
      });
      testWidgets('n1: NEGATIVE, an automatic floor holds the body at its content, content $content, $width wide', (
        t,
      ) async {
        final line = await _rects(t, _line([FlexCell(grow: 1, child: _body(content))], width), const ['c', 'b']);
        expect(line['b'], Rect.fromLTWH(0, 0, width, content));
        expect(await _rects(t, _spilled([_body(content)], width), const ['c', 'b']), line);
      });
      testWidgets('NEGATIVE: a body that does not shrink, content $content, $width wide', (t) async {
        final line = await _rects(
          t,
          _line([FlexCell(grow: 1, shrink: 0, min: 0, child: _body(content))], width),
          const ['c', 'b'],
        );
        expect(line['b'], Rect.fromLTWH(0, 0, width, content));
        expect(await _rects(t, _spilled([_body(content)], width), const ['c', 'b']), line);
      });
    }
  }
}
