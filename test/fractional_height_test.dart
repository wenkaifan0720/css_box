import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// A room `room` tall, loosened as a placed box's `Align` loosens it, with
// the share at its top.
Widget _room(double room, Widget box) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 100,
      height: room,
      child: Align(alignment: Alignment.topLeft, widthFactor: 1, child: box),
    ),
  ),
);

const _paint = ValueKey('paint');

void main() {
  // fixtures/abs-share-height-floor: what the box PAINTS is held, not just
  // what it reports.
  for (final (room, min, max, tall) in [
    (108.0, 33.0, double.infinity, 108 * .4901), // p1: the share
    (28.0, 33.0, double.infinity, 33.0), // p2: the floor binds past the room
    (108.0, 0.0, 20.0, 20.0), // a cap
    (108.0, 40.0, 20.0, 40.0), // p5: the floor over the cap
  ]) {
    testWidgets('49.01% of $room held to [$min, $max] is $tall', (tester) async {
      await tester.pumpWidget(
        _room(
          room,
          FractionalHeight(
            factor: .4901,
            min: min,
            max: max,
            child: const SizedBox(key: _paint, width: 4),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(_paint)).height, closeTo(tall, 1e-9));
    });
  }

  testWidgets('offered no height the floor holds the content', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            child: FractionalHeight(
              factor: .5,
              min: 30,
              max: 50,
              child: const SizedBox(key: _paint, width: 4, height: 10),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_paint)).height, 30);
  });

  testWidgets('asked, the content is held too', (tester) async {
    final box = FractionalHeight(factor: .5, min: 30, max: 50, child: const SizedBox(width: 4, height: 80));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: IntrinsicHeight(key: _paint, child: box),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_paint)).height, 50);
  });
}
