// AN ITEM NO WIDER THAN THE GRID'S ROOM, WHERE THE GRID SHRINKS TO ITS
// CONTENT, NEVER GROWS ITS COLUMN. A grid of no columns has one `auto`
// column (css-grid-1 7.5), floored at its items' least contributions (11.5):
// a width an item states, whether or not it clips (`tracks.dart`
// `_minimum`: the stated size first, 6.6). A box that shrinks to its content
// lays the grid out at no less than the less of its room and its own least
// or most width, both at least the item's: where the room is wider than the
// item the column is the grid's, and the item stands at its point of it.
// A product site's icon tiles are a 20px `display: grid; place-items: center` box
// round a 13px `overflow: hidden` icon in a row that shrinks to fit; the
// lowerer (`lossy_grid.dart`, `_gridAtL`) writes the tile's grid as an
// `Align` round the icon, which this pins to css_box's boxes at three
// sizes, in a row under an `IntrinsicWidth` and down a column
// (`fixtures/grid-item-stated-bounded-room`).
// NEGATIVE: an icon wider than the tile grows the column, and stands at its
// start, out of the tile; the `Align` holds it to the tile -- the lowerer
// keeps css_box's grid for it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

Widget _icon(double size) => SizedBox(
  key: _k('icon'),
  width: size,
  height: size,
  child: ClipRect(
    child: SizedBox(width: size, height: size),
  ),
);

/// The tile as css_box lays it out.
Widget _grid(double tile, double icon) => SizedBox(
  key: _k('tile'),
  width: tile,
  height: tile,
  child: Tracks(
    align: CellAlign.center,
    justify: CellAlign.center,
    children: [TrackCell(width: icon, height: icon, clips: true, child: _icon(icon))],
  ),
);

/// The tile as the lowerer writes it.
Widget _stock(double tile, double icon) => SizedBox(
  key: _k('tile'),
  width: tile,
  height: tile,
  child: Align(alignment: Alignment.center, child: _icon(icon)),
);

Widget _page(Widget tile, {required bool row}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: row
        ? IntrinsicWidth(
            child: Row(
              spacing: 6,
              children: [
                tile,
                SizedBox(key: _k('label'), width: 40, height: 21),
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile,
              SizedBox(key: _k('label'), width: 40, height: 21),
            ],
          ),
  ),
);

Future<Map<String, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {
    for (final k in const ['tile', 'icon', 'label']) k: t.getRect(find.byKey(_k(k))),
  };
}

void main() {
  for (final row in const [true, false]) {
    for (final (tile, icon) in const [(20.0, 13.0), (28.0, 16.0), (20.0, 20.0)]) {
      testWidgets(
        'a ${icon}px icon in a ${tile}px tile stands at its middle, ${row ? 'in a row that shrinks to fit' : 'down a column'}',
        (t) async {
          final css = await _rects(t, _page(_grid(tile, icon), row: row));
          final out = await _rects(t, _page(_stock(tile, icon), row: row));
          expect(out, css);
          expect(css['icon']!.left - css['tile']!.left, (tile - icon) / 2);
        },
      );
    }
  }

  testWidgets('NEGATIVE: an icon wider than its tile grows the column, out of the tile', (t) async {
    final css = await _rects(t, _page(_grid(20, 30), row: true));
    final out = await _rects(t, _page(_stock(20, 30), row: true));
    expect(css['icon']!.width, 30);
    expect(out['icon'], isNot(css['icon']));
  });
}
