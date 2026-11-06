// A SHRINK-TO-FIT BOX ROUND WHAT FITS ITS CONTENT, IN A GRID, IS ITS CHILD.
// css-sizing-3 5.1: a fit-content width is min(max-content, max(min-content,
// room)), which for a paragraph -- as wide as its longest line, broken at
// its room -- is the width the paragraph comes to by itself. `RenderTracks`
// asks an item its least and greatest widths, its height at a width, its
// dry layout and its dry baseline, and lays it out tight at its area or at
// its fit in it (`tracks.dart`, `_measure`, `_computeLeaf`); it reads no
// item's type and no item's last baseline, so the lowerer
// no longer takes a grid's
// items as asked css_box's walks, and writes the box as its child
// (`lossy.dart`, `_fitsOwnL`). The product site's and a product site's page grids held such
// boxes round their labels (`fixtures/grid-item-shrink-fits`). This pins
// the two spellings to the same boxes in `1fr` columns, which read an
// item's least width (its automatic minimum, css-grid-1 6.6), in an `auto`
// column, in an item placed at its start (fit-content in its area, 6.2),
// and on baselines in a row that stands on the grid's -- wide, and narrow
// enough that the words wrap and the least width decides the columns.
// NEGATIVE: round a column that stretches its children, which is as wide
// as it is offered, the box is not its child: placed at its start, the
// item shrinks to its words in the box and fills its area without it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [ValueKey('label'), ValueKey('other'), ValueKey('grid'), ValueKey('base')];

const _label = Text('three short words', key: ValueKey('label'));

Widget _page(double width, Widget grid) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text('x', key: ValueKey('base'), style: TextStyle(fontSize: 30)),
          Expanded(child: grid),
        ],
      ),
    ),
  ),
);

/// The four grids, [item] in the first column of each.
final Map<String, Widget Function(Widget)> _grids = {
  'two 1fr': (item) => Tracks(
    key: const ValueKey('grid'),
    columns: const [TrackSize.flex(1), TrackSize.flex(1)],
    spacing: 16,
    children: [
      TrackCell(column: 0, child: item),
      const SizedBox(key: ValueKey('other'), height: 10),
    ],
  ),
  'auto and 1fr': (item) => Tracks(
    key: const ValueKey('grid'),
    columns: const [TrackSize.auto, TrackSize.flex(1)],
    spacing: 16,
    children: [
      item,
      const Text('a much longer neighbour', key: ValueKey('other')),
    ],
  ),
  'placed at its start': (item) => Tracks(
    key: const ValueKey('grid'),
    columns: const [TrackSize.flex(1), TrackSize.flex(1)],
    justify: CellAlign.start,
    children: [
      item,
      const SizedBox(key: ValueKey('other'), width: 20, height: 10),
    ],
  ),
  'on baselines': (item) => Tracks(
    key: const ValueKey('grid'),
    columns: const [TrackSize.flex(1), TrackSize.flex(1)],
    align: CellAlign.baseline,
    children: [
      item,
      const Text('big', key: ValueKey('other'), style: TextStyle(fontSize: 24)),
    ],
  ),
};

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

void main() {
  for (final MapEntry(key: name, value: grid) in _grids.entries) {
    for (final width in const [600.0, 300.0, 160.0, 90.0]) {
      testWidgets('a shrink-to-fit box round a paragraph is the paragraph: $name, $width wide', (t) async {
        final kept = await _rects(t, _page(width, grid(const ShrinkWidth(child: _label))));
        final stock = await _rects(t, _page(width, grid(_label)));
        expect(stock, kept);
      });
    }
  }

  testWidgets('NEGATIVE: round a column that stretches, placed at its start, the box is not its child', (t) async {
    const column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Text('ab', key: ValueKey('label'))],
    );
    final grid = _grids['placed at its start']!;
    final kept = await _rects(t, _page(600, grid(const ShrinkWidth(child: column))));
    final stock = await _rects(t, _page(600, grid(column)));
    expect(stock[const ValueKey('label')]!.width, greaterThan(kept[const ValueKey('label')]!.width));
  });
}
