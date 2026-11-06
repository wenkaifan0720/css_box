// `direction: rtl` in `Tracks` (css-writing-modes-4 3.2, css-grid-1 7.1):
// under a right-to-left `Directionality` column 1 is the RIGHTMOST track,
// auto placement fills right to left, a span grows leftward, and every
// alignment measured from the inline start starts at the right edge; the
// rows do not move. Every rect is Chrome's, from fixtures/grid-rtl.html and
// grid-positioned-cell.html (n1), each grid built as the lowerer states it.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

Widget _box(String name) => ColoredBox(key: _k(name), color: const Color(0xFF000000));

/// Chrome lays boxes out in 1/64 px.
const _tolerance = 1 / 64;

/// [grid] laid out [width] wide from the top left of a left-to-right page,
/// and the rect of each keyed box in it from the grid's own top left,
/// against Chrome's.
Future<void> _expect(WidgetTester tester, double width, Widget grid, Map<String, Rect> chrome) async {
  // A window as wide as Chrome's, so the page's width is not held to the
  // test's 800.
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(key: _k('root'), width: width, child: grid),
      ),
    ),
  );
  final origin = tester.getTopLeft(find.byKey(_k('root')));
  for (final MapEntry(key: name, value: want) in chrome.entries) {
    final got = tester.getRect(find.byKey(_k(name))).shift(-origin);
    final d = [
      got.left - want.left,
      got.top - want.top,
      got.width - want.width,
      got.height - want.height,
    ].map((x) => x.abs()).reduce(math.max);
    expect(d, lessThanOrEqualTo(_tolerance), reason: '$name: tracks $got, Chrome $want');
  }
}

/// grid-rtl's g1 and g2: three columns, 60px, 90px and the rest, rows of
/// 30px and 8px gaps; auto placement, `grid-column: 2`, `span 2`.
Widget _three({TextDirection? direction}) => Tracks(
  key: _k('grid'),
  textDirection: direction,
  columns: const [TrackSize.fixed(60), TrackSize.fixed(90), TrackSize.flex(1)],
  autoRows: const [TrackSize.fixed(30)],
  spacing: 8,
  runSpacing: 8,
  children: [
    _box('a'),
    _box('b'),
    _box('c'),
    TrackCell(column: 1, child: _box('d')),
    TrackCell(columnSpan: 2, child: _box('e')),
  ],
);

const _rtlThree = {
  'grid': Rect.fromLTWH(0, 0, 1408, 106),
  'a': Rect.fromLTWH(1348, 0, 60, 30),
  'b': Rect.fromLTWH(1250, 0, 90, 30),
  'c': Rect.fromLTWH(0, 0, 1242, 30),
  'd': Rect.fromLTWH(1250, 38, 90, 30),
  'e': Rect.fromLTWH(1250, 76, 158, 30),
};

void main() {
  testWidgets('left to right, the control: column 1 is the leftmost', (tester) async {
    await _expect(tester, 1408, _three(), {
      'a': const Rect.fromLTWH(0, 0, 60, 30),
      'b': const Rect.fromLTWH(68, 0, 90, 30),
      'c': const Rect.fromLTWH(166, 0, 1242, 30),
    });
  });

  testWidgets('right to left: placement, a line number and a span all count from the right', (tester) async {
    await _expect(tester, 1408, Directionality(textDirection: TextDirection.rtl, child: _three()), _rtlThree);
  });

  testWidgets('a direction of its own over the one round it', (tester) async {
    await _expect(tester, 1408, _three(direction: TextDirection.rtl), _rtlThree);
  });

  testWidgets('justify-content: start packs the tracks at the right, and justify-self: end is the left', (
    tester,
  ) async {
    await _expect(
      tester,
      1408,
      Directionality(
        textDirection: TextDirection.rtl,
        child: Tracks(
          key: _k('grid'),
          columns: const [TrackSize.fixed(50), TrackSize.fixed(50)],
          autoRows: const [TrackSize.fixed(24)],
          spacing: 6,
          runSpacing: 6,
          justifyContent: TrackContent.start,
          children: [
            _box('wide'),
            TrackCell(
              width: 30,
              justify: CellAlign.end,
              child: SizedBox(width: 30, child: _box('narrow')),
            ),
          ],
        ),
      ),
      {
        'grid': const Rect.fromLTWH(0, 0, 1408, 24),
        'wide': const Rect.fromLTWH(1358, 0, 50, 24),
        'narrow': const Rect.fromLTWH(1302, 0, 30, 24),
      },
    );
  });

  testWidgets('a box out of the flow over column 1 stands in the rightmost track, at its left inset', (tester) async {
    await _expect(
      tester,
      1408,
      Directionality(
        textDirection: TextDirection.rtl,
        child: Tracks(
          key: _k('grid'),
          columns: const [TrackSize.fixed(80), TrackSize.fixed(80), TrackSize.flex(1)],
          spacing: 10,
          children: [
            TrackCell(
              positioned: true,
              column: 0,
              columnEnd: 1,
              left: 0,
              top: 0,
              width: 40,
              height: 20,
              z: 1,
              child: SizedBox(width: 40, height: 20, child: _box('mark')),
            ),
            TrackCell(height: 30, child: SizedBox(height: 30, child: _box('short'))),
          ],
        ),
      ),
      {
        'grid': const Rect.fromLTWH(0, 0, 1408, 30),
        'mark': const Rect.fromLTWH(1328, 0, 40, 20),
        'short': const Rect.fromLTWH(1328, 0, 80, 30),
      },
    );
  });
}
