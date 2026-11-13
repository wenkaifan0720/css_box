// A STATED WIDTH IN LESS ROOM IS ASKED AT THE ROOM. `FixedWidth` lays its
// child out at its width where the room has it and at the room where it does
// not, as a `SizedBox` of that width does; asked its height in less room than
// its width, it answered at its own width, so its words came out on fewer
// lines than it laid them out on, and an `IntrinsicHeight` round it cut the
// last of them off (`content.dart`, `RenderFixedWidth._laidAt`).
// NEGATIVE: in room as wide as the box or wider, it is asked at its own
// width, and so is a box asked with no width at all.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 14px wide at 14px.
const _style = TextStyle(fontSize: 14, height: 1.0);
const _box = ValueKey('box');
const _after = ValueKey('after');

Widget _page(double room) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: room,
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FixedWidth(key: _box, width: 80, child: Text('aaa bb cccc dd eee ffff gg', style: _style)),
            Container(key: _after, height: 10, color: const Color(0xFF000000)),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('in less room than its width it is asked at the room', (t) async {
    await t.pumpWidget(_page(40));
    expect(t.takeException(), isNull);
    final box = t.renderObject<RenderBox>(find.byKey(_box));
    // Laid out at 40, the words break onto 11 lines: 154 tall.
    expect(box.size, const Size(40, 154));
    expect(box.getMaxIntrinsicHeight(40), 154);
    expect(box.getMinIntrinsicHeight(40), 154);
    // The box after it stands under all of them.
    expect(t.getRect(find.byKey(_after)).top, 154);
  });

  testWidgets('NEGATIVE: in room as wide as it or wider, and with no width at all, it is asked at its own', (t) async {
    await t.pumpWidget(_page(400));
    expect(t.takeException(), isNull);
    final box = t.renderObject<RenderBox>(find.byKey(_box));
    // At 80, seven lines.
    expect(box.size, const Size(80, 98));
    expect(box.getMaxIntrinsicHeight(400), 98);
    expect(box.getMaxIntrinsicHeight(80), 98);
    expect(box.getMaxIntrinsicHeight(double.infinity), 98);
    expect(t.getRect(find.byKey(_after)).top, 98);
  });
}
