// A GRID LAYS AN ITEM IT DOES NOT STRETCH DOWN ITS ROW OUT AT THE ITEM'S
// OWN HEIGHT. An item aligned `start`, `center` or `end` is fit-content
// down its area (css-grid-1 6.2, css-align-3 6.1): `Tracks` measures it at
// its width and lays it out tight at the height that comes to (`_measure`,
// a dry layout at `tightFor(width)`; `_positionItem`, which stretches the
// height only where `_Item._stretches`). So a grid in such an item is
// handed its own height, and its rows have nothing to share out -- which
// neither spelling the lowerer writes it as shares either:
// a column
// of rows, or the `Table` of one intrinsic column it writes where it is
// asked its least width (`tracks_least_table_test.dart`). a docs site's
// menu panels, grids of links in the `min-content` columns of grids
// (`fixtures/grid-item-unstretched`).
//
// This pins an inner grid and both spellings to the same boxes, in an item
// aligned at each point beside a taller neighbour, at several widths.
// NEGATIVE: an item stretched down its row -- the default -- hands the
// inner grid the row's height, which its rows share out and a `Column`
// does not.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [ValueKey('grid'), ValueKey('inner'), ValueKey('a'), ValueKey('b'), ValueKey('side')];

const _a = Text('Getting started', key: ValueKey('a'));
const _b = Text('Core modules', key: ValueKey('b'));

Widget _page(double width, Widget grid) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: grid),
  ),
);

/// The inner grid css_box keeps: two rows 8 apart.
const Widget _inner = Tracks(key: ValueKey('inner'), runSpacing: 8, children: [_a, _b]);

/// What the lowerer writes for it: a column of rows ...
const Widget _column = Column(
  key: ValueKey('inner'),
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 8,
  children: [_a, _b],
);

/// ... or, asked its least width, a table of one intrinsic column.
final Widget _table = Table(
  key: const ValueKey('inner'),
  defaultColumnWidth: const IntrinsicColumnWidth(),
  children: const [
    TableRow(children: [_a]),
    TableRow(children: [SizedBox(height: 8)]),
    TableRow(children: [_b]),
  ],
);

/// A grid of a `min-content` column and a share, the inner grid [inner]
/// in an item aligned [align] (on the grid, or on the cell [onCell])
/// beside a taller neighbour.
Widget _outer(Widget inner, CellAlign? align, {bool onCell = false}) => Tracks(
  key: const ValueKey('grid'),
  columns: const [TrackSize.minContent, TrackSize.flex(1)],
  spacing: 12,
  align: onCell ? CellAlign.stretch : align ?? CellAlign.stretch,
  children: [
    onCell ? TrackCell(align: align, child: inner) : inner,
    const SizedBox(key: ValueKey('side'), height: 120, child: Text('beside it')),
  ],
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

void main() {
  for (final align in const [
    CellAlign.start,
    CellAlign.center,
    CellAlign.end,
    CellAlign.safeCenter,
    CellAlign.safeEnd,
  ]) {
    for (final onCell in const [false, true]) {
      testWidgets(
        'an item at a point down its row is laid out at its own height: ${align.name}${onCell ? ' on the cell' : ''}',
        (t) async {
          for (final width in const [600.0, 300.0, 140.0, 60.0]) {
            final kept = await _rects(t, _page(width, _outer(_inner, align, onCell: onCell)));
            for (final written in [_column, _table]) {
              expect(
                await _rects(t, _page(width, _outer(written, align, onCell: onCell))),
                kept,
                reason: '$width ${written.runtimeType}',
              );
            }
          }
        },
      );
    }
  }

  testWidgets('NEGATIVE: an item stretched down its row shares the row out over its rows', (t) async {
    final kept = await _rects(t, _page(600, _outer(_inner, null)));
    final written = await _rects(t, _page(600, _outer(_column, null)));
    expect(kept[const ValueKey('inner')]!.height, 120);
    expect(kept[const ValueKey('b')]!.top, greaterThan(written[const ValueKey('b')]!.top));
  });
}
