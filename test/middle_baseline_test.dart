// `vertical-align: middle` (CSS 2.1 10.8.1): the box's midpoint on the
// parent's baseline plus half the parent's x-height -- a baseline half the
// box's height and [MiddleBaseline.over] down from its top, which the
// float flow's paragraph stands on its own line's baseline. A Japanese news site's
// section link, an `inline-block` at `middle` beside a float
// (`fixtures/float-widget-nested-align` n1).
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font's ascent is 7.5 and its descent 2.5, rounded to 8 and 3: at
// `line-height: 30` the strut is 17 over the baseline and 13 under it.
const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 1, color: Color(0xFF000000));
const _box = Key('box');

Future<RenderFloatText> _pump(WidgetTester t, double height, {double? over}) async {
  t.view.physicalSize = const Size(800, 600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  final box = SizedBox(key: _box, width: 30, height: height);
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          child: FloatFlow(
            children: [
              const FloatSlot(float: FloatSide.left, width: 60, height: 30, child: SizedBox(width: 60, height: 30)),
              FloatText(
                TextSpan(
                  children: [
                    const TextSpan(text: 'aaaa '),
                    over == null
                        ? WidgetSpan(
                            alignment: PlaceholderAlignment.aboveBaseline,
                            baseline: TextBaseline.alphabetic,
                            child: box,
                          )
                        : WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: MiddleBaseline(over: over, child: box),
                          ),
                    const TextSpan(text: ' bbbb cccc dddd'),
                  ],
                ),
                style: _style,
                lineHeight: 30,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return t.renderObject<RenderFloatText>(find.byType(FloatText));
}

void main() {
  testWidgets('the middle stands [over] above the baseline', (t) async {
    // 16 tall at 2 over: 10 of it over the baseline at 17, its top at 7.
    await _pump(t, 16, over: 2);
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(110, 7, 30, 16));
    await _pump(t, 16, over: 4);
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(110, 5, 30, 16));
  });

  testWidgets('a box taller than the strut makes the line its two halves', (t) async {
    // 40 tall at 2 over: 22 over the baseline and 18 under, past the
    // strut's 17 and 13 -- a line 40 tall, the next one under it.
    final text = await _pump(t, 40, over: 2);
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(110, 0, 30, 40));
    expect(text.debugLines.map((l) => l.y), [0, 40]);
  });

  testWidgets('NEGATIVE: a box on its bottom edge stands that on the baseline', (t) async {
    await _pump(t, 16);
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(110, 1, 30, 16));
  });
}
