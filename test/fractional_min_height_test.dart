import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';

// A room `room` tall, loosened as a block flow that hands its height on
// loosens it (`LooseHeight`), with the box at its top.
Widget _room(double room, Widget box) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 100,
      height: room,
      child: LooseHeight(child: box),
    ),
  ),
);

const _paint = ValueKey('paint');

void main() {
  // fixtures/grid-window-floor-chain: `min-height: 100%` in a stretched
  // grid item, content shorter than the room, at the room and past it.
  for (final (room, factor, offset, content, tall) in [
    (400.0, 1.0, 0.0, 190.0, 400.0), // the floor binds: the room
    (400.0, 0.5, 10.0, 190.0, 210.0), // calc(50% + 10px)
    (400.0, 1.0, 0.0, 640.0, 640.0), // past the room: the content
  ]) {
    testWidgets('$content of content at $factor of $room and $offset is $tall', (tester) async {
      await tester.pumpWidget(
        _room(
          room,
          FractionalMinHeight(
            factor: factor,
            offset: offset,
            child: SizedBox(key: _paint, width: 4, height: content),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(_paint)).height, tall);
      // Past the room it hangs out of the box, which reports the room.
      final box = tester.renderObject<RenderFractionalMinHeight>(find.byType(FractionalMinHeight));
      expect(box.size.height, tall > room ? room : tall);
      expect(box.laidOut.height, tall);
    });
  }

  testWidgets('a floor that binds stretches what the box holds', (tester) async {
    // A grid's `1fr` row takes the room the floor makes (css-grid-1
    // 12.7.1), and stretches the item in it.
    await tester.pumpWidget(
      _room(
        500,
        const FractionalMinHeight(
          factor: 1,
          child: Tracks(
            columns: [TrackSize.flex(1)],
            rows: [TrackSize.auto, TrackSize.flex(1)],
            children: [
              SizedBox(height: 100),
              SizedBox(key: _paint),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_paint)).height, 400);
  });

  testWidgets('offered no height the share is nothing and the box its content', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SingleChildScrollView(
            child: FractionalMinHeight(factor: 1, child: SizedBox(key: _paint, width: 4, height: 10)),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(_paint)).height, 10);
  });

  testWidgets('measured, it is its content', (tester) async {
    await tester.pumpWidget(
      _room(300, const FractionalMinHeight(factor: 1, child: SizedBox(key: _paint, width: 4, height: 25))),
    );
    final box = tester.renderObject<RenderBox>(find.byType(FractionalMinHeight));
    expect(box.getMaxIntrinsicHeight(100), 25);
    expect(box.getMinIntrinsicHeight(100), 25);
    expect(box.getDryLayout(const BoxConstraints(maxWidth: 100, maxHeight: 300)).height, 300);
  });
}
