// `vertical-align: text-top` (CSS 2.1 10.8.1): the box's top on the top of
// the parent's content area, the parent's ascent over the baseline -- a
// baseline [TopBaseline.at] down from the box's top whatever its height,
// which a paragraph stands on its line's baseline. An `inline-block` of
// words at `text-top` (`fixtures/valign-text-bottom-words` n5), in a
// paragraph and beside a float (`fixtures/float-widget-nested-align`).
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font's ascent is 7.5 and its descent 2.5, rounded to 8 and 3: at
// `line-height: 30` the strut is 17 over the baseline and 13 under it.
const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 10, height: 1, color: Color(0xFF000000));
const _box = Key('box');

WidgetSpan _span(double height, double? at) {
  final box = SizedBox(key: _box, width: 30, height: height);
  return at == null
      ? WidgetSpan(alignment: PlaceholderAlignment.aboveBaseline, baseline: TextBaseline.alphabetic, child: box)
      : WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: TopBaseline(at: at, child: box),
        );
}

Future<RenderFloatText> _float(WidgetTester t, double height, {double? at}) async {
  t.view.physicalSize = const Size(800, 600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
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
                    _span(height, at),
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

Future<void> _paragraph(WidgetTester t, double height, {double? at}) async {
  t.view.physicalSize = const Size(800, 600);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'aaaa '),
                _span(height, at),
                const TextSpan(text: ' bbbb'),
              ],
            ),
            style: _style,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('beside a float the top stands [at] over the baseline, whatever the height', (t) async {
    // 16 tall at 8: its top 8 over the baseline at 17, at 9.
    await _float(t, 16, at: 8);
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(110, 9, 30, 16));
    // 24 tall at 8: its top where it was, 16 of it under the baseline.
    await _float(t, 24, at: 8);
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(110, 9, 30, 24));
  });

  testWidgets('a box that hangs past the strut makes the line its two halves', (t) async {
    // 40 tall at 8: 8 over the baseline and 32 under, past the strut's 13
    // -- a line 17 + 32 = 49 tall, the next one under it.
    final text = await _float(t, 40, at: 8);
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(110, 9, 30, 40));
    expect(text.debugLines.map((l) => l.y), [0, 49]);
  });

  testWidgets('in a paragraph the top stands [at] over the baseline, whatever the height', (t) async {
    // The line's ascent is the larger of the font's 7.5 and the box's 10:
    // the baseline 10 down, the box's top on the line's.
    await _paragraph(t, 16, at: 10);
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(50, 0, 30, 16));
    await _paragraph(t, 30, at: 10);
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(50, 0, 30, 30));
    // At 4, under the font's ascent: the baseline where the font puts it
    // -- where a box at 0 stands its top -- and the top 4 over it.
    await _paragraph(t, 16, at: 0);
    final baseline = t.getRect(find.byKey(_box)).top;
    expect(baseline, greaterThan(4));
    await _paragraph(t, 16, at: 4);
    expect(t.getRect(find.byKey(_box)), Rect.fromLTWH(50, baseline - 4, 30, 16));
  });

  testWidgets('NEGATIVE: a box on its bottom edge stands that on the baseline', (t) async {
    await _float(t, 16);
    expect(t.getRect(find.byKey(_box)), const Rect.fromLTWH(110, 1, 30, 16));
  });
}
