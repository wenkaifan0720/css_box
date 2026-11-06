// A CAP AT THE LARGER OF TWO (`FractionalConstraints.otherMaxLarger`):
// `max-width: max(50% + 40px, 70% + 10px)` is 0.5 of the room and 40 under
// 150, and 0.7 of it and 10 past it (css-values-4 10.9); `max(50%, 200px)`
// is 200 under 400 and half of the room past it. Chrome,
// `fixtures/max-width-min-of-two` n6 and `fixtures/pct-max-width-min` c6.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box');

Widget _page(double room, double f1, double o1, double f2, double o2, {double? floor, bool larger = true}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: room,
          child: Align(
            alignment: Alignment.topLeft,
            child: FractionalConstraints(
              minFactor: floor,
              maxFactor: f1,
              maxOffset: o1,
              otherMaxFactor: f2,
              otherMaxOffset: o2,
              otherMaxLarger: larger,
              child: const SizedBox(key: _box, width: double.infinity, height: 10),
            ),
          ),
        ),
      ),
    );

void main() {
  for (final (room, want) in [(100.0, 90.0), (150.0, 115.0), (400.0, 290.0), (700.0, 500.0)]) {
    testWidgets('max(50% + 40px, 70% + 10px) of $room is $want, and never past the room', (t) async {
      await t.pumpWidget(_page(room, 0.5, 40, 0.7, 10));
      expect(t.getSize(find.byKey(_box)).width, closeTo(want < room ? want : room, 1e-9));
    });
  }

  for (final (room, want) in [(300.0, 200.0), (400.0, 200.0), (640.0, 320.0)]) {
    testWidgets('max(50%, 200px) of $room is $want', (t) async {
      await t.pumpWidget(_page(room, 0.5, 0, 0, 200));
      expect(t.getSize(find.byKey(_box)).width, closeTo(want, 1e-9));
    });
  }

  testWidgets('a floor wins over the larger cap', (t) async {
    await t.pumpWidget(_page(300, 0.5, 0, 0, 200, floor: 0.9));
    expect(t.getSize(find.byKey(_box)).width, closeTo(270, 1e-9));
  });

  testWidgets('NEGATIVE: without the flag the smaller of the two binds', (t) async {
    await t.pumpWidget(_page(640, 0.5, 0, 0, 200, larger: false));
    expect(t.getSize(find.byKey(_box)).width, closeTo(200, 1e-9));
  });
}
