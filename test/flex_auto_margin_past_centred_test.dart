// AUTO MARGINS ALONG A ROW ITS ITEMS PASS ARE NOTHING, AND THE LINE'S
// JUSTIFICATION PLACES THE OVERFLOW (css-flexbox-1 9.5, "distribute any
// remaining free space": auto margins take only POSITIVE free space; else
// they are zero and `justify-content` aligns the items, unsafe where nothing
// says `safe`, css-align-3 4.4). A web portal's finance pager on a phone is
// `< 1 2 3 ... 10 >`, `justify-content: center`, the arrows at
// `margin-right: auto` / `margin-left: auto`: 367 wide in a column of 320
// at 360, which Chrome runs 23.5 out of each side. Where the lowerer drops
// that line (`lossy_flex.dart`) it writes the margins as `Spacer`s in a
// `Row`, which is the same boxes only while the items fit: past the room a
// `RenderFlex` has no free space to centre with (`remainingSpace = max(0,
// free)`, flex.dart `performLayout`) and sets them from its start, out of
// the end, with the overflow reported. So the lowerer keeps the line there
// (`_mayPassRoomL`), and fixtures/flex-auto-margin-past-centred is the page.
// This pins the two spellings to the same boxes where the items fit, at
// every justification, and apart past the room for `center` and `end`.
// NEGATIVE: past the room `flex-start`, `space-between` (which falls back to
// the flex start) and `space-around` / `space-evenly` (a safe centre,
// css-align-3 5.3, css_box `_fallback`) all pack at the start, as the `Row`
// does: the stock spelling is theirs even where the items pass the line.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [
  ValueKey('prev'),
  ValueKey('p1'),
  ValueKey('p2'),
  ValueKey('p3'),
  ValueKey('dots'),
  ValueKey('p10'),
  ValueKey('next'),
];

/// The items' own lengths and margins: 32 + 4 x (60 + 8) + (15 + 8) + 40.
const _items = 367.0;

Widget _box(String key, double w, double h) => SizedBox(key: ValueKey(key), width: w, height: h);

/// The pager as css_box lays it out: the arrows' auto margins and the line's
/// justification, as Chrome does.
Widget _line(MainAxisAlignment j) => FlexLine(
  mainAxisAlignment: j,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    FlexCell(autoMargin: const AutoEdges(right: true), child: _box('prev', 32, 36)),
    for (final p in const ['p1', 'p2', 'p3'])
      FlexCell(mainSize: 60, crossSize: 60, margin: const EdgeInsets.symmetric(horizontal: 4), child: _box(p, 60, 60)),
    FlexCell(margin: const EdgeInsets.symmetric(horizontal: 4), child: _box('dots', 15, 24)),
    FlexCell(
      mainSize: 60,
      crossSize: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: _box('p10', 60, 60),
    ),
    FlexCell(autoMargin: const AutoEdges(left: true), child: _box('next', 40, 36)),
  ],
);

/// The pager as the lowerer writes it where it drops the line: the auto
/// margins `Spacer`s in a `Row` of the line's justification.
Widget _row(MainAxisAlignment j) => Row(
  mainAxisSize: MainAxisSize.min,
  mainAxisAlignment: j,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    _box('prev', 32, 36),
    const Spacer(),
    for (final p in const ['p1', 'p2', 'p3'])
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(width: 60, child: _box(p, 60, 60)),
      ),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _box('dots', 15, 24)),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(width: 60, child: _box('p10', 60, 60)),
    ),
    const Spacer(),
    _box('next', 40, 36),
  ],
);

/// The column the pager stands in, [room] wide.
Widget _column(Widget pager, double room) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: room, child: pager),
  ),
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

void main() {
  for (final j in MainAxisAlignment.values) {
    for (final room in const [_items, 400.0, 520.0]) {
      testWidgets('where the items fit the margins take the room: $j in $room', (t) async {
        final line = await _rects(t, _column(_line(j), room));
        expect(t.takeException(), isNull);
        final stock = await _rects(t, _column(_row(j), room));
        expect(t.takeException(), isNull);
        expect(stock, line);
        expect(line[const ValueKey('prev')]!.left, 0);
        expect(line[const ValueKey('next')]!.right, room);
      });
    }
  }

  for (final room in const [320.0, 350.0, 200.0]) {
    testWidgets('a centred line its items pass runs out of both ends, a Row out of its end: in $room', (t) async {
      final line = await _rects(t, _column(_line(MainAxisAlignment.center), room));
      expect(t.takeException(), isNull);
      // The web portal at 360: a column of 320, 23.5 out of each side.
      expect(line[const ValueKey('prev')]!.left, (room - _items) / 2);
      expect(line[const ValueKey('next')]!.right, room + (_items - room) / 2);
      final stock = await _rects(t, _column(_row(MainAxisAlignment.center), room));
      expect(t.takeException(), isA<FlutterError>());
      expect(stock[const ValueKey('prev')]!.left, 0);
      expect(stock, isNot(line));
    });

    testWidgets('a line justified to its end its items pass runs out of its start: in $room', (t) async {
      final line = await _rects(t, _column(_line(MainAxisAlignment.end), room));
      expect(t.takeException(), isNull);
      expect(line[const ValueKey('prev')]!.left, room - _items);
      expect(line[const ValueKey('next')]!.right, room);
      final stock = await _rects(t, _column(_row(MainAxisAlignment.end), room));
      expect(t.takeException(), isA<FlutterError>());
      expect(stock, isNot(line));
    });

    for (final j in const [
      MainAxisAlignment.start,
      MainAxisAlignment.spaceBetween,
      MainAxisAlignment.spaceAround,
      MainAxisAlignment.spaceEvenly,
    ]) {
      testWidgets('NEGATIVE: $j past the room packs at the start, as the Row does: in $room', (t) async {
        final line = await _rects(t, _column(_line(j), room));
        expect(t.takeException(), isNull);
        final stock = await _rects(t, _column(_row(j), room));
        expect(t.takeException(), isA<FlutterError>());
        expect(stock, line);
        expect(line[const ValueKey('prev')]!.left, 0);
        expect(line[const ValueKey('next')]!.right, _items);
      });
    }
  }
}
