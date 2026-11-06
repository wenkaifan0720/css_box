import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart' show dryLastBaselineOf;

void main() {
  const style = TextStyle(fontSize: 10, height: 2);
  const strut = StrutStyle(fontSize: 10, height: 2, forceStrutHeight: true);

  // On a baseline-aligned row a box stands as far up as its baseline is
  // down (last_baseline_test.dart).
  double laidOut(WidgetTester tester) => -tester.getTopLeft(find.byType(LastBaseline)).dy;

  double dry(WidgetTester tester) {
    final column = tester.renderObject<RenderBox>(find.byType(Column));
    return dryLastBaselineOf(column, const BoxConstraints(maxWidth: 60), TextBaseline.alphabetic)!;
  }

  Widget lines(List<Widget> children) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const SizedBox(height: 100, child: Text('x', style: TextStyle(fontSize: 100))),
          SizedBox(
            width: 60,
            child: LastBaseline(
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        ],
      ),
    ),
  );

  testWidgets('what stands in an IgnoreBaseline has no say in the last baseline, laid out or dry', (tester) async {
    await tester.pumpWidget(lines(const [Text('one', style: style, strutStyle: strut)]));
    final (alone, aloneDry) = (laidOut(tester), dry(tester));
    await tester.pumpWidget(
      lines(const [
        Text('one', style: style, strutStyle: strut),
        IgnoreBaseline(
          child: Text('two', style: style, strutStyle: strut),
        ),
      ]),
    );
    expect(laidOut(tester), alone);
    expect(dry(tester), aloneDry);
    // NEGATIVE: the same line not ignored is the last one.
    await tester.pumpWidget(
      lines(const [Text('one', style: style, strutStyle: strut), Text('two', style: style, strutStyle: strut)]),
    );
    expect(laidOut(tester), alone + 20);
  });

  // A news site's strip links: a paragraph holds an inline block that stands on
  // its last line, and in it an icon in an IgnoreBaseline whose picture
  // arrives in the frame the paragraph lays out again. The icon's box is
  // under a relayout boundary (a tight box) that the frame lays out after
  // the paragraph; the walk that asked it threw, "A RenderObject does not
  // have any constraints before it has been laid out".
  Future<void> race(WidgetTester tester, Widget Function(Widget icon) round) async {
    final arrived = ValueNotifier(false);
    addTearDown(arrived.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'x'),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: LastBaseline(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: arrived,
                        builder: (_, on, __) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // What makes the paragraph lay out again, the same frame.
                            Text(on ? 'one two' : 'one', style: style, strutStyle: strut),
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: round(on ? const ColoredBox(color: Color(0xff000000)) : const SizedBox()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              style: style,
              strutStyle: strut,
            ),
          ),
        ),
      ),
    );
    arrived.value = true;
    await tester.pump();
    expect(tester.takeException(), isNull);
  }

  testWidgets('an icon in an IgnoreBaseline that arrives as the paragraph round it lays out is not asked', (
    tester,
  ) async {
    await race(tester, (icon) => IgnoreBaseline(child: icon));
  });

  testWidgets('a box not laid out yet when the walk comes is passed over, not asked', (tester) async {
    // A tight padding is the relayout boundary here, with no IgnoreBaseline.
    await race(tester, (icon) => Padding(padding: EdgeInsets.zero, child: icon));
  });
}
