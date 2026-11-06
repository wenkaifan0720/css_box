// InlineFlow hit-tests its children in the reverse of the order it paints
// them: a moved or faded box is painted after the rest of the flow (CSS 2.1
// appendix E, step 8), so where it is drawn over a later atomic inline, the
// press goes to it -- the control on top -- not to the one under it. The
// same order is the flow's [PaintOrder], for what walks the page's paint.
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:css_box/src/paint_order.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<int> pixel(WidgetTester t, Key key, int x, int y) async {
  final r = t.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await t.runAsync(() async {
    final i = await r.toImage(pixelRatio: 1);
    final b = (await i.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (y * i.width + x) * 4;
    final rgb = (b.getUint8(offset) << 16) | (b.getUint8(offset + 1) << 8) | b.getUint8(offset + 2);
    i.dispose();
    return rgb;
  }))!;
}

const shot = ValueKey('shot');
const font = InlineFont(size: 10, ascent: 8, descent: 2, lineHeight: 20);

Future<void> lay(WidgetTester t, List<InlineNode> kids) => t.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 1),
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: shot,
          child: SizedBox(
            width: 100,
            child: InlineFlow(font: font, children: kids),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  var hit = '';
  Widget button(String name, Color color) => GestureDetector(
    onTap: () => hit = name,
    child: SizedBox(width: 20, height: 20, child: ColoredBox(color: color)),
  );
  setUp(() => hit = '');

  testWidgets('a tap goes to the moved box painted over the atomic inline after it', (t) async {
    // The review's probe: red moved 20px on, over blue; red is drawn on top.
    await lay(t, [
      InlineBox(
        offset: const Offset(20, 0),
        children: [InlineAtom(child: button('front', const Color(0xffff0000)))],
      ),
      InlineAtom(child: button('back', const Color(0xff0000ff))),
    ]);
    final rgb = await pixel(t, shot, 25, 10);
    await t.tapAt(t.getTopLeft(find.byKey(shot)) + const Offset(25, 10));
    expect(rgb, 0xff0000);
    expect(hit, 'front');
  });

  testWidgets('a faded box is painted, and hit, over what follows it too', (t) async {
    await lay(t, [
      InlineBox(
        offset: const Offset(20, 0),
        opacity: 0.5,
        children: [InlineAtom(child: button('front', const Color(0xffff0000)))],
      ),
      InlineAtom(child: button('back', const Color(0xff0000ff))),
    ]);
    await t.tapAt(t.getTopLeft(find.byKey(shot)) + const Offset(25, 10));
    expect(hit, 'front');
  });

  testWidgets('the paint order puts the moved box last, and the hit test follows it', (t) async {
    await lay(t, [
      InlineBox(
        offset: const Offset(20, 0),
        children: [InlineAtom(child: button('front', const Color(0xffff0000)))],
      ),
      InlineAtom(child: button('back', const Color(0xff0000ff))),
    ]);
    final flow = t.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
    final held = <RenderObject>[];
    flow.visitChildren(held.add);
    expect(childrenInPaintOrder(flow), [held[1], held[0]]);
  });

  testWidgets('NEGATIVE: atomic inlines side by side each take their own taps', (t) async {
    await lay(t, [
      InlineAtom(child: button('first', const Color(0xffff0000))),
      InlineAtom(child: button('second', const Color(0xff0000ff))),
    ]);
    final flow = t.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
    final held = <RenderObject>[];
    flow.visitChildren(held.add);
    expect(childrenInPaintOrder(flow), held);
    await t.tapAt(t.getTopLeft(find.byKey(shot)) + const Offset(5, 10));
    expect(hit, 'first');
    await t.tapAt(t.getTopLeft(find.byKey(shot)) + const Offset(25, 10));
    expect(hit, 'second');
  });

  testWidgets('NEGATIVE: a box moved clear of the others still takes its own taps', (t) async {
    await lay(t, [
      InlineBox(
        offset: const Offset(40, 0),
        children: [InlineAtom(child: button('moved', const Color(0xffff0000)))],
      ),
      InlineAtom(child: button('still', const Color(0xff0000ff))),
    ]);
    await t.tapAt(t.getTopLeft(find.byKey(shot)) + const Offset(45, 10));
    expect(hit, 'moved');
    await t.tapAt(t.getTopLeft(find.byKey(shot)) + const Offset(25, 10));
    expect(hit, 'still');
  });
}
