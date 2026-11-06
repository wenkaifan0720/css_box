// An item's ASPECT RATIO in `Tracks` (css-sizing-4 4.1, css-grid-1 6.6):
// one item in a 100x100 grid of one implicit track each way. Every rect is
// Chrome's, from fixtures/grid-ratio-stretch.html, grid-ratio-stretch-which
// and grid-ratio-stretch-auto, with each item built as the lowerer states it.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _paint = ColoredBox(color: Color(0xFF000000));

/// The item the lowerer writes for an empty `aspect-ratio: [r]` box.
Widget _ratio(double r) => RatioBox(key: const ValueKey('item'), aspectRatio: r, child: _paint);

final _cases = <(String, TrackCell, Rect)>[
  // grid-ratio-stretch
  ('c1 the ratio alone covers the area', TrackCell(ratio: 2, child: _ratio(2)), const Rect.fromLTWH(0, 0, 200, 100)),
  (
    'c2 a floor across the ratio the inline reading meets',
    TrackCell(
      minHeight: 50,
      ratio: 2,
      child: FractionalConstraints(
        key: const ValueKey('item'),
        minFactor: 0,
        minOffset: 100,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 100, minHeight: 50),
          child: const AspectRatio(aspectRatio: 2, child: _paint),
        ),
      ),
    ),
    const Rect.fromLTWH(0, 0, 200, 100),
  ),
  (
    'c3 a floor across the ratio far under it',
    TrackCell(
      minHeight: 10,
      ratio: 2,
      child: FractionalConstraints(
        key: const ValueKey('item'),
        minFactor: 0,
        minOffset: 20,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 20, minHeight: 10),
          child: const AspectRatio(aspectRatio: 2, child: _paint),
        ),
      ),
    ),
    const Rect.fromLTWH(0, 0, 200, 100),
  ),
  (
    'c4 a floor along the inline axis hands the stretch back',
    TrackCell(
      minWidth: 50,
      ratio: 2,
      child: FractionalConstraints(
        key: const ValueKey('item'),
        minFactor: 0,
        minOffset: 50,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 50),
          child: RatioBox(aspectRatio: 2, child: _paint),
        ),
      ),
    ),
    const Rect.fromLTWH(0, 0, 100, 50),
  ),
  (
    'c5 a cap across the ratio is a cap along it',
    TrackCell(
      maxHeight: 20,
      ratio: 2,
      child: ConstrainedBox(
        key: const ValueKey('item'),
        constraints: const BoxConstraints(maxWidth: 40, maxHeight: 20),
        child: FractionalWidth(factor: 1, child: RatioBox(aspectRatio: 2, child: _paint)),
      ),
    ),
    const Rect.fromLTWH(0, 0, 40, 20),
  ),
  // grid-ratio-stretch-which
  (
    'd1 min-width 0 is no automatic minimum',
    TrackCell(minWidth: 0, ratio: 2, child: _ratio(2)),
    const Rect.fromLTWH(0, 0, 100, 50),
  ),
  (
    'd2 a cap far over the area',
    TrackCell(
      maxWidth: 500,
      ratio: 2,
      child: ConstrainedBox(
        key: const ValueKey('item'),
        constraints: const BoxConstraints(maxWidth: 500),
        child: FractionalWidth(factor: 1, child: RatioBox(aspectRatio: 2, child: _paint)),
      ),
    ),
    const Rect.fromLTWH(0, 0, 200, 100),
  ),
  (
    'd3 align-self start: the inline stretch alone',
    TrackCell(ratio: 2, align: CellAlign.start, child: _ratio(2)),
    const Rect.fromLTWH(0, 0, 100, 50),
  ),
  (
    'd4 justify-self start: the block stretch alone',
    TrackCell(ratio: 2, justify: CellAlign.start, child: _ratio(2)),
    const Rect.fromLTWH(0, 0, 200, 100),
  ),
  (
    'd5 place-self start: nothing for the ratio to work from',
    TrackCell(ratio: 2, align: CellAlign.start, justify: CellAlign.start, child: _ratio(2)),
    const Rect.fromLTWH(0, 0, 0, 0),
  ),
  // grid-ratio-stretch-auto
  (
    'e4 a ratio taller than it is wide covers the other way',
    TrackCell(ratio: 0.5, child: _ratio(0.5)),
    const Rect.fromLTWH(0, 0, 100, 200),
  ),
];

/// Chrome lays boxes out in 1/64 px; the grid, in doubles.
const _tolerance = 0.02;

void main() {
  for (final (name, cell, expected) in _cases) {
    testWidgets(name, (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: const ValueKey('grid'),
              width: 100,
              height: 100,
              child: Tracks(children: [cell]),
            ),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byKey(const ValueKey('grid')));
      final got = tester.getRect(find.byKey(const ValueKey('item'))).shift(-origin);
      final d = [
        got.left - expected.left,
        got.top - expected.top,
        got.width - expected.width,
        got.height - expected.height,
      ].map((x) => x.abs()).reduce(math.max);
      expect(d, lessThanOrEqualTo(_tolerance), reason: 'tracks $got, Chrome $expected');
    });
  }

  testWidgets('a ratio sizes the auto track it is in', (tester) async {
    // A 60px column of `auto` rows: the item is 60 wide by the stretch and
    // 30 deep by the ratio, and the row is as tall as that.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: const ValueKey('grid'),
            width: 60,
            child: Tracks(
              columns: const [TrackSize.fixed(60)],
              children: [TrackCell(ratio: 2, child: _ratio(2))],
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('grid'))), const Size(60, 30));
    expect(tester.getSize(find.byKey(const ValueKey('item'))), const Size(60, 30));
  });
}
