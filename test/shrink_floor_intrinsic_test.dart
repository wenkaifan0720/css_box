// A FIT-CONTENT BOX TOLD A FLOOR OF NOTHING IS AN `IntrinsicWidth`, AS LAID
// OUT. Its fit is min(max(floor, room), most) (css-sizing-3 5.1 with the
// floor a stated `min-width` puts in place of the automatic minimum,
// css-flexbox-1 4.5): under a floor of 0, min(room, most), never past the
// room -- what `RenderIntrinsicWidth` lays its child out at, its most
// clamped to the constraints. The stock pass writes it so where nothing asks
// its least width. A price-table site's `min-width: 0`
// menu items, their labels past the 32 the row leaves them
// (`fixtures/shrink-spill-room` p1, p4). This pins the two to the same boxes
// in a share of a row narrower than a word, between the words and the line,
// and past the line, and handed a tight width.
// NEGATIVE: told no floor, the box stands at its content's least where the
// room is less, past the room, and the `IntrinsicWidth` is held to it.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 10px wide at 10px.
const _style = TextStyle(fontSize: 10, height: 1.0);
const _content = ValueKey('content');

/// An 8px box and the item, in a row of [room] + 8.
Widget _row(Widget item, double room, {bool tight = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: room + 8,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8, height: 8),
          tight ? Expanded(child: item) : Flexible(child: item),
        ],
      ),
    ),
  ),
);

final _contents = <String, Widget Function()>{
  'words that break': () => const Text('Prediction Markets', key: _content, style: _style),
  'one line': () => const Text('Prediction Markets', key: _content, softWrap: false, style: _style),
  'a box of pixels': () => const SizedBox(key: _content, width: 60, height: 12),
};

Future<Rect> _rect(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return t.getRect(find.byKey(_content));
}

void main() {
  for (final MapEntry(key: name, value: content) in _contents.entries) {
    for (final room in const [20.0, 32.0, 120.0, 300.0]) {
      for (final tight in const [false, true]) {
        testWidgets('$name in ${tight ? 'a tight' : 'a loose'} $room: the IntrinsicWidth stands where the box does', (
          t,
        ) async {
          final box = await _rect(t, _row(ShrinkWidth(spill: true, floor: 0, child: content()), room, tight: tight));
          final stock = await _rect(t, _row(IntrinsicWidth(child: content()), room, tight: tight));
          expect(stock, box);
        });
      }
    }
  }

  testWidgets('NEGATIVE: told no floor, the box stands at its least past the room', (t) async {
    // `Prediction`, 100 wide, in 32.
    final box = await _rect(t, _row(ShrinkWidth(spill: true, child: _contents['words that break']!()), 32));
    final stock = await _rect(t, _row(IntrinsicWidth(child: _contents['words that break']!()), 32));
    expect(box.width, 100);
    expect(stock.width, 32);
  });
}
