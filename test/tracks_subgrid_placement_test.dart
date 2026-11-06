// A ROW SUBGRID PLACES ITS ITEMS AS ANY GRID DOES, and then clamps them to
// the rows it spans (css-grid-2 9, "each grid item's grid area is clamped
// to the subgrid's explicit grid"): an item that names a row takes it
// first, and one the flow puts past the last row stands on the last. Every
// rect is Chrome's, from fixtures/grid-row-subgrid-pair.html p5 and p6 at
// 1440px, each grid built as the lowerer states it and each text box a box
// of the height its lines come to in Chrome.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

/// A text box [h] tall, stretched to its area as a grid item is, on [row]
/// where it names one.
Widget _box(String key, double h, {double after = 0, int? row}) => TrackCell(
  row: row,
  margin: EdgeInsets.only(bottom: after),
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF000000),
    child: ConstrainedBox(constraints: BoxConstraints(minHeight: h)),
  ),
);

/// dba's card: a 156px picture over a body of five rows inside 16px
/// margins, holding [parts].
Widget _card(String id, List<Widget> parts) => TrackCell(
  rowSpan: 6,
  subgrid: true,
  align: CellAlign.stretch,
  child: ColoredBox(
    key: _k('$id.card'),
    color: const Color(0xFF111111),
    child: Tracks(
      columns: const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
      subgridRows: true,
      children: [
        ColoredBox(key: _k('$id.pic'), color: const Color(0xFF333333), child: const SizedBox(height: 156)),
        TrackCell(
          rowSpan: 5,
          subgrid: true,
          margin: const EdgeInsets.all(16),
          child: ColoredBox(
            key: _k('$id.body'),
            color: const Color(0xFF222222),
            child: Tracks(subgridRows: true, children: parts),
          ),
        ),
      ],
    ),
  ),
);

/// The five parts of a plain card, in order.
List<Widget> _plain(String id) => [
  _box('$id.h2', 22),
  _box('$id.sub', 18, after: 4),
  _box('$id.spec', 18, after: 8),
  _box('$id.price', 28, after: 4),
  _box('$id.loc', 16),
];

/// dba's listing: two columns `minmax(0, 1fr)` 16px apart, rows 16px apart,
/// items at the start of their areas.
Widget _list(List<Widget> cards) => Tracks(
  key: _k('list'),
  columns: const [
    TrackSize.repeat(2, [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))]),
  ],
  spacing: 16,
  runSpacing: 16,
  align: CellAlign.start,
  flow: TrackFlow.rowDense,
  children: cards,
);

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
        child: SizedBox(key: _k('root'), width: 640, child: grid),
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
  testWidgets('p5: a sixth part on five rows stands on the last, over the fifth', (tester) async {
    await _expect(
      tester,
      _list([
        _card('a', [..._plain('a'), _box('a.seller', 16)]),
        _card('b', _plain('b')),
      ]),
      {
        'list': const Rect.fromLTWH(0, 0, 640, 306),
        'a.card': const Rect.fromLTWH(0, 0, 312, 306),
        'a.body': const Rect.fromLTWH(16, 172, 280, 118),
        'a.h2': const Rect.fromLTWH(16, 172, 280, 22),
        'a.sub': const Rect.fromLTWH(16, 194, 280, 18),
        'a.spec': const Rect.fromLTWH(16, 216, 280, 18),
        'a.price': const Rect.fromLTWH(16, 242, 280, 28),
        'a.loc': const Rect.fromLTWH(16, 274, 280, 16),
        'a.seller': const Rect.fromLTWH(16, 274, 280, 16),
        'b.card': const Rect.fromLTWH(328, 0, 312, 306),
        'b.loc': const Rect.fromLTWH(344, 274, 280, 16),
      },
    );
  });

  testWidgets('p6: a part on a row of its own, and the flow a row further on', (tester) async {
    await _expect(
      tester,
      _list([
        _card('a', [
          _box('a.h2', 22),
          _box('a.sub', 18, after: 4),
          _box('a.spec', 18, after: 8, row: 1),
          _box('a.price', 28, after: 4),
          _box('a.loc', 16),
        ]),
        _card('b', _plain('b')),
      ]),
      {
        'list': const Rect.fromLTWH(0, 0, 640, 310),
        'a.body': const Rect.fromLTWH(16, 172, 280, 122),
        'a.h2': const Rect.fromLTWH(16, 172, 280, 22),
        'a.spec': const Rect.fromLTWH(16, 194, 280, 18),
        'a.sub': const Rect.fromLTWH(16, 220, 280, 22),
        'a.price': const Rect.fromLTWH(16, 246, 280, 28),
        'a.loc': const Rect.fromLTWH(16, 278, 280, 16),
        'b.sub': const Rect.fromLTWH(344, 194, 280, 22),
        'b.spec': const Rect.fromLTWH(344, 220, 280, 18),
      },
    );
  });

  testWidgets('two parts naming the same row stand side by side, the second in a column of the card\'s own', (
    tester,
  ) async {
    // css-grid-1 8.5: the second is placed in the first column free on its
    // row, which the subgrid's own grid adds; its rows are still the list's
    // (tracks_subgrid_own_columns_test has Chrome's rects).
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 640,
            child: _list([
              _card('a', [_box('a.h2', 22), _box('a.sub', 18, after: 4, row: 1), _box('a.spec', 18, after: 8, row: 1)]),
            ]),
          ),
        ),
      ),
    );
    expect(tester.getRect(find.byKey(_k('a.sub'))).left, isNot(tester.getRect(find.byKey(_k('a.spec'))).left));
  });
}
