// AN ITEM THAT STATES ITS LEAST SIZE gives a grid sized under a
// min-content constraint that least, not its min-content: Chrome sizes an
// `auto` minimum by its items' MINIMUM contributions there too (css-grid-1
// 6.6, 11.5 step 2: the stated `min-width` where it is not `auto`), where
// Taffy takes the limited min-content contribution of every item that is
// not a scroll container (`tracks.dart`, `_statesLeast`). So a grid of
// links of `min-width: 0` has no least width from them, and a share of a
// grid it is an item of has no floor from it: `Tracks` asks the nested
// `Tracks` its least width (`computeMinIntrinsicWidth`) for the item's
// content-based minimum (6.6). Chrome, measured: a docs site's mega menu at
// 240, link lists of `min-width: 0` in the menu's `repeat(3, 1fr)`, stood
// every share at 57.3, where these lists floored them at their words
// (`fixtures/grid-share-nested-grid-least` p4).
//
// This pins the menu css_box lays out to the row of `Expanded`s the lowerer
// writes for it -- every share at its share, the words hanging out -- at
// several widths; a stated least over the share floors it at that least,
// not the word; and an item across two `auto` columns gives them its stated
// least too. NEGATIVE: links of `min-width: auto` still floor the lists at
// their words; a link that clips gives nothing, as before; the greatest
// width is the words', whatever the least.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// The test font sets every glyph an em square: at 14px the longest words
// of the three lists are 154, 182 and 126 wide.
const _links = [
  ['Structuring content', 'Forms'],
  ['Accessibility'],
  ['Scripting'],
];

final _keys = [
  const ValueKey('menu'),
  for (var i = 0; i < 3; i++) ...[ValueKey('list$i'), for (var j = 0; j < _links[i].length; j++) ValueKey('link$i.$j')],
];

Widget _page(double width, Widget menu) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: menu),
  ),
);

Widget _link(int i, int j) => Text(_links[i][j], key: ValueKey('link$i.$j'));

/// The menu css_box lays out: three `1fr` columns 22 apart, each a list of
/// links 8 apart (`align-content: start`), each link in [cell].
Widget _kept(Widget Function(Widget link) cell) => Tracks(
  key: const ValueKey('menu'),
  columns: const [
    TrackSize.repeat(3, [TrackSize.flex(1)]),
  ],
  spacing: 22,
  runSpacing: 22,
  children: [
    for (var i = 0; i < 3; i++)
      Tracks(
        key: ValueKey('list$i'),
        spacing: 8,
        runSpacing: 8,
        alignContent: TrackContent.start,
        children: [for (var j = 0; j < _links[i].length; j++) cell(_link(i, j))],
      ),
  ],
);

/// What the lowerer writes for it: a row as tall as its tallest list, of
/// `Expanded`s, each a list stretched across its share.
Widget _written() => IntrinsicHeight(
  key: const ValueKey('menu'),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 22,
    children: [
      for (var i = 0; i < 3; i++)
        Expanded(
          child: Column(
            key: ValueKey('list$i'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [for (var j = 0; j < _links[i].length; j++) _link(i, j)],
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

Widget _none(Widget link) => TrackCell(minWidth: 0, child: link);
Widget _same(Widget link) => link;

void main() {
  // At 240 the shares are 65.3, under every list's longest word.
  for (final width in const [780.0, 400.0, 240.0]) {
    testWidgets('links of min-width 0 give the lists no least: the shares stand, $width wide', (t) async {
      final kept = await _rects(t, _page(width, _kept(_none)));
      final written = await _rects(t, _page(width, _written()));
      expect(written, kept);
      expect(kept, hasLength(_keys.length));
      for (var i = 0; i < 3; i++) {
        expect(_width(kept, 'list$i'), closeTo((width - 44) / 3, 1e-9));
      }
    });
  }

  testWidgets('a stated least over the share floors the list at it, not at its words', (t) async {
    final kept = await _rects(t, _page(240, _kept((link) => TrackCell(minWidth: 100, child: link))));
    expect([for (var i = 0; i < 3; i++) _width(kept, 'list$i')], [100, 100, 100]);
  });

  testWidgets('the least of a grid is its items\' stated leasts; its greatest is their words', (t) async {
    await t.pumpWidget(_page(780, _kept(_none)));
    final list = t.renderObject<RenderBox>(find.byKey(const ValueKey('list1')));
    expect(list.getMinIntrinsicWidth(double.infinity), 0);
    expect(list.getMaxIntrinsicWidth(double.infinity), 182);
    await t.pumpWidget(_page(780, _kept((link) => TrackCell(minWidth: 30, child: link))));
    final thirty = t.renderObject<RenderBox>(find.byKey(const ValueKey('list1')));
    expect(thirty.getMinIntrinsicWidth(double.infinity), 30);
    expect(thirty.getMaxIntrinsicWidth(double.infinity), 182);
  });

  testWidgets('an item across two auto columns gives them its stated least', (t) async {
    Widget grid(double? least) => Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: Tracks(
          key: const ValueKey('grid'),
          columns: const [TrackSize.auto, TrackSize.auto],
          spacing: 8,
          children: [TrackCell(columnSpan: 2, minWidth: least, child: const Text('Accessibility'))],
        ),
      ),
    );
    await t.pumpWidget(grid(0));
    expect(t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))).getMinIntrinsicWidth(double.infinity), 8);
    // NEGATIVE: at `min-width: auto` the item gives its word.
    await t.pumpWidget(grid(null));
    expect(t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))).getMinIntrinsicWidth(double.infinity), 182);
  });

  testWidgets('NEGATIVE: links of min-width auto floor the lists at their words', (t) async {
    final kept = await _rects(t, _page(240, _kept(_same)));
    final written = await _rects(t, _page(240, _written()));
    expect(written, isNot(kept));
    expect([for (var i = 0; i < 3; i++) _width(kept, 'list$i')], [154, 182, 126]);
    expect(_width(written, 'list1'), closeTo(196 / 3, 1e-9));
  });

  testWidgets('NEGATIVE: a link that clips gives nothing, as before', (t) async {
    final kept = await _rects(t, _page(240, _kept((link) => TrackCell(clips: true, child: link))));
    for (var i = 0; i < 3; i++) {
      expect(_width(kept, 'list$i'), closeTo(196 / 3, 1e-9));
    }
  });
}
