// PictureTile draws its child into an image once and repeats it; the image
// is drawn again whenever the child paints differently. A child with layers
// of its own -- a RepaintBoundary round content that changes or loads late,
// an opacity layer -- repaints them without marking the tile, so the tile
// keeps those layers live in a layer of its own and rasterises them again
// in the frame they change, instead of keeping the first picture forever.
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
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

Widget host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 1),
    child: Align(alignment: Alignment.topLeft, child: child),
  ),
);

const shot = ValueKey('shot');

/// A painter that counts its paints.
class Counted extends CustomPainter {
  Counted(this.color);
  final Color color;
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(Counted old) => old.color != color;
}

void main() {
  testWidgets('a tile redraws a child behind a repaint boundary when it changes', (t) async {
    // The review's probe: red, then blue, behind a RepaintBoundary.
    final color = ValueNotifier(const Color(0xffff0000));
    addTearDown(color.dispose);
    await t.pumpWidget(
      host(
        RepaintBoundary(
          key: shot,
          child: SizedBox(
            width: 20,
            height: 20,
            child: PictureTile(
              width: 4,
              height: 4,
              child: RepaintBoundary(
                child: ValueListenableBuilder<Color>(
                  valueListenable: color,
                  builder: (_, c, _) => ColoredBox(color: c),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(await pixel(t, shot, 1, 1), 0xff0000);
    expect(await pixel(t, shot, 17, 17), 0xff0000);
    color.value = const Color(0xff0000ff);
    await t.pump();
    expect(await pixel(t, shot, 1, 1), 0x0000ff);
    expect(await pixel(t, shot, 17, 17), 0x0000ff);
  });

  testWidgets('a tile redraws a child whose opacity layer changes its alpha', (t) async {
    final opacity = ValueNotifier(0.5);
    addTearDown(opacity.dispose);
    await t.pumpWidget(
      host(
        RepaintBoundary(
          key: shot,
          child: ColoredBox(
            color: const Color(0xffffffff),
            child: SizedBox(
              width: 20,
              height: 20,
              child: PictureTile(
                width: 4,
                height: 4,
                child: ValueListenableBuilder<double>(
                  valueListenable: opacity,
                  builder: (_, o, _) => Opacity(
                    opacity: o,
                    child: const ColoredBox(color: Color(0xffff0000)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final half = await pixel(t, shot, 1, 1);
    opacity.value = 0.25;
    await t.pump();
    final quarter = await pixel(t, shot, 1, 1);
    // Red over white: the green and blue channels come up as the alpha goes
    // down.
    expect(half & 0xff, inInclusiveRange(0x70, 0x90));
    expect(quarter & 0xff, inInclusiveRange(0xb0, 0xd0));
  });

  testWidgets('NEGATIVE: a tile over a plain child keeps its image while the child is unchanged', (t) async {
    final painter = Counted(const Color(0xffff0000));
    final other = ValueNotifier(const Color(0xff00ff00));
    addTearDown(other.dispose);
    await t.pumpWidget(
      host(
        RepaintBoundary(
          key: shot,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: PictureTile(width: 4, height: 4, child: CustomPaint(painter: painter)),
              ),
              ValueListenableBuilder<Color>(
                valueListenable: other,
                builder: (_, c, _) => SizedBox(width: 20, height: 20, child: ColoredBox(color: c)),
              ),
            ],
          ),
        ),
      ),
    );
    expect(painter.paints, 1);
    // The tile is painted again with its neighbour: the child is not.
    other.value = const Color(0xff0000ff);
    await t.pump();
    expect(painter.paints, 1);
    expect(await pixel(t, shot, 1, 1), 0xff0000);
    expect(await pixel(t, shot, 25, 1), 0x0000ff);
  });

  testWidgets('NEGATIVE: a tile over a child behind a repaint boundary repaints nothing of it while it is unchanged', (
    t,
  ) async {
    final painter = Counted(const Color(0xffff0000));
    final other = ValueNotifier(const Color(0xff00ff00));
    addTearDown(other.dispose);
    await t.pumpWidget(
      host(
        RepaintBoundary(
          key: shot,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: PictureTile(
                  width: 4,
                  height: 4,
                  child: RepaintBoundary(child: CustomPaint(painter: painter)),
                ),
              ),
              ValueListenableBuilder<Color>(
                valueListenable: other,
                builder: (_, c, _) => SizedBox(width: 20, height: 20, child: ColoredBox(color: c)),
              ),
            ],
          ),
        ),
      ),
    );
    expect(painter.paints, 1);
    other.value = const Color(0xff0000ff);
    await t.pump();
    expect(painter.paints, 1);
    expect(await pixel(t, shot, 1, 1), 0xff0000);
    expect(await pixel(t, shot, 17, 17), 0xff0000);
    expect(await pixel(t, shot, 25, 1), 0x0000ff);
  });

  testWidgets('NEGATIVE: a tile over a plain child that changes is drawn again', (t) async {
    final color = ValueNotifier(const Color(0xffff0000));
    addTearDown(color.dispose);
    await t.pumpWidget(
      host(
        RepaintBoundary(
          key: shot,
          child: SizedBox(
            width: 20,
            height: 20,
            child: PictureTile(
              width: 4,
              height: 4,
              child: ValueListenableBuilder<Color>(
                valueListenable: color,
                builder: (_, c, _) => ColoredBox(color: c),
              ),
            ),
          ),
        ),
      ),
    );
    expect(await pixel(t, shot, 1, 1), 0xff0000);
    color.value = const Color(0xff0000ff);
    await t.pump();
    expect(await pixel(t, shot, 1, 1), 0x0000ff);
  });
}
