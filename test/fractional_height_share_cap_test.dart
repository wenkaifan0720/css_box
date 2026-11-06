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
  // fixtures/abs-height-cap-share h4: `height: 100%; max-height: calc(50% +
  // 20px)`, two shares of the same block that cross at 40px.
  for (final (room, min, tall) in [
    (240.0, 0.0, 140.0), // the cap binds past 40
    (30.0, 0.0, 30.0), // the room binds under 40
    (240.0, 150.0, 150.0), // the floor wins over the cap
  ]) {
    testWidgets('100% of $room under calc(50% + 20px), floored at $min, is $tall', (tester) async {
      await tester.pumpWidget(
        _room(
          room,
          FractionalHeight(
            factor: 1,
            min: min,
            maxFactor: .5,
            maxOffset: 20,
            child: const SizedBox(key: _paint, width: 4),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(_paint)).height, closeTo(tall, 1e-9));
    });
  }

  testWidgets('a length cap beside the share cap: the smaller binds', (tester) async {
    await tester.pumpWidget(
      _room(
        240,
        FractionalHeight(
          factor: 1,
          max: 100,
          maxFactor: .5,
          maxOffset: 20,
          child: const SizedBox(key: _paint, width: 4),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_paint)).height, 100);
  });

  testWidgets('asked, the share cap is none: there is no room to take it of', (tester) async {
    final box = FractionalHeight(factor: .5, maxFactor: .1, child: const SizedBox(width: 4, height: 80));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: IntrinsicHeight(key: _paint, child: box),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_paint)).height, 80);
  });
}
