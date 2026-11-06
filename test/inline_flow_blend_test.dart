// InlineBox.blendMode: `mix-blend-mode` on an inline box (compositing-1
// 5.1). The box and all it holds are one group, as a faded box is, laid
// down at its opacity and blended whole into what is under it -- one
// `saveLayer` restored in the mode (the opacity first, then the blend,
// 3.3). A box faded inside it is a `saveLayer` too: a layer pushed inside
// the group's is no part of it. Measured in Chrome
// (fixtures/opacity-apart n9: a faded, multiplied frame a line breaks
// round).
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
  // `a ` is 0..32; an empty box padded 16 a side is 32..64 on the one line,
  // its content area 2..18 down (half-leading 2), and ` b` after it 64..96
  // -- a word after the box, so the space before it is no space at the end
  // of the line.
  InlineBox chip({
    double opacity = 1,
    BlendMode mode = BlendMode.srcOver,
    Color color = const Color(0xFFFF0000),
    List<InlineNode> kids = const [],
  }) => InlineBox(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: color),
    opacity: opacity,
    blendMode: mode,
    children: kids,
  );

  testWidgets('a blended box is blended into what is under it', (tester) async {
    var rgb = await shoot(tester, [const InlineText('a '), chip(), const InlineText(' b')]);
    expect(rgb(48, 10), (255, 0, 0), reason: 'painted over the green');
    rgb = await shoot(tester, [const InlineText('a '), chip(mode: BlendMode.multiply), const InlineText(' b')]);
    expect(rgb(48, 10), (0, 0, 0), reason: 'red times green');
    expect(rgb(100, 10), (0, 255, 0), reason: 'the backdrop past it');
    expect(tester.layers.whereType<OpacityLayer>(), isEmpty, reason: 'one saveLayer, no layer of its own');
  });

  testWidgets('its opacity goes first, then the blend', (tester) async {
    // Red at .5 multiplied into green: Sc.Dc + Dc(1 - Sa) = (0, .5, 0).
    final rgb = await shoot(tester, [
      const InlineText('a '),
      chip(opacity: 0.5, mode: BlendMode.multiply),
      const InlineText(' b'),
    ]);
    final (r, g, b) = rgb(48, 10);
    expect((r, b), (0, 0));
    expect(g, inInclusiveRange(126, 129));
  });

  testWidgets('a box faded inside it is laid down in its group, which is blended whole', (tester) async {
    // A white box multiplied: green where only it is. Inside it a blue box
    // at .5 over the white, (127, 127, 255), multiplied: (0, 127, 0).
    final rgb = await shoot(tester, [
      const InlineText('a '),
      chip(
        mode: BlendMode.multiply,
        color: const Color(0xFFFFFFFF),
        kids: [chip(opacity: 0.5, color: const Color(0xFF0000FF))],
      ),
      const InlineText(' b'),
    ]);
    expect(rgb(40, 10), (0, 255, 0), reason: 'the white box alone');
    final (r, g, b) = rgb(64, 10);
    expect((r, b), (0, 0));
    expect(g, inInclusiveRange(126, 129));
    expect(tester.layers.whereType<OpacityLayer>(), isEmpty, reason: 'the faded box is a saveLayer in the group');
  });

  testWidgets('NEGATIVE: a box faded and not blended is still a layer of its own', (tester) async {
    await shoot(tester, [const InlineText('a '), chip(opacity: 0.5), const InlineText(' b')]);
    expect([for (final l in tester.layers.whereType<OpacityLayer>()) l.alpha], [128]);
  });
}
