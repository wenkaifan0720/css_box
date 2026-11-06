import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart' show dryBaselineOf, dryLastBaselineOf;

void main() {
  const style = TextStyle(fontSize: 10, height: 2);
  const strut = StrutStyle(fontSize: 10, height: 2, forceStrutHeight: true);

  /// How far [child] stands its baseline down, first-line and wrapped:
  /// on a baseline-aligned row, a box stands as far UP as its baseline is
  /// down, so the row places its top at the difference.
  Future<(double, double)> baselines(WidgetTester tester, Widget child) async {
    final first = GlobalKey(), last = GlobalKey();
    await tester.pumpWidget(
      Directionality(
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
                child: KeyedSubtree(key: first, child: child),
              ),
              SizedBox(
                width: 60,
                child: LastBaseline(key: last, child: child),
              ),
            ],
          ),
        ),
      ),
    );
    double up(GlobalKey k) => -tester.getTopLeft(find.byKey(k)).dy;
    return (up(first), up(last));
  }

  testWidgets('a column of lines stands on its last one', (tester) async {
    final (first, last) = await baselines(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('one', style: style, strutStyle: strut),
          Text('two', style: style, strutStyle: strut),
        ],
      ),
    );
    expect(last - first, 20);
  });

  testWidgets('a paragraph that wraps stands on its last line', (tester) async {
    final (first, last) = await baselines(tester, const Text('one two six', style: style, strutStyle: strut));
    expect(last - first, 40);
  });

  // A HARD BREAK MAKES A LINE LIKE ANY OTHER (CSS 2.1 9.2.4): a Japanese news site's
  // desktop footer is an inline-block paragraph of two sentences a `<br>`
  // apart (fixtures/inline-block-break-last-baseline). Asked DRY, which a
  // flex line asks before it lays anything out, it stood on its first
  // line -- and Flutter keeps the dry answer for the laid-out question at
  // the same constraints, so the row round it stood it there too.
  testWidgets('a paragraph a hard break ends a line of stands on its last line, asked dry', (tester) async {
    final (first, last) = await baselines(tester, const Text('one\ntwo', style: style, strutStyle: strut));
    expect(last - first, 20);
    const c = BoxConstraints(maxWidth: 60);
    double dryDown() {
      final text = tester.renderObject<RenderParagraph>(find.byType(RichText).last);
      return dryLastBaselineOf(text, c, TextBaseline.alphabetic)! - dryBaselineOf(text, c, TextBaseline.alphabetic)!;
    }

    expect(dryDown(), 20);
    // A line the width wraps is not one the room in the world has: `one
    // two` breaks at 60, and the hard break after it is one line more.
    await baselines(tester, const Text('one two\nsix', style: style, strutStyle: strut));
    expect(dryDown(), 40);
  });

  testWidgets('a flex line that measures a broken paragraph first stands it on its last line', (tester) async {
    final k = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: FlexLine(
              children: [
                FlexCell(
                  mainSizeFraction: 1,
                  child: OverflowBox(
                    minHeight: 0,
                    maxHeight: double.infinity,
                    fit: OverflowBoxFit.deferToChild,
                    alignment: Alignment.topLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // The strut of the line round it: 24 tall, its baseline 18 down.
                        const SizedBox(
                          height: 24,
                          child: Baseline(baseline: 18, baselineType: TextBaseline.alphabetic, child: Text('')),
                        ),
                        LastBaseline(
                          key: k,
                          child: const Text('one\ntwo', style: style, strutStyle: strut),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // Its last baseline is 32.5 down, under the strut's 18: it stands at the top.
    expect(tester.getTopLeft(find.byKey(k)).dy, 0);
  });

  testWidgets('a positioned box is out of the flow and has no say', (tester) async {
    final (first, last) = await baselines(
      tester,
      const Stack(
        children: [
          Text('in', style: style, strutStyle: strut),
          Positioned(
            top: 50,
            left: 0,
            child: Text('out', style: style, strutStyle: strut),
          ),
        ],
      ),
    );
    expect(last, first);
  });
}
