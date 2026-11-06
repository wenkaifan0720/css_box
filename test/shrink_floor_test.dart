import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A CLIP WHOSE FLOOR IS TOLD GIVES WAY TO IT, AND STILL ANSWERS ITS CONTENT.
// A flex item that is a scroll container (or clips and states `min-width`)
// has that floor in its own line (css-flexbox-1 4.5) and contributes its
// content to whatever measures it (9.9.1). clip-floors-its-track's
// scroller of four 120px cards beside a label, in a row of 360: the one
// item the row lets give way, a `ShrinkWidth` round a plain clip, read its
// least off the cards and held 498.
void main() {
  Widget cards() => const ClipRect(child: SizedBox(width: 498, height: 40));

  Future<RenderBox> lay(WidgetTester tester, Widget shrink, double room) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: room,
            child: Row(
              children: [
                const SizedBox(width: 120, height: 40),
                Flexible(child: shrink),
              ],
            ),
          ),
        ),
      ),
    );
    return tester.renderObject<RenderBox>(find.byType(ShrinkWidth));
  }

  // The box reports the room it is offered (`spill`); the child it lays out
  // is the width the page draws.
  double drawn(WidgetTester tester) => tester.renderObject<RenderBox>(find.byType(ClipRect)).size.width;

  testWidgets('told a floor of nothing, it gives way to the room, and answers its content', (tester) async {
    final r = await lay(tester, ShrinkWidth(spill: true, floor: 0, child: cards()), 360);
    expect(drawn(tester), 240);
    expect(r.getMinIntrinsicWidth(double.infinity), 498);
    expect(r.getMaxIntrinsicWidth(double.infinity), 498);
  });

  testWidgets('told a floor, it keeps its content where the room holds it', (tester) async {
    await lay(tester, ShrinkWidth(spill: true, floor: 0, child: cards()), 800);
    expect(drawn(tester), 498);
  });

  testWidgets('told a floor above nothing, it stops at it', (tester) async {
    await lay(tester, ShrinkWidth(spill: true, floor: 300, child: cards()), 360);
    expect(drawn(tester), 300);
  });

  testWidgets('NEGATIVE: told no floor, it keeps its content\'s min-content and hangs out of the room', (tester) async {
    await lay(tester, ShrinkWidth(spill: true, child: cards()), 360);
    expect(drawn(tester), 498);
  });
}
