// A LINE THAT NEVER WRAPS IS AS NARROW AS ITS WORDS AND ITS ATOMIC INLINES
// AT THEIR OWN LEAST WIDTHS. The min-content of a box is the width its
// content takes with every box in it at ITS min-content contribution
// (css-sizing-3 5.1), and a line that never breaks lays those end to end:
// an inline-block of `white-space: normal` on a `nowrap` line counts its
// longest word, not its whole line. `LineBox` answers that (`linebox.dart`,
// `_floor`), where Skia's least width of a line that never wraps is its
// longest line -- every widget on it at its greatest. A price-table site's
// `Prediction Markets` line with its words in such a block, in a
// fit-content box narrower than the line: 67.6 side by side where Chrome
// narrows it to 53.6 (`fixtures/shrink-spill-room` n3). The room the line
// is laid out in stays its whole length (`_lineFloor`): only the least
// width moves. NEGATIVE: a line of words alone, which is its whole length
// either way, an atom of one width, which is that width either way, and an
// atom whose words never wrap either -- the inline-block that inherits the
// line's `nowrap` (`fixtures/inline-block-alone-measured` n2) -- which is
// there at its whole length, where Skia's least width of it is its longest
// word.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 14px wide at 14px.
const _style = TextStyle(fontSize: 14, height: 1.0);

const _line = ValueKey('line');
const _atom = ValueKey('atom');

/// `aa` then an inline box of [atom], on a line that never wraps.
Widget _para(Widget atom) => LineBox(
  key: _line,
  child: Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'aa'),
        WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: atom),
      ],
    ),
    softWrap: false,
    style: _style,
  ),
);

/// An inline-block of `white-space: normal`: `aa bb`, 28 at its least, 70
/// at its most.
Widget get _block => const LineBox(
  key: _atom,
  child: Text('aa bb', style: _style),
);

Widget _page(Widget box, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Align(alignment: Alignment.topLeft, child: box),
    ),
  ),
);

double _least(WidgetTester t) => t.renderObject<RenderBox>(find.byKey(_line)).getMinIntrinsicWidth(double.infinity);

void main() {
  testWidgets('the least width counts the atom at its own least', (t) async {
    await t.pumpWidget(_page(_para(_block), 300));
    expect(_least(t), 56);
    // Its greatest is still the whole line.
    expect(t.renderObject<RenderBox>(find.byKey(_line)).getMaxIntrinsicWidth(double.infinity), 98);
  });

  testWidgets('a fit-content box in a room under the line stands at that least', (t) async {
    await t.pumpWidget(_page(ShrinkWidth(spill: true, child: _para(_block)), 20));
    expect(t.getRect(find.byKey(_line)).width, 56);
    // In a room past the whole line, the line is its whole length, the
    // block on one line.
    await t.pumpWidget(_page(ShrinkWidth(spill: true, child: _para(_block)), 300));
    expect(t.getRect(find.byKey(_line)).width, 98);
    expect(t.getRect(find.byKey(_atom)).width, 70);
  });

  testWidgets('NEGATIVE: words alone, an atom of one width, and one whose words never wrap', (t) async {
    await t.pumpWidget(
      _page(
        const LineBox(
          key: _line,
          child: Text('aa bb', softWrap: false, style: _style),
        ),
        300,
      ),
    );
    expect(_least(t), 70);
    await t.pumpWidget(_page(_para(const SizedBox(key: _atom, width: 20, height: 10)), 300));
    expect(_least(t), 48);
    for (final atom in const [
      Text('aa bb', key: _atom, softWrap: false, style: _style),
      ColoredBox(
        key: _atom,
        color: Color(0xFF277DA1),
        child: Text('aa bb', softWrap: false, style: _style),
      ),
    ]) {
      await t.pumpWidget(_page(_para(atom), 300));
      expect(t.renderObject<RenderBox>(find.byKey(_atom)).getMinIntrinsicWidth(double.infinity), 28);
      expect(_least(t), 98);
    }
  });
}
