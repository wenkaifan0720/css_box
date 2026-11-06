// A SHARE OF A GRID IS NO NARROWER THAN A GRID IN IT AT ITS LEAST. A bare
// `1fr` is `minmax(auto, 1fr)`, and its `auto` floor is the min-content
// contribution of an item in it (css-grid-1 6.6, 11.5). An item that is
// itself a grid of columns its content sizes contributes its own
// min-content width: each `auto` column under a min-content constraint is
// its items' widest min-content contribution (11.5 steps 2.1 and 3, 11.7:
// no fraction under a min-content constraint), so the share is no narrower
// than the nested grid's widest item -- `Tracks` asks the nested `Tracks`
// its least width (`computeMinIntrinsicWidth`) and floors the column at
// it. The `Row` of `Expanded`s the lowerer writes for a grid of shares has
// no floor, so it keeps the grid where the nested grid's widest item
// passes a share at the room it is laid out in.
// A docs site's mega menu: link lists, `display: grid`, under a heading in a
// `display: grid` column, three of them in the menu's `repeat(3, 1fr)`
// (`fixtures/grid-one-column-least-asked`, p2;
// `fixtures/grid-share-nested-grid-least`).
//
// This pins the row the lowerer writes to the grid it keeps where every
// share holds its column's least, at several widths; and the grid where a
// share is under it. NEGATIVE: there the row stands every column at its
// share (kept); a list of `minmax(0, 1fr)` has no least, so the shares
// stand and the row is the grid at any width; a list of a length is that
// length at least, not its words, which the lowerer does not read; a list
// of two `auto` columns is no narrower than its widest item (the sum of
// its columns, which the lowerer does not read, is more); links of
// `min-width: 0` give the list no least at all (its items' minimum
// contributions, `tracks_stated_least_test.dart`; Chrome, measured: the
// fixture's p4), so the shares stand over the headings, as the row stands
// them; and the padding round a list floors it on top.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// The test font sets every glyph an em square: at 14px the longest words
// of the three lists are 154, 182 and 126 wide, the headings 56, 42, 28.
const _heads = ['HTML', 'CSS', 'JS'];
const _links = [
  ['Structuring content', 'Forms'],
  ['Accessibility'],
  ['Scripting'],
];

final _keys = [
  const ValueKey('menu'),
  for (var i = 0; i < 3; i++) ...[
    ValueKey('col$i'),
    ValueKey('head$i'),
    ValueKey('list$i'),
    for (var j = 0; j < _links[i].length; j++) ValueKey('link$i.$j'),
  ],
];

Widget _page(double width, Widget menu) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: menu),
  ),
);

Widget _link(int i, int j) => Text(_links[i][j], key: ValueKey('link$i.$j'));

/// The menu css_box keeps: three `1fr` columns 22 apart, each a grid of a
/// heading over a list of links, the list's columns [list], each link in
/// [cell] and each list in [round].
Widget _kept({
  List<TrackSize> list = const [],
  Widget Function(Widget link) cell = _same,
  Widget Function(int i, Widget list) round = _own,
}) => Tracks(
  key: const ValueKey('menu'),
  columns: const [
    TrackSize.repeat(3, [TrackSize.flex(1)]),
  ],
  spacing: 22,
  runSpacing: 22,
  children: [
    for (var i = 0; i < 3; i++)
      Tracks(
        key: ValueKey('col$i'),
        spacing: 12.8,
        runSpacing: 12.8,
        alignContent: TrackContent.start,
        children: [
          Text(_heads[i], key: ValueKey('head$i')),
          round(
            i,
            Tracks(
              key: round == _own ? ValueKey('list$i') : null,
              columns: list,
              spacing: 8,
              runSpacing: 8,
              children: [for (var j = 0; j < _links[i].length; j++) cell(_link(i, j))],
            ),
          ),
        ],
      ),
  ],
);

Widget _same(Widget link) => link;
Widget _own(int i, Widget list) => list;

/// What the lowerer writes for it where every share holds its column's
/// least: a row as tall as its tallest column, of `Expanded`s, each a
/// column stretched across its share; a list of one link is that link.
Widget _written() => IntrinsicHeight(
  key: const ValueKey('menu'),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 22,
    children: [
      for (var i = 0; i < 3; i++)
        Expanded(
          child: IntrinsicWidth(
            key: ValueKey('col$i'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12.8,
              children: [
                Text(_heads[i], key: ValueKey('head$i')),
                if (_links[i].length == 1)
                  KeyedSubtree(key: ValueKey('list$i'), child: _link(i, 0))
                else
                  Column(
                    key: ValueKey('list$i'),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [for (var j = 0; j < _links[i].length; j++) _link(i, j)],
                  ),
              ],
            ),
          ),
        ),
    ],
  ),
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {
    for (final k in _keys)
      if (find.byKey(k).evaluate().isNotEmpty) k: t.getRect(find.byKey(k)),
  };
}

double _width(Map<Key, Rect> r, String key) => r[ValueKey(key)]!.width;

void main() {
  // The shares at 780 and 600 (245.3, 185.3) hold every list's longest
  // word (182 the widest): the row is the grid.
  for (final width in const [780.0, 700.0, 600.0]) {
    testWidgets('every share holds the least of the grid in it: the row is the grid, $width wide', (t) async {
      final kept = await _rects(t, _page(width, _kept()));
      final written = await _rects(t, _page(width, _written()));
      expect(written, kept);
      expect(kept, hasLength(_keys.length));
    });
  }

  // Under 590 a share is narrower than 182: the grid floors that column.
  for (final width in const [560.0, 400.0, 240.0]) {
    testWidgets('NEGATIVE: a share under the least of the grid in it floors the column, $width wide (kept)', (t) async {
      final kept = await _rects(t, _page(width, _kept()));
      final written = await _rects(t, _page(width, _written()));
      expect(written, isNot(kept));
      final share = (width - 44) / 3;
      expect(_width(written, 'col1'), closeTo(share, 1e-9));
      expect(_width(kept, 'col1'), 182);
      if (width == 240) {
        // Every column falls to its list's longest word, side by side.
        expect([for (var i = 0; i < 3; i++) _width(kept, 'col$i')], [154, 182, 126]);
        expect(kept[const ValueKey('col2')]!.left, 154 + 22 + 182 + 22);
      }
    });
  }

  testWidgets('NEGATIVE: a list of minmax(0, 1fr) has no least: the shares stand and the row is the grid', (t) async {
    const zero = [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))];
    for (final width in const [780.0, 600.0, 400.0, 240.0]) {
      final kept = await _rects(t, _page(width, _kept(list: zero)));
      final written = await _rects(t, _page(width, _written()));
      expect(written, kept, reason: '$width');
      expect(_width(kept, 'col1'), closeTo((width - 44) / 3, 1e-9), reason: '$width');
    }
  });

  testWidgets('NEGATIVE: a list of a length is that length at least, not its words (not read)', (t) async {
    final kept = await _rects(t, _page(240, _kept(list: const [TrackSize.fixed(40)])));
    // The headings (56 the widest) and the 40 hold in the share of 65.3,
    // each link laid out at the 40 of its column.
    expect(_width(kept, 'col1'), closeTo(196 / 3, 1e-9));
    expect(_width(kept, 'link1.0'), 40);
  });

  testWidgets('a list of two auto columns is no narrower than its widest item: the sum of its columns', (t) async {
    // Each link beside a 16px icon, 6 apart: the column is the icon, the
    // gap and the word, 204 in the middle.
    final kept = await _rects(
      t,
      _page(
        240,
        _kept(
          round: (i, list) => Tracks(
            key: ValueKey('list$i'),
            columns: const [TrackSize.auto, TrackSize.auto],
            spacing: 6,
            runSpacing: 8,
            children: [
              for (var j = 0; j < _links[i].length; j++) ...[const SizedBox(width: 16, height: 16), _link(i, j)],
            ],
          ),
        ),
      ),
    );
    expect(_width(kept, 'col1'), 16 + 6 + 182);
    final written = await _rects(t, _page(240, _written()));
    expect(_width(written, 'col1'), lessThan(182));
  });

  testWidgets('links of min-width 0 give the list no least: the row is the grid; padding round it floors it on top', (
    t,
  ) async {
    final none = await _rects(t, _page(240, _kept(cell: (link) => TrackCell(minWidth: 0, child: link))));
    final written = await _rects(t, _page(240, _written()));
    expect(none, written);
    expect([for (var i = 0; i < 3; i++) _width(none, 'col$i')], everyElement(closeTo(196 / 3, 1e-9)));
    final padded = await _rects(
      t,
      _page(
        240,
        _kept(
          round: (i, list) =>
              Padding(key: ValueKey('list$i'), padding: const EdgeInsets.symmetric(horizontal: 10), child: list),
        ),
      ),
    );
    expect([for (var i = 0; i < 3; i++) _width(padded, 'col$i')], [174, 202, 146]);
  });
}
