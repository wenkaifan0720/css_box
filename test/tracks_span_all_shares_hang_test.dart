// SHARES UNDER ITEMS ACROSS THEM ALL, IN A ROOM THAT MAY BE LESS THAN THEIR
// GUTTERS, ARE A COLUMN AS WIDE AS THE WIDER OF THE TWO, HUNG PAST THE
// GRID'S END. The shares are nothing where the gutters leave nothing
// (css-grid-1 11.7.1: no free space, an `fr` of nothing) and the items
// across them all as wide as the gutters, at the start (an automatic minimum
// of nothing across a flexible track, 6.6; the tracks laid from the start,
// 11.8); where the room is wider, the items are all of it. A product site's cards
// are `repeat(12, 1fr)` 24px apart round a block at `grid-column: 1 / -1`
// inside a card's 32px padding, 264px of gutters in a room the lowerer does
// not read; it (`lossy_grid.dart`, `_gridAtL`) writes such a grid as a
// `Table` of one `MaxColumnWidth(FlexColumnWidth(), FixedColumnWidth(264))`:
// the column takes all of a width handed tight, no less than the gutters
// past the table's end, every cell laid out at `tightFor(width:)` at the top
// of its row (`rendering/table.dart`), a row gap a row of that height. This
// pins the two to the same boxes at widths above, at and under the gutters,
// bare `1fr` and `minmax(0, 1fr)`, and to the same heights asked at any
// width (`fixtures/grid-span-all-shares-hang`).
// NEGATIVE: what the lowerer keeps the grid for -- its least and most widths
// (a column of flex answers the gutters alone), a baseline (a table answers
// none), a height it is held to (the grid stretches its rows into it), and
// right to left (the table hangs its column past its right, where the grid
// hangs it past its left).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

const _keys = ['grid', 'a', 'b'];

Widget _a(String text) => Text(text, key: _k('a'));
Widget _b() => SizedBox(key: _k('b'), height: 40, child: const Text('Start for free'));

/// The grid as css_box lays it out: [n] columns of [track], [gap] apart.
Widget _grid(String text, {int n = 12, double gap = 24, TrackSize track = const TrackSize.flex(1)}) => Tracks(
  key: _k('grid'),
  columns: [
    TrackSize.repeat(n, [track]),
  ],
  spacing: gap,
  runSpacing: 8,
  children: [
    TrackCell(column: 0, columnEnd: n, margin: const EdgeInsets.only(top: 24), child: _a(text)),
    TrackCell(columnSpan: n, child: _b()),
  ],
);

/// The grid as the lowerer writes it: a table of one column no narrower
/// than the gutters [hang].
Widget _stock(String text, double hang) => Table(
  key: _k('grid'),
  columnWidths: {0: MaxColumnWidth(const FlexColumnWidth(), FixedColumnWidth(hang))},
  children: [
    TableRow(
      children: [Padding(padding: const EdgeInsets.only(top: 24), child: _a(text))],
    ),
    const TableRow(children: [SizedBox(height: 8)]),
    TableRow(children: [_b()]),
  ],
);

Widget _page(double width, Widget grid, {TextDirection dir = TextDirection.ltr}) => Directionality(
  textDirection: dir,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [grid]),
    ),
  ),
);

Future<Map<String, Rect>> _rects(WidgetTester t, Widget w) async {
  await _pump(t, w);
  return {for (final k in _keys) k: t.getRect(find.byKey(_k(k)))};
}

void _same(Map<String, Rect> out, Map<String, Rect> css) {
  expect(out.keys, css.keys);
  for (final k in css.keys) {
    expect(out[k], rectMoreOrLessEquals(css[k]!, epsilon: 1e-9), reason: k);
  }
}

/// The heights of the box keyed `grid`, asked at widths under, at and over
/// [hang].
Future<List<double>> _heights(WidgetTester t, Widget w, double hang) async {
  await _pump(t, w);
  final box = t.renderObject<RenderBox>(find.byKey(_k('grid')));
  return [
    for (final width in [hang - 100, hang, 600.0, 1200.0]) ...[
      box.getMinIntrinsicHeight(width),
      box.getMaxIntrinsicHeight(width),
    ],
  ];
}

const _short = 'Hi';
const _long = 'Everything you need to build the apps your teams run on, connected to your data and your work';
const _none = TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1));

/// A window wider than the widest page laid out here.
Future<void> _pump(WidgetTester t, Widget w) async {
  t.view
    ..physicalSize = const Size(2000, 1200)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(w);
}

void main() {
  for (final text in const [_short, _long]) {
    for (final (n, gap, track) in const [
      (12, 24.0, TrackSize.flex(1)),
      (12, 32.0, TrackSize.flex(1)),
      (6, 24.0, _none),
    ]) {
      final hang = gap * (n - 1);
      for (final width in [780.0, hang + 8, hang, hang - 40, 120.0]) {
        testWidgets(
          '$n shares $gap apart, ${text.length} letters, ${width}px wide: a column no narrower than the gutters',
          (t) async {
            final css = await _rects(t, _page(width, _grid(text, n: n, gap: gap, track: track)));
            final out = await _rects(t, _page(width, _stock(text, hang)));
            _same(out, css);
            expect(css['a']!.width, moreOrLessEquals(width > hang ? width : hang, epsilon: 1e-9));
          },
        );
      }
      testWidgets('$n shares $gap apart, ${text.length} letters: the same heights at any width', (t) async {
        final css = await _heights(t, _page(780, _grid(text, n: n, gap: gap, track: track)), hang);
        final out = await _heights(t, _page(780, _stock(text, hang)), hang);
        expect(out, [for (final v in css) moreOrLessEquals(v, epsilon: 1e-9)]);
      });
    }
  }

  testWidgets('NEGATIVE: a table answers its least and most widths with the gutters alone', (t) async {
    await _pump(t, _page(780, _grid(_long)));
    final css = t.renderObject<RenderBox>(find.byKey(_k('grid'))).getMaxIntrinsicWidth(double.infinity);
    await _pump(t, _page(780, _stock(_long, 264)));
    final out = t.renderObject<RenderBox>(find.byKey(_k('grid')));
    expect(css, greaterThan(264));
    expect([out.getMinIntrinsicWidth(double.infinity), out.getMaxIntrinsicWidth(double.infinity)], [264, 264]);
  });

  testWidgets('NEGATIVE: a table answers no baseline, where a row lines it up on one', (t) async {
    Widget lined(Widget grid) => _page(
      780,
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: grid),
          Text('x', key: _k('x')),
        ],
      ),
    );
    await _pump(t, lined(_grid(_short)));
    final css = t.getRect(find.byKey(_k('x')));
    await _pump(t, lined(_stock(_short, 264)));
    final out = t.getRect(find.byKey(_k('x')));
    // The grid stands on its first item's baseline, 24px down its margin.
    expect(css.top, greaterThanOrEqualTo(24));
    expect(out.top, isNot(css.top));
  });

  testWidgets('NEGATIVE: held to a height, the grid stretches its rows into it', (t) async {
    Widget held(Widget grid) => _page(780, SizedBox(height: 300, child: grid));
    final css = await _rects(t, held(_grid(_short)));
    final out = await _rects(t, held(_stock(_short, 264)));
    expect(out['b']!.top, isNot(moreOrLessEquals(css['b']!.top, epsilon: 0.5)));
  });

  testWidgets('NEGATIVE: right to left, the table hangs its column past its right', (t) async {
    final css = await _rects(t, _page(200, _grid(_short), dir: TextDirection.rtl));
    final out = await _rects(t, _page(200, _stock(_short, 264), dir: TextDirection.rtl));
    expect(css['a']!.left, lessThan(0));
    expect(out['b']!.left, isNot(moreOrLessEquals(css['b']!.left, epsilon: 0.5)));
  });
}
