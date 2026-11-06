// A PERCENTAGE MARGIN in `Tracks` (css-grid-1 6.4, CSS 2.1 8.3): every side
// a share of the WIDTH of the item's area, which moves the item inside the
// area without shrinking the box its own percentages read. Every rect is
// Chrome's, from fixtures/grid-item-pct.html, grid-item-margin.html (g1) and
// grid-positioned-cell.html (n2), each grid built as the lowerer states it.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _paint = ColoredBox(color: Color(0xFF000000));
const _five = EdgeInsets.all(0.05);

ValueKey<String> _k(String name) => ValueKey(name);

/// Chrome lays boxes out in 1/64 px, and each margin rounds on its own.
const _tolerance = 2 / 64;

/// [grid] laid out [width] wide from the top left, and the rect of each
/// keyed box in it from the grid's own top left, against Chrome's.
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

void main() {
  testWidgets('a share of the area on every side, beside a width that is a share of the area too', (tester) async {
    await _expect(
      tester,
      200,
      Tracks(
        key: _k('grid'),
        children: [
          TrackCell(
            widthFraction: 0.45,
            height: 20,
            marginShare: _five,
            child: SizedBox(key: _k('item'), height: 20, child: _paint),
          ),
        ],
      ),
      {'grid': const Rect.fromLTWH(0, 0, 200, 40), 'item': const Rect.fromLTWH(10, 10, 90, 20)},
    );
  });

  testWidgets('one level down, a share of the inner area and not of the outer', (tester) async {
    await _expect(
      tester,
      200,
      Tracks(
        key: _k('grid'),
        children: [
          TrackCell(
            widthFraction: 0.5,
            child: ColoredBox(
              key: _k('half'),
              color: const Color(0xFF111111),
              child: Tracks(
                children: [
                  TrackCell(
                    widthFraction: 0.45,
                    marginShare: _five,
                    child: ColoredBox(key: _k('item'), color: const Color(0xFF222222)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      {
        'grid': const Rect.fromLTWH(0, 0, 200, 10),
        'half': const Rect.fromLTWH(0, 0, 100, 10),
        'item': const Rect.fromLTWH(5, 5, 45, 0),
      },
    );
  });

  testWidgets('a share of the content box inside the grid\'s padding', (tester) async {
    await _expect(
      tester,
      200,
      Padding(
        key: _k('grid'),
        padding: const EdgeInsets.all(3),
        child: Tracks(
          children: [
            TrackCell(
              widthFraction: 0.45,
              height: 20,
              marginShare: _five,
              child: SizedBox(
                key: _k('item'),
                height: 20,
                child: const ColoredBox(
                  color: Color(0xFF333333),
                  child: Padding(padding: EdgeInsets.all(3)),
                ),
              ),
            ),
          ],
        ),
      ),
      {'grid': const Rect.fromLTWH(0, 0, 200, 45.38), 'item': const Rect.fromLTWH(12.69, 12.69, 87.3, 20)},
    );
  });

  testWidgets('a share beside a width in pixels leaves the width alone', (tester) async {
    await _expect(
      tester,
      200,
      Tracks(
        key: _k('grid'),
        children: [
          TrackCell(
            width: 60,
            height: 20,
            marginShare: _five,
            child: SizedBox(key: _k('item'), width: 60, height: 20, child: _paint),
          ),
        ],
      ),
      {'grid': const Rect.fromLTWH(0, 0, 200, 40), 'item': const Rect.fromLTWH(10, 10, 60, 20)},
    );
  });

  testWidgets('a stretched item is its area less the shares', (tester) async {
    await _expect(
      tester,
      200,
      Tracks(
        key: _k('grid'),
        children: [
          TrackCell(
            height: 20,
            marginShare: _five,
            child: SizedBox(key: _k('item'), height: 20, child: _paint),
          ),
        ],
      ),
      {'grid': const Rect.fromLTWH(0, 0, 200, 40), 'item': const Rect.fromLTWH(10, 10, 180, 20)},
    );
  });

  testWidgets('a share in a fixed area, beside margins in pixels', (tester) async {
    await _expect(
      tester,
      1408,
      Tracks(
        key: _k('grid'),
        columns: const [TrackSize.fixed(140), TrackSize.flex(1)],
        rows: const [TrackSize.fixed(70), TrackSize.fixed(70)],
        spacing: 10,
        runSpacing: 10,
        children: [
          TrackCell(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ColoredBox(key: _k('b1'), color: const Color(0xFF444444)),
          ),
          ColoredBox(key: _k('b2'), color: const Color(0xFF555555)),
          TrackCell(
            marginShare: _five,
            child: ColoredBox(key: _k('b3'), color: const Color(0xFF666666)),
          ),
          TrackCell(
            height: 30,
            child: SizedBox(key: _k('b4'), height: 30, child: _paint),
          ),
        ],
      ),
      {
        'grid': const Rect.fromLTWH(0, 0, 1408, 150),
        'b1': const Rect.fromLTWH(12, 8, 116, 54),
        'b2': const Rect.fromLTWH(150, 0, 1258, 70),
        'b3': const Rect.fromLTWH(7, 87, 126, 56),
        'b4': const Rect.fromLTWH(150, 80, 1258, 30),
      },
    );
  });

  testWidgets('an item out of the flow: a share of the area its lines name', (tester) async {
    await _expect(
      tester,
      1408,
      Tracks(
        key: _k('grid'),
        columns: const [TrackSize.fixed(100), TrackSize.fixed(100), TrackSize.flex(1)],
        children: [
          TrackCell(
            positioned: true,
            column: 1,
            columnEnd: 3,
            left: 0,
            top: 0,
            width: 60,
            height: 20,
            z: 1,
            marginShare: const EdgeInsets.only(left: 0.1),
            child: SizedBox(key: _k('shift'), width: 60, height: 20, child: _paint),
          ),
          TrackCell(height: 30, child: SizedBox(key: _k('short'), height: 30)),
        ],
      ),
      {
        'grid': const Rect.fromLTWH(0, 0, 1408, 30),
        'shift': const Rect.fromLTWH(230.8, 0, 60, 20),
        'short': const Rect.fromLTWH(0, 0, 100, 30),
      },
    );
  });
}
