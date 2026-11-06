import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A PROXY OF CSS_BOX'S ANSWERS ITS CHILD'S DRY BASELINE, AND NONE WHERE THE
// CHILD HAS NONE. From Flutter 3.41 to 3.47 `RenderProxyBoxMixin` asks
// `RenderBox.computeDryBaseline` instead, which asserts in debug
// (flutter#189711), and a row asks every item it holds: a `Compressible`
// round an `IgnoreBaseline` threw wherever a row or a paragraph asked
// across it.
Widget _page(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 300, child: child),
  ),
);

void main() {
  const room = BoxConstraints(maxWidth: 300, maxHeight: 600);

  testWidgets('round a box with no baseline, it answers none', (tester) async {
    await tester.pumpWidget(
      _page(const Compressible(natural: 10, child: IgnoreBaseline(child: SizedBox(width: 10, height: 10)))),
    );
    final box = tester.renderObject<RenderBox>(find.byType(Compressible));
    expect(box.getDryBaseline(room, TextBaseline.alphabetic), isNull);
  });

  testWidgets('a row that asks across it stands on its text', (tester) async {
    await tester.pumpWidget(
      _page(
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ag', style: TextStyle(fontSize: 20)),
            Compressible(natural: 10, child: IgnoreBaseline(child: SizedBox(width: 10, height: 10))),
          ],
        ),
      ),
    );
    final row = tester.renderObject<RenderBox>(find.byType(Row));
    final text = tester.renderObject<RenderBox>(find.byType(RichText));
    expect(row.getDryBaseline(room, TextBaseline.alphabetic), text.getDryBaseline(room, TextBaseline.alphabetic));
  });

  testWidgets('NEGATIVE: round text, it answers the text\'s', (tester) async {
    await tester.pumpWidget(_page(const Compressible(natural: 50, child: Text('Ag', style: TextStyle(fontSize: 20)))));
    final box = tester.renderObject<RenderBox>(find.byType(Compressible));
    final text = tester.renderObject<RenderBox>(find.byType(RichText));
    final b = box.getDryBaseline(room, TextBaseline.alphabetic);
    expect(b, isNotNull);
    expect(b, text.getDryBaseline(room, TextBaseline.alphabetic));
  });
}
