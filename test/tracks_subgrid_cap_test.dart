// A ROW SUBGRID UNDER A CAP ACROSS (css-grid-2 9): across it is an ordinary
// grid item, so stretched over its area and held to its `max-width` it is
// the smaller of the two (css-align-3 6.1), and each of its items sizes the
// rows round it at the width it comes to IN THAT -- not in the area. The
// geometry `fixtures/grid-row-subgrid-cap` p2 and p5 measure in Chrome: a
// body held to 180px in a 280px area wraps its title at 180, and the row
// it stands on is that tall beside the other card's.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

/// A grid item holding a box [w] by [h], stretched to its area.
Widget _box(String key, double w, double h) => TrackCell(
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF000000),
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: w, minHeight: h),
    ),
  ),
);

/// A grid item [ratio] times as wide as it is tall, as wide as its area.
Widget _ratio(String key, double ratio) => TrackCell(
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF333333),
    child: AspectRatio(aspectRatio: ratio),
  ),
);

/// A row subgrid spanning [rows] rows of the grid round it, held to [cap].
Widget _sub(
  String key,
  int rows,
  List<Widget> items, {
  double? cap,
  double? capShare,
  List<TrackSize> columns = const [],
}) => TrackCell(
  rowSpan: rows,
  maxWidth: cap,
  maxWidthFraction: capShare,
  subgrid: true,
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF111111),
    child: Tracks(subgridRows: true, columns: columns, children: items),
  ),
);

const _tolerance = 2 / 64;

Future<void> _expect(WidgetTester tester, Widget grid, Map<String, Rect> want) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(key: _k('root'), width: 400, child: grid),
      ),
    ),
  );
  final origin = tester.getTopLeft(find.byKey(_k('root')));
  for (final MapEntry(key: name, value: r) in want.entries) {
    final got = tester.getRect(find.byKey(_k(name))).shift(-origin);
    final d = [
      got.left - r.left,
      got.top - r.top,
      got.width - r.width,
      got.height - r.height,
    ].map((x) => x.abs()).reduce(math.max);
    expect(d, lessThanOrEqualTo(_tolerance), reason: '$name: tracks $got, want $r');
  }
}

Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

Widget _list(List<Widget> cards) => Tracks(
  key: _k('list'),
  columns: const [
    TrackSize.repeat(2, [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))]),
  ],
  spacing: 16,
  children: cards,
);

void main() {
  // `a`, twice as wide as it is tall, is 150 wide in A held to 150 -- 75
  // tall, where at A's 192px area it would be 96 -- and row 1 is 75 tall
  // beside B's 40.
  testWidgets('a capped subgrid of one column: its items size the rows at the cap', (tester) async {
    await _expect(
      tester,
      _list([
        _sub('A', 2, [_ratio('a', 2), _box('b', 0, 20)], cap: 150),
        _sub('B', 2, [_box('e', 0, 40), _box('f', 0, 15)]),
      ]),
      {
        'A': _r(0, 0, 150, 95),
        'a': _r(0, 0, 150, 75),
        'b': _r(0, 75, 150, 20),
        'B': _r(208, 0, 192, 95),
        'e': _r(208, 0, 192, 75),
        'f': _r(208, 75, 192, 20),
      },
    );
  });

  // Two `1fr` columns of A's own share the 150 of the cap, 75 each: `a`,
  // twice as wide as tall, is 37.5 tall there, where A's 192 would share
  // out 96 each and make it 48.
  testWidgets('a capped subgrid of columns of its own shares the cap out, not the area', (tester) async {
    await _expect(
      tester,
      _list([
        _sub(
          'A',
          1,
          [_ratio('a', 2), _box('b', 0, 10)],
          cap: 150,
          columns: const [TrackSize.flex(1), TrackSize.flex(1)],
        ),
        _sub('B', 1, [_box('e', 0, 20)]),
      ]),
      {
        'A': _r(0, 0, 150, 37.5),
        'a': _r(0, 0, 75, 37.5),
        'b': _r(75, 0, 75, 37.5),
        'B': _r(208, 0, 192, 37.5),
        'e': _r(208, 0, 192, 37.5),
      },
    );
  });

  // A CAPPED SUBGRID INSIDE A SUBGRID: dba's card is a row subgrid of the
  // list and its body one of the card's, held to a cap. `a`, twice as wide
  // as tall, is 150 wide in the body held to 150 -- 75 tall, where at the
  // card's 192 it would be 96 -- and the row it stands on is 75 tall
  // beside B's 40 (`fixtures/grid-row-subgrid-cap` p2: a title that wraps
  // at the body's 180, not the card's 280).
  testWidgets('a capped subgrid inside a subgrid: its items size the rows at the cap', (tester) async {
    await _expect(
      tester,
      _list([
        TrackCell(
          rowSpan: 3,
          subgrid: true,
          child: ColoredBox(
            key: _k('A'),
            color: const Color(0xFF222222),
            child: Tracks(
              subgridRows: true,
              children: [
                _box('pic', 0, 30),
                _sub('body', 2, [_ratio('a', 2), _box('b', 0, 20)], cap: 150),
              ],
            ),
          ),
        ),
        _sub('B', 3, [_box('pic2', 0, 10), _box('e', 0, 40), _box('f', 0, 15)]),
      ]),
      {
        'A': _r(0, 0, 192, 125),
        'pic': _r(0, 0, 192, 30),
        'body': _r(0, 30, 150, 95),
        'a': _r(0, 30, 150, 75),
        'b': _r(0, 105, 150, 20),
        'B': _r(208, 0, 192, 125),
        'e': _r(208, 30, 192, 75),
        'f': _r(208, 105, 192, 20),
      },
    );
  });

  // A CAP WIDER THAN THE AREA round columns of the body's own that are
  // wider than it too: the body is its area's 160 and its columns spill
  // out of it, and the card's first row is its picture's, 2.5 times as
  // wide as tall at the card's 192 -- 76.8 (`fixtures/grid-row-subgrid-cap`
  // p3: four 90px columns in a 280px body under `max-width: 400px`). The
  // body's `min-width: 0` is what holds the card's column to 192: without
  // it the body's automatic minimum is its columns' 200 and its margins,
  // and the card's one `auto` column would be 232 (css-grid-1 6.6).
  testWidgets('a subgrid inside a subgrid under a cap past its area: the rows round it are its host\'s', (
    tester,
  ) async {
    await _expect(
      tester,
      _list([
        TrackCell(
          rowSpan: 3,
          subgrid: true,
          child: ColoredBox(
            key: _k('A'),
            color: const Color(0xFF222222),
            child: Tracks(
              subgridRows: true,
              children: [
                _ratio('pic', 2.5),
                TrackCell(
                  rowSpan: 2,
                  minWidth: 0,
                  maxWidth: 300,
                  subgrid: true,
                  margin: const EdgeInsets.all(16),
                  child: ColoredBox(
                    key: _k('body'),
                    color: const Color(0xFF111111),
                    child: Tracks(
                      subgridRows: true,
                      columns: const [
                        TrackSize.fixed(50),
                        TrackSize.fixed(50),
                        TrackSize.fixed(50),
                        TrackSize.fixed(50),
                      ],
                      children: [
                        _box('t1', 0, 20),
                        _box('t2', 0, 10),
                        _box('t3', 0, 10),
                        _box('t4', 0, 10),
                        _box('l', 0, 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _sub('B', 3, [_ratio('pic2', 2.5), _box('e', 0, 12), _box('f', 0, 8)]),
      ]),
      {
        'A': _r(0, 0, 192, 138.8),
        'pic': _r(0, 0, 192, 76.8),
        'body': _r(16, 92.8, 160, 30),
        't1': _r(16, 92.8, 50, 20),
        't4': _r(166, 92.8, 50, 20),
        'l': _r(16, 112.8, 50, 10),
        'B': _r(208, 0, 192, 138.8),
        'pic2': _r(208, 0, 192, 76.8),
        'e': _r(208, 76.8, 192, 36),
      },
    );
  });

  // A cap that is a SHARE of the area: 75% of A's 192 is 144, and `a`,
  // twice as wide as tall, is 72 tall there (`fixtures/grid-row-subgrid-cap`
  // p6, 80% of a card).
  testWidgets('a subgrid capped at a share of its area: its items size the rows at that share', (tester) async {
    await _expect(
      tester,
      _list([
        _sub('A', 1, [_ratio('a', 2)], capShare: 0.75),
        _sub('B', 1, [_box('e', 0, 20)]),
      ]),
      {'A': _r(0, 0, 144, 72), 'a': _r(0, 0, 144, 72), 'B': _r(208, 0, 192, 72), 'e': _r(208, 0, 192, 72)},
    );
  });
}
