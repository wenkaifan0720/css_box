// AN ITEM THAT NEVER GIVES UP ITS LENGTH STANDS AT IT BESIDE SHARES OF THE
// WHOLE LINE, which take the shortfall (css-flexbox-1 9.7). Two such items
// state a length: one floored at it or above (`width: 32px; min-width:
// 32px`), which the line shrinks below its floor and freezes there (step
// 4d, 4e) -- a banking site's pricing rows, a label of `width: 100%; min-width: 0`
// beside a 32px button -- and one whose frame along the line is all of it
// (`width: 1px; border-left: 1px`), whose scaled shrink factor, its inner
// base times its factor, is nothing (step 4c) -- a news site's rules
// between halves and thirds of a row. Every share is then shrunk by its
// base, the line's length less the item, the gaps and the margins shared
// out by the fractions: what `Expanded`s of the fractions are handed beside
// a `SizedBox` of the length (`RenderFlex._computeSizes`). The lowerer
// (`lossy_flex.dart`, `_lineUp`'s `frozen`, `_heldAtLengthL`) writes that
// `Row`, and fixtures/flex-shares-beside-held is the page. This pins the
// two spellings to the same boxes, wide and narrow.
// The shares here hold nothing wide, or state `min-width: 0`: each share's
// own floor, its automatic minimum (4.5), is nothing, as an `Expanded`'s is.
// NEGATIVE: a floor under the length, and a frame short of it, give way
// with the shares -- by the length, or by what the frame leaves -- where
// the `SizedBox` holds all of it; and a share round a word stops at the
// word, the other half giving up the rest, where an `Expanded` has no
// floor (the news site's stories): the lowerer keeps css_box's line.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [ValueKey('line'), ValueKey('a'), ValueKey('held'), ValueKey('b')];

Widget _at(Widget line, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: line),
  ),
);

const _a = SizedBox(key: ValueKey('a'), height: 20);
const _b = SizedBox(key: ValueKey('b'), height: 24);
const _button = SizedBox(key: ValueKey('held'), height: 32);
const _rule = DecoratedBox(
  key: ValueKey('held'),
  decoration: BoxDecoration(border: Border(left: BorderSide(width: 1))),
  child: Padding(padding: EdgeInsets.only(left: 1)),
);

/// The banking site's row as css_box lays it out: the label all of the line, the
/// button floored at [floor].
Widget _row({double floor = 32}) => FlexLine(
  key: const ValueKey('line'),
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    const FlexCell(mainSizeFraction: 1, crossSizeFraction: 1, min: 0, child: _a),
    FlexCell(mainSize: 32, crossSize: 32, min: floor, crossMin: 32, child: _button),
  ],
);

/// The news site's halves as css_box lays them out, a rule of [rule] between,
/// its frame 1.
Widget _halves({double rule = 1, Widget a = _a}) => FlexLine(
  key: const ValueKey('line'),
  spacing: 12,
  children: [
    FlexCell(basisFraction: 0.5, mainSizeFraction: 1, child: a),
    FlexCell(mainSize: rule, frame: const EdgeInsets.only(left: 1), child: _rule),
    const FlexCell(basisFraction: 0.5, mainSizeFraction: 1, child: _b),
  ],
);

/// The row as the lowerer writes it.
Widget _rowStock() => Row(
  key: const ValueKey('line'),
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: const [
    Expanded(child: _a),
    SizedBox(width: 32, child: _button),
  ],
);

/// The halves as the lowerer writes them: stretched across, as a line
/// is, to the depth of its deepest item.
Widget _halvesStock({double rule = 1, Widget a = _a}) => IntrinsicHeight(
  child: Row(
    key: const ValueKey('line'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Expanded(child: a),
      SizedBox(width: rule, child: _rule),
      const Expanded(child: _b),
    ],
  ),
);

/// A half round a word: its floor is the word.
const _word = Text('roller', key: ValueKey('a'), style: TextStyle(fontSize: 10, height: 1));

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {
    for (final k in _keys)
      if (find.byKey(k).evaluate().isNotEmpty) k: t.getRect(find.byKey(k)),
  };
}

void main() {
  for (final width in const [400.0, 120.0, 40.0]) {
    testWidgets('a length floored at itself stands beside all of the line: $width wide', (t) async {
      final line = await _rects(t, _at(_row(), width));
      final stock = await _rects(t, _at(_rowStock(), width));
      expect(stock, line);
      expect(line[const ValueKey('held')]!.width, 32);
    });
    testWidgets('a length all frame stands between halves: $width wide', (t) async {
      final line = await _rects(t, _at(_halves(), width));
      final stock = await _rects(t, _at(_halvesStock(), width));
      expect(stock, line);
      expect(line[const ValueKey('held')]!.width, 1);
    });
  }

  testWidgets('NEGATIVE: a floor under the length gives way with the share', (t) async {
    final line = await _rects(t, _at(_row(floor: 20), 400));
    final stock = await _rects(t, _at(_rowStock(), 400));
    expect(stock[const ValueKey('held')], isNot(line[const ValueKey('held')]));
  });

  testWidgets('NEGATIVE: a half round a word stops at it, and the other gives up the rest', (t) async {
    final line = await _rects(t, _at(_halves(a: _word), 40));
    final stock = await _rects(t, _at(_halvesStock(a: _word), 40));
    // Its floor is the less of its word (60) and its width, all of the
    // line (40) -- css-flexbox-1 4.5 -- and an `Expanded` is 7.5.
    expect(line[const ValueKey('a')]!.width, 40);
    expect(stock[const ValueKey('a')], isNot(line[const ValueKey('a')]));
  });

  testWidgets('NEGATIVE: a frame short of the length gives way with the halves', (t) async {
    final line = await _rects(t, _at(_halves(rule: 9), 400));
    final stock = await _rects(t, _at(_halvesStock(rule: 9), 400));
    expect(stock[const ValueKey('held')], isNot(line[const ValueKey('held')]));
  });
}
