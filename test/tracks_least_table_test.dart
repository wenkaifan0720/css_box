// A GRID OF ONE COLUMN, ASKED ITS LEAST WIDTH WITH NO WIDTH TO TAKE, IS A
// `Table` OF ONE `IntrinsicColumnWidth()`. The one `auto` track -- the
// implicit one, or the `auto` floor of a bare `1fr` -- is its items'
// widest min-content contribution under a min-content constraint and their
// widest max-content one under a max-content constraint (css-grid-1 11.5
// step 2.1, 11.7), and handed a loose width the grid is fit to it: its
// content's most, clamped to the room but never under its content's least
// nor under a floor it is handed, every item stretched to the column
// (`tracks.dart`, `_layOut`). `RenderTable._computeColumnWidths` is that
// column to the pixel, and its cells are laid out at `tightFor(width:)` as
// the stretched `Column` lays its children out. The lowerer
// writes it so
// where the grid is asked its least width, which the `IntrinsicWidth` it
// otherwise writes answers with its most. a docs site's mega menu, link
// lists of `display: grid; gap: .5rem` in the menu's `1fr` columns
// (`fixtures/grid-one-column-least-asked`).
//
// This pins the two to the same boxes, and the same answers, in the
// columns of a grid that reads its items' least widths (wide, and narrow
// enough that a column falls to its least), in a shrink-to-fit box, in a
// loose room wider and narrower than the content's least, offered no width
// at all, and handed a floor; with a row gap, an item placed at the start
// and in the middle of the column, an item with a margin, a bare `1fr`.
// NEGATIVE: the `IntrinsicWidth` answers the least width with the most,
// and in a narrow column of the outer grid takes more than its share; a
// `minmax(0, 1fr)` column answers no least width, where the table answers
// its cells'; and a table answers no baseline, where the grid answers its
// first item's.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [ValueKey('grid'), ValueKey('a'), ValueKey('b'), ValueKey('c'), ValueKey('d'), ValueKey('beside')];

const _a = Text('Getting started modules', key: ValueKey('a'));
const _b = Text('Core', key: ValueKey('b'));
const _c = Text('Web Curriculum and more', key: ValueKey('c'));
const _d = Text('Check out the video course from Cascade', key: ValueKey('d'));

/// The grid css_box keeps, one column of four items 8 apart: one placed
/// at the start of the column, one in its middle, one with a margin.
Widget _grid({List<TrackSize> columns = const []}) => Tracks(
  key: const ValueKey('grid'),
  columns: columns,
  runSpacing: 8,
  children: const [
    _a,
    TrackCell(justify: CellAlign.start, child: _b),
    TrackCell(justify: CellAlign.center, child: _c),
    TrackCell(margin: EdgeInsets.fromLTRB(6, 2, 10, 4), child: _d),
  ],
);

/// What the lowerer writes for it.
final _table = Table(
  key: const ValueKey('grid'),
  defaultColumnWidth: const IntrinsicColumnWidth(),
  children: const [
    TableRow(children: [_a]),
    TableRow(children: [SizedBox(height: 8)]),
    TableRow(
      children: [Align(alignment: AlignmentDirectional.topStart, heightFactor: 1, child: _b)],
    ),
    TableRow(children: [SizedBox(height: 8)]),
    TableRow(
      children: [Align(alignment: Alignment.topCenter, heightFactor: 1, child: _c)],
    ),
    TableRow(children: [SizedBox(height: 8)]),
    TableRow(
      children: [Padding(padding: EdgeInsets.fromLTRB(6, 2, 10, 4), child: _d)],
    ),
  ],
);

/// What it wrote before: an `IntrinsicWidth` round a stretched column.
const _measured = IntrinsicWidth(
  key: ValueKey('grid'),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      _a,
      Align(alignment: AlignmentDirectional.topStart, heightFactor: 1, child: _b),
      Align(alignment: Alignment.topCenter, heightFactor: 1, child: _c),
      Padding(padding: EdgeInsets.fromLTRB(6, 2, 10, 4), child: _d),
    ],
  ),
);

Widget _page(double width, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  ),
);

/// Where it stands: each reads its least width, or hands it a loose one.
final Map<String, Widget Function(Widget grid)> _rooms = {
  // a docs site's menu: three `1fr` columns, which floor each at its items'
  // least (`minmax(auto, 1fr)`), the grid placed at the start of its own.
  'in a 1fr column of a grid': (g) => Tracks(
    columns: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1)],
    spacing: 22,
    children: [
      TrackCell(justify: CellAlign.start, child: g),
      const Text('a neighbour of many words', key: ValueKey('beside')),
      const Text('x'),
    ],
  ),
  'in an auto column of a grid': (g) => Tracks(
    columns: const [TrackSize.auto, TrackSize.auto],
    spacing: 16,
    children: [
      TrackCell(justify: CellAlign.start, child: g),
      const Text('a neighbour of many words', key: ValueKey('beside')),
    ],
  ),
  'in a shrink-to-fit box': (g) => ShrinkWidth(child: g),
  'in a loose room': (g) => Align(alignment: Alignment.topLeft, child: g),
  'handed a floor': (g) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 330), child: g),
  ),
  'offered no width': (g) =>
      OverflowBox(maxWidth: double.infinity, fit: OverflowBoxFit.deferToChild, alignment: Alignment.topLeft, child: g),
};

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {
    for (final k in _keys)
      if (find.byKey(k).evaluate().isNotEmpty) k: t.getRect(find.byKey(k)),
  };
}

/// Its answers to every question the table and the grid are asked.
List<Object?> _answers(RenderBox box) => [
  box.getMinIntrinsicWidth(double.infinity),
  box.getMaxIntrinsicWidth(double.infinity),
  for (final w in const [600.0, 240.0, 120.0, 60.0, double.infinity]) ...[
    box.getMinIntrinsicHeight(w),
    box.getMaxIntrinsicHeight(w),
  ],
  for (final c in const [
    BoxConstraints(maxWidth: 600),
    BoxConstraints(maxWidth: 120),
    BoxConstraints(minWidth: 330, maxWidth: 600),
    BoxConstraints.tightFor(width: 200),
    BoxConstraints.tightFor(width: 40),
    BoxConstraints(),
  ])
    box.getDryLayout(c),
];

void main() {
  for (final MapEntry(key: name, value: room) in _rooms.entries) {
    for (final width in const [900.0, 420.0, 200.0, 90.0]) {
      testWidgets('a grid of one column is a table of one intrinsic column: $name, $width wide', (t) async {
        for (final columns in const [
          <TrackSize>[],
          [TrackSize.flex(1)],
        ]) {
          final kept = await _rects(t, _page(width, room(_grid(columns: columns))));
          final stock = await _rects(t, _page(width, room(_table)));
          expect(stock, kept, reason: '$columns');
        }
      });
    }
  }

  testWidgets('a grid of one column answers as a table of one intrinsic column', (t) async {
    await t.pumpWidget(_page(400, _grid()));
    final kept = _answers(t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))));
    await t.pumpWidget(_page(400, _table));
    expect(_answers(t.renderObject<RenderBox>(find.byKey(const ValueKey('grid')))), kept);
  });

  testWidgets('NEGATIVE: an IntrinsicWidth answers its least width with its most', (t) async {
    await t.pumpWidget(_page(400, _grid()));
    final kept = t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))).getMinIntrinsicWidth(double.infinity);
    await t.pumpWidget(_page(400, _measured));
    expect(
      t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))).getMinIntrinsicWidth(double.infinity),
      greaterThan(kept),
    );
    // and in a narrow 1fr column of a grid it is floored at that.
    final room = _rooms['in a 1fr column of a grid']!;
    final grid = await _rects(t, _page(200, room(_grid())));
    final measured = await _rects(t, _page(200, room(_measured)));
    expect(measured[const ValueKey('beside')], isNot(grid[const ValueKey('beside')]));
  });

  testWidgets('NEGATIVE: a minmax(0, 1fr) column answers no least width', (t) async {
    await t.pumpWidget(_page(400, _grid(columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))])));
    final kept = t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))).getMinIntrinsicWidth(double.infinity);
    await t.pumpWidget(_page(400, _table));
    expect(
      t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))).getMinIntrinsicWidth(double.infinity),
      greaterThan(kept),
    );
  });

  testWidgets('NEGATIVE: a table answers no baseline, where the grid answers its first item\'s', (t) async {
    // Each in a row on one baseline beside a taller word: the grid stands
    // down at its first item's, the table, which answers none, at the top.
    Widget line(Widget x) => Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(width: 300, child: x),
        const Text('Mg', style: TextStyle(fontSize: 40)),
      ],
    );
    final grid = await _rects(t, _page(400, line(_grid())));
    final table = await _rects(t, _page(400, line(_table)));
    expect(grid[const ValueKey('grid')]!.top, greaterThan(0));
    expect(table[const ValueKey('grid')]!.top, 0);
  });
}
