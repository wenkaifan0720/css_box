// A ROW SUBGRID in `Tracks` (css-grid-2 9): a grid whose rows are the rows
// of the grid round it, its items sized as items of that grid. Every rect
// is Chrome's, from fixtures/grid-row-subgrid-pair.html at 1000px, each
// grid built as the lowerer states it and each text box a box of the
// height its lines come to in Chrome.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

/// A box [h] tall with nothing in it -- a text box's lines -- stretched to
/// its area as a grid item is.
Widget _box(String key, double h, {EdgeInsets margin = EdgeInsets.zero, CellAlign? align}) => TrackCell(
  margin: margin,
  align: align,
  child: ColoredBox(
    key: _k(key),
    color: const Color(0xFF000000),
    child: ConstrainedBox(constraints: BoxConstraints(minHeight: h)),
  ),
);

/// dba's card: a picture [pic] tall over a body of five rows inside 16px
/// margins, the card [frame] inside its edge and [gap] between its rows.
/// [texts] are the five text boxes' heights, and [columns] the card's own
/// (none: one implicit `auto` column, as a card that states none).
Widget _card(
  String id,
  double pic,
  List<double> texts, {
  EdgeInsets frame = EdgeInsets.zero,
  double gap = 0,
  List<Widget> over = const [],
  double? ratio,
  List<TrackSize> columns = const [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))],
}) => TrackCell(
  rowSpan: 6,
  subgrid: true,
  align: CellAlign.stretch,
  child: ColoredBox(
    key: _k('$id.card'),
    color: const Color(0xFF111111),
    child: Padding(
      padding: frame,
      child: Tracks(
        columns: columns,
        runSpacing: gap,
        subgridRows: true,
        subgridFrame: frame,
        children: [
          ...over,
          if (ratio == null)
            _box('$id.pic', pic)
          else
            // A picture held at a ratio by its padding: as tall as the
            // ratio makes it at its width, and asked its width at a
            // height, the height times the ratio.
            ColoredBox(
              key: _k('$id.pic'),
              color: const Color(0xFF333333),
              child: AspectRatio(aspectRatio: ratio),
            ),
          TrackCell(
            rowSpan: 5,
            subgrid: true,
            margin: const EdgeInsets.all(16),
            child: ColoredBox(
              key: _k('$id.body'),
              color: const Color(0xFF222222),
              child: Tracks(
                runSpacing: gap,
                subgridRows: true,
                children: [
                  _box('$id.h2', texts[0]),
                  _box('$id.sub', texts[1], margin: const EdgeInsets.only(bottom: 4)),
                  _box('$id.spec', texts[2], margin: const EdgeInsets.only(bottom: 8)),
                  _box('$id.price', texts[3], margin: const EdgeInsets.only(bottom: 4)),
                  _box('$id.loc', texts[4]),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

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

/// The five text boxes of a plain card at [top], its body [x] in.
Map<String, Rect> _plain(String id, double x, double top, List<double> rows) {
  final out = <String, Rect>{};
  final names = ['h2', 'sub', 'spec', 'price', 'loc'];
  final after = [0.0, 4.0, 8.0, 4.0, 0.0];
  var y = top;
  for (var i = 0; i < 5; i++) {
    out['$id.${names[i]}'] = Rect.fromLTWH(x, y, 280, rows[i] - after[i]);
    y += rows[i];
  }
  return out;
}

void main() {
  testWidgets('p1: an uneven pair -- each row as tall as the taller part in it', (tester) async {
    await _expect(
      tester,
      _list([
        _card('a', 156, [22, 18, 18, 28, 16]),
        _card('b', 156, [44, 18, 36, 28, 16]),
      ]),
      {
        'list': const Rect.fromLTWH(0, 0, 640, 346),
        'a.card': const Rect.fromLTWH(0, 0, 312, 346),
        'a.pic': const Rect.fromLTWH(0, 0, 312, 156),
        'a.body': const Rect.fromLTWH(16, 172, 280, 158),
        ..._plain('a', 16, 172, [44, 22, 44, 32, 16]),
        'b.card': const Rect.fromLTWH(328, 0, 312, 346),
        'b.body': const Rect.fromLTWH(344, 172, 280, 158),
        ..._plain('b', 344, 172, [44, 22, 44, 32, 16]),
      },
    );
  });

  testWidgets('p2: an empty part holds its gutter open, and a lone card has its rows to itself', (tester) async {
    await _expect(
      tester,
      _list([
        _card('a', 156, [22, 0, 18, 28, 16]),
        _card('b', 156, [22, 0, 18, 28, 16]),
        _card('c', 156, [22, 18, 18, 28, 16]),
      ]),
      {
        'list': const Rect.fromLTWH(0, 0, 640, 622),
        'a.card': const Rect.fromLTWH(0, 0, 312, 300),
        'a.body': const Rect.fromLTWH(16, 172, 280, 112),
        ..._plain('a', 16, 172, [22, 16, 26, 32, 16]),
        'b.card': const Rect.fromLTWH(328, 0, 312, 300),
        'c.card': const Rect.fromLTWH(0, 316, 312, 306),
        'c.body': const Rect.fromLTWH(16, 488, 280, 118),
        ..._plain('c', 16, 488, [22, 22, 26, 32, 16]),
      },
    );
  });

  testWidgets('p4: a card with a frame and a gap of its own beside a plain one', (tester) async {
    await _expect(
      tester,
      _list([
        _card('a', 143, [22, 18, 36, 28, 16], frame: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), gap: 6),
        _card('b', 156, [22, 18, 18, 28, 16]),
      ]),
      {
        'list': const Rect.fromLTWH(0, 0, 640, 360),
        'a.card': const Rect.fromLTWH(0, 0, 312, 360),
        'a.pic': const Rect.fromLTWH(13, 9, 286, 144),
        'a.body': const Rect.fromLTWH(29, 175, 254, 160),
        'a.h2': const Rect.fromLTWH(29, 175, 254, 22),
        'a.sub': const Rect.fromLTWH(29, 203, 254, 18),
        'a.spec': const Rect.fromLTWH(29, 231, 254, 36),
        'a.price': const Rect.fromLTWH(29, 281, 254, 28),
        'a.loc': const Rect.fromLTWH(29, 319, 254, 16),
        'b.card': const Rect.fromLTWH(328, 0, 312, 360),
        'b.pic': const Rect.fromLTWH(328, 0, 312, 156),
        'b.body': const Rect.fromLTWH(344, 172, 280, 172),
        ..._plain('b', 344, 172, [28, 28, 50, 38, 28]),
      },
    );
  });

  testWidgets('a picture at a ratio is as wide as its column, in a row taller than the ratio makes it', (tester) async {
    // p4 again, the framed card's picture a box whose width follows its
    // height, in the one `auto` column of a card that states none: its row
    // is 144 (the plain card's 156 less the gutters), and at that height
    // it would ask for 288 of the 286 its column has. The columns are
    // sized before the rows, as Chrome sizes a subgrid's.
    await _expect(
      tester,
      _list([
        _card(
          'a',
          0,
          [22, 18, 36, 28, 16],
          frame: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          gap: 6,
          ratio: 2,
          columns: const [],
        ),
        _card('b', 0, [22, 18, 18, 28, 16], ratio: 2, columns: const []),
      ]),
      {
        'a.card': const Rect.fromLTWH(0, 0, 312, 360),
        'a.pic': const Rect.fromLTWH(13, 9, 286, 144),
        'a.body': const Rect.fromLTWH(29, 175, 254, 160),
        'b.pic': const Rect.fromLTWH(328, 0, 312, 156),
        'b.body': const Rect.fromLTWH(344, 172, 280, 172),
      },
    );
  });

  testWidgets('a part that grows grows its row in the other card too', (tester) async {
    await _expect(
      tester,
      _list([
        _card('a', 156, [22, 18, 18, 28, 16]),
        _card('b', 156, [22, 18, 18, 28, 16]),
      ]),
      {
        'b.body': const Rect.fromLTWH(344, 172, 280, 118),
        ..._plain('a', 16, 172, [22, 22, 26, 32, 16]),
      },
    );
    await _expect(
      tester,
      _list([
        _card('a', 156, [22, 18, 18, 28, 16]),
        _card('b', 156, [44, 18, 36, 28, 16]),
      ]),
      {
        'b.body': const Rect.fromLTWH(344, 172, 280, 158),
        ..._plain('a', 16, 172, [44, 22, 44, 32, 16]),
      },
    );
  });

  testWidgets('a box out of the flow in a subgrid takes no row', (tester) async {
    await _expect(
      tester,
      _list([
        _card(
          'a',
          156,
          [22, 18, 18, 28, 16],
          over: [
            TrackCell(positioned: true, left: 0, top: 0, right: 0, bottom: 0, child: SizedBox(key: _k('a.cover'))),
          ],
        ),
        _card('b', 156, [44, 18, 36, 28, 16]),
      ]),
      {
        'a.cover': const Rect.fromLTWH(0, 0, 312, 346),
        ..._plain('a', 16, 172, [44, 22, 44, 32, 16]),
      },
    );
  });

  testWidgets('a subgrid straight under its cell, with no box of its own round it', (tester) async {
    Widget bare(String id, List<double> texts) => TrackCell(
      rowSpan: 6,
      subgrid: true,
      align: CellAlign.stretch,
      child: Tracks(
        key: _k('$id.card'),
        subgridRows: true,
        children: [
          _box('$id.pic', 156),
          TrackCell(
            rowSpan: 5,
            subgrid: true,
            margin: const EdgeInsets.all(16),
            child: Tracks(
              key: _k('$id.body'),
              subgridRows: true,
              children: [
                _box('$id.h2', texts[0]),
                _box('$id.sub', texts[1], margin: const EdgeInsets.only(bottom: 4)),
                _box('$id.spec', texts[2], margin: const EdgeInsets.only(bottom: 8)),
                _box('$id.price', texts[3], margin: const EdgeInsets.only(bottom: 4)),
                _box('$id.loc', texts[4]),
              ],
            ),
          ),
        ],
      ),
    );
    await _expect(
      tester,
      _list([
        bare('a', [22, 18, 18, 28, 16]),
        bare('b', [44, 18, 36, 28, 16]),
      ]),
      {
        'a.card': const Rect.fromLTWH(0, 0, 312, 346),
        'a.body': const Rect.fromLTWH(16, 172, 280, 158),
        ..._plain('a', 16, 172, [44, 22, 44, 32, 16]),
        'b.card': const Rect.fromLTWH(328, 0, 312, 346),
      },
    );
  });

  testWidgets('more parts than rows: the subgrid is laid out as a grid of its own', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 640,
            child: _list([
              TrackCell(
                rowSpan: 2,
                subgrid: true,
                child: Tracks(
                  key: _k('sub'),
                  subgridRows: true,
                  children: [_box('x', 10), _box('y', 10), _box('z', 10)],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_k('sub'))).height, 30);
    expect(tester.takeException(), isNull);
  });
}
