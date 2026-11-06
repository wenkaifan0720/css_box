// A SUBGRID'S EDGE TRACK WITH NO ITEM ON IT still holds its margin,
// border and padding there (css-grid-2 9: for each edge of a subgrid a
// hypothetical item is contributed to the track sizing, of the subgrid's
// margin, border and padding at that edge): of no size itself, and with
// no half gutter difference of the subgrid's own, which lies inside its
// edge -- an edge row of a row subgrid, an edge column of a column one.
// Every rect is Chrome's; the card beside each (or the marks under it)
// shows where the tracks round it came to.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

/// A grid item [h] tall, as `height: <h>px` is: not stretched.
Widget _box(String key, double h, {int? row}) => TrackCell(
  row: row,
  height: h,
  child: ColoredBox(key: _k(key), color: const Color(0xFF000000)),
);

/// A row subgrid spanning [rows] rows of the grid round it, of a row gap
/// of its own [gap] and a [frame] (padding and border) round its rows.
Widget _sub(
  String key,
  int rows,
  double gap,
  List<Widget> items, {
  EdgeInsets margin = EdgeInsets.zero,
  EdgeInsets frame = EdgeInsets.zero,
}) => TrackCell(
  rowSpan: rows,
  margin: margin,
  subgrid: true,
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF111111),
    child: Padding(
      padding: frame,
      child: Tracks(subgridRows: true, runSpacing: gap, subgridFrame: frame, children: items),
    ),
  ),
);

/// The card beside: its gap the list's, three items of no height.
Widget _beside(String p) => _sub('$p.B', 3, 16, [_box('$p.x', 0), _box('$p.y', 0), _box('$p.z', 0)]);

/// Chrome lays boxes out in 1/64 px.
const _tolerance = 2 / 64;

Future<void> _expect(WidgetTester tester, List<Widget> cards, Map<String, Rect> chrome) async {
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
          width: 640,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: Tracks(
                key: _k('list'),
                columns: const [
                  TrackSize.repeat(2, [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))]),
                ],
                runSpacing: 16,
                children: cards,
              ),
            ),
          ),
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

/// A column subgrid on the host's three columns, [items] boxes [w] wide
/// (stretched where null) and 10 tall, on the column given or the flow's,
/// over a row of marks of no width at each column's start.
Widget _columns(
  String p,
  List<(double?, int?)> items, {
  List<TrackSize> tracks = const [TrackSize.auto, TrackSize.auto, TrackSize.auto],
  double gap = 0,
  double ownGap = 0,
  EdgeInsets margin = EdgeInsets.zero,
  EdgeInsets frame = EdgeInsets.zero,
}) => Tracks(
  key: _k('$p.host'),
  columns: tracks,
  spacing: gap,
  justifyContent: TrackContent.start,
  children: [
    TrackCell(
      column: 0,
      columnEnd: 3,
      margin: margin,
      subgrid: true,
      child: ColoredBox(
        key: _k('$p.sub'),
        color: const Color(0xFF111111),
        child: Padding(
          padding: frame,
          child: Tracks(
            spacing: ownGap,
            subgridColumns: true,
            subgridFrame: frame,
            children: [
              for (final (i, (w, column)) in items.indexed)
                TrackCell(
                  column: column,
                  width: w,
                  height: 10,
                  child: ColoredBox(key: _k('$p.${'ab'[i]}'), color: const Color(0xFF000000)),
                ),
            ],
          ),
        ),
      ),
    ),
    for (var c = 0; c < 3; c++)
      TrackCell(
        row: 1,
        column: c,
        width: 0,
        height: 4,
        child: ColoredBox(key: _k('$p.m${c + 1}'), color: const Color(0xFF000000)),
      ),
  ],
);

Future<void> _expectAt(WidgetTester tester, Widget grid, double width, Map<String, Rect> chrome) async {
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
          width: 640,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: grid),
          ),
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

void main() {
  // The card's last row holds nothing: it is its 16px bottom margin tall,
  // not 16 less the 8 its gap of nothing gives back, as the rows beside
  // show (12, 0, 16 under two 16px gutters).
  testWidgets('the last row empty under a margin is the margin tall', (tester) async {
    await _expect(
      tester,
      [
        _sub('A', 3, 0, [_box('a', 20)], margin: const EdgeInsets.only(bottom: 16)),
        _beside('F1'),
      ],
      {
        'list': _r(0, 0, 300, 60),
        'A': _r(0, 0, 150, 44),
        'a': _r(0, 0, 150, 20),
        'F1.y': _r(150, 28, 150, 0),
        'F1.z': _r(150, 44, 150, 0),
      },
    );
  });

  // Its own 6px gap gives back 5 on each side of a gutter, and none of
  // the margin; a 4px margin is 4, not the nothing a half gutter less
  // would leave.
  testWidgets('a gap of its own, and a margin less than half a gutter', (tester) async {
    await _expect(
      tester,
      [
        _sub('A', 3, 6, [_box('a', 20)], margin: const EdgeInsets.only(bottom: 16)),
        _beside('F2'),
      ],
      {'list': _r(0, 0, 300, 63), 'A': _r(0, 0, 150, 47), 'F2.y': _r(150, 31, 150, 0), 'F2.z': _r(150, 47, 150, 0)},
    );
    await _expect(
      tester,
      [
        _sub('A', 3, 0, [_box('a', 20)], margin: const EdgeInsets.only(bottom: 4)),
        _beside('F4'),
      ],
      {'list': _r(0, 0, 300, 48), 'A': _r(0, 0, 150, 44), 'F4.z': _r(150, 44, 150, 0)},
    );
  });

  // The first row empty under a 12px margin and a 3px border: 15 tall.
  testWidgets('the first row empty under a margin and a border', (tester) async {
    await _expect(
      tester,
      [
        _sub(
          'A',
          3,
          0,
          [_box('a', 20, row: 2)],
          margin: const EdgeInsets.only(top: 12),
          frame: const EdgeInsets.only(top: 3),
        ),
        _beside('F3'),
      ],
      {
        'list': _r(0, 0, 300, 59),
        'A': _r(0, 12, 150, 47),
        'a': _r(0, 39, 150, 20),
        'F3.y': _r(150, 31, 150, 0),
        'F3.z': _r(150, 47, 150, 0),
      },
    );
  });

  // dba's card whose body leaves its last row empty: the body's 16px
  // bottom margin, on the card's last row, is that row.
  testWidgets('a body inside a card, its last row empty on the card\'s last', (tester) async {
    await _expect(
      tester,
      [
        _sub('A', 4, 0, [
          _box('pic', 30),
          _sub('body', 3, 0, [_box('a', 22), _box('b', 20)], margin: const EdgeInsets.symmetric(vertical: 16)),
        ]),
        _sub('B', 4, 16, [_box('w', 0), _box('x', 0), _box('y', 0), _box('z', 0)]),
      ],
      {
        'list': _r(0, 0, 300, 112),
        'A': _r(0, 0, 150, 112),
        'body': _r(0, 46, 150, 50),
        'a': _r(0, 46, 150, 22),
        'b': _r(0, 68, 150, 20),
        'x': _r(150, 38, 150, 0),
        'y': _r(150, 76, 150, 0),
        'z': _r(150, 96, 150, 0),
      },
    );
  });

  // Where the body's edge is inside the card, the card's gap gives back
  // its half there too: 10px of margin less 8 is a row of 2.
  testWidgets('a body whose empty last row is inside the card: the card\'s half gutter comes off', (tester) async {
    await _expect(
      tester,
      [
        _sub('A', 4, 0, [
          _sub('body', 3, 0, [_box('a', 20), _box('b', 20)], margin: const EdgeInsets.only(bottom: 10)),
          _box('foot', 30),
        ]),
        _sub('B', 4, 16, [_box('w', 0), _box('x', 0), _box('y', 0), _box('z', 0)]),
      ],
      {
        'list': _r(0, 0, 300, 88),
        'body': _r(0, 0, 150, 48),
        'b': _r(0, 20, 150, 20),
        'foot': _r(0, 58, 150, 30),
        'x': _r(150, 28, 150, 0),
        'y': _r(150, 48, 150, 0),
        'z': _r(150, 66, 150, 0),
      },
    );
  });

  // `auto auto auto`, not stretched: the last column holds nothing and is
  // the subgrid's 30px padding wide; the first, under a 20px padding and
  // a 3px border, is 23.
  testWidgets('a column subgrid\'s empty edge column is its frame wide', (tester) async {
    await _expectAt(
      tester,
      _columns('C1', const [(40, null), (50, null)], frame: const EdgeInsets.only(right: 30)),
      400,
      {
        'C1.host': _r(0, 0, 400, 14),
        'C1.sub': _r(0, 0, 120, 10),
        'C1.b': _r(40, 0, 50, 10),
        'C1.m2': _r(40, 10, 0, 4),
        'C1.m3': _r(90, 10, 0, 4),
      },
    );
    await _expectAt(tester, _columns('C2', const [(40, 1), (50, null)], frame: const EdgeInsets.only(left: 23)), 400, {
      'C2.sub': _r(0, 0, 113, 10),
      'C2.a': _r(23, 0, 40, 10),
      'C2.b': _r(63, 0, 50, 10),
      'C2.m2': _r(23, 10, 0, 4),
      'C2.m3': _r(63, 10, 0, 4),
    });
  });

  // A 16px host gutter and none of the subgrid's own: the items give back
  // 8 on each side of one, the empty last column's 10px margin none.
  testWidgets('a column subgrid\'s empty edge column under a margin, beside gutters it gives back', (tester) async {
    await _expectAt(
      tester,
      _columns('C3', const [(40, null), (50, null)], gap: 16, ownGap: 0, margin: const EdgeInsets.only(right: 10)),
      400,
      {'C3.sub': _r(0, 0, 98, 10), 'C3.b': _r(40, 0, 50, 10), 'C3.m2': _r(48, 10, 0, 4), 'C3.m3': _r(98, 10, 0, 4)},
    );
  });

  // `1fr` is `minmax(auto, 1fr)`: the empty last column's 60px padding is
  // its automatic minimum, and the other two share the 30 left of 90.
  testWidgets('an empty edge `1fr` column is floored by the frame', (tester) async {
    await _expectAt(
      tester,
      _columns(
        'C4',
        const [(null, null)],
        tracks: const [TrackSize.flex(1), TrackSize.flex(1), TrackSize.flex(1)],
        frame: const EdgeInsets.only(right: 60),
      ),
      90,
      {'C4.sub': _r(0, 0, 90, 10), 'C4.a': _r(0, 0, 15, 10), 'C4.m2': _r(15, 10, 0, 4), 'C4.m3': _r(30, 10, 0, 4)},
    );
  });

  // NEGATIVE: an edge row an item stands on is that item's, the margin on
  // it as before -- no second contribution: a 20px item under a 16px
  // margin on the last row is 20 + 16 - 8 = 28 of the list's 72.
  testWidgets('NEGATIVE: an edge row with an item on it takes nothing more', (tester) async {
    await _expect(
      tester,
      [
        _sub('A', 3, 0, [_box('a', 20), _box('b', 0), _box('c', 20)], margin: const EdgeInsets.only(bottom: 16)),
        _beside('N'),
      ],
      {'list': _r(0, 0, 300, 72), 'A': _r(0, 0, 150, 56), 'c': _r(0, 36, 150, 20), 'N.z': _r(150, 44, 150, 0)},
    );
  });
}
