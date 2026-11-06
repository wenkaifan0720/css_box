// A FLOOR OF A LENGTH THAT MAY PASS THE ROOM, HANDED THE ROOM TIGHT AND NO
// HEIGHT, IS A `Table` OF ONE COLUMN NO NARROWER THAN IT. `min-width` holds
// past the room: the box is the floor wide and hangs out of its end, as
// tall as its content is at that width (CSS 2.1 10.4). The lowerer let such
// a floor past the room in a `LayoutBuilder` round an `OverflowBox` of
// `math.max(box.maxWidth, floor)`, its child under a `ConstrainedBox` of the
// floor (`lossy.dart`, `_pastRoomL`): handed a width W tight, that child is
// laid out `max(W, floor)` wide, tight, at the start of a box W wide. A
// `Table` of one `MaxColumnWidth(FlexColumnWidth(), FixedColumnWidth(floor))`
// lays its one cell out at the same `tightFor(width:)`, at its top with no
// bound down (`rendering/table.dart`), and is W wide (`_pastRoomTableL`).
// A product site's panes past a phone, `width: 100%; min-width: 1200px`, and
// a price-table site's chart card; a Japanese news site's header and sections, `min-width:
// 1280px` down the page, are the same box, kept a `LayoutBuilder` for the
// app's parts. This pins the two to the same boxes at widths under, at and
// over the floor, round a box that fills its width, one that shrinks to its
// content, and words that wrap at it (`fixtures/block-floor-past-room-table`).
// NEGATIVE: what the lowerer keeps the `LayoutBuilder` for -- a width handed
// loose (the box is then as wide as its content, between the floor and the
// room), a height bound (a box under it that fills its height), a baseline
// asked (a table answers none), right to left (the table lays its column
// from the left, where the floor hangs off the left).
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

ValueKey<String> _k(String name) => ValueKey(name);

const _words = 'Breaking news from around the country and the world, every hour of the day';

/// What the floor holds: a box that fills its width, one that shrinks to
/// its content, or words that wrap at it.
final _boxes = <String, Widget Function()>{
  'filling': () => SizedBox(key: _k('box'), width: double.infinity, height: 116, child: const Text('Header')),
  'shrinking': () => Align(
    key: _k('box'),
    alignment: Alignment.topLeft,
    widthFactor: 1,
    heightFactor: 1,
    child: const Text('Masthead'),
  ),
  'words': () => Text(_words, key: _k('box')),
};

/// The floor as the lowerer wrote it before.
Widget _built(double floor, Widget box, {AlignmentGeometry a = AlignmentDirectional.topStart}) => LayoutBuilder(
  key: _k('floor'),
  builder: (context, c) => OverflowBox(
    maxWidth: math.max(c.maxWidth, floor),
    fit: OverflowBoxFit.deferToChild,
    alignment: a,
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: floor),
      child: box,
    ),
  ),
);

/// The floor as the lowerer writes it now.
Widget _table(double floor, Widget box) => Table(
  key: _k('floor'),
  columnWidths: {0: MaxColumnWidth(const FlexColumnWidth(), FixedColumnWidth(floor))},
  children: [
    TableRow(children: [box]),
  ],
);

Widget _page(double width, Widget floor, {bool loose = false, TextDirection dir = TextDirection.ltr}) => Directionality(
  textDirection: dir,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: loose ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
        children: [
          floor,
          SizedBox(key: _k('after'), height: 10),
        ],
      ),
    ),
  ),
);

Future<Map<String, Rect>> _rects(
  WidgetTester t,
  Widget w, [
  List<String> keys = const ['floor', 'box', 'after'],
]) async {
  await _pump(t, w);
  return {for (final k in keys) k: t.getRect(find.byKey(_k(k)))};
}

/// A window wider than the widest page laid out here.
Future<void> _pump(WidgetTester t, Widget w) async {
  t.view
    ..physicalSize = const Size(2000, 1200)
    ..devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(w);
}

void main() {
  for (final MapEntry(key: name, value: box) in _boxes.entries) {
    for (final width in const [1440.0, 1280.0, 968.0, 320.0]) {
      testWidgets('$name under a floor of 1280, ${width}px wide: the same boxes', (t) async {
        final built = await _rects(t, _page(width, _built(1280, box())));
        final table = await _rects(t, _page(width, _table(1280, box())));
        expect(table, built);
        expect(built['box']!.width, math.max(width, 1280));
      });
    }
  }

  testWidgets('NEGATIVE: handed the room loose, a box that shrinks to its content is between the floor and the room', (
    t,
  ) async {
    final built = await _rects(t, _page(1440, _built(100, _boxes['shrinking']!()), loose: true));
    final table = await _rects(t, _page(1440, _table(100, _boxes['shrinking']!()), loose: true));
    expect(built['box']!.width, lessThan(1440));
    expect(table['box']!.width, 1440);
  });

  testWidgets('NEGATIVE: a height bound, which a box under it fills', (t) async {
    Widget held(Widget floor) => _page(968, SizedBox(height: 300, child: floor));
    Widget tall() => Align(
      alignment: Alignment.bottomLeft,
      child: Text('Header', key: _k('box')),
    );
    final built = await _rects(t, held(_built(1280, tall())), ['box']);
    final table = await _rects(t, held(_table(1280, tall())), ['box']);
    expect(table['box']!.top, isNot(built['box']!.top));
  });

  testWidgets('NEGATIVE: a table answers no baseline, where a row lines it up on one', (t) async {
    Widget lined(Widget floor) => _page(
      968,
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: floor),
          Text('x', key: _k('x')),
        ],
      ),
    );
    Widget words() => Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Text(_words, key: _k('box')),
    );
    final built = await _rects(t, lined(_built(1280, words())), ['x']);
    final table = await _rects(t, lined(_table(1280, words())), ['x']);
    expect(table['x']!.top, isNot(built['x']!.top));
  });

  testWidgets('NEGATIVE: right to left, the floor hangs off the left, where the table lays its column from it', (
    t,
  ) async {
    final built = await _rects(t, _page(968, _built(1280, _boxes['filling']!()), dir: TextDirection.rtl));
    final table = await _rects(t, _page(968, _table(1280, _boxes['filling']!()), dir: TextDirection.rtl));
    expect(built['box']!.left, 968 - 1280);
    expect(table['box']!.left, isNot(built['box']!.left));
  });
}
