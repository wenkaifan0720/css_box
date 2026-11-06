import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

void main() {
  // AN EDGE AT NO DEPTH IS NO BASELINE (`RenderEdgeBaseline`). A recipe
  // site's pages head with a `min-height: 280px` flex row aligned `baseline`
  // round an empty block of `height: 100%`: an `IntrinsicHeight` round a
  // `Row` round a fill (`SizedBox(height: double.infinity)`) on its edge.
  // The row asked the fill's baseline under no height to sum its intrinsic
  // depth, the edge answered infinity, and the page threw "A Stack requires
  // bounded constraints" on every recipe route.
  Widget row(Key key) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      SizedBox(
        key: key,
        height: double.infinity,
        child: const EdgeBaseline(child: SizedBox(width: 10)),
      ),
    ],
  );

  testWidgets('a fill on its edge in a baseline row a floor deepens is the floor deep', (tester) async {
    final fill = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 280),
            child: IntrinsicHeight(child: row(fill)),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(fill)), const Size(10, 280));
    // Asked dry, as a grid measures its items, the same.
    final measured = tester.renderObject<RenderBox>(find.byType(IntrinsicHeight));
    expect(measured.getDryLayout(const BoxConstraints(maxWidth: 100, minHeight: 280)), const Size(100, 280));
    // The fill asked under no height hands its edge none: no baseline.
    final box = tester.renderObject<RenderBox>(find.byKey(fill));
    expect(box.getDryBaseline(const BoxConstraints(maxWidth: 100), TextBaseline.alphabetic), isNull);
  });

  testWidgets('NEGATIVE: under a height with a bound the edge is the baseline', (tester) async {
    final fill = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(height: 50, child: row(fill)),
        ),
      ),
    );
    final edge = tester.renderObject<RenderBox>(find.byType(EdgeBaseline));
    expect(edge.getDryBaseline(const BoxConstraints.tightFor(height: 50), TextBaseline.alphabetic), 50);
    expect(tester.getSize(find.byKey(fill)), const Size(10, 50));
  });
}
