// A ROW SUBGRID WITH COLUMNS OF ITS OWN (css-grid-2 9): its rows are the
// rows of the grid round it, and across it is an ordinary item with a grid
// of its own -- so each of its items sizes the rows round it at the width
// of ITS column, which the subgrid's own columns share its width out
// into. Every rect is Chrome's, each item a box of a stated size, or of
// a height that is half (or a quarter) of its width, inside a grid item
// that stretches.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

/// A grid item holding a box [w] by [h], stretched to its area.
Widget _box(String key, double w, double h, {int? row, int? column}) => TrackCell(
  row: row,
  column: column,
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF000000),
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: w, minHeight: h),
    ),
  ),
);

/// A grid item [ratio] times as wide as it is tall, as wide as its area:
/// `padding-bottom: 50%` is a ratio of 2.
Widget _ratio(String key, double ratio, {int? row}) => TrackCell(
  row: row,
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF333333),
    child: AspectRatio(aspectRatio: ratio),
  ),
);

/// A row subgrid spanning [rows] rows of the grid round it.
Widget _sub(String key, int rows, List<Widget> items, {EdgeInsets margin = EdgeInsets.zero}) => TrackCell(
  rowSpan: rows,
  margin: margin,
  subgrid: true,
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF111111),
    child: Tracks(subgridRows: true, children: items),
  ),
);

/// Chrome lays boxes out in 1/64 px.
const _tolerance = 2 / 64;

Future<void> _expect(WidgetTester tester, Widget grid, double width, Map<String, Rect> chrome) async {
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

Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

void main() {
  // css-grid-1 8.5: `b` and `c` both name row 2, so `c` takes the first
  // column free there -- a second, the card's own -- and `d` flows into
  // it on row 1. The card's two `auto` columns share its 192px out, 81 and
  // 111, and `c`, half as tall as it is wide, makes row 2 55.5 tall: at
  // the card's whole width it would be 96.
  testWidgets('two items on one row of a card: a column of its own, each item as tall as its column makes it', (
    tester,
  ) async {
    await _expect(
      tester,
      Tracks(
        key: _k('list'),
        columns: const [
          TrackSize.repeat(2, [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))]),
        ],
        spacing: 16,
        children: [
          _sub('A', 3, [_box('a', 60, 20), _box('b', 30, 50, row: 1), _ratio('c', 2, row: 1), _box('d', 90, 30)]),
          _sub('B', 3, [_box('e', 0, 40), _box('f', 0, 15), _box('g', 0, 25)]),
        ],
      ),
      400,
      {
        'list': _r(0, 0, 400, 120.5),
        'A': _r(0, 0, 192, 120.5),
        'a': _r(0, 0, 81, 40),
        'b': _r(0, 40, 81, 55.5),
        'c': _r(81, 40, 111, 55.5),
        'd': _r(81, 0, 111, 40),
        'B': _r(208, 0, 192, 120.5),
        'e': _r(208, 0, 192, 40),
        'f': _r(208, 40, 192, 55.5),
        'g': _r(208, 95.5, 192, 25),
      },
    );
  });

  // The body's own columns are inside the card's one: 280px shared out as
  // 130 and 150, and `r`, a quarter as tall as it is wide, is 32.5 on the
  // card's last row.
  testWidgets('a subgrid inside a card with an item on a column of its own', (tester) async {
    await _expect(
      tester,
      Tracks(
        key: _k('list'),
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
        children: [
          _sub('card', 3, [
            _box('pic', 0, 30),
            _sub('body', 2, [
              _box('h', 50, 20),
              _box('s', 70, 15, column: 1),
              _ratio('r', 4),
            ], margin: const EdgeInsets.symmetric(horizontal: 10)),
          ]),
        ],
      ),
      300,
      {
        'list': _r(0, 0, 300, 82.5),
        'card': _r(0, 0, 300, 82.5),
        'pic': _r(0, 0, 300, 30),
        'body': _r(10, 30, 280, 52.5),
        'h': _r(10, 30, 130, 20),
        's': _r(140, 30, 150, 20),
        'r': _r(10, 50, 130, 32.5),
      },
    );
  });

  // css-grid-1 7.5, 8.3: a line counted back from the end of no columns
  // at all, `grid-column: -2`, is the line BEFORE the first, and the
  // card's grid gains an implicit column in front for `b` -- one column in
  // all, which the flow starts from, so the three stand one under the
  // next at the card's whole width. Beside a `100px` of its own, `-3` is
  // before the first too: `d` flows into the front column, `e` is placed
  // past it down that column, and `f` flows on beside `e` into the 100px.
  testWidgets("an item on a column before the card's first: an implicit column in front, the flow starts from it", (
    tester,
  ) async {
    await _expect(
      tester,
      Tracks(
        key: _k('list'),
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
        children: [
          _sub('card', 3, [_box('a', 60, 20), _box('b', 30, 50, column: -1), _box('c', 90, 30)]),
        ],
      ),
      300,
      {
        'list': _r(0, 0, 300, 100),
        'card': _r(0, 0, 300, 100),
        'a': _r(0, 0, 300, 20),
        'b': _r(0, 20, 300, 50),
        'c': _r(0, 70, 300, 30),
      },
    );
    await _expect(
      tester,
      Tracks(
        key: _k('list'),
        columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
        children: [
          TrackCell(
            rowSpan: 3,
            subgrid: true,
            child: ColoredBox(
              key: _k('card'),
              color: const Color(0xFF111111),
              child: Tracks(
                subgridRows: true,
                columns: const [TrackSize.fixed(100)],
                children: [_box('d', 0, 20), _box('e', 0, 50, column: -2), _box('f', 0, 30)],
              ),
            ),
          ),
        ],
      ),
      300,
      {
        'list': _r(0, 0, 300, 70),
        'card': _r(0, 0, 300, 70),
        'd': _r(0, 0, 200, 20),
        'e': _r(0, 20, 200, 50),
        'f': _r(200, 20, 100, 50),
      },
    );
  });

  // css-grid-1 7.2.3.2, css-grid-2 9: a subgrid's grid is placed with its
  // host's, before any column is sized, so the width it is stretched to
  // is not known then and its columns `repeat(auto-fill, ..)` repeat
  // ONCE -- the body's `minmax(90px, 1fr)` is one column, 280 wide, where
  // three would fit, and `t`, placed on row 2 beside `s`, takes an
  // implicit column of its own (0 wide); `b` flows on beside `a` into it,
  // `c` finds no cell free on the body's two rows and is clamped onto the
  // last, over `s`. The card `C` repeats its own `minmax(100px, 1fr)` once
  // too: all four of its items stand in one column 300 wide.
  testWidgets(
    'columns a subgrid repeats to fill its width repeat once: its width is not known when its grid is placed',
    (tester) async {
      Widget fill(String key, int rows, double min, List<Widget> items, {EdgeInsets margin = EdgeInsets.zero}) =>
          TrackCell(
            rowSpan: rows,
            margin: margin,
            minWidth: 0,
            subgrid: true,
            child: ColoredBox(
              key: _k(key),
              color: const Color(0xFF111111),
              child: Tracks(
                subgridRows: true,
                columns: [
                  TrackSize.fill([TrackSize.between(TrackSize.fixed(min), const TrackSize.flex(1))]),
                ],
                children: items,
              ),
            ),
          );
      const list = [
        TrackSize.repeat(2, [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))]),
      ];
      await _expect(
        tester,
        Tracks(
          key: _k('list'),
          columns: list,
          spacing: 16,
          runSpacing: 16,
          children: [
            _sub('A', 3, [
              _box('pic', 0, 30),
              fill('body', 2, 90, [
                _box('a', 0, 20),
                _box('b', 0, 15),
                _ratio('c', 4),
                _box('s', 0, 10, row: 1),
                _box('t', 0, 40, row: 1),
              ], margin: const EdgeInsets.symmetric(horizontal: 16)),
            ]),
            _sub('B', 3, [_box('e', 0, 40), _box('f', 0, 15), _box('g', 0, 25)]),
          ],
        ),
        640,
        {
          'list': _r(0, 0, 640, 130),
          'A': _r(0, 0, 312, 130),
          'pic': _r(0, 0, 312, 40),
          'body': _r(16, 40, 280, 90),
          'a': _r(16, 40, 280, 20),
          'b': _r(296, 40, 0, 20),
          'c': _r(16, 60, 280, 70),
          's': _r(16, 60, 280, 70),
          't': _r(296, 60, 0, 70),
          'B': _r(328, 0, 312, 130),
          'e': _r(328, 0, 312, 40),
          'f': _r(328, 40, 312, 20),
          'g': _r(328, 60, 312, 70),
        },
      );
      await _expect(
        tester,
        Tracks(
          key: _k('list'),
          columns: list,
          spacing: 16,
          runSpacing: 16,
          children: [
            fill('C', 3, 100, [
              _box('h', 0, 20),
              _ratio('i', 4),
              _box('j', 0, 30, row: 1),
              _box('k', 0, 12),
            ], margin: const EdgeInsets.symmetric(horizontal: 6)),
            _sub('D', 3, [_box('l', 0, 10), _box('m', 0, 50), _box('n', 0, 5)]),
          ],
        ),
        640,
        {
          'list': _r(0, 0, 640, 145),
          'C': _r(6, 0, 300, 145),
          'h': _r(6, 0, 300, 20),
          'i': _r(6, 70, 300, 75),
          'j': _r(6, 20, 300, 50),
          'k': _r(6, 70, 300, 75),
          'D': _r(328, 0, 312, 145),
          'l': _r(328, 0, 312, 20),
          'm': _r(328, 20, 312, 50),
          'n': _r(328, 70, 312, 75),
        },
      );
    },
  );
}
