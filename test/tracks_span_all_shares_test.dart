// SHARES UNDER ITEMS ACROSS THEM ALL ARE ONE COLUMN, NEVER NARROWER THAN
// THEIR GUTTERS. The shares are what the gutters leave of the grid's width
// (css-grid-1 11.7.1), so an item across every one of them and every gutter
// between them is all of it -- wherever that is at least the gutters. Its
// items size the shares only together: an item across a flexible track
// grows the flexible tracks alone, in proportion to their factors, by what
// its contribution leaves past the gutters it covers (11.5, step 4; an
// automatic minimum of nothing across more than one track, 6.6), and under
// a max-content constraint a share is its items' room past the gutters over
// the factors (12.7) -- one column's least and most widths, but never less
// than the gutters. A product site's sections are `repeat(12, 1fr)` with a 24px
// gap round blocks at `grid-column: 1 / -1`; the lowerer (`lossy_grid.dart`,
// `_gridAtL`) writes such a grid as its items down a stretched `Column`,
// in a `ConstrainedBox` of the gutters' width where its width is asked or
// measured -- and with no gap (the product site's phone sections), at any width,
// with no box round it. This pins the two to the same boxes laid out at
// four widths down to the gutters, measured in a box that leaves it its
// own width, and to the same answers to every intrinsic question
// (`fixtures/grid-span-all-shares`).
// NEGATIVE: a room under the gutters (css_box's item is as wide as the
// gutters, past it; the lowerer writes a `Table` of one column no narrower
// than them there, `tracks_span_all_shares_hang_test.dart`), the floor left out (its
// least and most widths are its items' alone), and shares of no least,
// `minmax(0, 1fr)`, asked their least width (the gutters alone, whatever
// the items; the lowerer keeps the grid where it is asked one).
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
    TrackCell(
      column: 0,
      columnEnd: n,
      justify: CellAlign.stretch,
      margin: const EdgeInsets.only(top: 24),
      child: _a(text),
    ),
    TrackCell(columnSpan: n, child: _b()),
  ],
);

/// The grid as the lowerer writes it, floored at the gutters [floor].
Widget _stock(String text, {double? floor}) {
  final column = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: [
      Padding(padding: const EdgeInsets.only(top: 24), child: _a(text)),
      _b(),
    ],
  );
  return floor == null
      ? KeyedSubtree(key: _k('grid'), child: column)
      : ConstrainedBox(
          key: _k('grid'),
          constraints: BoxConstraints(minWidth: floor),
          child: column,
        );
}

Widget _page(double width, Widget grid, {bool loose = false}) => Directionality(
  textDirection: TextDirection.ltr,
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

Future<Map<String, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(_k(k)))};
}

/// The same boxes, to a billionth of a pixel: a share is what the gutters
/// leave over the factors, an item across them all the shares and the
/// gutters summed back, which rounds in the last place.
void _same(Map<String, Rect> out, Map<String, Rect> css) {
  expect(out.keys, css.keys);
  for (final k in css.keys) {
    expect(out[k], rectMoreOrLessEquals(css[k]!, epsilon: 1e-9), reason: k);
  }
}

/// Every intrinsic answer of the box keyed `grid`: its widths, and its
/// heights at widths from [floor] up (it is laid out no narrower).
Future<List<double>> _answers(WidgetTester t, Widget w, double floor) async {
  await t.pumpWidget(w);
  final box = t.renderObject<RenderBox>(find.byKey(_k('grid')));
  return [
    box.getMinIntrinsicWidth(double.infinity),
    box.getMaxIntrinsicWidth(double.infinity),
    for (final width in [floor, 600.0, 1200.0]) ...[box.getMinIntrinsicHeight(width), box.getMaxIntrinsicHeight(width)],
  ];
}

const _short = 'Hi';
// One word wider than the gutters.
const _word = 'Supercalifragilisticexpialidocious';
const _long = 'Everything you need to build the apps your teams run on, connected to your data and your work';

void main() {
  for (final text in const [_short, _long]) {
    for (final (n, gap) in const [(12, 24.0), (6, 24.0), (12, 32.0), (12, 0.0)]) {
      final floor = gap * (n - 1);
      // Down to the gutters; with none, to a narrow column.
      final narrow = floor > 0 ? floor : 120.0;
      for (final width in [780.0, 600.0, narrow + 8, narrow]) {
        testWidgets('$n shares $gap apart, ${text.length} letters, laid out ${width}px wide, are one column', (
          t,
        ) async {
          final css = await _rects(t, _page(width, _grid(text, n: n, gap: gap)));
          final out = await _rects(t, _page(width, _stock(text)));
          _same(out, css);
          expect(css['a']!.width, moreOrLessEquals(width, epsilon: 1e-9));
        });
      }
      for (final width in [780.0, narrow + 40]) {
        testWidgets(
          '$n shares $gap apart, ${text.length} letters, measured in ${width}px, are as wide as their content or gutters',
          (t) async {
            final css = await _rects(t, _page(width, _grid(text, n: n, gap: gap), loose: true));
            final out = await _rects(
              t,
              _page(width, IntrinsicWidth(child: _stock(text, floor: floor > 0 ? floor : null)), loose: true),
            );
            _same(out, css);
            expect(css['grid']!.width, greaterThanOrEqualTo(floor));
          },
        );
      }
      testWidgets('$n shares $gap apart, ${text.length} letters, answer every intrinsic as the floored column', (
        t,
      ) async {
        final css = await _answers(t, _page(1200, _grid(text, n: n, gap: gap)), narrow);
        final out = await _answers(t, _page(1200, _stock(text, floor: floor > 0 ? floor : null)), narrow);
        expect(out, [for (final v in css) moreOrLessEquals(v, epsilon: 1e-9)]);
      });
    }
    // Shares of no least lay out and answer their most width alike.
    const none = TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1));
    for (final width in const [780.0, 272.0]) {
      testWidgets('shares of no least, ${text.length} letters, laid out ${width}px wide, are one column', (t) async {
        final css = await _rects(t, _page(width, _grid(text, track: none)));
        final out = await _rects(t, _page(width, _stock(text)));
        _same(out, css);
      });
    }
    testWidgets('shares of no least, ${text.length} letters, measured, are as wide as their content or gutters', (
      t,
    ) async {
      final css = await _rects(t, _page(780, _grid(text, track: none), loose: true));
      final out = await _rects(t, _page(780, IntrinsicWidth(child: _stock(text, floor: 264)), loose: true));
      _same(out, css);
    });
  }

  testWidgets('NEGATIVE: a room under the gutters leaves the item as wide as them, past it', (t) async {
    final css = await _rects(t, _page(240, _grid(_long)));
    final out = await _rects(t, _page(240, _stock(_long)));
    expect(css['a']!.width, 264);
    expect(out['a']!.width, 240);
  });

  testWidgets('NEGATIVE: with no floor a column answers its items\' least and most widths alone', (t) async {
    final css = await _answers(t, _page(1200, _grid(_short)), 264);
    final out = await _answers(t, _page(1200, _stock(_short)), 264);
    expect(css.take(2).toList(), [264, 264]);
    expect(out.take(2).toList(), isNot([264, 264]));
  });

  testWidgets('NEGATIVE: shares of no least answer their least width with the gutters alone', (t) async {
    const none = TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1));
    final css = await _answers(t, _page(1200, _grid(_word, track: none)), 264);
    final out = await _answers(t, _page(1200, _stock(_word, floor: 264)), 264);
    expect(css.first, 264);
    expect(out.first, greaterThan(264));
  });
}
