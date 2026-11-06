// AN ITEM OF NO FLOOR, `min-width: 0`, IS ONE NO STOCK BOX NEEDS SAY. Its
// least width is its margins and nothing more: the floor replaces its
// automatic minimum (css-grid-1 6.6), so the column it stands in takes no
// width from its content in a layout of a definite width (11.5 step 2: its
// minimum contribution is its margins) -- which a share's `Expanded` and
// the stretching `Column` never take either. `Tracks` takes the floor in
// `_minimum` before it measures anything, and the lowerer
// drops it.
// A product site's page and card grids, `1fr 320px` and `repeat(3, 1fr)` round
// columns of `min-width: 0` (`fixtures/grid-item-floor-none`).
//
// This pins the grid and what the lowerer writes for it to the same boxes
// in a share beside a length, in three shares 16 apart, and alone in a grid
// of no columns -- wide, and narrow enough that a word passes the share.
// NEGATIVE: an item that states no floor floors its share at its longest
// word; an item of no floor but margins floors it at its margins.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [ValueKey('grid'), ValueKey('a'), ValueKey('b'), ValueKey('c')];

const _long = Text('Incomprehensibilities across the board', key: ValueKey('a'));
const _side = Text('Side', key: ValueKey('b'));

Widget _page(double width, Widget grid) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: grid),
  ),
);

/// The grids css_box keeps, beside what the lowerer writes for each.
final Map<String, (Widget Function(double? floor, EdgeInsets? margin), Widget Function(EdgeInsets? margin))> _pairs = {
  'a share beside a length': (
    (floor, margin) => Tracks(
      key: const ValueKey('grid'),
      columns: const [TrackSize.flex(1), TrackSize.fixed(120)],
      children: [
        TrackCell(minWidth: floor, margin: margin ?? EdgeInsets.zero, child: _long),
        _side,
      ],
    ),
    (margin) => IntrinsicHeight(
      key: const ValueKey('grid'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: margin == null ? _long : Padding(padding: margin, child: _long),
          ),
          const SizedBox(width: 120, child: _side),
        ],
      ),
    ),
  ),
  'three shares': (
    (floor, margin) => Tracks(
      key: const ValueKey('grid'),
      columns: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1)],
      spacing: 16,
      children: [
        TrackCell(minWidth: floor, margin: margin ?? EdgeInsets.zero, child: _long),
        TrackCell(minWidth: floor, child: _side),
        TrackCell(
          minWidth: floor,
          child: const Text('Build', key: ValueKey('c')),
        ),
      ],
    ),
    (margin) => IntrinsicHeight(
      key: const ValueKey('grid'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Expanded(
            child: margin == null ? _long : Padding(padding: margin, child: _long),
          ),
          const Expanded(child: _side),
          const Expanded(child: Text('Build', key: ValueKey('c'))),
        ],
      ),
    ),
  ),
  'one column': (
    (floor, margin) => Tracks(
      key: const ValueKey('grid'),
      children: [TrackCell(minWidth: floor, margin: margin ?? EdgeInsets.zero, child: _long)],
    ),
    (margin) => Column(
      key: const ValueKey('grid'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [margin == null ? _long : Padding(padding: margin, child: _long)],
    ),
  ),
};

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {
    for (final k in _keys)
      if (find.byKey(k).evaluate().isNotEmpty) k: t.getRect(find.byKey(k)),
  };
}

void main() {
  for (final MapEntry(key: name, value: (grid, stock)) in _pairs.entries) {
    for (final width in const [900.0, 400.0, 240.0, 170.0]) {
      testWidgets('an item of no floor is laid out as no floor is: $name, $width wide', (t) async {
        final kept = await _rects(t, _page(width, grid(0, null)));
        final written = await _rects(t, _page(width, stock(null)));
        expect(written, kept);
      });
    }
  }

  testWidgets('NEGATIVE: an item that states no floor floors its share at its longest word', (t) async {
    final (grid, stock) = _pairs['a share beside a length']!;
    final kept = await _rects(t, _page(240, grid(null, null)));
    final written = await _rects(t, _page(240, stock(null)));
    expect(kept[const ValueKey('b')]!.left, greaterThan(written[const ValueKey('b')]!.left));
  });

  testWidgets('NEGATIVE: an item of no floor but margins floors its share at them', (t) async {
    final (grid, stock) = _pairs['a share beside a length']!;
    const margin = EdgeInsets.symmetric(horizontal: 100);
    final kept = await _rects(t, _page(240, grid(0, margin)));
    final written = await _rects(t, _page(240, stock(margin)));
    expect(kept[const ValueKey('b')]!.left, greaterThan(written[const ValueKey('b')]!.left));
  });
}
