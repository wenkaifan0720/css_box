// A CAP AT THE SMALLER OF TWO SHARES THAT EACH ADD A LENGTH
// (`FractionalConstraints.otherMaxFactor`): `max-width: min(50% + 40px, 70%
// + 10px)` is 0.7 of the room and 10 under 150, and 0.5 of it and 40 past
// it (css-values-4 10.9). Chrome, `fixtures/max-width-min-of-two` p5: a
// `width: 100%` box under the cap in a 60% column is 0.5 of the column and
// 40 at every width the fixture is laid out at.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box');

Widget _page(double room, {double? floor, bool other = true}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: room,
      child: Align(
        alignment: Alignment.topLeft,
        child: FractionalConstraints(
          minFactor: floor,
          maxFactor: 0.5,
          maxOffset: 40,
          otherMaxFactor: other ? 0.7 : null,
          otherMaxOffset: other ? 10 : 0,
          child: const SizedBox(key: _box, width: double.infinity, height: 10),
        ),
      ),
    ),
  ),
);

void main() {
  for (final (room, want) in [(100.0, 80.0), (150.0, 115.0), (400.0, 240.0), (700.0, 390.0)]) {
    testWidgets('min(50% + 40px, 70% + 10px) of $room is $want', (t) async {
      await t.pumpWidget(_page(room));
      expect(t.getSize(find.byKey(_box)).width, closeTo(want, 1e-9));
    });
  }

  testWidgets('a floor wins over either cap', (t) async {
    // 90% of 100 is 90, over the second cap's 80.
    await t.pumpWidget(_page(100, floor: 0.9));
    expect(t.getSize(find.byKey(_box)).width, closeTo(90, 1e-9));
  });

  testWidgets('NEGATIVE: without the second cap the first alone binds', (t) async {
    // Half of 100 and 40 is 90, where the second cap would have made it 80.
    await t.pumpWidget(_page(100, other: false));
    expect(t.getSize(find.byKey(_box)).width, closeTo(90, 1e-9));
  });
}
