import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

void main() {
  const style = TextStyle(fontSize: 10, height: 2);
  const strut = StrutStyle(fontSize: 10, height: 2, forceStrutHeight: true);

  // A news site's section frames at 360: a baseline row stands on an inline block
  // that stands on its last line, and a line in it is under a relayout
  // boundary. Its text changes in the frame the row is laid out again at a
  // new width; the box between them is handed the same constraints and is
  // not laid out again, so the frame lays the line out after the row -- and
  // the walk asked the line it had not laid out yet: "Failed assertion:
  // '!debugNeedsLayout'" (RenderParagraph.computeDistanceToActualBaseline).
  testWidgets('a line whose text changes under a relayout boundary is laid out before the walk reads it', (
    tester,
  ) async {
    final n = ValueNotifier(0);
    addTearDown(n.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: ValueListenableBuilder<int>(
            valueListenable: n,
            builder: (_, v, __) => SizedBox(
              width: 200.0 + v,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Taller than the block: the block stands as far up as its baseline is down.
                  const SizedBox(height: 100, child: Text('x', style: TextStyle(fontSize: 100))),
                  Expanded(
                    child: LastBaseline(
                      key: const Key('block'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('one', style: style, strutStyle: strut),
                          SizedBox(
                            width: 60,
                            height: 60,
                            // Handed the same tight box at every width: not laid out again.
                            child: Padding(
                              padding: EdgeInsets.zero,
                              // Tight too, so a relayout boundary: the line's change stops here.
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Text(v == 0 ? 'two' : 'two four', style: style, strutStyle: strut),
                              ),
                            ),
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
      ),
    );
    double up() => -tester.getTopLeft(find.byKey(const Key('block'))).dy;
    final before = up();
    n.value = 1;
    await tester.pump();
    expect(tester.takeException(), isNull);
    // 'two four' wraps to two lines in 60: the block's last line is 20
    // lower, and the row stands it 20 higher.
    expect(up(), before + 20);
  });
}
