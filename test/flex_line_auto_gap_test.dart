// AN AUTO MARGIN IN ONE GAP OF A ROW TAKES ALL THE FREE SPACE THERE
// (css-flexbox-1 8.1, 9.5 step 5): the items before it stand at the start,
// the items after it at the end, and where the line is short of room the
// margin is nothing and the items shrink as they would with none (9.7).
// A product site's sidebar rows -- a 16px icon of `flex-shrink: 0`, a label, and a
// count of `margin-left: auto`, 8px apart -- are such a line. The lowerer
// (`lossy_flex.dart`, `_lineUp`'s `autoGap`) spells it a `Row` justified
// `spaceBetween` of two: the items before the margin and the items after
// it, each a `Row` as long as its items, the side that shrinks in a loose
// `Flexible`. That side is handed what the other side and the gap leave,
// and is laid out in it as the whole line is with no margin
// (`RenderFlex._computeSizes`); asked a length, a line of one flexed child
// answers that child's (`RenderFlex._getIntrinsicSize`), the sum of the
// items', as css_box sums them. fixtures/flex-auto-margin-gap is the page.
// This pins the two spellings to the same boxes where the row has room to
// spare, exactly enough and too little -- the label's words break, and a
// paragraph that wraps is as wide as it is handed (`TextWidthBasis.parent`),
// as the item is -- and measured along it and across.
// NEGATIVE: the margin a `Spacer` beside the label's `Flexible` takes one
// part in the label's factor and one of the room, and leaves the rest at
// the end; and items that may shrink on both sides of the margin shrink
// together in CSS, each by its base, where the two sides of a `Row` would
// share the line by their factors -- the lowerer keeps css_box's line for
// both.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _ten = TextStyle(fontSize: 10, height: 1);
const _keys = [ValueKey('line'), ValueKey('icon'), ValueKey('label'), ValueKey('count')];

Widget _at(Widget line, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: line),
  ),
);

/// Loose: the line at its own length, no more than [width].
Widget _looseAt(Widget line, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: line,
    ),
  ),
);

const _icon = SizedBox(key: ValueKey('icon'), width: 16, height: 16);
const _label = Text('aaaa bbbb', key: ValueKey('label'), style: _ten);
Text _count(String s) => Text(s, key: const ValueKey('count'), style: _ten);

/// The row as css_box lays it out: the count of one word, or of words that
/// may shrink.
Widget _line({String count = 'cc'}) => FlexLine(
  key: const ValueKey('line'),
  spacing: 8,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    const FlexCell(shrink: 0, mainSize: 16, crossSize: 16, min: 0, child: _icon),
    _label,
    FlexCell(autoMargin: const AutoEdges(left: true), child: _count(count)),
  ],
);

/// The row as the lowerer writes it: the icon and the label in a loose
/// `Flexible`, the count after it, the room between.
Widget _stock() => Row(
  key: const ValueKey('line'),
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.center,
  spacing: 8,
  children: [
    Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: const [
          SizedBox(width: 16, child: _icon),
          Flexible(flex: 90, child: _label),
        ],
      ),
    ),
    _count('cc'),
  ],
);

/// The same spelling round a count that shrinks too, each side flexed by
/// its base: the sides share the line by their factors.
Widget _bothSides() => Row(
  key: const ValueKey('line'),
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.center,
  spacing: 8,
  children: [
    Flexible(
      flex: 114,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: const [
          SizedBox(width: 16, child: _icon),
          Flexible(flex: 90, child: _label),
        ],
      ),
    ),
    Flexible(flex: 50, child: _count('cc dd')),
  ],
);

/// The flat spelling: the margin a `Spacer`.
Widget _spacer() => Row(
  key: const ValueKey('line'),
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  spacing: 8,
  children: [
    const SizedBox(width: 16, child: _icon),
    const Flexible(flex: 90, child: _label),
    const Spacer(),
    _count('cc'),
  ],
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

void main() {
  // 300: room to spare; 142: the items and gaps exactly; 100 and 92: the
  // label shrinks to 48 and to 40, its words on two lines.
  for (final width in const [300.0, 142.0, 100.0, 92.0]) {
    testWidgets('the margin takes the room, the label the shortfall: $width wide', (t) async {
      final line = await _rects(t, _at(_line(), width));
      final stock = await _rects(t, _at(_stock(), width));
      expect(stock, line);
      // The count ends the row.
      expect(line[const ValueKey('count')]!.right, width);
    });
  }

  testWidgets('asked its length, the row answers its items and gaps', (t) async {
    final line = await _rects(t, _looseAt(IntrinsicWidth(child: _line()), 600));
    final stock = await _rects(t, _looseAt(IntrinsicWidth(child: _stock()), 600));
    expect(stock, line);
    expect(line[const ValueKey('line')]!.width, 142);
  });

  for (final width in const [300.0, 100.0]) {
    testWidgets('asked its depth at $width, the row answers the label at its share', (t) async {
      final line = await _rects(t, _at(IntrinsicHeight(child: _line()), width));
      final stock = await _rects(t, _at(IntrinsicHeight(child: _stock()), width));
      expect(stock, line);
    });
  }

  testWidgets('NEGATIVE: a Spacer for the margin leaves the room at the end', (t) async {
    final line = await _rects(t, _at(_line(), 300));
    final flat = await _rects(t, _at(_spacer(), 300));
    expect(flat[const ValueKey('count')], isNot(line[const ValueKey('count')]));
  });

  testWidgets('NEGATIVE: what shrinks on both sides of the margin shrinks together', (t) async {
    final line = await _rects(t, _at(_line(count: 'cc dd'), 100));
    final stock = await _rects(t, _at(_bothSides(), 100));
    expect(stock[const ValueKey('label')], isNot(line[const ValueKey('label')]));
  });
}
