// A SPAN OF SHARES ACROSS A GUTTER IS A ROW OF NO SPACING, THE GUTTERS
// PADDING ROUND ITS ITEMS. The shares are what the gutters leave of the
// grid's width W over the factors F (css-grid-1 11.7.1), `u = (W - (n - 1)
// g) / F` for n columns g apart, and an item from column s across k columns
// of factors K, with P of them before it, stands at `P u + s g` and is `K u
// + (k - 1) g` wide (the gutters lie between the columns alone, 10.1). A
// `Row` of no spacing that covers every column -- a hole a `Spacer` of its
// factors, an item an `Expanded` of its K -- hands that item `K W / F` at `P
// W / F`, and what lies between the two at either end is the same at every
// W: `g (s - P (n - 1) / F)` before the item and `g ((P + K) (n - 1) / F -
// (s + k - 1))` after it. A news site's front page is `repeat(24,
// minmax(0, 1fr))` 32 apart round a lead across 16 columns beside a rail
// across 8, and a banking site's pricing figures `repeat(12, minmax(0, 1fr))` 16
// apart round a figure across columns 3 to 10; the lowerer
// (`lossy_grid.dart`, `_gutterPadsL`) writes such a row as that `Row` in an
// `IntrinsicHeight`, its items stretched down it -- one item alone in the
// `Row`, which lays it out at its own height -- an even padding a symmetric
// one, floored at the gutters in an `IntrinsicWidth` where it is measured. This pins the two to the same
// boxes at widths down to the gutters, left to right and right to left,
// measured, and to the same answers to every intrinsic question it is
// asked: its most width and its heights (`fixtures/grid-span-shares-gutters`).
// NEGATIVE: a room under the gutters (the shares are nothing, the items
// still the gutters apart, past the room), the `Row` the lowerer wrote
// before (the gutters its spacing, shared out over the items), and factors
// that would pad an item by less than nothing (`3fr 1fr 1fr` round an item
// across the last two, which stands before the `Expanded` it would be
// written in); the lowerer keeps the grid for each.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

const _words = 'The lead story of the day and the rail beside it';

/// An item: a box round words that wrap at its width, stretched down its
/// row.
Widget _item(String name, int words) =>
    ColoredBox(key: _k(name), color: const Color(0xFF3060A0), child: Text(_words.split(' ').take(words).join(' ')));

/// One grid: its columns' factors, its gutter, and its items (start, span,
/// words), all in one row.
typedef _Case = ({List<int> factors, double gap, List<(int, int, int)> items});

Widget _grid(_Case g) => Tracks(
  key: _k('grid'),
  columns: [for (final f in g.factors) TrackSize.between(const TrackSize.fixed(0), TrackSize.flex(f.toDouble()))],
  spacing: g.gap,
  children: [for (final (i, (s, k, w)) in g.items.indexed) TrackCell(column: s, columnSpan: k, child: _item('$i', w))],
);

/// The grid as the lowerer writes it: a hole a `Spacer`, an item an
/// `Expanded` of its factors padded by its share of the gutters, in a row
/// of no spacing -- or, [spaced], the row it wrote before, the gutters its
/// spacing.
Widget _stock(_Case g, {bool spaced = false, double? floor}) {
  final n = g.factors.length;
  final f = g.factors.fold(0, (a, x) => a + x);
  int sum(int from, int to) => g.factors.sublist(from, to).fold(0, (a, x) => a + x);
  final kids = <Widget>[];
  var col = 0;
  void hole(int to) {
    if (to <= col) return;
    if (spaced) {
      for (var i = col; i < to; i++) {
        kids.add(Spacer(flex: g.factors[i]));
      }
    } else {
      kids.add(Spacer(flex: sum(col, to)));
    }
  }

  for (final (i, (s, k, w)) in g.items.indexed) {
    hole(s);
    final p = sum(0, s), across = sum(s, s + k);
    final start = g.gap * (s - p * (n - 1) / f);
    final end = g.gap * ((p + across) * (n - 1) / f - (s + k - 1));
    final x = _item('$i', w);
    final pad = start == end
        ? EdgeInsets.symmetric(horizontal: start)
        : EdgeInsetsDirectional.only(start: start, end: end);
    kids.add(
      Expanded(
        flex: across,
        child: spaced ? x : Padding(padding: pad, child: x),
      ),
    );
    col = s + k;
  }
  hole(n);
  final one = g.items.length == 1;
  final flex = Row(
    crossAxisAlignment: one ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
    spacing: spaced ? g.gap : 0,
    children: kids,
  );
  final row = one ? flex : IntrinsicHeight(child: flex);
  return floor == null
      ? KeyedSubtree(key: _k('grid'), child: row)
      : ConstrainedBox(
          key: _k('grid'),
          constraints: BoxConstraints(minWidth: floor),
          child: row,
        );
}

Widget _page(double width, Widget grid, {bool loose = false, TextDirection dir = TextDirection.ltr}) => Directionality(
  textDirection: dir,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: loose ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
        children: [grid],
      ),
    ),
  ),
);

Future<Map<String, Rect>> _rects(WidgetTester t, Widget w, int items) async {
  await _pump(t, w);
  return {
    for (final k in ['grid', for (var i = 0; i < items; i++) '$i']) k: t.getRect(find.byKey(_k(k))),
  };
}

/// The same boxes, to a millionth of a pixel: the shares and the padding
/// are worked out in other orders, which round in the last places.
void _same(Map<String, Rect> out, Map<String, Rect> css) {
  expect(out.keys, css.keys);
  for (final k in css.keys) {
    expect(out[k], rectMoreOrLessEquals(css[k]!, epsilon: 1e-6), reason: k);
  }
}

/// The intrinsic answers the lowerer leaves the grid asked: its most width,
/// and its heights at widths from [floor] up.
Future<List<double>> _answers(WidgetTester t, Widget w, double floor) async {
  await _pump(t, w);
  final box = t.renderObject<RenderBox>(find.byKey(_k('grid')));
  return [
    box.getMaxIntrinsicWidth(double.infinity),
    for (final width in [floor, floor + 100, 1400.0]) ...[
      box.getMinIntrinsicHeight(width),
      box.getMaxIntrinsicHeight(width),
    ],
  ];
}

/// A window wider than the widest page laid out here.
Future<void> _pump(WidgetTester t, Widget w) async {
  t.view
    ..physicalSize = const Size(2000, 1200)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(w);
}

void main() {
  final cases = <String, _Case>{
    // The news site: the lead and the rail, the one gutter between them
    // 10.67 after the one and 21.33 before the other.
    'lead and rail': (factors: List.filled(24, 1), gap: 32, items: [(0, 16, 11), (16, 8, 6)]),
    // The banking site: one figure across columns 3 to 10, a hole either side.
    'figure': (factors: List.filled(12, 1), gap: 16, items: [(2, 8, 11)]),
    // Two spans with holes between: six columns 20 apart.
    'holes between': (factors: List.filled(6, 1), gap: 20, items: [(1, 2, 7), (4, 2, 3)]),
    // Factors that differ and still pad by something: `1fr 2fr 1fr` 12
    // apart, an item across the first two beside one in the last.
    'other factors': (factors: [1, 2, 1], gap: 12, items: [(0, 2, 9), (2, 1, 4)]),
  };
  for (final MapEntry(key: name, value: g) in cases.entries) {
    final gutters = g.gap * (g.factors.length - 1);
    for (final dir in TextDirection.values) {
      for (final width in [1376.0, 960.0, gutters + 64, gutters]) {
        testWidgets('$name, ${dir.name}, laid out ${width}px wide: the same boxes', (t) async {
          final css = await _rects(t, _page(width, _grid(g), dir: dir), g.items.length);
          final out = await _rects(t, _page(width, _stock(g), dir: dir), g.items.length);
          _same(out, css);
        });
      }
    }
    for (final words in [1, 11]) {
      final _Case h = (factors: g.factors, gap: g.gap, items: [for (final (s, k, _) in g.items) (s, k, words)]);
      testWidgets('$name, $words words, measured: as wide as its content or gutters', (t) async {
        final css = await _rects(t, _page(1400, _grid(h), loose: true), h.items.length);
        final out = await _rects(
          t,
          _page(1400, IntrinsicWidth(child: _stock(h, floor: gutters)), loose: true),
          h.items.length,
        );
        _same(out, css);
        expect(css['grid']!.width, greaterThanOrEqualTo(gutters));
      });
      testWidgets('$name, $words words: the same most width and heights', (t) async {
        final css = await _answers(t, _page(1400, _grid(h)), gutters);
        final out = await _answers(t, _page(1400, _stock(h, floor: gutters)), gutters);
        expect(out, [for (final v in css) moreOrLessEquals(v, epsilon: 1e-6)]);
      });
    }
  }

  testWidgets('NEGATIVE: a room under the gutters leaves the items the gutters apart, past it', (t) async {
    final _Case g = (factors: List.filled(12, 1), gap: 16.0, items: [(0, 8, 3), (8, 4, 3)]);
    final css = await _rects(t, _page(120, _grid(g)), 2);
    final out = await _rects(t, _page(120, _stock(g)), 2);
    expect(css['1']!.left, 8 * 16);
    expect(out['1']!.left, isNot(moreOrLessEquals(css['1']!.left, epsilon: 0.5)));
  });

  testWidgets('NEGATIVE: the row the lowerer wrote before shares the gutters out over its items', (t) async {
    final _Case g = (factors: List.filled(24, 1), gap: 32.0, items: [(0, 16, 11), (16, 8, 6)]);
    final css = await _rects(t, _page(1376, _grid(g)), 2);
    final out = await _rects(t, _page(1376, _stock(g, spaced: true)), 2);
    expect((out['0']!.width - css['0']!.width).abs(), greaterThan(0.5));
  });

  testWidgets('NEGATIVE: `3fr 1fr 1fr` would pad an item by less than nothing', (t) async {
    final _Case g = (factors: [3, 1, 1], gap: 10.0, items: [(1, 2, 3)]);
    final css = await _rects(t, _page(600, _grid(g)), 1);
    // The `Expanded` of the last two columns' factors starts 3/5 of the way
    // along; the item 2px before it.
    expect(css['0']!.left, moreOrLessEquals(600 * 3 / 5 - 2, epsilon: 1e-9));
  });
}
