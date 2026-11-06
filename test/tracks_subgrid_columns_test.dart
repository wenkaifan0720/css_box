// A COLUMN SUBGRID in `Tracks` (css-grid-2 9): a grid whose columns are
// the columns of the grid round it, its items sized as items of that grid
// -- in its column pass, and in how wide it says it is. Every rect is
// Chrome's, each item a box of a stated width and height inside a grid
// item that stretches, as the lowerer states such a grid.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

/// A grid item holding a box [w] by [h]: [w] wide at its min-content and
/// its max-content, stretched to its area.
Widget _box(
  String key,
  double w,
  double h, {
  int? column,
  int? row,
  int? columnEnd,
  int columnSpan = 1,
  EdgeInsets margin = EdgeInsets.zero,
}) => TrackCell(
  column: column,
  row: row,
  columnEnd: columnEnd,
  columnSpan: columnSpan,
  margin: margin,
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF000000),
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: w, minHeight: h),
    ),
  ),
);

/// The subgrid under a cell of the host from [column] to [columnEnd]: its
/// [frame] a padding inside its box, [gap] between its own columns and
/// [runGap] between its rows.
Widget _sub(
  String key,
  List<Widget> items, {
  required int column,
  required int columnEnd,
  EdgeInsets frame = EdgeInsets.zero,
  EdgeInsets margin = EdgeInsets.zero,
  double gap = 0,
  double runGap = 0,
}) => TrackCell(
  column: column,
  columnEnd: columnEnd,
  margin: margin,
  subgrid: true,
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF111111),
    child: Padding(
      padding: frame,
      child: Tracks(spacing: gap, runSpacing: runGap, subgridColumns: true, subgridFrame: frame, children: items),
    ),
  ),
);

/// Chrome lays boxes out in 1/64 px.
const _tolerance = 2 / 64;

/// Lays [grid] out in a 640px case [width] wide -- or, where there is no
/// width, as wide as its content says it is, as `width: max-content` --
/// and holds each named box to Chrome's rect in the case.
Future<void> _expect(WidgetTester tester, Widget grid, Map<String, Rect> chrome, {double? width}) async {
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
            child: width == null ? IntrinsicWidth(child: grid) : SizedBox(width: width, child: grid),
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
  // css-grid-1 12.7.1: `1fr` is `minmax(auto, 1fr)`, and the subgrid's
  // 56px item sizes the host's track -- 56 wide, the other eleven sharing
  // what is left.
  testWidgets('the last three of twelve `1fr`: an item wider than its share keeps its track', (tester) async {
    await _expect(
      tester,
      Tracks(
        key: _k('grid'),
        columns: const [
          TrackSize.repeat(12, [TrackSize.flex(1)]),
        ],
        children: [
          _sub('sub', [_box('a', 56, 24), _box('b', 30, 24), _box('c', 30, 24)], column: -3, columnEnd: -1),
        ],
      ),
      {
        'grid': _r(0, 0, 600, 24),
        'sub': _r(445.078, 0, 154.906, 24),
        'a': _r(445.078, 0, 56, 24),
        'b': _r(501.078, 0, 49.453, 24),
        'c': _r(550.531, 0, 49.453, 24),
      },
      width: 600,
    );
  });

  testWidgets('the first four of twelve `1fr` 20px apart, each its item\'s', (tester) async {
    await _expect(
      tester,
      Tracks(
        key: _k('grid'),
        columns: const [
          TrackSize.repeat(12, [TrackSize.flex(1)]),
        ],
        spacing: 20,
        children: [
          _sub(
            'sub',
            [_box('a', 37, 24), _box('b', 55, 24), _box('c', 29, 24), _box('d', 39, 24)],
            column: 0,
            columnEnd: 4,
            // `normal`: a subgrid's gutter is its host's (css-grid-2 9).
            gap: 20,
          ),
        ],
      ),
      {
        'sub': _r(0, 0, 220, 24),
        'a': _r(0, 0, 37, 24),
        'b': _r(57, 0, 55, 24),
        'c': _r(132, 0, 29, 24),
        'd': _r(181, 0, 39, 24),
      },
      width: 600,
    );
  });

  // css-grid-2 9: the subgrid's 30px gutter stands centred in the host's
  // 10px, 10px of it on each side an extra margin of the item beside it,
  // and its 12px padding one on its edge items -- each item as wide as
  // it says only once they are counted, which squeezes the two tracks
  // the subgrid is not on to 67.5.
  testWidgets('a gutter and a padding of the subgrid\'s own count in the host\'s tracks', (tester) async {
    await _expect(
      tester,
      Tracks(
        key: _k('grid'),
        columns: const [
          TrackSize.repeat(6, [TrackSize.flex(1)]),
        ],
        spacing: 10,
        children: [
          _sub(
            'sub',
            [_box('a', 69, 24), _box('b', 71, 24), _box('c', 71, 24), _box('d', 120, 24)],
            column: 1,
            columnEnd: 5,
            gap: 30,
            frame: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ],
      ),
      {
        'sub': _r(77.5, 0, 445, 24),
        'a': _r(89.5, 0, 69, 24),
        'b': _r(188.5, 0, 71, 24),
        'c': _r(289.5, 0, 71, 24),
        'd': _r(390.5, 0, 120, 24),
      },
      width: 600,
    );
  });

  // The host's intrinsic width is its column pass with no room to fill:
  // the subgrid's items are in it, the cell is not.
  Widget contentSized() => Tracks(
    key: _k('grid'),
    columns: const [TrackSize.auto, TrackSize.auto, TrackSize.auto],
    spacing: 8,
    children: [
      _sub(
        'sub',
        [_box('a', 40, 24), _box('b', 70, 24), _box('c', 50, 24)],
        column: 0,
        columnEnd: 3,
        gap: 12,
        frame: const EdgeInsets.symmetric(horizontal: 5),
      ),
      _box('x', 90, 16, column: 1, row: 1),
    ],
  );
  const contentRects = {
    'grid': Rect.fromLTWH(0, 0, 210, 40),
    'sub': Rect.fromLTWH(0, 0, 210, 24),
    'a': Rect.fromLTWH(5, 0, 40, 24),
    'b': Rect.fromLTWH(57, 0, 86, 24),
    'c': Rect.fromLTWH(155, 0, 50, 24),
    'x': Rect.fromLTWH(55, 24, 90, 16),
  };

  testWidgets('a host as wide as its content counts the subgrid\'s items', (tester) async {
    await _expect(tester, contentSized(), contentRects);
    final host = tester.renderObject<RenderBox>(find.byKey(_k('grid')));
    // Chrome's `width: min-content` and `width: max-content`.
    expect(host.getMinIntrinsicWidth(double.infinity), moreOrLessEquals(210, epsilon: _tolerance));
    expect(host.getMaxIntrinsicWidth(double.infinity), moreOrLessEquals(210, epsilon: _tolerance));
  });

  // The subgrid places its items on its own rows (css-grid-1 8.5) with a
  // gutter of its own between them: the host sizes its columns by them
  // and its row by how tall the subgrid comes to on those columns. Its
  // 4px gutter is NARROWER than the host's 10px, and the difference, as
  // an extra margin, is negative.
  testWidgets('rows of the subgrid\'s own, an item on a line, margins, a gutter narrower than the host\'s', (
    tester,
  ) async {
    await _expect(
      tester,
      Tracks(
        key: _k('grid'),
        columns: const [TrackSize.fixed(100), TrackSize.flex(1), TrackSize.flex(1), TrackSize.auto],
        spacing: 10,
        runSpacing: 5,
        children: [
          _sub(
            'sub',
            [
              _box('a', 30, 20),
              _box('b', 50, 40),
              _box('c', 20, 10, column: 3),
              _box('d', 60, 30, margin: const EdgeInsets.only(left: 8)),
              _box('e', 25, 25),
            ],
            column: 0,
            columnEnd: -1,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            gap: 4,
            runGap: 7,
          ),
          _box('x', 0, 10, column: 0, columnEnd: -1),
        ],
      ),
      {
        'grid': _r(0, 0, 500, 92),
        'sub': _r(6, 0, 488, 77),
        'a': _r(6, 0, 97, 40),
        'b': _r(107, 0, 179.5, 40),
        'c': _r(474, 0, 20, 40),
        'd': _r(14, 47, 89, 30),
        'e': _r(107, 47, 179.5, 30),
        'x': _r(0, 82, 500, 10),
      },
      width: 500,
    );
  });

  testWidgets('an item of the subgrid across two of the host\'s `auto` columns', (tester) async {
    await _expect(
      tester,
      Tracks(
        key: _k('grid'),
        columns: const [
          TrackSize.repeat(3, [TrackSize.auto]),
        ],
        children: [
          _sub(
            'sub',
            [_box('a', 150, 20, columnSpan: 2), _box('b', 40, 20), _box('c', 30, 20)],
            column: 0,
            columnEnd: -1,
          ),
        ],
      ),
      {
        'grid': _r(0, 0, 400, 40),
        'sub': _r(0, 0, 400, 40),
        'a': _r(0, 0, 290, 20),
        'b': _r(290, 0, 110, 20),
        'c': _r(0, 20, 100, 20),
      },
      width: 400,
    );
  });

  // css-grid-2 9: "the justify-self property on it is ignored, as are any
  // specified width constraints".
  testWidgets('a subgrid that says a width and a `justify-self` is stretched across its columns', (tester) async {
    await _expect(
      tester,
      Tracks(
        key: _k('grid'),
        columns: const [TrackSize.flex(1), TrackSize.flex(1)],
        children: [
          TrackCell(
            column: 0,
            columnEnd: -1,
            justify: CellAlign.center,
            width: 100,
            maxWidth: 120,
            subgrid: true,
            child: ColoredBox(
              key: _k('sub'),
              color: const Color(0xFF111111),
              child: Tracks(subgridColumns: true, children: [_box('a', 40, 20), _box('b', 60, 20)]),
            ),
          ),
        ],
      ),
      {'sub': _r(0, 0, 300, 20), 'a': _r(0, 0, 150, 20), 'b': _r(150, 0, 150, 20)},
      width: 300,
    );
  });

  // A subgrid CLAMPS an item on a line past its columns onto them
  // (css-grid-2 9), where a grid of its own would add a column -- across,
  // before its flow runs, so the flow wraps at its last column. `b` at
  // `grid-column: 6` of three is on the third, beside `a`, and `a`, 80px
  // in a 50px share, keeps its track 80 wide in the host.
  testWidgets('an item on a line past the subgrid\'s columns is clamped onto its last', (tester) async {
    await _expect(
      tester,
      Tracks(
        key: _k('grid'),
        columns: const [
          TrackSize.repeat(12, [TrackSize.flex(1)]),
        ],
        children: [
          _sub('sub', [_box('a', 80, 24), _box('b', 30, 24, column: 5)], column: -3, columnEnd: -1),
          _box('first', 0, 24, column: 0),
        ],
      ),
      {
        'grid': _r(0, 0, 600, 48),
        'sub': _r(425.453, 0, 174.547, 24),
        'a': _r(425.453, 0, 80, 24),
        'b': _r(552.719, 0, 47.2812, 24),
        'first': _r(0, 24, 47.2656, 24),
      },
      width: 600,
    );
    // `f` at `grid-column: 5` after three is on the third column a row
    // down, not over `e`; `span 5` is three, on a row of its own. Past
    // the end both ways (`6 / 8`) is the last column; the flow goes on
    // from it.
    Widget six(List<Widget> items) => Tracks(
      key: _k('grid'),
      columns: const [
        TrackSize.repeat(6, [TrackSize.flex(1)]),
      ],
      children: [_sub('sub', items, column: 1, columnEnd: 4)],
    );
    await _expect(
      tester,
      six([
        _box('c', 0, 24),
        _box('d', 0, 24),
        _box('e', 0, 24),
        _box('f', 0, 24, column: 4),
        _box('g', 0, 24, columnSpan: 5),
      ]),
      {
        'sub': _r(100, 0, 300, 72),
        'c': _r(100, 0, 100, 24),
        'd': _r(200, 0, 100, 24),
        'e': _r(300, 0, 100, 24),
        'f': _r(300, 24, 100, 24),
        'g': _r(100, 48, 300, 24),
      },
      width: 600,
    );
    await _expect(
      tester,
      six([_box('c', 0, 24), _box('g', 0, 24, columnSpan: 4), _box('h', 0, 24, column: 6), _box('d', 0, 24)]),
      {
        'sub': _r(100, 0, 300, 96),
        'c': _r(100, 0, 100, 24),
        'g': _r(100, 24, 300, 24),
        'h': _r(300, 48, 100, 24),
        'd': _r(100, 72, 100, 24),
      },
      width: 600,
    );
    await _expect(tester, six([_box('c', 0, 24), _box('h', 0, 24, column: 5, columnEnd: 7), _box('d', 0, 24)]), {
      'sub': _r(100, 0, 300, 48),
      'c': _r(100, 0, 100, 24),
      'h': _r(300, 0, 100, 24),
      'd': _r(100, 24, 100, 24),
    }, width: 600);
  });

  // NEGATIVE: a line BEFORE the subgrid's first has Chrome's flow run over
  // as many more columns as it is in front, which no clamp of the one item
  // says: the host does not share its columns, and its items size nothing
  // of the host's -- the twelve shares stay 50 each.
  testWidgets('NEGATIVE: an item on a line before the subgrid\'s first: the host counts none of its items', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            child: Tracks(
              columns: const [
                TrackSize.repeat(12, [TrackSize.flex(1)]),
              ],
              children: [
                _sub('sub', [_box('a', 80, 24), _box('b', 30, 24, column: -6)], column: -3, columnEnd: -1),
                _box('first', 0, 24, column: 0),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(_k('first'))).width, moreOrLessEquals(50, epsilon: _tolerance));
  });
}
