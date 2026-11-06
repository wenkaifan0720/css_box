// A GRID ITEM'S AREA IS ITS CONTAINING BLOCK (css-grid-1 9, CSS 2.1 10.1),
// so a percentage padding of the item is a share of the AREA's width (CSS
// 2.1 8.4), whatever width the item comes to: `TrackCell(room: true)`
// offers the area to the `Inset(ofRoom: true)` inside it. Every rect is
// Chrome's: `width: calc(50% + 10px); min-width: 200px; padding: 0 5%` in
// a `1fr` column of two, 8px apart.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

/// The content-box item: 60% of its area and 10px, never under 200px and
/// its padding, which is a tenth of the area -- 5% each side.
Widget _item(String key, {bool floored = true}) => TrackCell(
  width: 10,
  widthFraction: 0.6,
  minWidth: floored ? 200 : null,
  minWidthFraction: floored ? 0.1 : null,
  height: 30,
  room: true,
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF000000),
    child: Inset(
      insets: EdgeInsets.zero,
      shares: const EdgeInsets.symmetric(horizontal: 0.05),
      ofRoom: true,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(key: _k('$key.in'), width: double.infinity, height: 10),
      ),
    ),
  ),
);

Widget _grid(double width, List<Widget> items) => SizedBox(
  width: width,
  child: Tracks(columns: const [TrackSize.flex(1), TrackSize.flex(1)], spacing: 8, children: items),
);

Widget _cell(String key) => TrackCell(height: 30, child: SizedBox(key: _k(key), height: 30));

/// Chrome lays boxes out in 1/64 px.
const _tolerance = 2 / 64;

Future<void> _expect(WidgetTester tester, Widget grid, Map<String, Rect> chrome) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          key: _k('root'),
          width: 1440,
          child: Align(alignment: Alignment.topLeft, child: grid),
        ),
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

Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

void main() {
  // In a 700px area the share sizes the item, 430 = 0.6 * 700 + 10, and in
  // a 364px one the floor does, 236.375 = 200 + 0.1 * 364: its padding is
  // 5% of the area either way, 35 and 18.2 -- where a share of the item's
  // own width would be 1/12 of it less 10/12, 18.86 at 236.375.
  testWidgets("a share of the item's padding is of its area, where its share sizes it and where its floor does", (
    tester,
  ) async {
    await _expect(tester, _grid(1408, [_item('a1'), _cell('b1')]), {
      'a1': _r(0, 0, 430, 30),
      'a1.in': _r(35, 0, 360, 10),
      'b1': _r(708, 0, 700, 30),
    });
    await _expect(tester, _grid(736, [_item('a2'), _cell('b2')]), {
      'a2': _r(0, 0, 236.375, 30),
      'a2.in': _r(18.1875, 0, 200, 10),
      'b2': _r(372, 0, 364, 30),
    });
  });

  // css-sizing-3 5.2.1: where the area is not known -- the item's
  // contribution to the `1fr` columns that make it -- the share in its
  // floor and its padding are of nothing, so it asks for 200 and its
  // column grows to that in 328px: 200 and 120. It is then 220 wide in
  // the 200 area, 10px of padding each side of it. Unfloored, it is 106.
  testWidgets('where the area is not known a share of it is nothing: the floor alone sizes the column', (tester) async {
    await _expect(tester, _grid(328, [_item('a3'), _cell('b3')]), {
      'a3': _r(0, 0, 220, 30),
      'a3.in': _r(10, 0, 200, 10),
      'b3': _r(208, 0, 120, 30),
    });
    await _expect(tester, _grid(328, [_item('a4', floored: false), _cell('b4')]), {
      'a4': _r(0, 0, 106, 30),
      'a4.in': _r(8, 0, 90, 10),
      'b4': _r(168, 0, 160, 30),
    });
  });
}
