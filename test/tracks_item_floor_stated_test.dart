// A GRID NEVER READS THE LEAST WIDTH OF AN ITEM THAT STATES ITS OWN FLOOR.
// An item's automatic minimum is its content's min-content only where it
// states no `min-width` and does not clip (css-grid-1 6.6), and a column of
// an `auto` minimum is floored at that minimum (11.5 step 2.1): `Tracks`
// reads an item's min-content contribution only under a content constraint
// on the grid itself or for a `min-content` or `fit-content()` column
// (`tracks.dart`, `_intrinsicSizes`, `_minimum`), and lays a stretched item
// out at its area (`_Item.known`). So a fit-content box in such an item
// answers its least width to no one, and the lowerer
// writes it as an `IntrinsicWidth`, which answers its least width with its most.
// A docs site's page grid, `320px auto` with `min-width: 0` on its article,
// and a music store's `auto 1px 30%` sale columns
// (`fixtures/grid-item-floor-stated`). This pins the two spellings to the
// same boxes in an `auto` column beside a length, alone, beside a pixel
// and a share, in `1fr` columns and in `minmax(0, auto)` -- wide, and
// narrow enough that the words pass the column.
// A grid asked its own least width reads the floor the item states, not
// its least, as Chrome does (`tracks.dart`, `_statesLeast`), so the two
// answer it alike.
// NEGATIVE: an item that states no floor is floored at its content's
// min-content, which the `IntrinsicWidth` answers with its most; so is one
// in a `min-content` column; and a grid asked its own least width reads it
// where the item states no floor.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [ValueKey('grid'), ValueKey('item'), ValueKey('words'), ValueKey('other')];

const _column = Column(
  key: ValueKey('item'),
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [Text('several short words here', key: ValueKey('words'))],
);

const _other = Text('a neighbour of many words', key: ValueKey('other'));

Widget _page(double width, Widget grid) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: grid),
  ),
);

/// The grids, [box] in an item stating a floor of [floor] (none where
/// null), in the column the docs site and the music store hold it in.
final Map<String, Widget Function(Widget box, double? floor)> _grids = {
  'beside a length': (box, floor) => Tracks(
    key: const ValueKey('grid'),
    columns: const [TrackSize.fixed(120), TrackSize.auto],
    children: [
      _other,
      TrackCell(minWidth: floor, child: box),
    ],
  ),
  'alone': (box, floor) => Tracks(
    key: const ValueKey('grid'),
    columns: const [TrackSize.auto],
    children: [
      TrackCell(minWidth: floor, child: box),
      _other,
    ],
  ),
  'beside a pixel and a share': (box, floor) => Tracks(
    key: const ValueKey('grid'),
    columns: const [TrackSize.auto, TrackSize.fixed(1), TrackSize.fraction(0.3)],
    spacing: 20,
    children: [
      TrackCell(minWidth: floor, child: box),
      const SizedBox(height: 4),
      _other,
    ],
  ),
  'in 1fr columns': (box, floor) => Tracks(
    key: const ValueKey('grid'),
    columns: const [TrackSize.flex(1), TrackSize.flex(1)],
    spacing: 16,
    children: [
      TrackCell(minWidth: floor, child: box),
      _other,
    ],
  ),
  'in minmax(0, auto)': (box, floor) => Tracks(
    key: const ValueKey('grid'),
    columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.auto), TrackSize.auto],
    children: [
      TrackCell(minWidth: floor, child: box),
      _other,
    ],
  ),
};

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

void main() {
  for (final MapEntry(key: name, value: grid) in _grids.entries) {
    for (final width in const [600.0, 300.0, 180.0, 90.0]) {
      testWidgets('an item that states its floor answers its least width to no one: $name, $width wide', (t) async {
        for (final floor in const [0.0, 40.0]) {
          final kept = await _rects(t, _page(width, grid(const ShrinkWidth(child: _column), floor)));
          final stock = await _rects(t, _page(width, grid(const IntrinsicWidth(child: _column), floor)));
          expect(stock, kept, reason: 'floor $floor');
        }
      });
    }
  }

  testWidgets('NEGATIVE: an item that states no floor is floored at its least width', (t) async {
    final grid = _grids['beside a length']!;
    final kept = await _rects(t, _page(180, grid(const ShrinkWidth(child: _column), null)));
    final stock = await _rects(t, _page(180, grid(const IntrinsicWidth(child: _column), null)));
    expect(stock[const ValueKey('item')]!.width, greaterThan(kept[const ValueKey('item')]!.width));
  });

  testWidgets('NEGATIVE: a min-content column reads the least width of an item of a floor', (t) async {
    Widget grid(Widget box) => Tracks(
      key: const ValueKey('grid'),
      columns: const [TrackSize.minContent, TrackSize.flex(1)],
      children: [
        TrackCell(minWidth: 0, child: box),
        _other,
      ],
    );
    final kept = await _rects(t, _page(600, grid(const ShrinkWidth(child: _column))));
    final stock = await _rects(t, _page(600, grid(const IntrinsicWidth(child: _column))));
    expect(stock[const ValueKey('item')]!.width, greaterThan(kept[const ValueKey('item')]!.width));
  });

  testWidgets('a grid asked its own least width reads the floor an item states, not its least', (t) async {
    final grid = _grids['alone']!;
    double least(WidgetTester t) =>
        t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))).getMinIntrinsicWidth(double.infinity);
    await t.pumpWidget(_page(600, grid(const ShrinkWidth(child: _column), 0)));
    final kept = least(t);
    await t.pumpWidget(_page(600, grid(const IntrinsicWidth(child: _column), 0)));
    expect(least(t), kept);
    // The neighbour's longest word, 9 em squares at 14px.
    expect(kept, 126);
    // NEGATIVE: an item that states no floor gives its least, which the
    // `IntrinsicWidth` answers with its most.
    await t.pumpWidget(_page(600, grid(const ShrinkWidth(child: _column), null)));
    final none = least(t);
    await t.pumpWidget(_page(600, grid(const IntrinsicWidth(child: _column), null)));
    expect(least(t), greaterThan(none));
  });
}
