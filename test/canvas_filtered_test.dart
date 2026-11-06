// CanvasFiltered: a `filter` inside a box with a `mix-blend-mode`. CSS
// blends the group the filter is in (compositing-1 5.1); an
// `ImageFiltered` there is a layer of its own, which the `saveLayer` the
// [Blend] makes does not hold, so the box was drawn over what is behind it
// in the normal way, its blend and its opacity lost.
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const green = Color(0xFF00FF00), red = Color(0xFFFF0000);

Future<(int, int, int) Function(int, int)> shoot(WidgetTester tester, Widget box) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: green,
          child: SizedBox(
            width: 200,
            height: 100,
            child: Align(alignment: Alignment.topLeft, child: box),
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

final blur = ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2, tileMode: TileMode.decal);

void main() {
  testWidgets('a filtered box in a blend is blended with the rest of the group', (tester) async {
    // Red multiplied into green is black, at the box's middle where the
    // blur leaves it red.
    final rgb = await shoot(
      tester,
      Blend(
        mode: BlendMode.multiply,
        child: CanvasFiltered(
          imageFilter: blur,
          child: const SizedBox(width: 100, height: 100, child: ColoredBox(color: red)),
        ),
      ),
    );
    expect(rgb(50, 50), (0, 0, 0), reason: 'red times green');
    expect(rgb(150, 50), (0, 255, 0), reason: 'the backdrop past it');
    expect(tester.layers.whereType<ImageFilterLayer>(), isEmpty, reason: 'filtered on the canvas');
  });

  testWidgets('NEGATIVE: an ImageFiltered in a blend is a layer the blend does not hold', (tester) async {
    final rgb = await shoot(
      tester,
      Blend(
        mode: BlendMode.multiply,
        child: ImageFiltered(
          imageFilter: blur,
          child: const SizedBox(width: 100, height: 100, child: ColoredBox(color: red)),
        ),
      ),
    );
    expect(rgb(50, 50), (255, 0, 0), reason: 'drawn over the green, not multiplied');
  });

  testWidgets('it filters as ImageFiltered does', (tester) async {
    Future<List<(int, int, int)>> row(Widget Function(Widget) filtered) async {
      final rgb = await shoot(tester, filtered(const SizedBox(width: 100, height: 100, child: ColoredBox(color: red))));
      return [
        for (final x in [90, 96, 98, 100, 102, 104, 110]) rgb(x, 50),
      ];
    }

    final layer = await row((c) => ImageFiltered(imageFilter: blur, child: c));
    final canvas = await row((c) => CanvasFiltered(imageFilter: blur, child: c));
    expect(layer[3], isNot((255, 0, 0)), reason: 'the edge is blurred');
    for (var i = 0; i < layer.length; i++) {
      for (var ch = 0; ch < 3; ch++) {
        final a = [layer[i].$1, layer[i].$2, layer[i].$3][ch], b = [canvas[i].$1, canvas[i].$2, canvas[i].$3][ch];
        expect((a - b).abs(), lessThanOrEqualTo(1), reason: 'pixel $i channel $ch: $layer vs $canvas');
      }
    }
  });

  testWidgets('what pushes a layer in it is filtered in a layer', (tester) async {
    // The canvas cannot hold the child's layer, so the box pushes one, as
    // ImageFiltered does, and still filters what is in it.
    final rgb = await shoot(
      tester,
      CanvasFiltered(
        imageFilter: ColorMatrix.invert(1).toFilter(),
        child: const SizedBox(
          width: 100,
          height: 100,
          child: Opacity(opacity: 0.5, child: ColoredBox(color: red)),
        ),
      ),
    );
    expect(tester.layers.whereType<ImageFilterLayer>(), hasLength(1));
    // Red at half, inverted to cyan at half, over the green.
    final (r, g, b) = rgb(50, 50);
    expect(r, 0);
    expect(g, 255);
    expect(b, inInclusiveRange(125, 130));
  });
}
