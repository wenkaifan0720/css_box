// AUTO MARGINS DOWN A COLUMN A GRID STRETCHES TAKE THE ROOM THE ROW LEAVES.
// A grid stretches an item of no alignment down its row (css-align-3 6.1),
// and the row is as tall as its tallest item (css-grid-1 11.5) -- or
// taller, where the grid is offered a height its `auto` rows share (11.8).
// `Tracks` measures the item at no height and lays it out tight at its area
// (`_measure`, `performLayout`), so a flex column there is the row's height
// and its auto margins take what its content leaves (css-flexbox-1 8.1,
// 9.5 step 5). Under rows that are all `auto` the row is never shorter than
// the item's content, the room is never negative, and the margins fall as
// a justification a `Column` lays out at the row's height and measures as
// its content -- the line's own justification places nothing then. That
// is what the lowerer writes for a column of a grid it keeps:
// a product site's
// "Cycle time by agent" chart, three `1fr` columns each of a bar of its
// own height with `margin-top: auto` over a 65px label, in a grid offered
// the height of its card (`fixtures/grid-offered-item-auto-margin`).
//
// This pins the kept line and the `Column` to the same boxes, each way the
// margins fall, in a grid offered a height and in one of no height, at
// several widths. NEGATIVE: the `Column` of the content's height the
// lowerer wrote before (every bar at the top of its column); a row the
// grid states shorter than the content, where CSS puts the overflow by the
// line's own justification and a `Column` from its start (kept); and
// margins that fall unevenly, which no justification puts (kept).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _heights = [381.0, 357.0, 338.0];

final _keys = [
  const ValueKey('grid'),
  for (var i = 0; i < 3; i++) ...[ValueKey('col$i'), ValueKey('bar$i'), ValueKey('label$i')],
];

Widget _page(double width, double? height, Widget grid) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, height: height, child: grid),
  ),
);

Widget _grid(Widget Function(int i) column, {List<TrackSize> rows = const []}) => Tracks(
  key: const ValueKey('grid'),
  columns: const [
    TrackSize.repeat(3, [TrackSize.flex(1)]),
  ],
  rows: rows,
  children: [for (var i = 0; i < 3; i++) TrackCell(minWidth: 0, child: column(i))],
);

/// The column css_box keeps: a bar of its own height and a 65px label,
/// their auto margins [bar] and [label] -- 4px under the bar where its own
/// margin there is not auto.
Widget Function(int) _kept(
  AutoEdges bar,
  AutoEdges label, {
  MainAxisAlignment justify = MainAxisAlignment.start,
  double spacing = 0,
}) =>
    (i) => FlexLine(
      key: ValueKey('col$i'),
      direction: Axis.vertical,
      mainAxisAlignment: justify,
      spacing: spacing,
      children: [
        FlexCell(
          margin: EdgeInsets.only(bottom: bar.bottom ? 0 : 4),
          autoMargin: bar,
          child: SizedBox(key: ValueKey('bar$i'), height: _heights[i]),
        ),
        FlexCell(
          mainSize: 65,
          autoMargin: label,
          child: SizedBox(key: ValueKey('label$i')),
        ),
      ],
    );

/// What the lowerer writes for it: a `Column` justified as the margins fall.
Widget Function(int) _written(MainAxisAlignment? justify, {double spacing = 0, double under = 4}) =>
    (i) => ShrinkWidth(
      key: ValueKey('col$i'),
      child: Column(
        mainAxisSize: justify == null ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: justify ?? MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: under),
            child: SizedBox(key: ValueKey('bar$i'), height: _heights[i]),
          ),
          SizedBox(height: 65, child: SizedBox(key: ValueKey('label$i'))),
        ],
      ),
    );

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w, {bool overflows = false}) async {
  await t.pumpWidget(w);
  // A `Column` short of room reports what passes its end.
  if (overflows) expect(t.takeException(), isNotNull);
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

/// The keys whose boxes stand apart in [a] and [b], past rounding: a
/// `Column` spreads its room by one division, css_box's line by another,
/// and the two meet to within 1e-9 of a pixel.
List<Key> _apart(Map<Key, Rect> a, Map<Key, Rect> b) => [
  for (final k in _keys)
    if ([
      a[k]!.left - b[k]!.left,
      a[k]!.top - b[k]!.top,
      a[k]!.right - b[k]!.right,
      a[k]!.bottom - b[k]!.bottom,
    ].any((d) => d.abs() > 1e-9))
      k,
];

const _none = AutoEdges.none;
const _top = AutoEdges(top: true);
const _bottom = AutoEdges(bottom: true);
const _both = AutoEdges(top: true, bottom: true);

void main() {
  // Each way the margins fall evenly, and the justification it is.
  final cases = <(String, AutoEdges, AutoEdges, MainAxisAlignment)>[
    ('the bar pushed down (linear)', _top, _none, MainAxisAlignment.end),
    ('the label pushed up', _none, _bottom, MainAxisAlignment.start),
    ('both centred', _top, _bottom, MainAxisAlignment.center),
    ('apart', _bottom, _none, MainAxisAlignment.spaceBetween),
    ('each round itself', _both, _both, MainAxisAlignment.spaceAround),
    ('evenly', _both, _bottom, MainAxisAlignment.spaceEvenly),
  ];
  for (final (name, bar, label, justify) in cases) {
    testWidgets('auto margins down a column a grid stretches: $name', (t) async {
      for (final height in const [null, 450.0, 560.0, 590.0]) {
        for (final width in const [600.0, 900.0, 300.0]) {
          for (final spacing in const [0.0, 8.0]) {
            final kept = await _rects(t, _page(width, height, _grid(_kept(bar, label, spacing: spacing))));
            final written = await _rects(
              t,
              _page(width, height, _grid(_written(justify, spacing: spacing, under: bar.bottom ? 0 : 4))),
            );
            expect(_apart(written, kept), isEmpty, reason: '$width x $height, spacing $spacing: $written / $kept');
          }
        }
      }
    });
  }

  testWidgets("the line's own justification places nothing beside auto margins", (t) async {
    for (final justify in const [MainAxisAlignment.center, MainAxisAlignment.end, MainAxisAlignment.spaceBetween]) {
      for (final height in const [null, 560.0]) {
        final kept = await _rects(t, _page(600, height, _grid(_kept(_top, _none, justify: justify))));
        expect(
          _apart(await _rects(t, _page(600, height, _grid(_written(MainAxisAlignment.end)))), kept),
          isEmpty,
          reason: '$justify $height',
        );
      }
    }
  });

  testWidgets('NEGATIVE: a Column of its content stands every bar at the top of its column', (t) async {
    for (final height in const [null, 560.0]) {
      final kept = await _rects(t, _page(600, height, _grid(_kept(_top, _none))));
      final before = await _rects(t, _page(600, height, _grid(_written(null))));
      // The labels stand on one line in the kept grid, at three heights in the old spelling.
      expect(kept[const ValueKey('label1')]!.top, kept[const ValueKey('label0')]!.top);
      expect(before[const ValueKey('label1')]!.top, lessThan(before[const ValueKey('label0')]!.top - 20));
    }
  });

  testWidgets('NEGATIVE: a row the grid states shorter than the content is overflowed by the line\'s justification', (
    t,
  ) async {
    const rows = [TrackSize.fixed(300)];
    final kept = await _rects(
      t,
      _page(600, null, _grid(_kept(_top, _none, justify: MainAxisAlignment.end), rows: rows)),
    );
    final written = await _rects(
      t,
      _page(600, null, _grid(_written(MainAxisAlignment.end), rows: rows)),
      overflows: true,
    );
    // CSS runs the content out of the top of the column; a `Column` short
    // of room sets it from its top.
    expect(kept[const ValueKey('bar0')]!.top, lessThan(kept[const ValueKey('col0')]!.top));
    expect(written[const ValueKey('bar0')]!.top, written[const ValueKey('col0')]!.top);
  });

  testWidgets('NEGATIVE: margins that fall unevenly are no justification', (t) async {
    // A margin each side of the bar, none round the label: the room is
    // split above and under the bar, and the label stands at the foot.
    final kept = await _rects(t, _page(600, 560, _grid(_kept(_both, _none))));
    for (final justify in MainAxisAlignment.values) {
      expect(
        _apart(await _rects(t, _page(600, 560, _grid(_written(justify, under: 0)))), kept),
        isNotEmpty,
        reason: '$justify',
      );
    }
  });
}
