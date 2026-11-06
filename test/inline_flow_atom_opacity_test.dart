// InlineAtom.opacity: an atomic inline's own `opacity`, painted by the
// flow. Outside a blended box it is a layer of its own, as an `Opacity`
// round the child is; inside one (`InlineBox.blendMode`) it is a
// `saveLayer` in the group's, which a pushed layer would not be -- laid
// down in the group, then the group blended whole. Measured in Chrome
// (fixtures/mix-blend-plus-lighter n2, inline-flow-blend n1).
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const green = Color(0xFF00FF00);

Future<(int, int, int) Function(int, int)> shoot(WidgetTester tester, List<InlineNode> kids) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: green,
            child: SizedBox(
              width: 200,
              child: InlineFlow(
                font: const InlineFont(size: 16, ascent: 13, descent: 3, lineHeight: 20, xHeight: 12.8),
                style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
                children: kids,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final data = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final w = image.width;
    image.dispose();
    return (bytes!, w);
  });
  return (int x, int y) {
    final i = (y * data!.$2 + x) * 4;
    return (data.$1.getUint8(i), data.$1.getUint8(i + 1), data.$1.getUint8(i + 2));
  };
}

void main() {
  // `a ` is 0..32; a white box multiplied over the green, 16 on each side
  // of a 20x10 blue atom: the atom 48..68, standing on the baseline (13
  // down), so 3..13.
  const blue = ColoredBox(color: Color(0xFF0000FF), child: SizedBox(width: 20, height: 10));
  List<InlineNode> kids(double opacity, {BlendMode mode = BlendMode.multiply}) => [
    const InlineText('a '),
    InlineBox(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
      blendMode: mode,
      children: [InlineAtom(opacity: opacity, child: blue)],
    ),
  ];

  testWidgets('a faded atom in a blended box is laid down in its group, which is blended whole', (tester) async {
    // Blue at .5 over the white, (127, 127, 255), multiplied into green:
    // (0, 127, 0). An `Opacity` pushed as a layer of its own would be laid
    // over the blended group instead: (127, 127+, 255)-ish, not green.
    final rgb = await shoot(tester, kids(0.5));
    expect(rgb(40, 10), (0, 255, 0), reason: 'the white box alone, multiplied');
    final (r, g, b) = rgb(58, 8);
    expect((r, b), (0, 0));
    expect(g, inInclusiveRange(126, 129));
    expect(tester.layers.whereType<OpacityLayer>(), isEmpty, reason: 'a saveLayer in the group, no layer of its own');
  });

  testWidgets('an atom at no opacity paints nothing', (tester) async {
    final rgb = await shoot(tester, kids(0));
    expect(rgb(58, 8), (0, 255, 0));
  });

  testWidgets('NEGATIVE: in no blended box, a faded atom is a layer of its own', (tester) async {
    final rgb = await shoot(tester, kids(0.5, mode: BlendMode.srcOver));
    expect([for (final l in tester.layers.whereType<OpacityLayer>()) l.alpha], [128]);
    final (r, g, b) = rgb(58, 8);
    expect((r, g), (127, 127), reason: 'blue at .5 over the white');
    expect(b, 255);
  });
}
