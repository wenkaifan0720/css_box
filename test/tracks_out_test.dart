// A box OUT OF THE FLOW in `Tracks`: `position: absolute` in a grid that
// is its containing block (css-grid-1 9.1, 9.3). Every rect is Chrome's,
// from fixtures/grid-positioned-cell.html at 1440 and 360 (the grid's own
// 16px body margin taken off), with each grid built as the lowerer states
// it.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// Item [key]'s box: a coloured box of no size of its own.
Widget _box(String key) => ColoredBox(key: ValueKey(key), color: const Color(0xFF000000));

/// A browser vendor's five tracks: two edges of `minmax(0, calc(50% - 400px))`, two
/// `1fr` and a 300px middle, 20px apart.
const _five = [
  TrackSize.between(TrackSize.fixed(0), TrackSize.affine(-400, 0.5)),
  TrackSize.flex(1),
  TrackSize.fixed(300),
  TrackSize.flex(1),
  TrackSize.between(TrackSize.fixed(0), TrackSize.affine(-400, 0.5)),
];

/// The hero over lines 2 to 5, in the flow.
TrackCell _hero(String key) => TrackCell(column: 1, columnEnd: 4, height: 80, child: _box(key));

Widget _p1() => Tracks(
  columns: _five,
  spacing: 20,
  children: [
    TrackCell(
      positioned: true,
      column: 1,
      columnEnd: 4,
      leftFraction: 0.5,
      top: 0,
      widthFraction: 1,
      maxWidthFraction: 1,
      minHeight: 120,
      z: 1,
      child: FractionalTranslation(translation: const Offset(-0.5, 0), child: _box('bleed')),
    ),
    _hero('hero'),
  ],
);

Widget _p2() => Tracks(
  columns: _five,
  spacing: 20,
  children: [
    TrackCell(
      positioned: true,
      column: 0,
      columnEnd: -1,
      leftFraction: 0.5,
      top: 0,
      widthFraction: 1,
      minHeight: 60,
      z: 1,
      child: FractionalTranslation(translation: const Offset(-0.5, 0), child: _box('whole')),
    ),
    _hero('hero'),
  ],
);

Widget _p4() => Tracks(
  columns: const [TrackSize.fixed(100), TrackSize.flex(1), TrackSize.fixed(100)],
  rows: const [TrackSize.fixed(30), TrackSize.fixed(50), TrackSize.fixed(30)],
  spacing: 8,
  runSpacing: 6,
  children: [
    TrackCell(
      positioned: true,
      column: 0,
      row: 1,
      columnEnd: 2,
      leftFraction: 0.25,
      rightFraction: 0.25,
      top: 10,
      bottom: 10,
      z: 1,
      child: _box('inset'),
    ),
    _box('c1'),
    _box('c2'),
    _box('c3'),
  ],
);

Widget _p5() => Tracks(
  columns: const [TrackSize.fixed(100), TrackSize.fixed(100), TrackSize.flex(1)],
  rows: const [TrackSize.fixed(40), TrackSize.fixed(40)],
  spacing: 10,
  runSpacing: 10,
  children: [
    TrackCell(
      positioned: true,
      column: 1,
      row: 0,
      rowEnd: 2,
      right: 10,
      bottom: 5,
      width: 40,
      height: 20,
      z: 1,
      child: _box('end'),
    ),
    TrackCell(height: 40, child: _box('c1')),
    TrackCell(height: 40, child: _box('c2')),
    TrackCell(height: 40, child: _box('c3')),
  ],
);

Widget _p6() => Tracks(
  columns: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1)],
  rows: const [TrackSize.fixed(60)],
  children: [
    TrackCell(
      positioned: true,
      column: 0,
      columnEnd: 2,
      justify: CellAlign.center,
      align: CellAlign.end,
      width: 50,
      height: 20,
      z: 1,
      child: _box('mid'),
    ),
    _box('c1'),
  ],
);

Widget _p7() => Tracks(
  columns: const [TrackSize.fixed(50), TrackSize.fixed(50), TrackSize.fixed(50)],
  spacing: 5,
  children: [
    TrackCell(
      positioned: true,
      column: 0,
      columnEnd: 8,
      left: 0,
      right: 0,
      top: 0,
      height: 10,
      z: 1,
      child: _box('wide'),
    ),
    TrackCell(height: 30, child: _box('c1')),
    TrackCell(height: 30, child: _box('c2')),
  ],
);

Widget _p8() => SizedBox(
  height: 60,
  child: Tracks(
    columns: const [TrackSize.flex(1), TrackSize.flex(1)],
    children: [
      TrackCell(positioned: true, column: 1, row: 0, top: 5, left: 5, width: 30, height: 30, child: _box('solo')),
    ],
  ),
);

Widget _p9() => Tracks(
  columns: const [TrackSize.fixed(60), TrackSize.fixed(60), TrackSize.fixed(60), TrackSize.fixed(60)],
  spacing: 10,
  children: [
    TrackCell(
      positioned: true,
      column: 1,
      columnSpan: 2,
      top: 0,
      bottom: 0,
      left: 0,
      right: 0,
      z: 1,
      child: _box('fill'),
    ),
    TrackCell(height: 30, child: _box('c1')),
    TrackCell(height: 30, child: _box('c2')),
    TrackCell(height: 30, child: _box('c3')),
    TrackCell(height: 30, child: _box('c4')),
  ],
);

/// Chrome lays boxes out in 1/64 px; the grid, in doubles.
const _tolerance = 0.02;

final _cases = <(String, double, Widget Function(), Map<String, Rect>)>[
  (
    'p1 a share of the area named by lines 2 to 5',
    1408,
    _p1,
    {
      'root': const Rect.fromLTWH(0, 0, 1408, 80),
      'bleed': const Rect.fromLTWH(324, 0, 760, 120),
      'hero': const Rect.fromLTWH(324, 0, 760, 80),
    },
  ),
  (
    'p1 the tracks past the box at 360',
    328,
    _p1,
    {
      'root': const Rect.fromLTWH(0, 0, 328, 80),
      'bleed': const Rect.fromLTWH(20, 0, 340, 120),
      'hero': const Rect.fromLTWH(20, 0, 340, 80),
    },
  ),
  (
    'p2 lines 1 to -1 are the grid, not the box',
    1408,
    _p2,
    {'whole': const Rect.fromLTWH(0, 0, 1408, 60), 'hero': const Rect.fromLTWH(324, 0, 760, 80)},
  ),
  (
    'p2 lines 1 to -1 past the box at 360',
    328,
    _p2,
    {'whole': const Rect.fromLTWH(0, 0, 380, 60), 'hero': const Rect.fromLTWH(20, 0, 340, 80)},
  ),
  (
    'p4 a line is the edge of the track beside it, not of its gap',
    1408,
    _p4,
    {
      'root': const Rect.fromLTWH(0, 0, 1408, 122),
      'inset': const Rect.fromLTWH(325, 46, 650, 66),
      'c1': const Rect.fromLTWH(0, 0, 100, 30),
      'c2': const Rect.fromLTWH(108, 0, 1192, 30),
      'c3': const Rect.fromLTWH(1308, 0, 100, 30),
    },
  ),
  ('p4 at 360', 328, _p4, {'inset': const Rect.fromLTWH(55, 46, 110, 66)}),
  (
    'p5 a start line alone runs to the box, and the end insets place it',
    1408,
    _p5,
    {
      'root': const Rect.fromLTWH(0, 0, 1408, 90),
      'end': const Rect.fromLTWH(1358, 65, 40, 20),
      'c3': const Rect.fromLTWH(220, 0, 1188, 40),
    },
  ),
  ('p5 at 360', 328, _p5, {'end': const Rect.fromLTWH(278, 65, 40, 20)}),
  (
    'p6 no insets: the alignments place it in its area',
    1408,
    _p6,
    {'mid': const Rect.fromLTWH(444.33, 40, 50, 20), 'c1': const Rect.fromLTWH(0, 0, 469.33, 60)},
  ),
  ('p6 at 360', 328, _p6, {'mid': const Rect.fromLTWH(84.33, 40, 50, 20)}),
  (
    'p7 a line past the grid is the box edge',
    1408,
    _p7,
    {
      'root': const Rect.fromLTWH(0, 0, 1408, 30),
      'wide': const Rect.fromLTWH(0, 0, 1408, 10),
      'c2': const Rect.fromLTWH(55, 0, 50, 30),
    },
  ),
  ('p7 at 360', 328, _p7, {'wide': const Rect.fromLTWH(0, 0, 328, 10)}),
  (
    'p8 a grid whose only child is out of the flow',
    1408,
    _p8,
    {'root': const Rect.fromLTWH(0, 0, 1408, 60), 'solo': const Rect.fromLTWH(709, 5, 30, 30)},
  ),
  ('p8 at 360', 328, _p8, {'solo': const Rect.fromLTWH(169, 5, 30, 30)}),
  (
    'p9 a line and a span, all four insets 0',
    1408,
    _p9,
    {
      'root': const Rect.fromLTWH(0, 0, 1408, 30),
      'fill': const Rect.fromLTWH(70, 0, 130, 30),
      'c4': const Rect.fromLTWH(210, 0, 60, 30),
    },
  ),
];

void main() {
  for (final (name, width, build, expected) in _cases) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(key: const ValueKey('root'), width: width, child: build()),
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byKey(const ValueKey('root')));
      final off = <String>[];
      for (final MapEntry(:key, :value) in expected.entries) {
        final got = tester.getRect(find.byKey(ValueKey(key))).shift(-origin);
        final d = [
          got.left - value.left,
          got.top - value.top,
          got.width - value.width,
          got.height - value.height,
        ].map((x) => x.abs()).reduce(math.max);
        if (d > _tolerance) off.add('$key: tracks $got, Chrome $value');
      }
      expect(off, isEmpty);
    });
  }

  testWidgets('a box out of the flow sizes no track and gives no baseline', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: const ValueKey('root'),
            width: 200,
            child: Tracks(
              columns: const [TrackSize.auto],
              children: [
                TrackCell(positioned: true, top: 0, left: 0, width: 500, height: 300, child: _box('out')),
                TrackCell(height: 20, child: _box('in')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('root'))), const Size(200, 20));
    expect(tester.getRect(find.byKey(const ValueKey('in'))), const Rect.fromLTWH(0, 0, 200, 20));
    expect(tester.getRect(find.byKey(const ValueKey('out'))), const Rect.fromLTWH(0, 0, 500, 300));
  });
}
