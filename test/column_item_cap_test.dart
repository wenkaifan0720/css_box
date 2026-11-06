// A CAP INSIDE A COLUMN'S ITEM IS THE ITEM'S CONTENT HEIGHT, AND THE
// COLUMN SHRINKS IT BY NOTHING. A block of `max-height: 30px` round words
// that take more is 30 tall (CSS 2.1 10.7), and the item round it has
// that for its flex base size and its automatic minimum alike
// (css-flexbox-1 9.2 step 3 E, 4.5), so a column short of room takes
// nothing from it (9.7): Chrome holds it at 30 in a column its card
// shrinks to 19.8 (`fixtures/flex-column-floor-block` n1, 1/3/1/0). The
// column overflows and its `space-between` falls back to its start
// (css-align-3 4.3). The lowerer
// reads such an item as giving nothing up, as it reads one round a
// `min-height`, and hangs the column from its start with the slot's floor
// kept:
//   OverflowBox(fit: OverflowBoxFit.deferToChild,
//       maxHeight: double.infinity, alignment: Alignment.topCenter,
//       child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           ...))
// -- a `RenderFlex` hands an item it does not flex no ceiling down the
// line, and a `ConstrainedBox(maxHeight: 30)` is then its content clamped
// to 30. This pins the hung column to css_box's line with the card shorter
// than the content, as tall and taller.
// NEGATIVE: the column unhung reports what passes its end; a capped item
// whose content is shorter than the cap is its content's height, in both.
import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 14px wide; a line is 18 tall.
const _style = TextStyle(fontSize: 14, height: 18 / 14);
const _keys = [ValueKey('card'), ValueKey('inner'), ValueKey('first'), ValueKey('second')];

Widget _page(Widget w) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: w),
);

// Three lines of words at the inner column's 185.4 (54 tall), under a cap
// of 30; or one short word under it.
Widget _first(String words) => ColoredBox(
  key: const ValueKey('first'),
  color: const Color(0xFFFF9F1C),
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 30),
    child: Text(words, style: _style),
  ),
);
const _second = ColoredBox(
  key: ValueKey('second'),
  color: Color(0xFFCBF3F0),
  child: Text('snipe', style: _style),
);

// The card: a 40px picture that clips, and the inner column, which grows
// from nothing and may shrink to nothing.
Widget _card(double height, Widget inner) => SizedBox(
  key: const ValueKey('card'),
  width: 300,
  height: height,
  child: FlexLine(
    direction: Axis.vertical,
    spacing: 16,
    children: [
      const FlexCell(mainSize: 40, min: 0, clips: true, child: SizedBox.shrink()),
      FlexCell(
        grow: 1,
        crossSizeFraction: 0.618,
        min: 0,
        child: KeyedSubtree(key: const ValueKey('inner'), child: inner),
      ),
    ],
  ),
);

Widget _line(String words) => FlexLine(
  direction: Axis.vertical,
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  spacing: 8,
  children: [
    FlexCell(child: _first(words)),
    const FlexCell(child: _second),
  ],
);

Widget _column(String words, {bool hung = true}) {
  final column = Column(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [_first(words), _second],
  );
  return hung
      ? OverflowBox(
          fit: OverflowBoxFit.deferToChild,
          maxHeight: double.infinity,
          alignment: Alignment.topCenter,
          child: column,
        )
      : column;
}

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(_page(w));
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

void main() {
  for (final words in const ['copper stint and quartz dunlin', 'tern']) {
    for (final height in const [50.0, 72.0, 120.0, 200.0]) {
      testWidgets(
        'a column round an item of a capped block, hung, stands where the line does: "$words", card $height',
        (t) async {
          final line = await _rects(t, _card(height, _line(words)));
          final hung = await _rects(t, _card(height, _column(words)));
          expect(t.takeException(), isNull);
          expect(hung, line);
          // The item is its content clamped to the cap, whatever the room.
          expect(hung[const ValueKey('first')]!.height, words == 'tern' ? 18 : 30);
        },
      );
    }
  }

  testWidgets('NEGATIVE: the column unhung, in the item its card shrinks, reports what passes its end', (t) async {
    await t.pumpWidget(_page(_card(50, _column('copper stint and quartz dunlin', hung: false))));
    expect(t.takeException(), isA<FlutterError>());
  });
}
