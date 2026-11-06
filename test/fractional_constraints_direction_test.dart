import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box'), _room = ValueKey('room');

// fixtures/width-stretch-atomic n3: `width: stretch; min-width: 340px` in a
// 300px block -- the box handed the room tight, its floor past it.
Widget _in(TextDirection d, {double floor = 340}) => Directionality(
  textDirection: d,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      key: _room,
      width: 300,
      height: 20,
      child: FractionalConstraints(
        minFactor: 0,
        minOffset: floor,
        textDirection: d,
        child: const SizedBox(key: _box, height: 20),
      ),
    ),
  ),
);

void main() {
  testWidgets('under ltr the floor hangs off the right', (tester) async {
    await tester.pumpWidget(_in(TextDirection.ltr));
    expect(tester.getRect(find.byKey(_box)), const Rect.fromLTWH(0, 0, 340, 20));
    expect(tester.getSize(find.byKey(_room)).width, 300);
  });

  testWidgets('under rtl it keeps its right edge on the room\'s and hangs off the left', (tester) async {
    await tester.pumpWidget(_in(TextDirection.rtl));
    expect(tester.getRect(find.byKey(_box)), const Rect.fromLTWH(-40, 0, 340, 20));
    expect(tester.getSize(find.byKey(_room)).width, 300);
  });

  testWidgets('a floor inside the room moves nothing', (tester) async {
    await tester.pumpWidget(_in(TextDirection.rtl, floor: 72));
    expect(tester.getRect(find.byKey(_box)), const Rect.fromLTWH(0, 0, 300, 20));
  });
}
