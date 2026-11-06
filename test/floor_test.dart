import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

Widget _page(double floor, double content) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FloorBox(
            floor: floor,
            margin: 30,
            child: KeyedSubtree(
              key: const ValueKey('box'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [SizedBox(height: content)],
              ),
            ),
          ),
          const SizedBox(height: 30),
          const SizedBox(key: ValueKey('next'), height: 10),
        ],
      ),
    ),
  ),
);

void main() {
  // fixtures/min-height-end-margin: the box, and where the next one starts.
  for (final (floor, box, next) in [(100.0, 100.0, 100.0), (40.0, 40.0, 40.0), (10.0, 20.0, 50.0)]) {
    testWidgets('a floor of $floor over 20 of content and a 30px margin', (tester) async {
      await tester.pumpWidget(_page(floor, 20));
      expect(tester.getSize(find.byKey(const ValueKey('box'))).height, box);
      expect(tester.getTopLeft(find.byKey(const ValueKey('next'))).dy, next);
    });
  }

  testWidgets('measured the way it lays out', (tester) async {
    await tester.pumpWidget(_page(40, 20));
    final r = tester.renderObject<RenderBox>(find.byType(FloorBox));
    expect(r.getMinIntrinsicHeight(300), 10);
    expect(r.getMaxIntrinsicHeight(300), 10);
  });
}
