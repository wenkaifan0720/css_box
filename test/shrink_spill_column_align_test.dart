// A BOX THAT SPILLS ACROSS A COLUMN HANGS WHERE THE COLUMN PLACES IT. An
// item a column does not stretch is as wide as its fit-content, which has a
// min-content floor (css-flexbox-1 9.4 step 7, css-sizing-3 5.2.1), and
// `align-items: center` places that margin box past both edges, `end` past
// the start, where it is wider than the column (css-align-3 4.4: the
// fallback is unsafe). css_box's line sizes the item so and places it; the
// stock pass writes such a line as a `Column`, which hands the box a loose
// width, and the box reports the room and hangs its child as
// [ShrinkWidth.spillAlign] says.
// A price-table site's phone tab bar: `Community Hub`, held on one line, 72.6 wide
// in a sixth of the bar of 53.3 that centres it (`fixtures/shrink-spill-room`
// n1). This pins the two spellings to the same boxes, with the line past the
// column and inside it, a word that breaks and one line that does not.
// NEGATIVE: hung from its start (the box's default), the stock spelling
// stands the line where the column does not; and under the line itself the
// hang moves nothing, the item being laid out at its fit-content.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 10px wide at 10px.
const _style = TextStyle(fontSize: 10, height: 1.0);
const _label = ValueKey('label');

Widget _page(Widget column, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: column),
  ),
);

Widget _text(bool wraps) => Text('Community Hub', key: _label, softWrap: wraps, style: _style);

/// The tab as css_box lays it out: a column of an icon over the label.
Widget _line(CrossAxisAlignment cross, Widget label) => FlexLine(
  direction: Axis.vertical,
  crossAxisAlignment: cross,
  children: [
    const FlexCell(child: SizedBox(width: 24, height: 24)),
    FlexCell(margin: const EdgeInsets.only(top: 2), child: label),
  ],
);

/// The tab as the stock pass writes it.
Widget _column(CrossAxisAlignment cross, Widget label) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: cross,
  children: [
    const SizedBox(width: 24, height: 24),
    Padding(padding: const EdgeInsets.only(top: 2), child: label),
  ],
);

Future<Rect> _rect(WidgetTester t, Widget w, double width) async {
  await t.pumpWidget(_page(w, width));
  return t.getRect(find.byKey(_label));
}

void main() {
  for (final (cross, align) in const [(CrossAxisAlignment.center, 0.0), (CrossAxisAlignment.end, 1.0)]) {
    for (final wraps in const [false, true]) {
      // 130 on one line; 90 at its least where it breaks (`Community`).
      for (final width in const [53.3, 100.0, 200.0]) {
        testWidgets(
          '$cross, ${wraps ? 'a line that breaks' : 'one line'}, in $width: the column spelling stands where the line does',
          (t) async {
            final line = await _rect(t, _line(cross, ShrinkWidth(spill: true, child: _text(wraps))), width);
            final stock = await _rect(
              t,
              _column(cross, ShrinkWidth(spill: true, spillAlign: align, child: _text(wraps))),
              width,
            );
            expect(stock, line);
            // Under the line itself the hang moves nothing.
            expect(
              await _rect(t, _line(cross, ShrinkWidth(spill: true, spillAlign: align, child: _text(wraps))), width),
              line,
            );
          },
        );
      }
    }
  }

  testWidgets('NEGATIVE: hung from its start, the column spelling stands the line where the line does not', (t) async {
    for (final cross in const [CrossAxisAlignment.center, CrossAxisAlignment.end]) {
      final line = await _rect(t, _line(cross, ShrinkWidth(spill: true, child: _text(false))), 53.3);
      final stock = await _rect(t, _column(cross, ShrinkWidth(spill: true, child: _text(false))), 53.3);
      expect(stock.left, 0);
      expect(line.left, lessThan(-1));
      // Inside the room the start is where either places it.
      expect(
        await _rect(t, _column(cross, ShrinkWidth(spill: true, child: _text(false))), 200),
        await _rect(t, _line(cross, ShrinkWidth(spill: true, child: _text(false))), 200),
      );
    }
  });
}
