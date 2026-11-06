// ONE ITEM ACROSS A SHARE OF A ROW AND THE `auto` ROW AFTER IT IS THE
// GRID'S ONE ROW. Its span makes the second row (css-grid-1 7.5:
// `grid-auto-rows` is `auto`). An item across a flexible track grows the
// flexible ones alone (11.5, step 4) and its automatic minimum is nothing
// (6.6: it spans more than one track, one of them flexible), so the `auto`
// row is nothing tall and the share all of the item: its whole height under
// a max-content constraint (12.7), the most it is offered under a loose one,
// and the height the grid is held to -- or nothing at a factor of 0, where
// the grid is as tall as its content. A product site's menu columns are
// `grid-template-rows: 1fr` (`0fr`, closed, on a phone) round a list at
// `grid-row: 1 / span 2`; the lowerer (`lossy_grid.dart`, `_gridAtL`) writes
// such a grid as its item, or a `SizedBox` of no height round it. This pins
// the two to the same boxes down a stretched column at two widths, in a row
// of a height that leaves the item its own, and held to a height
// (`fixtures/grid-row-share-span-auto`).
// NEGATIVE: a `0fr` row held to a height, which the `auto` row after it
// stretches into (11.8) and the item with it; a gutter between the two
// taller than the item, which the item is never less than; and a share
// under one whole, which takes only that much of the item. The lowerer
// keeps css_box's grid for them.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

const _keys = ['grid', 'list'];

/// The menu's list: six links, a line each. (A paragraph, not a `Column`:
/// offered less than its height it overflows silently, as the list does in
/// the browser, where a `Column` throws.)
Widget _list() => Text([for (var i = 0; i < 6; i++) 'Link $i'].join('\n'), key: _k('list'));

/// The grid as css_box lays it out: one row of [share], the list across it
/// and the `auto` row after it.
Widget _grid(double share, {double runSpacing = 0, Widget? item, bool clips = false}) => Tracks(
  key: _k('grid'),
  rows: [TrackSize.flex(share)],
  runSpacing: runSpacing,
  children: [TrackCell(row: 0, rowSpan: 2, clips: clips, child: item ?? _list())],
);

/// The grid as the lowerer writes it.
Widget _stock(double share) =>
    share == 0 ? SizedBox(key: _k('grid'), height: 0, child: _list()) : KeyedSubtree(key: _k('grid'), child: _list());

Widget _page(double width, Widget grid, {double? held, double? row}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: row != null
          ? SizedBox(
              height: row,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: grid)],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                held != null ? SizedBox(height: held, child: grid) : grid,
                const SizedBox(height: 20),
              ],
            ),
    ),
  ),
);

Future<Map<String, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(_k(k)))};
}

Future<List<double>> _height(WidgetTester t, Widget w, double width) async {
  await t.pumpWidget(w);
  final box = t.renderObject<RenderBox>(find.byKey(_k('grid')));
  return [box.getMinIntrinsicHeight(width), box.getMaxIntrinsicHeight(width)];
}

void main() {
  for (final share in const [1.0, 2.0, 0.0]) {
    for (final width in const [600.0, 240.0]) {
      testWidgets('one item across a row of ${share}fr and the row after it, ${width}px wide, is the grid\'s one row', (
        t,
      ) async {
        final css = await _rects(t, _page(width, _grid(share)));
        final out = await _rects(t, _page(width, _stock(share)));
        expect(out, css);
        expect(css['grid']!.height, share == 0 ? 0 : css['list']!.height);
        expect(css['list']!.height, share == 0 ? 0 : greaterThan(0));
      });
      // Its least and most heights; an item that clips alike.
      for (final clips in const [false, true]) {
        testWidgets(
          'one item${clips ? ' that clips' : ''} across a row of ${share}fr and the row after it, ${width}px wide, answers its heights as the grid',
          (t) async {
            expect(
              await _height(t, _page(width, _stock(share)), width),
              await _height(t, _page(width, _grid(share, clips: clips)), width),
            );
          },
        );
      }
    }
    // In a row of a height: offered at most 60 or 400, it takes what it
    // wants of it.
    for (final row in const [60.0, 400.0]) {
      testWidgets('one item across a row of ${share}fr and the row after it, offered at most ${row}px', (t) async {
        final css = await _rects(t, _page(600, _grid(share), row: row));
        final out = await _rects(t, _page(600, _stock(share), row: row));
        expect(out, css);
      });
    }
  }
  // Held to a height, a share takes it.
  for (final held in const [60.0, 300.0]) {
    testWidgets('one item across a row of 1fr and the row after it, held to ${held}px, takes it', (t) async {
      final css = await _rects(t, _page(600, _grid(1), held: held));
      final out = await _rects(t, _page(600, SizedBox(height: held, child: _stock(1))));
      expect(out, css);
      expect(css['list']!.height, held);
    });
  }

  testWidgets('NEGATIVE: a row of 0fr held to a height stretches the auto row after it, and the item', (t) async {
    final css = await _rects(t, _page(600, _grid(0), held: 120));
    // The grid's one row, as a column of rows writes it, held to the height.
    final out = await _rects(
      t,
      _page(
        600,
        SizedBox(
          height: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_stock(0)],
          ),
        ),
      ),
    );
    expect(css['list']!.height, 120);
    expect(out['list']!.height, 0);
  });

  testWidgets('NEGATIVE: a gutter taller than the item between the two rows', (t) async {
    await t.pumpWidget(_page(600, _grid(1, runSpacing: 30, item: Text('Link', key: _k('list')))));
    expect(t.getRect(find.byKey(_k('list'))).height, 30);
  });

  testWidgets('NEGATIVE: a share under one whole takes only that much of the item', (t) async {
    final css = await _rects(t, _page(600, _grid(0.5)));
    final out = await _rects(t, _page(600, _stock(0.5)));
    expect(out, isNot(css));
    expect(css['grid']!.height, closeTo(out['list']!.height / 2, 0.01));
  });
}
