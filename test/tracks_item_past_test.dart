// ONE ITEM OF A STATED SIZE, WHERE IT MAY BE WIDER THAN THE GRID, IS LET
// PAST IT. A grid of no columns has one `auto` column, at least as wide as
// its item states (css-grid-1 11.5) and stretched into the grid where that
// is less (11.8), and the item stands at its point of the column
// (css-align-3 6.1): where the item is the wider, at its start, whatever
// `justify-items` says -- and so down a row held to a height the item is
// taller than. The lowerer writes it as an `OverflowBox` of no ceiling either way in
// the `Align` that places it: the box lays the item out at its own size
// and is no larger than the room, its child at its start
// (`RenderConstrainedOverflowBox`, `OverflowBoxFit.deferToChild`). A product site's
// icon buttons, 20px `place-items: center` grids round a 10 to 16px icon
// in a share of a row the lowerer does not prove
// (`fixtures/grid-item-past-unproven-room`).
//
// HANDED ITS WIDTH LOOSE, the grid is as wide as its content (`tracks.dart`
// `_layOut`, a loose maximum its max-size), where an `Align` takes all of
// it: there the lowerer writes it in an `IntrinsicWidth` (`_GridL.measured`,
// a width handed loose), which hands the `Align` the item's own width, the
// `OverflowBox`'s greatest intrinsic width, or the room where that is less.
//
// This pins the two to the same boxes, and the same answers, with the
// icon narrower and wider than the button, shorter and taller, placed at
// the start, the middle and the end, held to the button's height and not,
// handed the button's width tight and loose, left to right and right to
// left. NEGATIVE: an `Align` alone squeezes an icon wider than the button;
// a box with a ceiling down squeezes one taller than the button it is held
// to; a second item is stretched to the column the first widens; handed
// its width loose, an `Align` with no `IntrinsicWidth` round it takes all
// of it.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [ValueKey('grid'), ValueKey('icon')];

Widget _icon(double w, [double h = 12]) => SizedBox(
  key: const ValueKey('icon'),
  width: w,
  height: h,
  child: const ColoredBox(color: Color(0xff000000)),
);

/// The grid css_box keeps, round one icon [w] wide and [h] tall, placed
/// [justify].
Widget _grid(double w, CellAlign justify, [double h = 12]) => Tracks(
  key: const ValueKey('grid'),
  align: CellAlign.center,
  justify: justify,
  children: [TrackCell(width: w, height: h, child: _icon(w, h))],
);

AlignmentGeometry _point(CellAlign justify, {required bool held}) => switch (justify) {
  CellAlign.start => held ? AlignmentDirectional.centerStart : AlignmentDirectional.topStart,
  CellAlign.end => held ? AlignmentDirectional.centerEnd : AlignmentDirectional.topEnd,
  _ => held ? Alignment.center : Alignment.topCenter,
};

/// What the lowerer writes for it: [past] the `OverflowBox` round it --
/// with no ceiling down unless [ceiling] -- in an `IntrinsicWidth` where
/// its width is handed [loose].
Widget _stock(
  double w,
  CellAlign justify, {
  required bool held,
  double h = 12,
  bool past = true,
  bool ceiling = false,
  bool loose = false,
}) {
  final Widget icon = past
      ? OverflowBox(
          maxWidth: double.infinity,
          maxHeight: ceiling ? null : double.infinity,
          fit: OverflowBoxFit.deferToChild,
          alignment: AlignmentDirectional.topStart,
          child: _icon(w, h),
        )
      : _icon(w, h);
  const key = ValueKey('grid');
  final placed = Align(
    key: loose ? null : key,
    alignment: _point(justify, held: held),
    heightFactor: held ? null : 1,
    child: icon,
  );
  return loose ? IntrinsicWidth(key: key, child: placed) : placed;
}

/// The button: a box [width] wide that holds the grid to its height, or a
/// column that leaves it its own -- or, [loose], a box at most [width]
/// wide.
Widget _page(
  double width,
  Widget grid, {
  required bool held,
  bool loose = false,
  TextDirection dir = TextDirection.ltr,
}) => Directionality(
  textDirection: dir,
  child: Align(
    alignment: Alignment.topLeft,
    child: loose
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              minHeight: held ? 20 : 0,
              maxHeight: held ? 20 : double.infinity,
            ),
            child: grid,
          )
        : held
        ? SizedBox(width: width, height: 20, child: grid)
        : SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [grid],
            ),
          ),
  ),
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

/// The grid's answers: its intrinsic sizes, and its dry layout at widths
/// handed [loose] or tight.
List<Object?> _answers(RenderBox box, {required bool loose}) => [
  box.getMinIntrinsicWidth(double.infinity),
  box.getMaxIntrinsicWidth(double.infinity),
  for (final w in const [40.0, 13.0, 5.0, double.infinity]) ...[
    box.getMinIntrinsicHeight(w),
    box.getMaxIntrinsicHeight(w),
  ],
  for (final c
      in loose
          ? const [
              BoxConstraints(maxWidth: 40),
              BoxConstraints(maxWidth: 6),
              BoxConstraints(maxWidth: 8, maxHeight: 30),
              BoxConstraints(),
            ]
          : const [
              BoxConstraints.tightFor(width: 40),
              BoxConstraints.tightFor(width: 6),
              BoxConstraints(minWidth: 8, maxWidth: 8, maxHeight: 30),
              BoxConstraints.tightFor(width: 20, height: 20),
            ])
    box.getDryLayout(c),
];

void main() {
  for (final dir in TextDirection.values) {
    for (final held in const [true, false]) {
      for (final loose in const [false, true]) {
        for (final justify in const [CellAlign.start, CellAlign.center, CellAlign.end]) {
          testWidgets(
            'an item let past the grid stands where the grid stands it: ${justify.name}, ${held ? 'held' : 'free'}, ${loose ? 'loose, ' : ''}${dir.name}',
            (t) async {
              for (final (width, icon, h) in const [
                (20.0, 13.0, 12.0),
                (20.0, 20.0, 12.0),
                (20.0, 30.0, 12.0),
                (8.0, 13.0, 12.0),
                (20.0, 13.0, 30.0),
                (20.0, 30.0, 30.0),
              ]) {
                final kept = await _rects(t, _page(width, _grid(icon, justify, h), held: held, loose: loose, dir: dir));
                final stock = await _rects(
                  t,
                  _page(
                    width,
                    _stock(icon, justify, held: held, h: h, loose: loose),
                    held: held,
                    loose: loose,
                    dir: dir,
                  ),
                );
                expect(stock, kept, reason: '$icon x $h in $width');
              }
            },
          );
        }
      }
    }
  }

  for (final loose in const [false, true]) {
    testWidgets('an item let past the grid answers as the grid does${loose ? ', its width handed loose' : ''}', (
      t,
    ) async {
      for (final (icon, h) in const [(13.0, 12.0), (30.0, 12.0), (30.0, 30.0)]) {
        await t.pumpWidget(_page(20, _grid(icon, CellAlign.center, h), held: false, loose: loose));
        final kept = _answers(t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))), loose: loose);
        await t.pumpWidget(
          _page(
            20,
            _stock(icon, CellAlign.center, held: false, h: h, loose: loose),
            held: false,
            loose: loose,
          ),
        );
        expect(
          _answers(t.renderObject<RenderBox>(find.byKey(const ValueKey('grid'))), loose: loose),
          kept,
          reason: '$icon x $h',
        );
      }
    });
  }

  testWidgets('NEGATIVE: a box with a ceiling down squeezes an item taller than the button', (t) async {
    final kept = await _rects(t, _page(20, _grid(13, CellAlign.center, 30), held: true));
    final squeezed = await _rects(
      t,
      _page(20, _stock(13, CellAlign.center, held: true, h: 30, ceiling: true), held: true),
    );
    expect(kept[const ValueKey('icon')]!.height, 30);
    expect(squeezed[const ValueKey('icon')]!.height, 20);
  });

  testWidgets('NEGATIVE: handed its width loose, an Align alone takes all of it', (t) async {
    final kept = await _rects(t, _page(40, _grid(13, CellAlign.center), held: false, loose: true));
    final bare = await _rects(t, _page(40, _stock(13, CellAlign.center, held: false), held: false, loose: true));
    expect(kept[const ValueKey('grid')]!.width, 13);
    expect(bare[const ValueKey('grid')]!.width, 40);
  });

  testWidgets('NEGATIVE: an Align alone squeezes an item wider than the grid', (t) async {
    final kept = await _rects(t, _page(20, _grid(30, CellAlign.center), held: true));
    final squeezed = await _rects(t, _page(20, _stock(30, CellAlign.center, held: true, past: false), held: true));
    expect(squeezed[const ValueKey('icon')]!.width, lessThan(kept[const ValueKey('icon')]!.width));
  });

  testWidgets('NEGATIVE: a second item is stretched to the column the first widens', (t) async {
    await t.pumpWidget(
      _page(
        20,
        Tracks(
          key: const ValueKey('grid'),
          children: [
            TrackCell(width: 30, height: 12, child: _icon(30)),
            const SizedBox(key: ValueKey('other'), height: 4),
          ],
        ),
        held: false,
      ),
    );
    expect(t.getRect(find.byKey(const ValueKey('other'))).width, 30);
  });
}
